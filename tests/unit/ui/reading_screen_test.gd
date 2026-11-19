extends GdUnitTestSuite
## Logic of the Reading screen without a render check (design/ux/reading-screen.md: Interaction Map,
## Lifecycle, Acceptance). The screen only reads RunSession; every touch goes to it.

const SCENE := "res://src/ui/reading/reading_screen.tscn"

var _t: SessionRig
var _screen: ReadingScreen
var _now: int
var _checks: Array[OptionData] = []


func before_test() -> void:
	_t = SessionRig.new()
	_now = 10000
	_checks = []
	_make_screen()


func _make_screen() -> void:
	_screen = (load(SCENE) as PackedScene).instantiate() as ReadingScreen
	_screen.clock = func() -> int: return _now
	_screen.check_requested.connect(func(option: OptionData) -> void: _checks.append(option))
	add_child(_screen)
	_screen.setup(_t.session, _t.hero)


func after_test() -> void:
	_screen.queue_free()


func _open_guard() -> void:
	_now += ReadingScreen.GUARD_MS + 1


func _started(read: bool = true) -> void:
	_screen.start()
	_t.settle()
	if read:
		_screen.stake_seen()
	_open_guard()


func _card(id: String) -> OptionCard:
	for card: OptionCard in _screen.cards():
		if card.view.option.id == id:
			return card
	return null


func test_scene_page_builds_a_card_per_option_inactive_until_the_stake_is_read() -> void:
	_started(false)
	assert_int(_screen.cards().size()).is_equal(3)
	assert_int(_card("a").view.state).is_equal(OptionView.State.INACTIVE)


func test_touch_on_an_inactive_card_shows_the_hint_and_changes_nothing() -> void:
	_started(false)
	var before: int = _t.session.journal_size()
	_screen.card_tapped(_card("a"))
	assert_bool(_screen.hint_visible()).is_true()
	assert_int(_t.session.journal_size()).is_equal(before)
	assert_int(_card("a").view.state).is_equal(OptionView.State.INACTIVE)
	assert_bool(_t.session.waiting()).is_false()


func test_stake_seen_reports_the_latch_once_and_opens_the_cards() -> void:
	_started(false)
	_screen.stake_seen()
	assert_bool(_t.session.stake_read()).is_true()
	assert_int(_card("a").view.state).is_equal(OptionView.State.OPEN)
	assert_bool(_screen.hint_visible()).is_false()


func test_open_plain_card_applies_the_outcome_and_shows_the_outcome_page() -> void:
	_started()
	_screen.card_tapped(_card("a"))
	_t.settle()
	assert_int(_screen.page_kind()).is_equal(StoryScreen.Kind.OUTCOME)
	assert_int(_screen.cards().size()).is_equal(0)
	assert_bool(_screen.next_visible()).is_true()


func test_the_page_waits_for_the_write_before_it_is_drawn() -> void:
	_started()
	_screen.card_tapped(_card("a"))
	assert_bool(_t.session.waiting()).is_true()
	assert_int(_screen.page_kind()).is_equal(StoryScreen.Kind.SCENE)
	_t.settle()
	assert_int(_screen.page_kind()).is_equal(StoryScreen.Kind.OUTCOME)


func test_touch_inside_the_guard_window_is_dropped_and_not_queued() -> void:
	_started()
	_now = _screen.guard_until() - 1
	_screen.card_tapped(_card("a"))
	assert_int(_t.session.journal_size()).is_equal(0)
	assert_bool(_t.session.waiting()).is_false()
	_open_guard()
	assert_int(_t.session.journal_size()).is_equal(0)


func test_risky_card_asks_the_roll_screen_with_its_option() -> void:
	_started()
	_screen.card_tapped(_card("r"))
	assert_int(_checks.size()).is_equal(1)
	assert_str(_checks[0].id).is_equal("r")


func test_second_touch_while_waiting_is_rejected() -> void:
	_started()
	_screen.card_tapped(_card("a"))
	_screen.card_tapped(_card("c"))
	_t.settle()
	assert_int(_t.session.journal_size()).is_equal(1)


func test_next_moves_one_page_and_a_repeat_is_rejected() -> void:
	_started()
	_screen.card_tapped(_card("a"))
	_t.settle()
	_open_guard()
	_screen.next_pressed()
	_screen.next_pressed()
	_t.settle()
	assert_str(_screen.scene_id()).is_equal("s2")
	assert_int(_t.session.journal_size()).is_equal(1)


func test_non_ok_load_builds_nothing() -> void:
	_screen.on_loaded(SaveWriter.LoadCode.CORRUPT, null)
	assert_int(_screen.page_kind()).is_equal(-1)
	assert_bool(_screen.next_visible()).is_false()


func test_ok_load_builds_the_resumed_page_with_a_fresh_guard() -> void:
	_t.started()
	_t.settle()
	_screen.on_loaded(SaveWriter.LoadCode.OK, _t.session.screen())
	assert_str(_screen.scene_id()).is_equal("s1")
	assert_int(_screen.guard_until()).is_equal(_now + ReadingScreen.GUARD_MS)


func test_goal_zone_opens_the_panel_and_back_closes_only_the_panel() -> void:
	_started()
	_screen.goal_tapped()
	assert_bool(_screen.panel_open()).is_true()
	_screen.go_back()
	assert_bool(_screen.panel_open()).is_false()
	assert_str(_screen.scene_id()).is_equal("s1")


func test_cards_get_no_touch_while_the_panel_is_open() -> void:
	_started()
	_screen.goal_tapped()
	_screen.card_tapped(_card("a"))
	assert_int(_t.session.journal_size()).is_equal(0)


func test_back_on_a_scene_does_nothing_and_in_the_guard_is_swallowed() -> void:
	_started()
	_screen.go_back()
	assert_bool(_screen.panel_open()).is_false()
	_screen.goal_tapped()
	_now = _screen.guard_until() - 1
	_screen.go_back()
	assert_bool(_screen.panel_open()).is_true()


func test_no_goal_zone_on_a_coda() -> void:
	var coda: StoryScreen = StoryScreen.new(StoryScreen.Kind.CODA)
	coda.transition = TransitionData.new()
	_screen.show_page(coda)
	assert_bool(_screen.goal_visible()).is_false()


func test_the_latch_survives_a_rebuild_on_the_same_screen() -> void:
	_started()
	_screen.rebuild()
	assert_int(_card("a").view.state).is_equal(OptionView.State.OPEN)


func test_line_in_view_needs_the_line_above_the_free_bottom() -> void:
	assert_bool(ReadingScreen.line_in_view(900.0, 100.0, 1000.0)).is_true()
	assert_bool(ReadingScreen.line_in_view(1001.0, 100.0, 1000.0)).is_false()
	assert_bool(ReadingScreen.line_in_view(90.0, 100.0, 1000.0)).is_false()


func test_flow_text_passes_the_mouse_and_the_accent_strip_ignores_it() -> void:
	_started()
	assert_int(_screen.flow_mouse_filter()).is_equal(Control.MOUSE_FILTER_PASS)
	assert_int(_screen.accent_mouse_filter()).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(_screen.hint_mouse_filter()).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_leaving_the_tree_kills_the_page_tween() -> void:
	_started()
	_screen.reduce_motion = false
	_screen.rebuild()
	_screen.get_parent().remove_child(_screen)
	assert_bool(_screen.tween_running()).is_false()
	add_child(_screen)


# --- audit round 1 (SCR1 TD decisions C1-C4, U1, U4, G1) ---

func _menu_button() -> Button:
	return _screen.find_child("Menu", true, false) as Button


func _screen_links(connections: Array) -> int:
	return connections.filter(func(link: Dictionary) -> bool: return (link["callable"] as Callable).get_object() == _screen).size()


func test_setup_twice_keeps_one_subscription() -> void:
	_screen.setup(_t.session, _t.hero)
	assert_int(_screen_links(_t.session.show_released.get_connections())).is_equal(1)
	assert_int(_screen_links(_t.session.loaded.get_connections())).is_equal(1)


func test_reentering_the_tree_resubscribes_once() -> void:
	remove_child(_screen)
	assert_int(_screen_links(_t.session.show_released.get_connections())).is_equal(0)
	add_child(_screen)
	assert_int(_screen_links(_t.session.show_released.get_connections())).is_equal(1)


func test_a_scene_without_text_raises_the_latch_at_once() -> void:
	_t.started(false)
	var page: StoryScreen = StoryScreen.new(StoryScreen.Kind.SCENE)
	page.scene = _t.session.screen().scene
	_screen.show_page(page)
	assert_bool(_t.session.stake_read()).is_true()
	assert_int(_card("a").view.state).is_equal(OptionView.State.OPEN)


func _refuse() -> RefusingState:
	var state: RefusingState = RefusingState.new(_t.hero.flags, Callable())
	_t.session._state = state
	return state


func _error_button(node_name: String) -> Button:
	return _screen.find_child("FlowError", true, false).find_child(node_name, true, false) as Button


func _fail_plain() -> void:
	_started()
	_refuse()
	_screen.card_tapped(_card("a"))


func _fail_roll() -> void:
	_started()
	_screen.card_tapped(_card("r"))
	_t.session.roll()
	_t.settle()
	_refuse()
	_t.session.continue_check()
	_t.session.close_check()
	_screen.refresh()


func test_a_flow_error_after_a_roll_shows_the_error_screen_without_cards() -> void:
	_fail_roll()
	assert_object(_screen.find_child("FlowError", true, false)).is_not_null()
	assert_object(_error_button("Load")).is_not_null()
	assert_object(_error_button("Menu")).is_not_null()
	assert_bool((_screen.find_child("Scroll", true, false) as Control).visible).is_false()


func test_a_flow_error_without_a_check_shows_the_error_screen_and_writes_nothing() -> void:
	_fail_plain()
	var writes: int = _t.writes()
	assert_object(_error_button("Load")).is_not_null()
	assert_bool((_screen.find_child("Scroll", true, false) as Control).visible).is_false()
	assert_int(_t.writes()).is_equal(writes)


func test_the_error_buttons_are_big_stacked_and_apart() -> void:
	_fail_plain()
	await get_tree().process_frame
	await get_tree().process_frame
	var load_button: Button = _error_button("Load")
	var menu_button: Button = _error_button("Menu")
	assert_float(load_button.size.y).is_greater_equal(168.0)
	assert_float(menu_button.size.y).is_greater_equal(168.0)
	assert_float(load_button.size.x).is_greater_equal(168.0)
	assert_float(menu_button.position.y - (load_button.position.y + load_button.size.y)).is_greater_equal(24.0)


func test_the_error_screen_has_a_title_and_the_approved_line() -> void:
	_fail_plain()
	var panel: Node = _screen.find_child("FlowError", true, false)
	assert_str((panel.find_child("Title", true, false) as Label).text).is_equal("Не удалось продолжить")
	assert_str((panel.find_child("Note", true, false) as Label).text).is_equal("Ход не прошёл. Последнее сохранение цело: загрузите его.")


func test_error_buttons_ignore_touches_in_the_guard_window() -> void:
	_fail_plain()
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_error_button("Menu").pressed.emit()
	assert_int(asked.size()).is_equal(0)
	assert_bool(_error_button("Menu").disabled).is_false()


func test_menu_asks_with_a_message_and_keeps_both_buttons_available() -> void:
	_fail_plain()
	_open_guard()
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_error_button("Menu").pressed.emit()
	assert_int(asked.size()).is_equal(1)
	assert_bool(_error_button("Menu").disabled).is_false()
	assert_bool(_error_button("Load").disabled).is_false()
	assert_object(_screen.find_child("Message", true, false)).is_not_null()
	_error_button("Load").pressed.emit()
	_t.settle()
	assert_int(_t.loads.size()).is_equal(1)


func test_back_works_while_the_buttons_are_disabled() -> void:
	_fail_plain()
	_open_guard()
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_error_button("Load").disabled = true
	_screen.go_back()
	assert_int(asked.size()).is_equal(1)


func test_load_of_an_empty_slot_on_the_error_screen_keeps_the_slot_and_the_screen() -> void:
	_fail_plain()
	_t.settle()
	_open_guard()
	var before: Dictionary = _t.disk_body()
	_t.rig.files.clear()
	_error_button("Load").pressed.emit()
	_t.settle()
	assert_int(_t.loads.size()).is_equal(1)
	assert_bool(_t.session.flow_error()).is_true()
	assert_bool(_error_button("Load").disabled).is_false()
	assert_object(_screen.find_child("Message", true, false)).is_not_null()
	assert_int(_t.rig.files.size()).is_equal(0)
	assert_dict(before).is_not_empty()


func test_load_of_a_corrupt_slot_keeps_the_error_screen_and_a_rebuild_draws_no_cards() -> void:
	_fail_plain()
	_t.settle()
	_open_guard()
	for path: String in _t.rig.files.keys():
		_t.rig.files[path] = "not a save".to_utf8_buffer()
	_error_button("Load").pressed.emit()
	_t.settle()
	_screen.rebuild()
	assert_bool(_t.session.flow_error()).is_true()
	assert_object(_screen.find_child("FlowError", true, false)).is_not_null()
	assert_int(_screen.cards().size()).is_equal(0)


func test_load_reloads_the_last_save_once_and_leaves_the_error_screen() -> void:
	_fail_plain()
	_open_guard()
	_error_button("Load").pressed.emit()
	_error_button("Load").pressed.emit()
	_t.settle()
	assert_int(_t.loads.size()).is_equal(1)
	assert_bool(_t.session.flow_error()).is_false()
	assert_object(_screen.find_child("FlowError", true, false)).is_null()
	assert_int(_screen.cards().size()).is_equal(3)


func test_a_failed_load_gives_the_buttons_back() -> void:
	_fail_plain()
	_open_guard()
	_t.settle()
	for path: String in _t.rig.files.keys():
		_t.rig.files[path] = "not a save".to_utf8_buffer()
	_error_button("Load").pressed.emit()
	_t.settle()
	assert_int(_t.loads.size()).is_equal(1)
	assert_bool(_error_button("Load").disabled).is_false()
	assert_bool(_error_button("Menu").disabled).is_false()


func test_back_on_the_error_screen_is_the_menu_and_swallowed_in_the_guard() -> void:
	_fail_plain()
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_screen.go_back()
	assert_int(asked.size()).is_equal(0)
	_open_guard()
	_screen.go_back()
	assert_int(asked.size()).is_equal(1)


func test_the_save_is_not_touched_by_the_error_screen_and_the_menu() -> void:
	_fail_plain()
	_t.settle()
	var before: Dictionary = _t.disk_body()
	_open_guard()
	_error_button("Menu").pressed.emit()
	_t.settle()
	assert_dict(_t.disk_body()).is_equal(before)


func test_a_rebuild_keeps_the_error_screen() -> void:
	_fail_plain()
	_screen.rebuild()
	assert_object(_screen.find_child("FlowError", true, false)).is_not_null()
	assert_int(_screen.cards().size()).is_equal(0)


func test_menu_button_asks_for_the_menu() -> void:
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_screen.show_page(StoryScreen.new(StoryScreen.Kind.ENDING))
	_open_guard()
	_menu_button().pressed.emit()
	assert_int(asked.size()).is_equal(1)


func test_back_on_an_ending_does_nothing_and_writes_nothing() -> void:
	var asked: Array[bool] = []
	_screen.menu_requested.connect(func() -> void: asked.append(true))
	_started()
	_t.settle()
	var writes: int = _t.writes()
	_screen.show_page(StoryScreen.new(StoryScreen.Kind.ENDING))
	_open_guard()
	_screen.go_back()
	assert_int(asked.size()).is_equal(0)
	assert_int(_screen.page_kind()).is_equal(StoryScreen.Kind.ENDING)
	assert_int(_t.writes()).is_equal(writes)


func test_the_boot_menu_handler_leaves_the_save_and_the_screen_alone() -> void:
	var boot: Control = auto_free((load("res://src/boot/boot.gd") as GDScript).new()) as Control
	_screen.menu_requested.connect(func() -> void: boot.call("on_menu_requested"))
	_started()
	_t.settle()
	var writes: int = _t.writes()
	var journal: int = _t.session.journal_size()
	_screen.show_page(StoryScreen.new(StoryScreen.Kind.ENDING))
	_open_guard()
	_menu_button().pressed.emit()
	_t.settle()
	assert_int(_t.writes()).is_equal(writes)
	assert_int(_t.session.journal_size()).is_equal(journal)
	assert_int(_screen.page_kind()).is_equal(StoryScreen.Kind.ENDING)


func test_band_is_the_strip_plus_the_hint_and_scales() -> void:
	assert_float(ReadingScreen.band(1.0, 70.0)).is_equal(125.0)
	assert_float(ReadingScreen.band(2.0, 70.0)).is_equal(180.0)


func test_goal_zone_collapses_only_at_200_percent_on_1920() -> void:
	assert_bool(ReadingScreen.collapse_goal(2.0, 1920.0)).is_true()
	assert_bool(ReadingScreen.collapse_goal(2.0, 2400.0)).is_false()
	assert_bool(ReadingScreen.collapse_goal(1.0, 1920.0)).is_false()


func test_collapsed_goal_zone_hides_the_caption_and_the_panel_keeps_it() -> void:
	_screen.theme = ThemeScale.scaled(_screen.theme, 2.0)
	_screen.collapse_height = 1920.0
	_started()
	_screen.rebuild()
	assert_bool((_screen.get_node("%GoalLabel") as Label).visible).is_false()
	_screen.goal_tapped()
	assert_bool(_screen.panel_open()).is_true()


func test_a_touch_reaches_the_tap_panel_once() -> void:
	assert_bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")).is_true()
	var panel: TapPanel = auto_free(TapPanel.new()) as TapPanel
	panel.size = Vector2(200, 200)
	var taps: Array[bool] = []
	panel.tapped.connect(func() -> void: taps.append(true))
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(50, 50)
	var up: InputEventMouseButton = down.duplicate() as InputEventMouseButton
	up.pressed = false
	panel._gui_input(down)
	panel._gui_input(up)
	assert_int(taps.size()).is_equal(1)


func test_the_sheet_lists_the_visible_flags_the_session_gives() -> void:
	# Arrange: oa sets f_b, which is visible; oc would set f_c, which is hidden
	for decl: FlagDecl in _t.hero.flags:
		decl.visible = decl.id == "f_b"
		decl.title = "title_%s" % decl.id
	_started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_open_guard()
	_screen.goal_tapped()
	var lines: Array[String] = []
	for child: Node in _screen._sheet_body.get_children():
		lines.append((child as Label).text)
	# Assert
	assert_bool(lines.has("title_f_b")).is_true()
	assert_bool(lines.has("title_f_a")).is_false()


# --- cartouche over the frame slot of the outcome page (НП-60, reading-screen.md Component Inventory) ---

func _set_cartouche(outcome_id: String, id: String) -> void:
	for outcome: OutcomeData in _t.hero.chapters[0].outcomes:
		if outcome.id == outcome_id:
			outcome.cartouche = id


func _open_outcome(card_id: String) -> void:
	_started()
	_screen.card_tapped(_card(card_id))
	_t.settle()


func _plate() -> Label:
	return _screen.find_child("Cartouche", true, false) as Label


func _frame_rect() -> Rect2:
	var frame: Control = _screen.find_child("Frame", true, false) as Control
	return Rect2(frame.global_position, frame.size)


func _flow_bottom() -> float:
	var scroll: Control = _screen.find_child("Scroll", true, false) as Control
	return scroll.global_position.y + scroll.size.y


func test_outcome_with_bonk_shows_the_plate_over_the_frame_slot() -> void:
	_set_cartouche("oa", "bonk")
	_open_outcome("a")
	assert_object(_plate()).is_not_null()
	assert_str(_plate().text).is_equal("БОНК!")
	assert_bool(_plate().is_visible_in_tree()).is_true()


func test_censor_shows_its_own_text() -> void:
	_set_cartouche("oa", "censor")
	_open_outcome("a")
	assert_str(_plate().text).is_equal("@#$%&!")


func test_outcome_without_a_cartouche_has_no_plate() -> void:
	_set_cartouche("oa", "bonk")
	_open_outcome("c")
	assert_object(_plate()).is_null()


func test_scene_page_has_no_plate() -> void:
	_set_cartouche("oa", "bonk")
	_started()
	assert_object(_plate()).is_null()


func test_plate_is_at_least_42_px_times_the_text_scale_and_ignores_touch() -> void:
	_set_cartouche("oa", "bonk")
	_open_outcome("a")
	assert_int(_plate().get_theme_font_size(&"font_size")).is_greater_equal(roundi(ReadingScreen.CARTOUCHE_PX * _screen._scale()))
	assert_int(_plate().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_plate_does_not_shift_the_layout() -> void:
	_open_outcome("c")
	await await_idle_frame()
	var without: Rect2 = _frame_rect()
	_screen.free()
	_t = SessionRig.new()
	_make_screen()
	_set_cartouche("oa", "bonk")
	_open_outcome("a")
	await await_idle_frame()
	assert_object(_plate()).is_not_null()
	assert_vector(_frame_rect().position).is_equal(without.position)
	assert_vector(_frame_rect().size).is_equal(without.size)


func test_outcome_page_flow_reaches_the_bottom_margin() -> void:
	_set_cartouche("oa", "bonk")
	_open_outcome("a")
	await await_idle_frame()
	var view: float = _screen.get_viewport().get_visible_rect().size.y
	assert_float(_flow_bottom()).is_greater_equal(view - 200.0)
