/*
 * Звук целиком синтезируется Web Audio — никаких файлов.
 * Музыка: короткий «костяной» вальсок-полька — ксилофон + туба (умпа-умпа),
 * как в мультфильмах про пляшущих скелетов. Мелодия оригинальная.
 */
(function (root) {
  'use strict';
  var ctx = null, master = null, musicGain = null, sfxGain = null;
  var musicOn = true, sfxOn = true, playing = false, timer = null;
  var step = 0, nextTime = 0;
  var BPM = 138, STEP = 60 / BPM / 2; // восьмые

  function midi(name) {
    var m = /^([A-G])(#|b)?(-?\d)$/.exec(name);
    var base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]];
    if (m[2] === '#') base++;
    if (m[2] === 'b') base--;
    return 12 * (+m[3] + 1) + base;
  }
  function freq(name) { return 440 * Math.pow(2, (midi(name) - 69) / 12); }

  function ensure() {
    if (ctx) return true;
    var AC = root.AudioContext || root.webkitAudioContext;
    if (!AC) return false;
    try {
      ctx = new AC();
    } catch (e) { return false; }
    master = ctx.createGain(); master.gain.value = 0.9; master.connect(ctx.destination);
    musicGain = ctx.createGain(); musicGain.gain.value = 0.16; musicGain.connect(master);
    sfxGain = ctx.createGain(); sfxGain.gain.value = 0.5; sfxGain.connect(master);
    return true;
  }

  function env(g, t, a, peak, d) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
  }
  function tone(dest, type, f, t, dur, peak, a) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.type = type; o.frequency.setValueAtTime(f, t);
    env(g, t, a || 0.004, peak, dur);
    o.connect(g); g.connect(dest);
    o.start(t); o.stop(t + (a || 0.004) + dur + 0.05);
    return o;
  }

  // ---------- Музыка ----------
  var MEL = [
    'A4', 'C5', 'E5', 'C5', 'A4', null, 'E4', null,
    'G#4', 'A4', 'B4', 'C5', 'B4', 'A4', 'G#4', null,
    'D5', 'F5', 'A5', 'F5', 'D5', null, 'A4', null,
    'E5', 'D5', 'C5', 'B4', 'G#4', null, 'E4', null,
    'A4', 'C5', 'E5', 'A5', 'G#5', 'A5', 'E5', null,
    'F5', null, 'E5', null, 'D5', null, 'C5', null,
    'D5', 'F5', 'E5', 'D5', 'C5', 'B4', 'G#4', 'B4',
    'A4', null, 'E4', null, 'A3', null, null, null
  ];
  var CH = {
    Am: { b: ['A2', 'E2'], c: ['A3', 'C4', 'E4'] },
    Dm: { b: ['D2', 'A2'], c: ['D4', 'F4', 'A3'] },
    E: { b: ['E2', 'B2'], c: ['E3', 'G#3', 'B3'] },
    F: { b: ['F2', 'C3'], c: ['F3', 'A3', 'C4'] }
  };
  var BARS = ['Am', 'Am', 'Dm', 'E', 'Am', 'F', 'Dm|E', 'Am'];

  function xylo(f, t) {
    tone(musicGain, 'sine', f, t, 0.28, 0.5, 0.002);
    tone(musicGain, 'sine', f * 3.98, t, 0.06, 0.12, 0.001);
  }
  function tuba(f, t) {
    var o = ctx.createOscillator(), g = ctx.createGain(), lp = ctx.createBiquadFilter();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(f, t);
    lp.type = 'lowpass'; lp.frequency.value = 420;
    env(g, t, 0.02, 0.55, 0.26);
    o.connect(lp); lp.connect(g); g.connect(musicGain);
    o.start(t); o.stop(t + 0.35);
  }
  function stab(notes, t) {
    notes.forEach(function (n) { tone(musicGain, 'square', freq(n), t, 0.07, 0.05, 0.003); });
  }

  function schedule() {
    while (nextTime < ctx.currentTime + 0.15) {
      var s = step % 64, bar = Math.floor(s / 8), inBar = s % 8;
      var names = BARS[bar].split('|');
      var chord = CH[names.length > 1 && inBar >= 4 ? names[1] : names[0]];
      if (MEL[s]) xylo(freq(MEL[s]), nextTime);
      if (inBar === 0 || inBar === 4) tuba(freq(chord.b[inBar === 0 ? 0 : 1]), nextTime);
      if (inBar === 2 || inBar === 6) stab(chord.c, nextTime);
      step++;
      nextTime += STEP;
    }
  }

  function startMusic() {
    if (!musicOn || playing || !ensure()) return;
    if (ctx.state === 'suspended') ctx.resume();
    playing = true;
    nextTime = ctx.currentTime + 0.1;
    timer = setInterval(schedule, 40);
  }
  function stopMusic() {
    playing = false;
    if (timer) clearInterval(timer);
    timer = null;
  }

  // ---------- Звуковые эффекты ----------
  function noiseBurst(t, dur, f) {
    var len = Math.floor(ctx.sampleRate * dur), buf = ctx.createBuffer(1, len, ctx.sampleRate), d = buf.getChannelData(0);
    for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    var src = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain();
    src.buffer = buf; bp.type = 'bandpass'; bp.frequency.value = f || 2500; bp.Q.value = 2;
    g.gain.value = 0.9;
    src.connect(bp); bp.connect(g); g.connect(sfxGain);
    src.start(t);
  }
  var SFX = {
    click: function (t) { tone(sfxGain, 'sine', 880, t, 0.05, 0.25); },
    dice: function (t) {
      for (var i = 0; i < 9; i++) noiseBurst(t + i * 0.09 + Math.random() * 0.04, 0.035, 1800 + Math.random() * 1600);
    },
    success: function (t) {
      ['C5', 'E5', 'G5', 'C6'].forEach(function (n, i) { tone(sfxGain, 'triangle', freq(n), t + i * 0.08, 0.3, 0.45); });
    },
    // «грустный тромбон»: вва-вва-вва-ваааа
    fail: function (t) {
      var notes = ['D4', 'C#4', 'C4', 'B3'];
      notes.forEach(function (n, i) {
        var o = ctx.createOscillator(), g = ctx.createGain(), lp = ctx.createBiquadFilter();
        var st = t + i * 0.36, dur = i === 3 ? 1.0 : 0.3;
        o.type = 'sawtooth'; o.frequency.setValueAtTime(freq(n), st);
        if (i === 3) {
          var lfo = ctx.createOscillator(), lg = ctx.createGain();
          lfo.frequency.value = 6; lg.gain.value = 5;
          lfo.connect(lg); lg.connect(o.frequency);
          lfo.start(st); lfo.stop(st + dur + 0.1);
        }
        lp.type = 'lowpass'; lp.frequency.value = 900;
        g.gain.setValueAtTime(0.0001, st);
        g.gain.exponentialRampToValueAtTime(0.35, st + 0.05);
        g.gain.setValueAtTime(0.35, st + dur * 0.7);
        g.gain.exponentialRampToValueAtTime(0.0001, st + dur);
        o.connect(lp); lp.connect(g); g.connect(sfxGain);
        o.start(st); o.stop(st + dur + 0.05);
      });
    },
    hurt: function (t) {
      var o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine'; o.frequency.setValueAtTime(160, t); o.frequency.exponentialRampToValueAtTime(45, t + 0.25);
      env(g, t, 0.005, 0.8, 0.25);
      o.connect(g); g.connect(sfxGain); o.start(t); o.stop(t + 0.35);
    },
    item: function (t) {
      tone(sfxGain, 'sine', freq('E6'), t, 0.12, 0.3);
      tone(sfxGain, 'sine', freq('B6'), t + 0.08, 0.25, 0.3);
    },
    good: function (t) {
      ['C4', 'E4', 'G4', 'C5', 'E5'].forEach(function (n) { tone(sfxGain, 'triangle', freq(n), t, 1.6, 0.22, 0.03); });
      ['G5', 'C6'].forEach(function (n, i) { tone(sfxGain, 'square', freq(n), t + 0.15 * i, 0.4, 0.08); });
    },
    dirge: function (t) {
      ['A2', 'F2', 'E2', 'A1'].forEach(function (n, i) { tone(sfxGain, 'triangle', freq(n), t + i * 0.55, 0.6, 0.5, 0.02); });
    },
    whoosh: function (t) { noiseBurst(t, 0.25, 600); }
  };

  function play(name) {
    if (!sfxOn || !ensure() || !SFX[name]) return;
    if (ctx.state === 'suspended') ctx.resume();
    SFX[name](ctx.currentTime + 0.01);
  }

  root.AUDIO = {
    play: play,
    unlock: function () { if (ensure() && ctx.state === 'suspended') ctx.resume(); if (musicOn) startMusic(); },
    setMusic: function (on) { musicOn = on; if (on) startMusic(); else stopMusic(); },
    setSfx: function (on) { sfxOn = on; },
    pause: function () { stopMusic(); if (ctx && ctx.state === 'running') ctx.suspend(); },
    resume: function () { if (ctx && ctx.state === 'suspended') ctx.resume(); if (musicOn && ctx) startMusic(); }
  };
})(typeof window !== 'undefined' ? window : globalThis);
