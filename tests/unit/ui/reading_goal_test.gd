extends GdUnitTestSuite
## The goal zone of the Reading screen draws the core view (chapter-goal.md, rules 4, 6; no screen-side
## «reached milestone» memory: the chain survives a load).

const SCENE := "res://src/ui/reading/reading_screen.tscn"

var _t: SessionRig
var _screen: ReadingScreen
var _now: int = 10000


func before_test() -> void:
	_t = SessionRig.new(SessionRig.HERO_ID, [GoalFixtures.chapter_g(), GoalFixtures.chapter_h()])
	_screen = _make_screen(_t)


func after_test() -> void:
	_screen.queue_free()


func _make_screen(rig: SessionRig) -> ReadingScreen:
	var screen: ReadingScreen = (load(SCENE) as PackedScene).instantiate() as ReadingScreen
	screen.clock = func() -> int: return _now
	add_child(screen)
	screen.setup(rig.session, rig.hero)
	return screen


func _dots(screen: ReadingScreen) -> Array[int]:
	# [dots, filled]
	var container: Node = screen.get_node("%Dots")
	var filled: int = 0
	for dot: Panel in container.get_children():
		var style: StyleBoxFlat = dot.get_theme_stylebox(&"panel") as StyleBoxFlat
		filled += 1 if style.bg_color.a > 0.0 else 0
	return [container.get_child_count(), filled]


func test_a_new_run_shows_the_chain_with_one_filled_dot_and_the_goal_line() -> void:
	_screen.start()
	_t.settle()
	assert_array(_dots(_screen)).is_equal([3, 1])
	assert_str((_screen.get_node("%GoalLabel") as Label).text).contains(GoalFixtures.GOAL)


func test_the_chain_is_rebuilt_from_the_snapshot_after_a_load() -> void:
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.settle()
	_screen.queue_free()
	_t.restart()
	_screen = _make_screen(_t)
	_screen.resume()
	_t.settle()
	assert_array(_dots(_screen)).is_equal([3, 2])
	assert_str((_screen.get_node("%GoalLabel") as Label).text).is_equal("Перейти мост")


func test_the_failed_caption_appears_with_the_outcome_text_of_the_fail() -> void:
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.settle()
	_t.read_stake()
	_screen.show_page(_t.session.screen())
	_t.session.apply_plain(_t.option("x"))
	_t.settle()
	_screen.show_page(_t.session.screen())
	assert_str((_screen.get_node("%GoalLabel") as Label).text).is_equal("Цель провалена: %s" % GoalFixtures.GOAL)
	assert_array(_dots(_screen)).is_equal([3, 2])


func _sheet_texts() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in _screen.get_node("%SheetBody").get_children():
		texts.append(label.text)
	return texts


func _to_failed_outcome() -> void:
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.settle()
	_t.read_stake()
	_t.session.apply_plain(_t.option("x"))
	_t.settle()
	_screen.show_page(_t.session.screen())


func test_the_panel_in_freeze_has_the_failed_line_first_then_the_goal_of_the_attempt() -> void:
	_to_failed_outcome()
	_now += ReadingScreen.GUARD_MS + 1
	_screen.goal_tapped()
	var texts: Array[String] = _sheet_texts()
	assert_str(texts[0]).is_equal("Цель провалена: %s" % GoalFixtures.GOAL)
	assert_str(texts[1]).is_equal("Цель главы")
	assert_str(texts[2]).is_equal(GoalFixtures.GOAL)


func test_the_panel_in_running_mode_starts_with_the_goal_heading() -> void:
	_screen.start()
	_t.settle()
	_now += ReadingScreen.GUARD_MS + 1
	_screen.goal_tapped()
	assert_str(_sheet_texts()[0]).is_equal("Цель главы")


func test_the_panel_does_not_substitute_the_chapter_goal_for_a_lost_start() -> void:
	# chapter m_h has two starts: an empty start in the context means no goal (Э-18, Э-21 г)
	var chapters: Array = [GoalFixtures.chapter_h()]
	var rig: SessionRig = SessionRig.new(SessionRig.HERO_ID, chapters)
	_screen.queue_free()
	_screen = _make_screen(rig)
	rig.started()
	rig.session._state.set_attempt("", 1)
	_screen.show_page(rig.session.screen())
	_now += ReadingScreen.GUARD_MS + 1
	_screen.goal_tapped()
	assert_array(_sheet_texts()).not_contains(["Идти дальше"])


func test_the_outcome_text_event_refreshes_the_goal_zone_through_the_signal() -> void:
	_to_failed_outcome()
	assert_str((_screen.get_node("%GoalLabel") as Label).text).is_equal("Цель провалена: %s" % GoalFixtures.GOAL)
