# Godot Random Numbers — Quick Reference

Last verified: 2026-11-08 on 4.7.2.stable.official.ed1daf0bf (linux x86_64, headless) | Engine: Godot 4.7

Verified by `godot-specialist` on the installed binary (ClassDB, the docs embedded in the
binary via `--dump-extension-api-with-docs`, and headless runs). Items marked
**NOT VERIFIED** were not run; the reason is given.

## Verified on the installed binary

- `RandomNumberGenerator` (RefCounted): `randi_range(from: int, to: int) -> int` is inclusive
  on both ends (100k draws of (1,20): min 1, max 20). Also `randi`, `randf`, `randf_range`,
  `randfn`, `rand_weighted`, `randomize`, properties `seed`, `state` (int).
- Algorithm: binary docs say "currently uses PCG32" and "an implementation detail and should
  not be depended upon". Do NOT hardcode seed-derived sequences in tests; cross-version and
  cross-platform stability is **NOT VERIFIED** (one binary, linux x86_64 only).
- A fresh `RandomNumberGenerator.new()` is already randomly seeded; `randomize()` is optional.
- `state` save/restore is exact, also into a different instance. Restore only values read from
  `state`. JSON loses precision on the 64-bit `state` (verified: -384333191215171124 came back
  as -384333191215171136); use `var_to_str`/`str_to_var` or store it as a String.
- Same `seed` gives an identical sequence across instances and across process runs on one binary.
- Reversed arguments: the global `randi_range` documents a swap; the instance method does not
  document it (it happened to work). Always pass `(1, 20)`.
- d20 smoke: 200k draws, chi-square 14.16 (df 19, critical 30.14 at α = 0.05); 100 seeds × 200k:
  mean chi-square 19.09, 5/100 over the 0.05 critical value, 0/100 over 0.01. No bias detected.
- Speed: 200k draws take 17–25 ms.

## Global functions (@GlobalScope)

- `randi`, `randf`, `randi_range` (swaps reversed args), `randf_range`, `randfn`, `randomize`,
  `seed(base)`, `rand_from_seed`. Auto-randomized at startup. No getter for the global state.
- One shared generator: any foreign `randi()` shifts the stream (verified: one extra call turned
  [18, 9, 1, …] into [9, 1, 16, …]). Never use the global functions where reproducibility or test
  injection matters; own a `RandomNumberGenerator` instance per system.

## Debug vs release detection

- `OS.is_debug_build()`: true in the editor binary (with and without `-d`). False in release
  templates per the binary docs — **NOT VERIFIED** (no export templates installed).
- Feature tags on the editor binary: `debug`, `editor`, `editor_runtime` true; `release`,
  `template`, `template_debug`, `template_release`, `mobile`, `android` false.
- Do not gate on `Engine.is_editor_hint()`: it returned true under `godot --headless -s`.
- `OS.get_cmdline_user_args()` returns args after `--` (desktop verified; Android **NOT VERIFIED**).
- GDScript has no conditional compilation (**NOT VERIFIED** on the binary): an
  `if OS.is_debug_build()` branch still ships in the PCK. To keep code out of release, exclude
  the file in the release export preset.

## Recommended pattern (d20 checks, `design/gdd/d20-checks.md`)

- An injectable source: `class_name D20Source extends RefCounted` with `@abstract func roll() -> int`
  (`@abstract` verified working in 4.7.2), passed in through the constructor — not an autoload,
  not the global functions.
- `EngineD20Source` owns its own `RandomNumberGenerator`; `roll()` calls `randi_range(1, 20)` once
  when the player presses «Бросить». The animation only reads the known result.
- `ScriptedD20Source.new(rolls: PackedInt32Array, fallback: D20Source)`: when the sequence runs
  out, or a value is outside 1–20 (`push_error`), it uses `fallback`.
- Tests drive logic through `ScriptedD20Source`; a fixed seed is only for the bounds and χ² smoke.
