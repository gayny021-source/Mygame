// canvas_fx_drop_shadow — flat cartoon drop shadow under the sprite's own silhouette.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer, Android phones.
// Budget: 1 extra texture sample per pixel. Needs transparent padding on the shadow
// side at least as large as `offset_px`.
// COLOR on entry = texture(TEXTURE, UV) * vertex color * modulate (4.7.2); the shadow
// takes the vertex alpha through a varying, so a faded-out sprite casts no shadow.
shader_type canvas_item;

group_uniforms shadow_look;
uniform vec4 shadow_color : source_color = vec4(0.08, 0.05, 0.03, 0.6);
uniform vec2 offset_px = vec2(4.0, 6.0);
group_uniforms;

varying mediump vec4 v_color;

void vertex() {
	v_color = COLOR;
}

void fragment() {
	mediump vec4 c = COLOR;
	mediump float s = texture(TEXTURE, UV - offset_px * TEXTURE_PIXEL_SIZE).a;
	mediump vec4 shadow = vec4(shadow_color.rgb, shadow_color.a * s * v_color.a);
	COLOR = mix(shadow, c, c.a);
}
