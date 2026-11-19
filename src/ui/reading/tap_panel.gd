class_name TapPanel
extends PanelContainer
## A touch target that acts on release (design/ux/reading-screen.md, Interaction Map; accessibility M4).
## A finger that slides more than DRAG_LIMIT or leaves the panel cancels the tap, so a swipe that
## scrolls the flow never presses anything. A second finger is ignored while the first one is down
## (touch arrives as emulated left-mouse events, so only the first finger reaches here).

## The finger was released inside the panel without a swipe.
signal tapped()

## S_ЖЕСТ of the spec: a movement above this many pixels is a swipe, not a tap.
const DRAG_LIMIT: float = 24.0

var _down: bool = false
var _press_at: Vector2


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(button.position)
		else:
			_release(button.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _down and _is_swipe(motion.position):
		_set_down(false)


## True while a finger rests on the panel and may still become a tap.
func is_down() -> bool:
	return _down


## Visual hook: the finger went down or was cancelled / released.
func _on_down_changed(_is_pressed: bool) -> void:
	pass


func _press(at: Vector2) -> void:
	if _down:
		return
	_press_at = at
	_set_down(true)


func _release(at: Vector2) -> void:
	if not _down:
		return
	_set_down(false)
	if not _is_swipe(at):
		tapped.emit()


func _is_swipe(at: Vector2) -> bool:
	var outside: bool = not Rect2(Vector2.ZERO, size).has_point(at)
	return outside or at.distance_to(_press_at) > DRAG_LIMIT


func _set_down(value: bool) -> void:
	_down = value
	_on_down_changed(value)
