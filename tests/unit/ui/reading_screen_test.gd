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
