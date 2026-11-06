/*
 * Движок текстового квеста: экраны, проверки d20, здоровье, предметы,
 * автосохранение и «Книга концовок». Истории лежат в js/stories/*.js
 * и регистрируются через window.STORY.add(...).
 */
(function () {
  'use strict';

  var STAT = { str: 'СИЛ', dex: 'ЛОВ', int: 'ИНТ', cha: 'ХАР' };
  var STAT_FULL = { str: 'Сила', dex: 'Ловкость', int: 'Интеллект', cha: 'Харизма' };
  var KIND = { good: 'Светлый финал', bad: 'Мрачный финал', odd: 'Странный финал', death: 'Встреча со стажёром' };
  var SAVE_KEY = 'dv.save.v1', ENDINGS_KEY = 'dv.endings.v1', SETTINGS_KEY = 'dv.settings.v1';

  var app = document.getElementById('app');
  var heroes = window.STORY.list;
  var state = null;       // текущая партия
  var screen = 'title';   // title | heroes | hero | play | book
  var overlayEl = null;
  var overlayClose = null;
  var busy = false;       // идёт бросок / смена сцены

  // ---------- Хранилище ----------
  var store = {
    get: function (k, d) { try { var v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* приватный режим */ } },
    del: function (k) { try { localStorage.removeItem(k); } catch (e) { /* ignore */ } }
  };
  var settings = store.get(SETTINGS_KEY, { music: true, sfx: true });
  AUDIO.setMusic(false);
  AUDIO.setSfx(settings.sfx);

  function foundEndings() { return store.get(ENDINGS_KEY, {}); }
  function markEnding(heroId, endId) {
    var all = foundEndings();
    all[heroId] = all[heroId] || [];
    var isNew = all[heroId].indexOf(endId) < 0;
    if (isNew) all[heroId].push(endId);
    store.set(ENDINGS_KEY, all);
    return isNew;
  }

  // ---------- Утилиты ----------
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function arr(v) { return v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]; }
  function fmt(s) { return esc(s).replace(/\*([^*]+)\*/g, '<i>$1</i>'); }
  function paras(list) {
    return arr(list).filter(Boolean).map(function (p) {
      return '<p' + (/^—/.test(p) ? ' class="say"' : '') + '>' + fmt(p) + '</p>';
    }).join('');
  }
  function mod(v) { return (v > 0 ? '+' : v < 0 ? '−' : '±') + Math.abs(v); }
  function hero() { return state && window.STORY.get(state.hero); }
  function ctx() {
    return {
      has: function (id) { return state.items.indexOf(id) >= 0; },
      flag: function (f) { return !!state.flags[f]; },
      gold: state.gold, hp: state.hp, st: state
    };
  }
  function val(v) { return typeof v === 'function' ? v(ctx()) : v; }
  function itemInfo(id) {
    var h = hero(), it = h && h.itemInfo[id];
    return it || { name: id, desc: '' };
  }
  function vibrate(ms) { try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* ignore */ } }

  var ICON = {
    menu: '<svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/></svg>',
    bag: '<svg viewBox="0 0 24 24"><path d="M6 9h12l-1 11H7z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/><path d="M9 9V7a3 3 0 0 1 6 0v2" fill="none" stroke="currentColor" stroke-width="2.2"/></svg>',
    heart: '<svg viewBox="0 0 24 24"><path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z" fill="#c9553f" stroke="#17110b" stroke-width="2"/></svg>',
    die: '<svg viewBox="0 0 24 24"><path d="M12 2l9 5v10l-9 5-9-5V7z" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 2v6M3 7l9 1 9-1M12 8l-6 9h12z" fill="none" stroke="currentColor" stroke-width="1.4"/></svg>',
    key: '<svg viewBox="0 0 24 24"><circle cx="8" cy="12" r="4" fill="none" stroke="currentColor" stroke-width="2.2"/><path d="M12 12h9M18 12v3M21 12v2" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>',
    check: '<svg viewBox="0 0 24 24" class="mark"><circle cx="12" cy="12" r="10" fill="#d3c39f" stroke="#17110b" stroke-width="2"/><path d="M7 12l3 3 7-7" fill="none" stroke="#17110b" stroke-width="2.6" stroke-linecap="round"/></svg>',
    lock: '<svg viewBox="0 0 24 24" class="mark"><rect x="5" y="10" width="14" height="11" rx="2" fill="#5d5142" stroke="#17110b" stroke-width="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="#9f8f72" stroke-width="2.2"/></svg>'
  };

  // Зерно плёнки генерируется один раз и подставляется в CSS
  (function makeGrain() {
    try {
      var c = document.createElement('canvas'); c.width = c.height = 128;
      var g = c.getContext('2d'), img = g.createImageData(128, 128);
      for (var i = 0; i < img.data.length; i += 4) {
        var v = Math.random() * 255;
        img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
        img.data[i + 3] = Math.random() < 0.5 ? 70 : 0;
      }
      g.putImageData(img, 0, 0);
      document.documentElement.style.setProperty('--grain', 'url(' + c.toDataURL() + ')');
    } catch (e) { /* без зерна тоже можно */ }
  })();

  function frame(spec, cls) {
    return '<div class="frame' + (cls ? ' ' + cls : '') + '">' + ART.render(spec) + '<i class="scratch"></i><i class="scratch s2"></i></div>';
  }
  function show(html, name) {
    screen = name;
    app.innerHTML = '<div class="screen">' + html + '</div>';
    window.scrollTo(0, 0);
  }
  function on(sel, fn) {
    var els = app.querySelectorAll(sel);
    for (var i = 0; i < els.length; i++) els[i].addEventListener('click', fn);
  }
  function toast(msg) {
    var t = document.createElement('div');
    t.className = 'toast'; t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function () { t.remove(); }, 2600);
  }

  // ---------- Оверлей (диалоги) ----------
  function openOverlay(html, onClose) {
    closeOverlay(true);
    overlayEl = document.createElement('div');
    overlayEl.className = 'overlay';
    overlayEl.innerHTML = '<div class="dialog" role="dialog" aria-modal="true">' + html + '</div>';
    document.body.appendChild(overlayEl);
    overlayClose = onClose || null;
    return overlayEl;
  }
  function closeOverlay(silent) {
    if (!overlayEl) return;
    overlayEl.remove();
    overlayEl = null;
    var cb = overlayClose; overlayClose = null;
    if (!silent && cb) cb();
  }

  // ---------- Титульный экран ----------
  var TITLE_ART = {
    bg: 'stage', fx: ['notes'],
    items: [
      ['umbrella', 248, 256, { s: 1.1 }],
      ['death', 236, 262, { shades: true, cocktail: true, s: 1.05 }],
      ['sign', 330, 262, { text: ['Ушла', 'в отпуск'] }],
      ['intern', 120, 262, { s: 1.05 }],
      ['skeleton', 76, 262, { instr: 'tuba', s: 0.8 }]
    ]
  };

  function renderTitle() {
    var save = store.get(SAVE_KEY, null);
    var canContinue = save && !save.over && window.STORY.get(save.hero);
    var html = '<div class="title-wrap">' +
      '<h1 class="logo">Смерть в&nbsp;отпуске<small>мрачная сказка в картинках</small></h1>' +
      frame(TITLE_ART) +
      '<p class="tagline">Текстовый квест с кубиком d20, четырьмя героями и кучей способов плохо кончить.</p>' +
      '<div class="menu">' +
      (canContinue ? '<button class="btn big" data-act="continue">Продолжить</button>' : '') +
      '<button class="btn big" data-act="new">' + (canContinue ? 'Новая история' : 'Начать') + '</button>' +
      '<button class="btn center" data-act="book">Книга концовок</button>' +
      '<button class="btn center" data-act="rules">Как играть</button>' +
      '<button class="btn ghost center" data-act="sound">' + soundLabel() + '</button>' +
      '</div><p class="footer-note">Иллюстрации нарисованы кодом в духе мультфильмов 1930-х.</p></div>';
    show(html, 'title');
    on('[data-act="continue"]', function () { AUDIO.play('click'); state = save; renderScene(false); });
    on('[data-act="new"]', function () { AUDIO.play('click'); renderHeroes(); });
    on('[data-act="book"]', function () { AUDIO.play('click'); renderBook(); });
    on('[data-act="rules"]', function () { AUDIO.play('click'); showRules(); });
    on('[data-act="sound"]', function () { showSound(); });
  }

  function soundLabel() {
    return 'Звук: музыка ' + (settings.music ? 'вкл' : 'выкл') + ', эффекты ' + (settings.sfx ? 'вкл' : 'выкл');
  }
  function showSound() {
    AUDIO.play('click');
    var el = openOverlay('<h3>Звук</h3>' +
      '<button class="btn center" data-s="music">Музыка: ' + (settings.music ? 'вкл' : 'выкл') + '</button>' +
      '<button class="btn center" data-s="sfx">Эффекты: ' + (settings.sfx ? 'вкл' : 'выкл') + '</button>' +
      '<button class="btn ghost center" data-s="close" style="color:var(--ink)">Готово</button>', function () {
        if (screen === 'title') renderTitle();
      });
    el.querySelector('[data-s="music"]').onclick = function () {
      settings.music = !settings.music; store.set(SETTINGS_KEY, settings);
      AUDIO.setMusic(settings.music); this.textContent = 'Музыка: ' + (settings.music ? 'вкл' : 'выкл');
    };
    el.querySelector('[data-s="sfx"]').onclick = function () {
      settings.sfx = !settings.sfx; store.set(SETTINGS_KEY, settings);
      AUDIO.setSfx(settings.sfx); AUDIO.play('click'); this.textContent = 'Эффекты: ' + (settings.sfx ? 'вкл' : 'выкл');
    };
    el.querySelector('[data-s="close"]').onclick = function () { closeOverlay(); };
  }

  function showRules() {
    var el = openOverlay('<h3>Как играть</h3><div class="result-text">' + paras([
      'Это текстовый квест в духе настольных ролевых игр. Читай, выбирай, рискуй.',
      'Варианты со значком кубика — проверки. Бросается двадцатигранник (d20), к выпавшему числу прибавляется характеристика героя: Сила, Ловкость, Интеллект или Харизма. Если сумма не меньше сложности — успех.',
      'Двадцать на кубике — всегда успех. Единица — всегда провал, даже у гения.',
      'Провалы бьют по здоровью. Кончится здоровье — за тобой придёт стажёр Смерти с учебным серпом.',
      'Некоторые варианты появляются, только если у героя есть нужный предмет или он что-то разузнал раньше. Сумка — в правом верхнем углу.',
      'У каждого героя своя история и несколько концовок. Собери их все в Книге концовок. Игра сохраняется сама.'
    ]) + '</div><button class="btn big" data-x>Понятно</button>');
    el.querySelector('[data-x]').onclick = function () { AUDIO.play('click'); closeOverlay(); };
  }

  // ---------- Выбор героя ----------
  function renderHeroes() {
    var found = foundEndings();
    var html = '<div class="topbar"><button class="icon-btn" data-back aria-label="Назад">' + ICON.menu + '</button><div class="hero-name"><b>Выбери героя</b></div></div>' +
      '<div class="premise"><b>Что стряслось в Гнилодоле</b><br>' + fmt(window.STORY.premise) + '</div><div class="heroes">';
    heroes.forEach(function (h) {
      var f = (found[h.id] || []).length;
      html += '<button class="hero-card" data-hero="' + h.id + '">' + frame(h.portrait) +
        '<div class="body"><h3>' + esc(h.name) + '</h3><div class="cls">' + esc(h.cls) + '</div>' +
        '<p class="teaser">' + fmt(h.teaser) + '</p>' +
        '<div class="found">Концовок найдено: ' + f + ' из ' + h.endings.length + '</div></div></button>';
    });
    html += '</div>';
    show(html, 'heroes');
    on('[data-back]', function () { AUDIO.play('click'); renderTitle(); });
    on('[data-hero]', function () { AUDIO.play('click'); renderHero(this.getAttribute('data-hero')); });
  }

  function statsHtml(stats) {
    return '<div class="stats">' + Object.keys(STAT).map(function (k) {
      return '<span class="stat" title="' + STAT_FULL[k] + '">' + STAT_FULL[k] + ' <b>' + mod(stats[k] || 0) + '</b></span>';
    }).join('') + '</div>';
  }

  function renderHero(id) {
    var h = window.STORY.get(id);
    var items = h.startItems.map(function (i) { var it = h.itemInfo[i]; return '<li><b>' + esc(it.name) + '</b><span>' + esc(it.desc) + '</span></li>'; }).join('');
    var html = '<div class="topbar"><button class="icon-btn" data-back aria-label="Назад">' + ICON.menu + '</button><div class="hero-name"><b>' + esc(h.name) + '</b></div></div>' +
      frame(h.portrait) +
      '<div class="sheet"><h2>' + esc(h.name) + '</h2><div class="cls" style="color:var(--dark)">' + esc(h.cls) + '</div>' +
      '<div class="scene-text" style="margin-top:10px">' + paras(h.bio) + '</div>' +
      statsHtml(h.stats) +
      '<div class="stats"><span class="stat">Здоровье <b>' + h.hp + '</b></span></div>' +
      '<ul class="bag-list items">' + items + '</ul></div>' +
      '<button class="btn big" data-start>Начать историю</button>' +
      '<button class="btn ghost center" data-back>Другой герой</button>';
    show(html, 'hero');
    on('[data-back]', function () { AUDIO.play('click'); renderHeroes(); });
    on('[data-start]', function () { AUDIO.play('click'); AUDIO.unlock(); if (settings.music) AUDIO.setMusic(true); newGame(id); });
  }

  function newGame(id) {
    var h = window.STORY.get(id);
    state = { hero: id, scene: null, hp: h.hp, maxHp: h.hp, items: h.startItems.slice(), flags: {}, gold: h.gold || 0, used: {}, entered: {}, over: false };
    go(h.start, true);
  }

  // ---------- Игровой процесс ----------
  function go(id, first) {
    var h = hero();
    if (state.hp <= 0) id = h.death;
    if (!h.scenes[id]) { console.error('Нет сцены', id); id = h.start; }
    state.scene = id;
    var sc = h.scenes[id];
    if (sc.enter && !state.entered[id]) { state.entered[id] = 1; applyEff(sc.enter); }
    if (sc.ending) {
      state.over = true;
      state.newEnding = markEnding(h.id, sc.ending);
    }
    store.set(SAVE_KEY, state);
    renderScene(!first);
  }

  function hpHtml() {
    var s = '';
    for (var i = 0; i < state.maxHp; i++) s += '<span class="' + (i < state.hp ? '' : 'lost') + '">' + ICON.heart + '</span>';
    return s;
  }

  function choiceAvailable(ch, key) {
    if (ch.once && state.used[key]) return false;
    var n = ch.need;
    if (!n) return true;
    var c = ctx();
    if (arr(n.has).some(function (i) { return !c.has(i); })) return false;
    if (arr(n.no).some(function (i) { return c.has(i); })) return false;
    if (arr(n.flag).some(function (f) { return !c.flag(f); })) return false;
    if (arr(n.noflag).some(function (f) { return c.flag(f); })) return false;
    if (n.gold && state.gold < n.gold) return false;
    return true;
  }

  function renderScene(iris) {
    var h = hero(), sc = h.scenes[state.scene];
    if (sc.ending) return renderEnding(iris);
    var choicesHtml = '';
    sc.choices.forEach(function (ch, i) {
      var key = state.scene + '#' + i;
      if (!choiceAvailable(ch, key)) return;
      var badge = '';
      if (ch.check) {
        var m = h.stats[ch.check.stat] || 0;
        badge = '<span class="badge" title="Проверка: ' + STAT_FULL[ch.check.stat] + ', сложность ' + ch.check.dc + '">' + ICON.die + STAT[ch.check.stat] + ' ' + mod(m) + ' · ' + ch.check.dc + '</span>';
      } else if (ch.need && ch.need.has) {
        badge = '<span class="badge item">' + ICON.key + esc(itemInfo(arr(ch.need.has)[0]).name) + '</span>';
      }
      choicesHtml += '<button class="btn choice" data-choice="' + i + '"><span class="txt">' + fmt(val(ch.t)) + '</span>' + badge + '</button>';
    });
    var html = topbar() +
      '<div class="play-grid">' + frame(val(sc.art), iris ? 'iris-in' : '') +
      '<div><h2 class="scene-title">' + esc(val(sc.title)) + '</h2>' +
      '<div class="scene-text">' + paras(val(sc.text)) + '</div>' +
      '<div class="choices">' + choicesHtml + '</div></div></div>';
    show(html, 'play');
    bindTopbar();
    on('[data-choice]', function () { choose(+this.getAttribute('data-choice')); });
    busy = false;
  }

  function topbar() {
    var h = hero();
    return '<div class="topbar"><button class="icon-btn" data-menu aria-label="Меню">' + ICON.menu + '</button>' +
      '<div class="hero-name"><b>' + esc(h.name) + '</b><div class="hp" aria-label="Здоровье ' + state.hp + ' из ' + state.maxHp + '">' + hpHtml() + '</div></div>' +
      '<button class="icon-btn" data-bag aria-label="Сумка">' + ICON.bag + '</button></div>';
  }
  function bindTopbar() {
    on('[data-menu]', function () { showGameMenu(); });
    on('[data-bag]', function () { showBag(); });
  }
  function refreshHp() {
    var el = app.querySelector('.hp');
    if (el) { el.innerHTML = hpHtml(); el.classList.remove('hp-anim'); void el.offsetWidth; el.classList.add('hp-anim'); }
  }

  function applyEff(e) {
    var out = [];
    if (!e) return out;
    e = val(e);
    if (e.hp) {
      var before = state.hp;
      state.hp = Math.max(0, Math.min(state.maxHp, state.hp + e.hp));
      var d = state.hp - before;
      if (d < 0) { out.push('−' + (-d) + ' здоровья'); AUDIO.play('hurt'); vibrate(120); refreshHp(); }
      if (d > 0) { out.push('+' + d + ' здоровья'); refreshHp(); }
    }
    arr(e.add).forEach(function (id) {
      if (state.items.indexOf(id) < 0) { state.items.push(id); out.push('Получено: ' + itemInfo(id).name); }
    });
    arr(e.del).forEach(function (id) {
      var i = state.items.indexOf(id);
      if (i >= 0) { state.items.splice(i, 1); out.push('Потеряно: ' + itemInfo(id).name); }
    });
    arr(e.set).forEach(function (f) { state.flags[f] = 1; });
    arr(e.unset).forEach(function (f) { delete state.flags[f]; });
    if (e.gold) {
      state.gold = Math.max(0, state.gold + e.gold);
      out.push((e.gold > 0 ? '+' : '−') + Math.abs(e.gold) + ' ' + coins(Math.abs(e.gold)));
    }
    return out;
  }
  function coins(n) {
    var m10 = n % 10, m100 = n % 100;
    if (m10 === 1 && m100 !== 11) return 'монета';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return 'монеты';
    return 'монет';
  }

  function transition(to) {
    var fr = app.querySelector('.frame');
    AUDIO.play('whoosh');
    if (fr) { fr.classList.remove('iris-in'); fr.classList.add('iris-out'); }
    setTimeout(function () { go(to); }, fr ? 360 : 0);
  }

  function choose(i) {
    if (busy) return;
    var sc = hero().scenes[state.scene], ch = sc.choices[i];
    var key = state.scene + '#' + i;
    if (!choiceAvailable(ch, key)) return;
    busy = true;
    AUDIO.play('click');
    if (ch.once) state.used[key] = 1;
    if (ch.check) return rollDice(ch);
    var delta = applyEff(ch.eff);
    var to = val(ch.to);
    if (ch.say) {
      showResult({ text: val(ch.say), delta: delta, to: to });
    } else {
      if (delta.length) { AUDIO.play('item'); toast(delta.join(' · ')); }
      transition(to);
    }
  }

  function dieSvg(num) {
    return '<svg viewBox="0 0 100 100"><path d="M50 4 L92 28 L92 72 L50 96 L8 72 L8 28Z" fill="#fbf5e4" stroke="#17110b" stroke-width="4" stroke-linejoin="round"/>' +
      '<path d="M50 4 L50 26 M8 28 L28 34 M92 28 L72 34 M8 72 L28 66 M92 72 L72 66 M50 96 L50 78 M50 26 L72 34 L72 66 L50 78 L28 66 L28 34Z M28 34 L50 26 L72 34 L50 70 Z" fill="none" stroke="#9f8f72" stroke-width="2" stroke-linejoin="round"/>' +
      '<text x="50" y="62" text-anchor="middle" font-family="Lobster, Georgia, serif" font-size="34" fill="#17110b">' + num + '</text></svg>';
  }

  function rollDice(ch) {
    var h = hero(), m = h.stats[ch.check.stat] || 0, dc = ch.check.dc;
    var el = openOverlay(
      '<h3>Проверка: ' + STAT_FULL[ch.check.stat] + '</h3>' +
      '<div class="roll-line">Нужно ' + dc + '+ · бонус ' + mod(m) + '</div>' +
      '<div class="die-wrap rolling">' + dieSvg('?') + '</div>' +
      '<div class="roll-line" data-line>Кубик катится…</div><div data-res></div>');
    var wrap = el.querySelector('.die-wrap');
    AUDIO.play('dice');
    var ticks = 0;
    var iv = setInterval(function () {
      wrap.innerHTML = dieSvg(1 + Math.floor(Math.random() * 20));
      if (++ticks >= 12) {
        clearInterval(iv);
        var roll = 1 + Math.floor(Math.random() * 20);
        if (window.__forceRoll) roll = window.__forceRoll;
        var total = roll + m;
        var ok = roll === 20 || (roll !== 1 && total >= dc);
        wrap.classList.remove('rolling'); wrap.classList.add('landed');
        wrap.innerHTML = dieSvg(roll);
        var line = roll === 20 ? 'Двадцать! Критический успех!' : roll === 1 ? 'Единица. Критический провал.' : roll + ' ' + mod(m) + ' = ' + total + ' против ' + dc;
        el.querySelector('[data-line]').textContent = line;
        var out = ok ? ch.pass : ch.fail;
        out = out || {};
        var delta = applyEff(ch.eff).concat(applyEff(out.eff));
        AUDIO.play(ok ? 'success' : 'fail');
        var to = val(out.to) || val(ch.to);
        var res = el.querySelector('[data-res]');
        res.innerHTML = '<div class="verdict ' + (ok ? 'ok' : 'bad') + '">' + (ok ? 'Успех!' : 'Провал') + '</div>' +
          resultBody(val(out.text), delta) + '<button class="btn big" data-next>' + (state.hp <= 0 ? 'Ой…' : 'Дальше') + '</button>';
        res.querySelector('[data-next]').onclick = function () { AUDIO.play('click'); closeOverlay(true); transition(to); };
        res.querySelector('[data-next]').focus({ preventScroll: true });
      }
    }, 80);
    overlayClose = null;
  }

  function resultBody(text, delta) {
    return '<div class="result-text">' + paras(text) + '</div>' +
      (delta && delta.length ? '<div class="delta">' + esc(delta.join(' · ')) + '</div>' : '');
  }

  function showResult(r) {
    if (r.delta && r.delta.length) AUDIO.play('item');
    var el = openOverlay(resultBody(r.text, r.delta) + '<button class="btn big" data-next>' + (state.hp <= 0 ? 'Ой…' : 'Дальше') + '</button>');
    el.querySelector('[data-next]').onclick = function () { AUDIO.play('click'); closeOverlay(true); transition(r.to); };
    overlayClose = null;
  }

  function showBag() {
    AUDIO.play('click');
    var h = hero();
    var list = state.items.map(function (id) { var it = itemInfo(id); return '<li><b>' + esc(it.name) + '</b><span>' + esc(it.desc) + '</span></li>'; }).join('');
    if (state.gold) list += '<li><b>Монеты: ' + state.gold + '</b><span>Звенят. Пахнут чужими карманами.</span></li>';
    var el = openOverlay('<h3>Сумка</h3>' + statsHtml(h.stats) +
      '<div class="stats"><span class="stat">Здоровье <b>' + state.hp + ' / ' + state.maxHp + '</b></span></div>' +
      '<ul class="bag-list">' + (list || '<li><span>Пусто. Даже моль ушла.</span></li>') + '</ul>' +
      '<button class="btn big" data-x>Закрыть</button>');
    el.querySelector('[data-x]').onclick = function () { AUDIO.play('click'); closeOverlay(); };
  }

  function showGameMenu() {
    AUDIO.play('click');
    var el = openOverlay('<h3>Пауза</h3>' +
      '<button class="btn center" data-m="resume">Вернуться в игру</button>' +
      '<button class="btn center" data-m="restart">Начать историю заново</button>' +
      '<button class="btn center" data-m="rules">Как играть</button>' +
      '<button class="btn center" data-m="sound">Звук</button>' +
      '<button class="btn center" data-m="title">В главное меню</button>');
    el.querySelector('[data-m="resume"]').onclick = function () { AUDIO.play('click'); closeOverlay(); };
    el.querySelector('[data-m="restart"]').onclick = function () {
      AUDIO.play('click'); closeOverlay(true);
      var e2 = openOverlay('<h3>Начать заново?</h3><p>Прогресс этой истории пропадёт. Найденные концовки останутся в книге.</p>' +
        '<button class="btn big" data-y>Да, заново</button><button class="btn center" data-n>Нет</button>');
      e2.querySelector('[data-y]').onclick = function () { AUDIO.play('click'); closeOverlay(true); newGame(state.hero); };
      e2.querySelector('[data-n]').onclick = function () { AUDIO.play('click'); closeOverlay(); };
    };
    el.querySelector('[data-m="rules"]').onclick = function () { AUDIO.play('click'); showRules(); };
    el.querySelector('[data-m="sound"]').onclick = function () { showSound(); };
    el.querySelector('[data-m="title"]').onclick = function () { AUDIO.play('click'); closeOverlay(true); renderTitle(); };
  }

  // ---------- Концовка ----------
  function renderEnding(iris) {
    var h = hero(), sc = h.scenes[state.scene];
    var end = h.endings.filter(function (e) { return e.id === sc.ending; })[0] || { title: sc.title, kind: 'odd' };
    var found = (foundEndings()[h.id] || []).length;
    var html = topbar() +
      '<div class="play-grid">' + frame(val(sc.art), iris ? 'iris-in' : '') +
      '<div class="ending-card"><span class="ending-kind">' + KIND[end.kind] + (state.newEnding ? ' · новая!' : '') + '</span>' +
      '<h2 class="ending-title">' + esc(end.title) + '</h2>' +
      '<div class="scene-text" style="text-align:left">' + paras(val(sc.text)) + '</div>' +
      '<div class="the-end">Конец</div>' +
      '<div class="ending-count">Концовок героя найдено: ' + found + ' из ' + h.endings.length + '</div>' +
      '<button class="btn big" data-again>Ещё раз за этого героя</button>' +
      '<button class="btn center" data-other>Выбрать другого героя</button>' +
      '<button class="btn ghost center" data-book>Книга концовок</button></div></div>';
    show(html, 'play');
    bindTopbar();
    AUDIO.play(end.kind === 'death' || end.kind === 'bad' ? 'dirge' : 'good');
    on('[data-again]', function () { AUDIO.play('click'); newGame(h.id); });
    on('[data-other]', function () { AUDIO.play('click'); renderHeroes(); });
    on('[data-book]', function () { AUDIO.play('click'); renderBook(); });
    busy = false;
  }

  // ---------- Книга концовок ----------
  function renderBook() {
    var found = foundEndings(), total = 0, got = 0;
    var body = '';
    heroes.forEach(function (h) {
      var f = found[h.id] || [];
      body += '<div class="book-hero"><h3>' + esc(h.name) + ' — ' + f.length + ' / ' + h.endings.length + '</h3>';
      h.endings.forEach(function (e) {
        total++;
        var ok = f.indexOf(e.id) >= 0;
        if (ok) got++;
        body += '<div class="end-row' + (ok ? '' : ' locked') + '">' + (ok ? ICON.check : ICON.lock) +
          '<div><b>' + (ok ? esc(e.title) : '???') + '</b><span>' + (ok ? KIND[e.kind] + '. ' + esc(e.note || '') : 'Ещё не найдена. ' + esc(e.hint || '')) + '</span></div></div>';
      });
      body += '</div>';
    });
    var html = '<div class="topbar"><button class="icon-btn" data-back aria-label="Назад">' + ICON.menu + '</button><div class="hero-name"><b>Книга концовок</b></div></div>' +
      '<div class="book"><p class="tagline">Собрано ' + got + ' из ' + total + '. Смерть ведёт учёт — она это любит.</p>' + body + '</div>' +
      '<button class="btn big" data-back>Назад</button>';
    show(html, 'book');
    on('[data-back]', function () { AUDIO.play('click'); renderTitle(); });
  }

  // ---------- Системная кнопка «Назад» (Android) и пауза ----------
  window.gameBack = function () {
    if (overlayEl) {
      if (overlayEl.querySelector('[data-next]')) return true; // результат броска нужно дочитать
      AUDIO.play('click'); closeOverlay(); return true;
    }
    if (screen === 'play') { showGameMenu(); return true; }
    if (screen === 'hero') { renderHeroes(); return true; }
    if (screen === 'heroes' || screen === 'book') { renderTitle(); return true; }
    return false;
  };
  window.onAppPause = function () { AUDIO.pause(); };
  window.onAppResume = function () { if (settings.music) AUDIO.resume(); };
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) AUDIO.pause(); else if (settings.music) AUDIO.resume();
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') window.gameBack();
  });
  // первое касание «разблокирует» звук (политика автозапуска)
  document.addEventListener('pointerdown', function unlock() {
    AUDIO.unlock();
    if (!settings.music) AUDIO.setMusic(false); else AUDIO.setMusic(true);
    document.removeEventListener('pointerdown', unlock);
  });

  // доступ для автотестов
  window.GAME = { go: function (id) { go(id); }, state: function () { return state; }, newGame: newGame, renderTitle: renderTitle };

  renderTitle();
})();
