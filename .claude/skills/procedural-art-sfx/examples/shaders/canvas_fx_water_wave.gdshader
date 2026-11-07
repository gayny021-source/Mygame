// canvas_fx_water_wave — water / heat / dream wobble: offsets UV with two sine waves.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer, Android phones.
// Budget: 1 dependent texture sample per pixel. Works on any Sprite2D or TextureRect.
// COLOR in fragment() already holds the texture at the UNdistorted UV, so the vertex
// color (modulate is applied before vertex() in 4.7.2) goes through a varying and the
// texture is sampled once, at the distorted UV.
shader_type canvas_item;

// Second wave runs at a different rate and depth so the two never line up into a
// regular grid.
const float SECOND_WAVE_FREQUENCY = 0.7;
const float SECOND_WAVE_SPEED = 1.3;
const float SECOND_WAVE_DEPTH = 0.5;
// Each wave phase wraps on a full period, so there is no jump and sin() inputs stay small.
const float TWO_PI = 6.2831853;

group_uniforms wave_motion;
uniform float amplitude : hint_range(0.0, 0.05) = 0.01;
uniform float frequency : hint_range(0.0, 60.0) = 18.0;
uniform float speed : hint_range(0.0, 10.0) = 2.0;
group_uniforms wave_look;
uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 1.0);
group_uniforms;

varying mediump vec4 v_color;

void vertex() {
	v_color = COLOR;
}

void fragment() {
	float phase1 = mod(TIME * speed, TWO_PI);
	float phase2 = mod(TIME * speed * SECOND_WAVE_SPEED, TWO_PI);
	vec2 uv = UV;
	uv.x += sin(uv.y * frequency + phase1) * amplitude;
	uv.y += cos(uv.x * frequency * SECOND_WAVE_FREQUENCY + phase2) * amplitude * SECOND_WAVE_DEPTH;
	COLOR = texture(TEXTURE, uv) * tint * v_color;
}
