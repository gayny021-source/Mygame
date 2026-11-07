// canvas_fx_outline_glow — pulsing glow / outline around a sprite's opaque pixels.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer, Android phones.
// Budget: 8 neighbour texture samples per pixel — fine for one sprite, NOT for a
// full-screen layer. Leave transparent padding >= radius_px around the sprite, or the
// glow is clipped at the texture edge. No fallback tier: drop the shader if a device
// struggles. COLOR on entry = texture(TEXTURE, UV) * vertex color * modulate (4.7.2);
// the glow takes the vertex alpha through a varying, so a faded-out sprite has no glow.
shader_type canvas_item;

// cos(45°) = sin(45°): puts the four diagonal samples on the same radius as the axis ones.
const float DIAGONAL = 0.7071;
// One full sine period, so TIME can wrap without a visible jump in the pulse.
const float TWO_PI = 6.2831853;

group_uniforms glow_look;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float radius_px : hint_range(0.0, 16.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

varying mediump vec4 v_color;

void vertex() {
	v_color = COLOR;
}

void fragment() {
	mediump vec4 c = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * radius_px;
	mediump float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + px * DIAGONAL).a);
	a = max(a, texture(TEXTURE, UV - px * DIAGONAL).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y) * DIAGONAL).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y) * DIAGONAL).a);
	mediump float pulse = (1.0 - pulse_depth) + pulse_depth * sin(mod(TIME * pulse_speed, TWO_PI));
	mediump vec4 glow = vec4(glow_color.rgb, glow_color.a * a * pulse * v_color.a);
	COLOR = mix(glow, c, c.a);
}
