class_name Juice
extends RefCounted
## Tween-based feedback helpers for touch UI (Godot 4.7.2).
##
## Rules this file keeps (each was checked headless in 4.7.2):
## - One juice Tween per node. A new helper first calls finish(), which kills
##   the old Tween AND puts the node back at rest: Tween.kill() alone leaves the
##   property mid-way, so a button could stay half-transparent or shifted.
## - Controls animate offset_transform_* (new in 4.7): containers do not reset
##   it, the layout rect and the global transform stay unchanged, and the pivot
##   defaults to the centre. Rest is always "offset 0, scale 1", so a repeated
##   shake cannot drift.
## - Node2D animates `position`; its rest position is taken after finish(), so
##   overlapping punches return to the true home.
## - A Tween made with node.create_tween() dies with its node: after
##   queue_free() it is invalid and nothing touches the freed node.
## - Helpers do nothing on a node outside the tree (pop_in just shows it at rest).
##   After an `await`, the CALLER checks is_instance_valid(node) first.

const TWEEN_KEY := &"_juice_tween"
const REST_KEY := &"_juice_rest"


## Ends the running juice animation on `node` at once and leaves it at rest.
## Use it for "skip animation", the reduce-motion setting, and before driving
## the same node with any other Tween. Rest values are restored ONLY when a
## Tween is still running: after a finished animation the node is already at
## rest, and the game may have moved or dimmed it since.
static func finish(node: CanvasItem) -> void:
	if not is_instance_valid(node):
		return
	var running := false
	if node.has_meta(TWEEN_KEY):
		var old: Tween = node.get_meta(TWEEN_KEY)
		running = old != null and old.is_valid()
		if running:
			old.kill()
		node.remove_meta(TWEEN_KEY)
	if node.has_meta(REST_KEY):
		if running:
			var rest: Dictionary[String, Variant] = node.get_meta(REST_KEY)
			for path: String in rest:
				node.set_indexed(NodePath(path), rest[path])
		node.remove_meta(REST_KEY)


## Springy press: squash on touch, overshoot back. Call from `button_down`.
static func press_bounce(c: Control) -> void:
	if not c.is_inside_tree():
		return
	_use_offset_transform(c)
	var tw := _restart(c, {"offset_transform_scale": Vector2.ONE})
	tw.tween_property(c, "offset_transform_scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Window pop-in: fade and scale up from 0.85 with overshoot. Call after add_child().
static func pop_in(c: Control, duration := 0.3) -> void:
	c.show()
	if not c.is_inside_tree():
		c.modulate.a = 1.0
		return
	_use_offset_transform(c)
	var tw := _restart(c, {"modulate:a": 1.0, "offset_transform_scale": Vector2.ONE})
	c.modulate.a = 0.0
	c.offset_transform_scale = Vector2(0.85, 0.85)
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.6)
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Recoil / punch on a Node2D (a die, a card sprite): kick along `dir`, spring back.
static func punch(n: Node2D, dir: Vector2, strength := 12.0) -> void:
	if not n.is_inside_tree() or dir == Vector2.ZERO:
		return
	finish(n)
	var home := n.position
	var tw := _restart(n, {"position": home})
	tw.tween_property(n, "position", home + dir.normalized() * strength, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position", home, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Shake with decaying random offsets. Controls shake their offset_transform
## (layout untouched); Node2D shakes `position` around its rest position.
static func shake(item: CanvasItem, strength := 10.0, steps := 6, step_time := 0.04) -> void:
	if not item.is_inside_tree() or steps <= 0:
		return
	var prop := ""
	var home := Vector2.ZERO
	if item is Control:
		_use_offset_transform(item as Control)
		prop = "offset_transform_position"
	elif item is Node2D:
		finish(item)
		prop = "position"
		home = (item as Node2D).position
	else:
		return
	var tw := _restart(item, {prop: home})
	for i in steps:
		var k := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k
		tw.tween_property(item, prop, home + off, step_time)
	tw.tween_property(item, prop, home, step_time)


## Short haptic pulse. `enabled` comes from the player's settings; amplitude is in
## [0, 1], -1 = device default. Android needs permissions/vibrate in the export preset.
## Does nothing outside Android and iOS, so it is safe on desktop and in tests.
static func buzz(enabled: bool, duration_ms := 30, amplitude := -1.0) -> void:
	if not enabled:
		return
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return
	Input.vibrate_handheld(duration_ms, amplitude)


static func _restart(node: CanvasItem, rest: Dictionary[String, Variant]) -> Tween:
	finish(node)
	node.set_meta(REST_KEY, rest)
	var tw := node.create_tween()
	node.set_meta(TWEEN_KEY, tw)
	return tw


static func _use_offset_transform(c: Control) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
