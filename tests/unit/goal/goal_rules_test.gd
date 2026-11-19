extends GdUnitTestSuite
## GoalRules: F2, normalization (Э-21), the mode table (States) and the view model
## (chapter-goal.md, rules 1, 3, 5, 6, 7, 12; AC-71, AC-73).

const MODE := GoalView.Mode
const CAPTION := GoalView.Caption

var _g: ChapterData
var _h: ChapterData


func before_test() -> void:
	var chapters: Array[ChapterData] = GoalFixtures.chapters()
	_g = chapters[0]
	_h = chapters[1]


func _scene(chapter: ChapterData, id: String) -> SceneData:
	for scene: SceneData in chapter.scenes:
		if scene.id == id:
			return scene
	return null


func test_milestone_number_is_the_list_position_and_zero_for_none_or_broken() -> void:
	assert_int(GoalRules.milestone_number(_g, _scene(_g, "s2"))).is_equal(2)
	var broken: SceneData = SceneData.new()
	broken.milestone = "nope"
	assert_int(GoalRules.milestone_number(_g, broken)).is_equal(0)
	assert_int(GoalRules.milestone_number(_g, SceneData.new())).is_equal(0)
	assert_int(GoalRules.milestone_number(_g, null)).is_equal(0)


func test_f2_start_scene_assigns_whatever_was_before() -> void:
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s1"), true, 5, false)).is_equal(1)
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s1"), true, 0, true)).is_equal(1)


func test_f2_start_scene_with_a_broken_or_empty_milestone_gives_one() -> void:
	var broken: SceneData = SceneData.new()
	broken.milestone = "nope"
	assert_int(GoalRules.next_milestone_max(_g, broken, true, 3, false)).is_equal(1)
	assert_int(GoalRules.next_milestone_max(_g, SceneData.new(), true, 3, false)).is_equal(1)


func test_f2_raises_to_a_higher_milestone_and_keeps_a_lower_or_equal_one() -> void:
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s2"), false, 1, false)).is_equal(2)
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s2"), false, 2, false)).is_equal(2)
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s1"), false, 3, false)).is_equal(3)


func test_f2_scene_without_a_milestone_changes_nothing() -> void:
	assert_int(GoalRules.next_milestone_max(_g, SceneData.new(), false, 2, false)).is_equal(2)


func test_f2_with_the_fail_flag_standing_freezes_the_value() -> void:
	assert_int(GoalRules.next_milestone_max(_g, _scene(_g, "s3"), false, 1, true)).is_equal(1)


func test_f2_brings_the_old_value_into_one_to_v() -> void:
	assert_int(GoalRules.next_milestone_max(_g, SceneData.new(), false, 9, false)).is_equal(3)
	assert_int(GoalRules.next_milestone_max(_g, SceneData.new(), false, 0, false)).is_equal(1)
	assert_int(GoalRules.next_milestone_max(_g, SceneData.new(), false, -4, false)).is_equal(1)


func test_f2_chapter_without_milestones_gives_zero() -> void:
	var bare: ChapterData = ChapterData.new()
	assert_int(GoalRules.next_milestone_max(bare, SceneData.new(), true, 4, false)).is_equal(0)
	assert_int(GoalRules.next_milestone_max(bare, SceneData.new(), false, 4, false)).is_equal(0)


func test_f2_never_decreases_along_a_path_without_a_new_start() -> void:
	var value: int = 1
	for id: String in ["s1", "s2", "s1", "s3", "s2"]:
		var next: int = GoalRules.next_milestone_max(_g, _scene(_g, id), false, value, false)
		assert_int(next).is_greater_equal(value)
		value = next
	assert_int(value).is_equal(3)


func test_normalize_a_valid_context_is_left_alone_without_an_issue() -> void:
	var context: GoalRules.Context = GoalRules.normalize_context(_g, _scene(_g, "s2"), "st_main", 2, false)
	assert_int(context.milestone_max).is_equal(2)
	assert_str(context.start).is_equal("st_main")
	assert_str(context.issue).is_empty()


func test_normalize_missing_value_takes_the_scene_milestone_without_the_fail_flag() -> void:
	var context: GoalRules.Context = GoalRules.normalize_context(_g, _scene(_g, "s2"), "st_main", 0, false)
	assert_int(context.milestone_max).is_equal(2)
	assert_str(context.issue).is_not_empty()
	assert_bool(context.is_error).is_false()


func test_normalize_missing_value_with_the_fail_flag_is_one() -> void:
	assert_int(GoalRules.normalize_context(_g, _scene(_g, "s3"), "st_main", 0, true).milestone_max).is_equal(1)


func test_normalize_value_above_v_becomes_v_with_an_issue() -> void:
	assert_int(GoalRules.normalize_context(_g, _scene(_g, "s1"), "st_main", 7, false).milestone_max).is_equal(3)
	assert_str(GoalRules.normalize_context(_g, _scene(_g, "s1"), "st_main", 7, false).issue).is_not_empty()


func test_normalize_lost_start_takes_the_only_entry() -> void:
	var context: GoalRules.Context = GoalRules.normalize_context(_g, _scene(_g, "s1"), "gone", 1, false)
	assert_str(context.start).is_equal("st_main")
	assert_bool(context.is_error).is_false()
	assert_str(context.issue).is_not_empty()


func test_normalize_lost_start_among_several_is_empty_and_an_error() -> void:
	var context: GoalRules.Context = GoalRules.normalize_context(_h, _scene(_h, "h1"), "", 1, false)
	assert_str(context.start).is_empty()
	assert_bool(context.is_error).is_true()


func test_normalize_chapter_without_milestones_keeps_zero() -> void:
	var bare: ChapterData = ChapterData.new()
	assert_int(GoalRules.normalize_context(bare, null, "", 0, false).milestone_max).is_equal(0)


# Rows of States: [in_chapter, flag, pending, final_shown, mode]
func test_mode_table(in_chapter: bool, flag: bool, pending: bool, final_shown: bool, expected: int, test_parameters := [
	[false, false, false, false, MODE.NOT_STARTED],
	[false, true, true, true, MODE.NOT_STARTED],
	[true, false, false, false, MODE.RUNNING],
	[true, false, false, true, MODE.DONE_OK],
	[true, true, true, false, MODE.RUNNING],
	[true, true, false, false, MODE.FROZEN],
	[true, true, false, true, MODE.DONE_FAILED],
]) -> void:
	assert_int(GoalRules.mode(in_chapter, flag, pending, final_shown)).is_equal(expected)


func test_impossible_combinations_do_not_break_the_view_and_are_named() -> void:
	assert_bool(GoalRules.is_impossible(true, true, true)).is_true()
	assert_bool(GoalRules.is_impossible(false, true, false)).is_true()
	assert_bool(GoalRules.is_impossible(true, true, false)).is_false()
	assert_int(GoalRules.mode(true, true, true, true)).is_equal(MODE.DONE_FAILED)
	assert_int(GoalRules.mode(true, false, true, false)).is_equal(MODE.RUNNING)
	assert_int(GoalRules.mode(true, false, true, true)).is_equal(MODE.DONE_OK)


func test_no_intermediate_freeze_on_the_final_ac71() -> void:
	# the flag stands, the final text is not shown yet: running while pending, done once shown, never frozen on the final
	assert_int(GoalRules.mode(true, true, true, false)).is_equal(MODE.RUNNING)
	assert_int(GoalRules.mode(true, true, false, true)).is_equal(MODE.DONE_FAILED)


func test_view_outside_a_chapter_is_not_started() -> void:
	var view: GoalView = GoalRules.view(null, null, "", 0, false, false, false)
	assert_int(view.mode).is_equal(MODE.NOT_STARTED)
	assert_int(view.caption).is_equal(CAPTION.NONE)


func test_view_on_the_start_scene_says_the_goal_and_later_the_step() -> void:
	var first: GoalView = GoalRules.view(_g, _scene(_g, "s1"), "st_main", 1, false, false, false)
	assert_int(first.caption).is_equal(CAPTION.GOAL)
	assert_str(first.caption_text).is_equal(GoalFixtures.GOAL)
	assert_int(first.milestones_total).is_equal(3)
	assert_int(first.position).is_equal(1)
	var later: GoalView = GoalRules.view(_g, _scene(_g, "s2"), "st_main", 1, false, false, false)
	assert_int(later.caption).is_equal(CAPTION.STEP)
	assert_str(later.caption_text).is_equal("Идти к мосту")


func test_view_frozen_names_the_failed_goal_and_keeps_the_position() -> void:
	var view: GoalView = GoalRules.view(_g, _scene(_g, "s3"), "st_main", 2, true, false, false)
	assert_int(view.mode).is_equal(MODE.FROZEN)
	assert_int(view.position).is_equal(2)
	assert_int(view.caption).is_equal(CAPTION.FAILED)
	assert_str(view.caption_text).is_equal(GoalFixtures.GOAL)


func test_view_done_ok_fills_the_chain_and_done_failed_keeps_the_freeze_position() -> void:
	var ok: GoalView = GoalRules.view(_g, _scene(_g, "s3"), "st_main", 3, false, false, true)
	assert_int(ok.mode).is_equal(MODE.DONE_OK)
	assert_int(ok.position).is_equal(3)
	assert_int(ok.caption).is_equal(CAPTION.FULFILLED)
	var failed: GoalView = GoalRules.view(_g, _scene(_g, "s3"), "st_main", 2, true, false, true)
	assert_int(failed.mode).is_equal(MODE.DONE_FAILED)
	assert_int(failed.position).is_equal(2)
	assert_int(failed.caption).is_equal(CAPTION.FAILED)


func test_view_pending_keeps_the_step_caption() -> void:
	var view: GoalView = GoalRules.view(_g, _scene(_g, "s2"), "st_main", 2, true, true, false)
	assert_int(view.mode).is_equal(MODE.RUNNING)
	assert_int(view.caption).is_equal(CAPTION.STEP)
	assert_str(view.caption_text).is_equal("Перейти мост")


func test_view_goal_comes_from_the_start_of_the_attempt() -> void:
	var failed_start: GoalView = GoalRules.view(_h, _scene(_h, "h1"), "st_fail", 1, false, false, false)
	assert_str(failed_start.goal).is_equal(GoalFixtures.FAIL_GOAL)
	var main: GoalView = GoalRules.view(_h, _scene(_h, "h1"), "st_main", 1, false, false, false)
	assert_str(main.goal).is_equal("Идти дальше")


func test_view_lost_start_among_several_has_no_goal_and_no_goal_caption() -> void:
	var view: GoalView = GoalRules.view(_h, _scene(_h, "h2"), "", 1, false, false, true)
	assert_str(view.goal).is_empty()
	assert_int(view.caption).is_equal(CAPTION.NONE)


func test_view_chapter_without_milestones_has_no_chain_and_the_goal_line() -> void:
	var bare: ChapterData = ChapterData.new()
	bare.goal = "Цель"
	var view: GoalView = GoalRules.view(bare, null, "", 0, false, false, false)
	assert_int(view.milestones_total).is_equal(0)
	assert_int(view.position).is_equal(0)
	assert_int(view.caption).is_equal(CAPTION.GOAL)


func test_view_is_a_pure_function_of_its_inputs() -> void:
	var one: GoalView = GoalRules.view(_g, _scene(_g, "s2"), "st_main", 2, false, false, false)
	var two: GoalView = GoalRules.view(_g, _scene(_g, "s2"), "st_main", 2, false, false, false)
	assert_int(one.position).is_equal(two.position)
	assert_int(one.mode).is_equal(two.mode)
	assert_str(one.caption_text).is_equal(two.caption_text)


func test_view_stake_is_empty_when_the_chapter_has_none() -> void:
	assert_str(GoalRules.view(_g, _scene(_g, "s1"), "st_main", 1, false, false, false).stake).is_empty()


func test_view_stake_is_the_chapter_stake() -> void:
	_g.stake = "Склеп не отпустит чужака."
	assert_str(GoalRules.view(_g, _scene(_g, "s1"), "st_main", 1, false, false, false).stake).is_equal("Склеп не отпустит чужака.")
