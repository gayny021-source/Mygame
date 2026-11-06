#!/usr/bin/env node
/*
 * Проверка историй без браузера:
 *  1) у всех переходов есть целевая сцена, у предметов — описание, у картинок — известные фигуры;
 *  2) каждая концовка достижима по графу сцен;
 *  3) тысячи случайных прохождений по правилам движка: ни одного тупика,
 *     каждая концовка реально выпадает.
 * Запуск: node tools/validate-story.js
 */
'use strict';
const path = require('path');
const root = path.join(__dirname, '..', 'game', 'js');
global.window = global;
require(path.join(root, 'art.js'));
require(path.join(root, 'story.js'));
for (const f of ['knight', 'doctor', 'goblin', 'monk']) require(path.join(root, 'stories', f + '.js'));

const errors = [];
const err = (h, msg) => errors.push(`[${h}] ${msg}`);
const arr = v => (v === undefined || v === null ? [] : Array.isArray(v) ? v : [v]);
const STATS = ['str', 'dex', 'int', 'cha'];

function mockCtx(flags, items) {
  return { has: i => items.includes(i), flag: f => flags.includes(f), gold: 0, hp: 5, st: {} };
}
// все возможные значения поля (функции вызываем на разных комбинациях флагов)
function variants(v, h) {
  if (typeof v !== 'function') return [v];
  const flags = new Set(), items = new Set(Object.keys(h.itemInfo));
  for (const sc of Object.values(h.scenes)) {
    for (const ch of sc.choices || []) {
      for (const o of [ch, ch.pass, ch.fail]) {
        if (!o) continue;
        const e = typeof o.eff === 'object' ? o.eff : {};
        arr(e.set).forEach(f => flags.add(f));
      }
      if (ch.need) arr(ch.need.flag).forEach(f => flags.add(f));
    }
    if (sc.enter) arr(sc.enter.set).forEach(f => flags.add(f));
  }
  const fl = [...flags];
  const out = [v(mockCtx([], [])), v(mockCtx(fl, [...items]))];
  fl.forEach(f => out.push(v(mockCtx([f], []))));
  return out;
}

function checkArt(h, id, art) {
  for (const spec of variants(art, h)) {
    if (!spec || !ART.BG[spec.bg]) { err(h.id, `${id}: неизвестный фон ${spec && spec.bg}`); continue; }
    for (const it of spec.items || []) {
      if (!ART.FIG[it[0]] && !ART.PROP[it[0]]) err(h.id, `${id}: неизвестная фигура ${it[0]}`);
    }
    for (const f of spec.fx || []) if (!ART.FX[f]) err(h.id, `${id}: неизвестный эффект ${f}`);
    try { ART.render(spec); } catch (e) { err(h.id, `${id}: ошибка рисования ${e.message}`); }
  }
}

for (const h of STORY.list) {
  const S = h.scenes;
  if (!S[h.start]) err(h.id, 'нет стартовой сцены');
  if (!S[h.death] || !S[h.death].ending) err(h.id, 'нет сцены смерти');
  STATS.forEach(s => { if (typeof h.stats[s] !== 'number') err(h.id, 'нет характеристики ' + s); });
  h.startItems.forEach(i => { if (!h.itemInfo[i]) err(h.id, 'нет описания предмета ' + i); });
  checkArt(h, 'portrait', h.portrait);
  const endIds = new Set(h.endings.map(e => e.id));
  const edges = {};
  for (const [id, sc] of Object.entries(S)) {
    edges[id] = new Set();
    checkArt(h, id, sc.art);
    for (const t of variants(sc.text, h)) if (!arr(t).length) err(h.id, `${id}: пустой текст`);
    if (sc.ending) {
      if (!endIds.has(sc.ending)) err(h.id, `${id}: концовка ${sc.ending} не описана в endings`);
      if (sc.choices.length) err(h.id, `${id}: у концовки есть выборы`);
      continue;
    }
    if (!sc.choices.length) err(h.id, `${id}: нет выборов`);
    sc.choices.forEach((ch, i) => {
      const where = `${id}#${i}`;
      if (ch.check) {
        if (!STATS.includes(ch.check.stat)) err(h.id, `${where}: плохая характеристика`);
        if (!ch.pass || !ch.fail) err(h.id, `${where}: нет pass/fail`);
        for (const o of [ch.pass, ch.fail]) if (o) {
          for (const t of variants(o.to || ch.to, h)) { if (!S[t]) err(h.id, `${where}: нет сцены ${t}`); else edges[id].add(t); }
          for (const t of variants(o.text, h)) if (!arr(t).length) err(h.id, `${where}: нет текста результата`);
        }
      } else {
        for (const t of variants(ch.to, h)) { if (!S[t]) err(h.id, `${where}: нет сцены ${t}`); else edges[id].add(t); }
      }
      if (ch.need) arr(ch.need.has).concat(arr(ch.need.no)).forEach(it => { if (!h.itemInfo[it]) err(h.id, `${where}: нет предмета ${it}`); });
      for (const o of [ch, ch.pass, ch.fail]) if (o) for (const e of variants(o.eff, h)) if (e) arr(e.add).concat(arr(e.del)).forEach(it => { if (!h.itemInfo[it]) err(h.id, `${where}: нет предмета ${it}`); });
    });
    if (sc.enter) arr(sc.enter.add).forEach(it => { if (!h.itemInfo[it]) err(h.id, `${id}: нет предмета ${it}`); });
  }
  // достижимость по графу
  const seen = new Set([h.start, h.death]), queue = [h.start];
  while (queue.length) { const c = queue.shift(); for (const n of edges[c] || []) if (!seen.has(n)) { seen.add(n); queue.push(n); } }
  for (const id of Object.keys(S)) if (!seen.has(id)) err(h.id, `сцена ${id} недостижима`);
  for (const e of h.endings) if (!Object.values(S).some(sc => sc.ending === e.id)) err(h.id, `у концовки ${e.id} нет сцены`);
}

// ---------- Случайные прохождения по правилам движка ----------
function simulate(h, rnd) {
  const st = { hp: h.hp, items: h.startItems.slice(), flags: {}, gold: h.gold || 0, used: {}, entered: {} };
  const c = () => ({ has: i => st.items.includes(i), flag: f => !!st.flags[f], gold: st.gold, hp: st.hp, st });
  const val = v => (typeof v === 'function' ? v(c()) : v);
  const apply = e => {
    e = val(e); if (!e) return;
    if (e.hp) st.hp = Math.max(0, Math.min(h.hp, st.hp + e.hp));
    arr(e.add).forEach(i => { if (!st.items.includes(i)) st.items.push(i); });
    arr(e.del).forEach(i => { const k = st.items.indexOf(i); if (k >= 0) st.items.splice(k, 1); });
    arr(e.set).forEach(f => { st.flags[f] = 1; });
    arr(e.unset).forEach(f => { delete st.flags[f]; });
    if (e.gold) st.gold = Math.max(0, st.gold + e.gold);
  };
  const avail = (ch, key) => {
    if (ch.once && st.used[key]) return false;
    const n = ch.need; if (!n) return true;
    const x = c();
    if (arr(n.has).some(i => !x.has(i))) return false;
    if (arr(n.no).some(i => x.has(i))) return false;
    if (arr(n.flag).some(f => !x.flag(f))) return false;
    if (arr(n.noflag).some(f => x.flag(f))) return false;
    if (n.gold && st.gold < n.gold) return false;
    return true;
  };
  let id = h.start;
  for (let steps = 0; steps < 400; steps++) {
    if (st.hp <= 0) id = h.death;
    const sc = h.scenes[id];
    if (sc.enter && !st.entered[id]) { st.entered[id] = 1; apply(sc.enter); }
    if (sc.ending) return { ending: sc.ending, steps };
    const opts = sc.choices.map((ch, i) => [ch, i]).filter(([ch, i]) => avail(ch, id + '#' + i));
    if (!opts.length) return { stuck: id };
    const [ch, i] = opts[Math.floor(rnd() * opts.length)];
    if (ch.once) st.used[id + '#' + i] = 1;
    if (ch.check) {
      const roll = 1 + Math.floor(rnd() * 20), total = roll + (h.stats[ch.check.stat] || 0);
      const ok = roll === 20 || (roll !== 1 && total >= ch.check.dc);
      const out = ok ? ch.pass : ch.fail;
      apply(ch.eff); apply(out.eff);
      id = val(out.to) || val(ch.to);
    } else {
      apply(ch.eff);
      id = val(ch.to);
    }
    if (!h.scenes[id]) return { stuck: 'нет сцены ' + id };
  }
  return { loop: id };
}

let seed = 12345;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const RUNS = 20000;
for (const h of STORY.list) {
  const hits = {}; let steps = 0;
  for (let r = 0; r < RUNS; r++) {
    const res = simulate(h, rnd);
    if (res.stuck) { err(h.id, 'тупик: ' + res.stuck); break; }
    if (res.loop) { err(h.id, 'бесконечный цикл около ' + res.loop); break; }
    hits[res.ending] = (hits[res.ending] || 0) + 1; steps += res.steps;
  }
  for (const e of h.endings) if (!hits[e.id]) err(h.id, `концовка ${e.id} не выпала ни разу за ${RUNS} прохождений`);
  const line = h.endings.map(e => `${e.id} ${((hits[e.id] || 0) / RUNS * 100).toFixed(1)}%`).join(', ');
  console.log(`${h.name}: ${Object.keys(h.scenes).length} сцен, ${h.endings.length} концовок; средняя длина ${(steps / RUNS).toFixed(1)} шагов`);
  console.log('   ' + line);
}

if (errors.length) {
  console.error('\nОшибки:\n' + errors.join('\n'));
  process.exit(1);
}
console.log('\nВсё в порядке.');
