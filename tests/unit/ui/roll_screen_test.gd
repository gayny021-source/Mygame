extends GdUnitTestSuite
## Logic of the Roll screen without a render check (design/ux/roll-screen.md: States, Interaction Map,
## Lifecycle; Acceptance RS-U4, RS-U5, RS-I1…I12 as far as they run headless). The tumble tween is not
## waited for: `finish_tumble()` plays its end at once.

const SCENE := "res://src/ui/roll/roll_screen.tscn"

var _t: SessionRig
var _screen: RollScreen
var _now: int
var _exits: Array[int] = []
var _faces: Array[int] = []
var _shown: Array[bool] = []


func before_test() -> void:
	_now = 10000
	_exits = []
	_faces = []
	_shown = []
	_make(14)


func after_test() -> void:
	_screen.queue_free()


func _make(face: int) -> void:
	if _screen != null:
		_screen.queue_free()
	_t = SessionRig.new()
	_t.source = CountingD20Source.new(face)
	_t.restart()
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_screen = _build()


func _build() -> RollScreen:
	var screen: RollScreen = (load(SCENE) as PackedScene).instantiate() as RollScreen
	screen.clock = func() -> int: return _now
	screen.fade_s = 0.0
	screen.rng.seed = 7
	screen.exited.connect(func(kind: int, _page: StoryScreen) -> void: _exits.append(kind))
	screen.face_changed.connect(func(face: int) -> void: _faces.append(face))
	screen.result_shown.connect(func(success: bool, _crit: int) -> void: _shown.append(success))
	add_child(screen)
	screen.setup(_t.session)
	screen.open()
	return screen


func _open_guard() -> void:
	_now += RollScreen.GUARD_MS + 1


func _rolled() -> void:
	_open_guard()
	_screen.roll_pressed()
	_open_guard()


func _node(node_name: String) -> Control:
	return _screen.get_node("%" + node_name) as Control


func test_u4_flicker_never_asks_the_d20_source() -> void:
	_rolled()
	_screen.finish_tumble()
	_t.settle()
	_screen.skip()
	assert_int(_t.source.calls).is_equal(1)


func test_u5_same_seed_gives_the_same_flicker() -> void:
	var other: RollScreen = _build()
	_faces.clear()
	for index: int in 6:
		_screen.flicker()
	var first: Array[int] = _faces.duplicate()
	_faces.clear()
	other.rng.seed = 7
	_screen.rng.seed = 7
	for index: int in 6:
		other.flicker()
	assert_array(_faces).is_equal(first)
	other.queue_free()


func test_i1_touch_inside_the_open_window_is_dropped_and_not_queued() -> void:
	_screen.roll_pressed()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.CHOSEN)
	_open_guard()
	_screen.roll_pressed()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.TUMBLING)


func test_i1_skip_inside_the_roll_window_is_dropped() -> void:
	_open_guard()
	_screen.roll_pressed()
	_screen.skip()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.TUMBLING)


func test_i2_slow_write_holds_the_face_until_the_signal() -> void:
	_rolled()
	assert_bool(_t.session.waiting()).is_true()
	_screen.finish_tumble()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.WAITING)
	_screen.skip()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.WAITING)
	assert_array(_shown).is_empty()
	_t.settle()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_array(_shown).has_size(1)


func test_i3_skip_on_a_crit_keeps_the_buttons_off_until_the_short_animation_ends() -> void:
	_make(20)
	_rolled()
	_t.settle()
	_screen.skip()
	assert_bool(_node("Cartouche").visible).is_true()
	_now += 400
	_screen.go_back()
	assert_bool((_node("Action") as Button).disabled).is_true()
	_now += 300
	_screen.tick()
	assert_bool((_node("Action") as Button).disabled).is_false()


func test_i4_back_is_cancel_before_the_roll() -> void:
	_open_guard()
	_screen.go_back()
	assert_array(_exits).is_equal([RollScreen.Exit.CANCELLED])
	assert_bool(_t.session.roll() == null).is_true()


func test_i4_back_on_the_active_result_applies_nothing_and_stays() -> void:
	_rolled()
	_t.settle()
	_screen.finish_tumble()
	_screen.skip()
	_open_guard()
	_screen.tick()
	_screen.go_back()
	assert_array(_exits).is_empty()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)


func test_i4_back_while_rolling_skips_and_does_not_cancel() -> void:
	_rolled()
	_t.settle()
	_screen.go_back()
	assert_array(_exits).is_empty()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)


func test_i5_pause_resume_shows_the_static_result_once() -> void:
	_rolled()
	_screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_t.settle()
	_screen.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_array(_shown).has_size(1)
	assert_bool((_node("Action") as Button).disabled).is_true()
	_now += 301
	_screen.tick()
	assert_bool((_node("Action") as Button).disabled).is_false()


func test_i6_resize_keeps_the_state_and_the_result() -> void:
	_rolled()
	_t.settle()
	_screen.skip()
	var calc: String = (_node("Calc") as Label).text
	_screen.size = Vector2(1080, 2400)
	_screen.size = Vector2(1080, 1920)
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_str((_node("Calc") as Label).text).is_equal(calc)


func test_i7_restored_turn_opens_on_the_result_without_cancel() -> void:
	_rolled()
	_t.settle()
	var calls: int = _t.source.calls
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	_exits.clear()
	_shown.clear()
	_screen.queue_free()
	_screen = _build()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_float(_node("Back").modulate.a).is_equal(0.0)
	assert_int(_node("Back").mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_array(_shown).has_size(1)
	assert_int(_t.source.calls).is_equal(calls)


func test_i8_mouse_filters_and_hidden_slots() -> void:
	assert_int(_screen.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(_node("Reroll").mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool((_node("Reroll") as Button).disabled).is_true()
	assert_int(_node("Cartouche").mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(_node("CartoucheLabel").mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var back_size: Vector2 = _node("Back").size
	_rolled()
	for node_name: String in ["Back", "Action"]:
		var slot: Control = _node(node_name)
		assert_int(slot.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_float(slot.modulate.a).is_equal(0.0)
		assert_int(slot.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_vector(_node("Back").size).is_equal(back_size)
	_t.settle()
	_screen.skip()
	var action: Button = _node("Action") as Button
	assert_int(action.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_now += 301
	_screen.tick()
	assert_int(action.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_i9_released_write_reveals_at_the_end_of_the_tumble() -> void:
	_rolled()
	_t.settle()
	assert_bool(_t.session.waiting()).is_false()
	_screen.finish_tumble()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.REVEALING)


func test_i9_refused_commit_leaves_no_wait_and_reveals_without_show_released() -> void:
	_t.hero.id = "Bad Id"
	_open_guard()
	_screen.roll_pressed()
	assert_bool(_t.session.waiting()).is_false()
	_screen.finish_tumble()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.REVEALING)
	_open_guard()
	_screen.skip()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_array(_shown).has_size(1)


func test_i11_wait_after_the_tumble_stops_flicker() -> void:
	_rolled()
	_screen.finish_tumble()
	_faces.clear()
	_screen.finish_wait()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.WAITING)
	_now += 1
	assert_array(_faces).has_size(1)


func test_i12_reduced_motion_one_face_change_and_instant_crit() -> void:
	_make(20)
	_screen.reduce_motion = true
	_screen.open()
	_rolled()
	_t.settle()
	assert_int(_screen.phase()).is_equal(RollScreen.Phase.SHOWN)
	assert_array(_faces).has_size(1)
	assert_bool(_node("Cartouche").visible).is_true()
	_now += 301
	_screen.tick()
	assert_bool((_node("Action") as Button).disabled).is_false()


func test_continue_applies_the_outcome_and_exits_with_the_page() -> void:
	_rolled()
	_t.settle()
	_screen.skip()
	_now += 301
	_screen.tick()
	var pages: Array[StoryScreen] = []
	_screen.exited.connect(func(_kind: int, page: StoryScreen) -> void: pages.append(page))
	_screen.continue_pressed()
	_t.settle()
	assert_array(_exits).is_equal([RollScreen.Exit.CONTINUED])
	assert_object(pages[0]).is_not_null()
