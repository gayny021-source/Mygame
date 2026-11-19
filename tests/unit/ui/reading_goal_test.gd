extends GdUnitTestSuite
## The goal zone of the Reading screen draws the core view (chapter-goal.md, rules 4, 6; no screen-side
## «reached milestone» memory: the chain survives a load).

const SCENE := "res://src/ui/reading/reading_screen.tscn"

var _t: SessionRig
var _screen: ReadingScreen


func before_test() -> void:
	_t = SessionRig.new(SessionRig.HERO_ID, [GoalFixtures.chapter_g(), GoalFixtures.chapter_h()])
	_screen = _make_screen(_t)


func after_test() -> void:
	_screen.queue_free()


func _make_screen(rig: SessionRig) -> ReadingScreen:
	var screen: ReadingScreen = (load(SCENE) as PackedScene).instantiate() as ReadingScreen
	screen.clock = func() -> int: return 10000
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
