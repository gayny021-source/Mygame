// canvas_fx_drop_shadow — flat cartoon drop shadow under the sprite's own silhouette.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer, Android phones.
// Budget: 1 extra texture sample per pixel. Needs transparent padding on the shadow
// side at least as large as `offset_px`.
// COLOR on entry = texture(TEXTURE, UV) * vertex color * modulate (4.7.2). The body is
// composited OVER its shadow with the unmodulated alphas, then the result is faded by
// the vertex alpha: sprite and shadow fade as one, without a colour shift or a darker
// rim on anti-aliased edges.
shader_type canvas_item;

// Keeps the divisions defined where both layers are empty.
const float MIN_ALPHA = 0.0001;

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
	mediump float body_a = c.a / max(v_color.a, MIN_ALPHA);
	mediump float s = texture(TEXTURE, UV - offset_px * TEXTURE_PIXEL_SIZE).a;
	mediump float shadow_a = shadow_color.a * s * (1.0 - body_a);
	mediump float out_a = body_a + shadow_a;
	mediump vec3 rgb = (c.rgb * body_a + shadow_color.rgb * shadow_a) / max(out_a, MIN_ALPHA);
	COLOR = vec4(rgb, out_a * v_color.a);
}
