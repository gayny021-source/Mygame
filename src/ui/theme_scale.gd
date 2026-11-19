class_name ThemeScale
extends RefCounted
## Text scale of the reading screens (design/ux/reading-screen.md, accessibility M1/M7): 200 % is a
## multiplier of the theme font sizes, not `content_scale` (TD, U5).

const MIN_FACTOR: float = 1.0
const MAX_FACTOR: float = 2.0


## A copy of `base` with every font size (and the default one) times `factor`, clamped to 1.0…2.0.
## `base` stays at 100 %: call it again with the base theme, never with a scaled copy.
static func scaled(base: Theme, factor: float) -> Theme:
	var result: Theme = base.duplicate()
	var k: float = clampf(factor, MIN_FACTOR, MAX_FACTOR)
	result.default_font_size = roundi(base.default_font_size * k)
	for type: StringName in base.get_font_size_type_list():
		for item: StringName in base.get_font_size_list(type):
			result.set_font_size(item, type, roundi(base.get_font_size(item, type) * k))
	return result
