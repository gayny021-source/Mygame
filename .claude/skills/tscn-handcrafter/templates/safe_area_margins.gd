class_name SafeAreaMargins
extends MarginContainer
## Keeps everything inside this container out of camera cutouts and system bars.
##
## Each margin = max(base margin, real inset + AIR) where the display reports an
## inset (camera cutout, system bar), else the base margin. AIR keeps text from
## touching the cutout. Recomputed on start and whenever the viewport size changes.
## API checked in Godot 4.7.2 (ClassDB): DisplayServer.get_display_safe_area()
## -> Rect2i in screen pixels. Headless it returns an empty rect (checked); then
## only the base margins apply. What desktop returns has not been checked.

@export var base_left := 48
@export var base_top := 96
@export var base_right := 48
@export var base_bottom := 72
## Extra viewport pixels kept between a reported inset and the content.
@export var air := 24


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var insets := insets_for(
		DisplayServer.get_display_safe_area(),
		DisplayServer.window_get_position(),
		DisplayServer.window_get_size(),
		get_viewport().get_visible_rect().size
	)
	add_theme_constant_override("margin_left", margin_for(base_left, insets[0], air))
	add_theme_constant_override("margin_top", margin_for(base_top, insets[1], air))
	add_theme_constant_override("margin_right", margin_for(base_right, insets[2], air))
	add_theme_constant_override("margin_bottom", margin_for(base_bottom, insets[3], air))


## Base margin when there is no inset; otherwise inset + air, never below base.
static func margin_for(base: int, inset: int, air_px: int) -> int:
	return base if inset <= 0 else maxi(base, inset + air_px)


## Pure conversion, unit-testable: returns [left, top, right, bottom] insets in
## viewport pixels for a window at `win_pos` of `win_size` screen pixels showing
## a viewport of `view` pixels. Any empty input gives zeros.
static func insets_for(safe: Rect2i, win_pos: Vector2i, win_size: Vector2i, view: Vector2) -> PackedInt32Array:
	if safe.size.x <= 0 or safe.size.y <= 0 or win_size.x <= 0 or win_size.y <= 0:
		return PackedInt32Array([0, 0, 0, 0])
	var k := view / Vector2(win_size)
	var win_end := win_pos + win_size
	var left := float(safe.position.x - win_pos.x) * k.x
	var top := float(safe.position.y - win_pos.y) * k.y
	var right := float(win_end.x - safe.end.x) * k.x
	var bottom := float(win_end.y - safe.end.y) * k.y
	return PackedInt32Array([ceili(maxf(left, 0.0)), ceili(maxf(top, 0.0)), ceili(maxf(right, 0.0)), ceili(maxf(bottom, 0.0))])
