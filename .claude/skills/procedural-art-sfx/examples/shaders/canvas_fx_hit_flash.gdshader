// canvas_fx_hit_flash — hit / damage flash: tints the sprite toward flash_color.
// Author: Claude (procedural-art-sfx skill), 2026-11-07.
// Target: Godot 4.7.2, Compatibility renderer (OpenGL ES 3 / 3.3), Android phones.
// Budget: 0 extra texture samples, 1 mix per pixel. Animate `flash` 1 -> 0 with a Tween.
// In fragment(), COLOR already holds texture(TEXTURE, UV) * vertex color * modulate
// (checked in the 4.7.2 Compatibility canvas shader), so the texture is not sampled again.
shader_type canvas_item;

group_uniforms flash_look;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash);
}
