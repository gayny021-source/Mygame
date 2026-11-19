extends GdUnitTestSuite
## RunSession and the chapter goal (chapter-goal.md, rules 1, 5, 7, 11, 12; Э-20, Э-21, Э-24; AC-71, AC-77).
## F2 runs before the snapshot of the entry and commit 1; two flags and one event; a load derives them.

const MODE := GoalView.Mode
const CAPTION := GoalView.Caption

var _t: SessionRig
var _changed: int


func before_test() -> void:
	_t = _rig()


func _rig() -> SessionRig:
	var rig: SessionRig = SessionRig.new(SessionRig.HERO_ID, [GoalFixtures.chapter_g(), GoalFixtures.chapter_h()])
	_changed = 0
	rig.session.goal_changed.connect(func() -> void: _changed += 1)
	return rig


# The option, its write, and the text of the outcome shown (the UI event).
func _take(option_id: String, shown: bool = true) -> void:
	_t.session.apply_plain(_t.option(option_id))
	_t.settle()
	if shown:
		_t.session.report_outcome_text_shown()


func _next() -> void:
	_t.session.advance()
	_t.settle()
	_t.read_stake()
	_t.settle()


func _reload() -> void:
	_t.restart()
	_changed = 0
	_t.session.goal_changed.connect(func() -> void: _changed += 1)
	_t.session.load_saved()
	_t.settle()


func test_before_a_run_the_view_is_not_started() -> void:
	assert_int(_t.session.goal_view().mode).is_equal(MODE.NOT_STARTED)


func test_a_new_run_writes_start_and_the_first_milestone_before_the_first_snapshot() -> void:
	_t.started()
	var state: Dictionary = _t.disk_body()["resume"]["state"]
	assert_str(state["start"]).is_equal("st_main")
	assert_float(state["milestone_max"]).is_equal(1.0)
	var view: GoalView = _t.session.goal_view()
	assert_int(view.mode).is_equal(MODE.RUNNING)
	assert_int(view.caption).is_equal(CAPTION.GOAL)
	assert_int(view.position).is_equal(1)


func test_entering_a_milestone_scene_moves_p_into_the_entry_snapshot_and_the_schema() -> void:
	_t.started()
	_take("a")
	_next()
	var body: Dictionary = _t.disk_body()
	assert_float(body["resume"]["state"]["milestone_max"]).is_equal(2.0)
	assert_float(body["schema"][0]["state"]["milestone_max"]).is_equal(2.0)
	assert_int(_t.session.goal_view().position).is_equal(2)
	assert_int(_t.session.goal_view().caption).is_equal(CAPTION.STEP)


func test_the_fail_outcome_keeps_running_until_its_text_is_shown_then_freezes_with_one_signal() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x", false)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	assert_int(_t.session.goal_view().caption).is_equal(CAPTION.STEP)
	var before: int = _changed
	_t.session.report_outcome_text_shown()
	var view: GoalView = _t.session.goal_view()
	assert_int(_changed - before).is_equal(1)
	assert_int(view.mode).is_equal(MODE.FROZEN)
	assert_int(view.position).is_equal(2)
	assert_int(view.caption).is_equal(CAPTION.FAILED)
	_t.session.report_outcome_text_shown()
	assert_int(_changed - before).is_equal(1)


func test_milestones_after_the_freeze_do_not_move_p() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x")
	_next()
	assert_int(_t.session.goal_view().position).is_equal(2)
	assert_float(_t.disk_body()["resume"]["state"]["milestone_max"]).is_equal(2.0)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)


func test_the_final_text_completes_the_goal_in_one_step_without_a_freeze_between() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("e", false)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	_t.session.report_outcome_text_shown()
	var view: GoalView = _t.session.goal_view()
	assert_int(view.mode).is_equal(MODE.DONE_OK)
	assert_int(view.position).is_equal(3)
	assert_int(view.caption).is_equal(CAPTION.FULFILLED)


func test_a_fail_on_the_final_goes_straight_to_failed_ac71() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("y", false)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	_t.session.report_outcome_text_shown()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.DONE_FAILED)
	assert_int(_t.session.goal_view().position).is_equal(3)


func test_the_coda_belongs_to_the_chapter_and_the_next_start_resets_the_context() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("e")
	_t.session.advance()
	assert_int(_t.session.screen().kind).is_equal(StoryScreen.Kind.CODA)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.DONE_OK)
	_t.session.advance()
	_t.settle()
	var view: GoalView = _t.session.goal_view()
	assert_int(view.mode).is_equal(MODE.RUNNING)
	assert_int(view.position).is_equal(1)
	assert_int(view.milestones_total).is_equal(2)
	assert_str(_t.session.goal_view().goal).is_equal("Идти дальше")
	assert_int(_t.logs.size()).is_equal(0)


func test_a_failed_chapter_enters_the_next_one_through_the_fail_start_with_its_goal() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x")
	_next()
	_take("e")
	_t.session.advance()
	_t.session.advance()
	_t.settle()
	var view: GoalView = _t.session.goal_view()
	assert_str(view.goal).is_equal(GoalFixtures.FAIL_GOAL)
	assert_int(view.mode).is_equal(MODE.RUNNING)
	assert_str(_t.disk_body()["resume"]["state"]["start"]).is_equal("st_fail")


func test_a_new_run_resets_the_final_flag() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("e")
	_t.session.start_new()
	_t.settle()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	assert_int(_t.session.goal_view().position).is_equal(1)


func test_load_restores_p_and_start_and_the_final_flag_is_false() -> void:
	_t.started()
	_take("a")
	_next()
	_reload()
	var view: GoalView = _t.session.goal_view()
	assert_int(view.position).is_equal(2)
	assert_int(view.mode).is_equal(MODE.RUNNING)
	assert_str(_t.disk_body()["resume"]["state"]["start"]).is_equal("st_main")


func test_load_after_a_fail_freezes_at_once_without_a_pending_step() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x")
	_next()
	_reload()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)
	assert_int(_t.session.goal_view().position).is_equal(2)


func test_load_on_a_pending_fail_outcome_derives_pending_e24() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x", false)
	_reload()
	assert_int(_t.session.screen().kind).is_equal(StoryScreen.Kind.OUTCOME)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	assert_int(_t.session.goal_view().caption).is_equal(CAPTION.STEP)
	_t.session.report_outcome_text_shown()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)


func test_load_on_a_final_outcome_waits_for_the_event_ac77() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("e")
	_reload()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	_t.session.report_outcome_text_shown()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.DONE_OK)


func test_load_on_a_final_outcome_that_sets_the_flag_goes_to_failed_in_one_step() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("y", false)
	_reload()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	_t.session.report_outcome_text_shown()
	assert_int(_t.session.goal_view().mode).is_equal(MODE.DONE_FAILED)


func test_an_old_slot_without_the_context_loads_and_is_normalized_with_one_log_line_e21() -> void:
	_t.started()
	_take("a")
	_next()
	var body: Dictionary = _t.disk_body()
	body["resume"]["state"].erase("start")
	body["resume"]["state"].erase("milestone_max")
	_t.rig.files.clear()
	_t.rig.put(SessionRig.KEY, 1, body)
	_reload()
	assert_int(_t.loads[0][0]).is_equal(SaveWriter.LoadCode.OK)
	var view: GoalView = _t.session.goal_view()
	assert_int(view.position).is_equal(2)
	assert_str(view.goal).is_equal(GoalFixtures.GOAL)
	assert_int(_t.logs.filter(func(line: String) -> bool: return line.begins_with("цель главы")).size()).is_equal(1)


func test_a_slot_with_an_unknown_key_in_the_state_is_refused_dt04() -> void:
	_t.started()
	var body: Dictionary = _t.disk_body()
	body["resume"]["state"]["status"] = "x"
	_t.rig.files.clear()
	_t.rig.put(SessionRig.KEY, 1, body)
	_reload()
	assert_int(_t.loads[0][0]).is_equal(SaveWriter.LoadCode.CORRUPT)


func test_the_chapter_signal_in_running_mode_changes_nothing() -> void:
	_t.started()
	_t.session._on_chapter_finished("m_g")
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	assert_int(_t.logs.size()).is_equal(1)


func test_the_chapter_signal_of_another_chapter_changes_nothing_and_logs_once() -> void:
	_t.started()
	_t.session._on_chapter_finished("m_other")
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)
	assert_int(_t.logs.size()).is_equal(1)


func test_the_chapter_signal_after_the_coda_makes_it_not_started_and_a_repeat_logs_info() -> void:
	_t.started()
	_take("a")
	_next()
	_take("g")
	_next()
	_take("e")
	_t.session._on_chapter_finished("m_g")
	assert_int(_t.session.goal_view().mode).is_equal(MODE.NOT_STARTED)
	assert_int(_t.logs.size()).is_equal(0)
	_t.session._on_chapter_finished("m_g")
	assert_int(_t.logs.size()).is_equal(1)


func test_report_without_an_outcome_on_screen_changes_nothing() -> void:
	_t.started()
	var before: int = _changed
	_t.session.report_outcome_text_shown()
	assert_int(_changed).is_equal(before)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.RUNNING)


func test_ac72_a_flag_standing_since_an_earlier_scene_is_not_pending_after_a_load_and_p_is_two() -> void:
	_t.started()
	_take("a")
	_next()
	_take("x")
	_next()
	_take("y", false)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)
	_reload()
	assert_int(_t.session.screen().kind).is_equal(StoryScreen.Kind.OUTCOME)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)
	assert_int(_t.session.goal_view().position).is_equal(2)
	assert_int(_t.session.goal_view().caption).is_equal(CAPTION.FAILED)


func test_a_graph_loop_back_into_a_node_does_not_make_the_repeated_fail_pending_after_a_load() -> void:
	# s2 is a node: x sets f_fail and leads back into s2; the second x sets nothing (the flag stands)
	var data: Dictionary = GoalFixtures.chapter_g()
	GraphFixtures.find(data["transitions"], "t_s2")["to"] = "scene:s2"
	_t = SessionRig.new(SessionRig.HERO_ID, [data, GoalFixtures.chapter_h()])
	_t.started()
	_take("a")
	_next()
	_take("x")
	_next()
	_take("x", false)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)
	_reload()
	assert_int(_t.session.screen().kind).is_equal(StoryScreen.Kind.OUTCOME)
	assert_int(_t.session.goal_view().mode).is_equal(MODE.FROZEN)


# Rows of a damaged context: the load succeeds and the view is normalized (Э-21).
func test_a_damaged_context_type_loads_and_is_normalized(milestone: Variant, start: Variant, test_parameters := [
	["2", "st_main"], [1.5, "st_main"], [null, "st_main"], [2, 5], [2, null],
]) -> void:
	_t.started()
	_take("a")
	_next()
	var body: Dictionary = _t.disk_body()
	body["resume"]["state"]["milestone_max"] = milestone
	body["resume"]["state"]["start"] = start
	_t.rig.files.clear()
	_t.rig.put(SessionRig.KEY, 1, body)
	_reload()
	assert_int(_t.loads[0][0]).is_equal(SaveWriter.LoadCode.OK)
	var view: GoalView = _t.session.goal_view()
	assert_int(view.position).is_equal(2)
	assert_str(view.goal).is_equal(GoalFixtures.GOAL)
