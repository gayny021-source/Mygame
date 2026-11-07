// post_screen_old_film — 1930s cartoon film look over the whole screen: grain,
// vignette, gentle flicker and rare vertical scratches.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer, Android phones.
// Budget: one full-screen pass with 1 screen-texture sample per pixel, redrawn every
// frame while TIME runs — measure frame time on the weakest phone (/perf-profile).
// Fallback tier: turn the layer off (reduce-motion setting or low-end phones).
// Rules (SKILL.md): the ColorRect is a leaf with mouse_filter = IGNORE, every wrapper
// around it is IGNORE too, and defaults stay low because the layer sits over body text.
shader_type canvas_item;

// Film "frames" per second for grain and flicker: lower than the screen rate on purpose.
const float FILM_FPS = 18.0;
// Frame counter wraps here so sin() inside hash() keeps small inputs on mobile GPUs.
const float FRAME_WRAP = 64.0;
// Scratch line half-width as 1 - (fraction of screen width).
const float SCRATCH_SHARPNESS = 0.9985;
const float SCRATCH_STRENGTH = 0.6;
const vec3 SCRATCH_COLOR = vec3(0.95);
// Grain is sampled on this grid so it stays a fine speckle at any screen size.
const float GRAIN_GRID = 512.0;

group_uniforms film_strength;
uniform float grain : hint_range(0.0, 0.3) = 0.05;
uniform float vignette : hint_range(0.0, 1.5) = 0.35;
uniform float flicker : hint_range(0.0, 0.2) = 0.03;
uniform float scratches : hint_range(0.0, 1.0) = 0.1;
group_uniforms film_look;
uniform vec4 paper_tint : source_color = vec4(1.0, 0.95, 0.85, 1.0);
group_uniforms;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

// Classic one-line hash: dot with two irrational-ish constants, sin, keep the fraction.
// highp on purpose: the large multiplier needs full precision.
float hash(highp vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	mediump vec4 base = texture(screen_tex, SCREEN_UV);
	float t = mod(floor(TIME * FILM_FPS), FRAME_WRAP);
	mediump float n = hash(SCREEN_UV * GRAIN_GRID + t) - 0.5;
	mediump vec3 col = base.rgb + n * grain;
	mediump float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette * d * d;
	col *= 1.0 - flicker * hash(vec2(t, 1.0));
	float line_x = hash(vec2(t, 7.0));
	mediump float line = step(SCRATCH_SHARPNESS, 1.0 - abs(SCREEN_UV.x - line_x)) * step(1.0 - scratches, hash(vec2(t, 3.0)));
	col = mix(col, SCRATCH_COLOR, line * SCRATCH_STRENGTH);
	COLOR = vec4(col * paper_tint.rgb, 1.0);
}
