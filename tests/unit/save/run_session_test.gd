extends GdUnitTestSuite
## Unit tests for RunSession, the owner of Save transitions 1, 2, 3, 6, 7 (save-system.md, rules 4, 7,
## 8, 10; AC-22, AC-23, AC-24 (6), AC-25, AC-31, AC-38; ADR-0002 §1, §5 B2; DD-021, DD-022; story SV4).

const KIND := StoryScreen.Kind
const LOAD_OK: int = SaveWriter.LoadCode.OK
const LOAD_CORRUPT: int = SaveWriter.LoadCode.CORRUPT

var _t: SessionRig


func before_test() -> void:
	_t = SessionRig.new()


func _resume_of(body: Dictionary) -> Dictionary:
	return body["resume"]["position"]


# A tampered copy of the disk body, written as the only generation `gen`.
func _put(body: Dictionary, gen: int) -> void:
	_t.rig.put(SessionRig.KEY, gen, body)


func test_start_new_is_one_pair_one_ticket_and_shows_after_the_signal() -> void:
	# Act
	var screen: StoryScreen = _t.session.start_new()
	var waiting_before: bool = _t.session.waiting()
	_t.settle()
	# Assert (AC-22 transition 6, AC-24)
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_bool(waiting_before).is_true()
	assert_bool(_t.session.waiting()).is_false()
	assert_int(_t.released).is_equal(1)
	assert_int(_t.rig.finished.size()).is_equal(1)
	assert_int(_t.writes()).is_equal(2)
	var body: Dictionary = _t.disk_body()
	assert_str(body["run_id"]).is_equal("run1")
	assert_array(body["schema"]).is_empty()
	assert_bool(body.has("roll")).is_false()
	assert_str(_resume_of(body)["scene"]).is_equal("s1")


func test_new_run_over_an_old_one_has_another_run_id_and_empty_schema() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	# Act
	_t.session.start_new()
	_t.settle()
	# Assert
	var body: Dictionary = _t.disk_body()
	assert_str(body["run_id"]).is_equal("run2")
	assert_array(body["schema"]).is_empty()
	assert_str(_resume_of(body)["scene"]).is_equal("s1")
	assert_array(body["resume"]["state"]["flags"]).is_empty()


func test_plain_option_commits_2_with_pending_outcome_and_no_commit_1() -> void:
	# Arrange
	_t.started()
	var before: int = _t.writes()
	# Act
	var screen: StoryScreen = _t.session.apply_plain(_t.option("a"))
	var waiting: bool = _t.session.waiting()
	_t.settle()
	# Assert (AC-22 transition 2, AC-25)
	assert_int(screen.kind).is_equal(KIND.OUTCOME)
	assert_bool(waiting).is_true()
	assert_int(_t.writes() - before).is_equal(1)
	assert_str(_resume_of(_t.disk_body())["pending_outcome"]).is_equal("oa")
	assert_bool(_t.session.waiting()).is_false()


func test_advance_into_a_scene_commits_1_once_and_does_not_wait() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	var before: int = _t.writes()
	# Act
	var screen: StoryScreen = _t.session.advance()
	var waiting: bool = _t.session.waiting()
	_t.settle()
	# Assert (AC-22 transition 1, B2)
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_bool(waiting).is_false()
	assert_int(_t.writes() - before).is_equal(1)
	var position: Dictionary = _resume_of(_t.disk_body())
	assert_str(position["scene"]).is_equal("s2")
	assert_str(position["pending_outcome"]).is_empty()


func test_check_commits_3_then_7_with_the_state_before_the_outcome() -> void:
	# Arrange
	_t.started()
	var before: int = _t.writes()
	assert_bool(_t.session.choose_check(_t.option("r"))).is_true()
	# Act
	var rolled: D20Result = _t.session.roll()
	var waiting_rolled: bool = _t.session.waiting()
	_t.settle()
	var after_roll: Dictionary = _t.disk_body()
	var shown: StoryScreen = _t.session.continue_check()
	var waiting_applied: bool = _t.session.waiting()
	_t.settle()
	var after_apply: Dictionary = _t.disk_body()
	# Assert (AC-22 transitions 3, 7; AC-25)
	assert_int(rolled.roll).is_equal(SessionRig.FACE)
	assert_bool(waiting_rolled).is_true()
	assert_bool(waiting_applied).is_true()
	assert_int(_t.writes() - before).is_equal(2)
	assert_bool(after_roll["roll"]["applied"]).is_false()
	assert_bool(after_apply["roll"]["applied"]).is_true()
	assert_array(after_apply["resume"]["state"]["flags"]).is_empty()
	assert_int(shown.kind).is_equal(KIND.OUTCOME)
	assert_bool(_t.session.has_flag("f_a")).is_true()


func test_entering_a_scene_after_a_check_drops_the_roll_record() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	_t.session.continue_check()
	_t.settle()
	# Act
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	# Assert (AC-23)
	var body: Dictionary = _t.disk_body()
	assert_bool(body.has("roll")).is_false()
	assert_str(_resume_of(body)["scene"]).is_equal("s2")


func test_schema_gets_a_snapshot_for_a_node_scene_and_one_for_the_next_chapter() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	var in_node: Dictionary = _t.disk_body()
	# Act: s2 (node) -> its option -> chapter m_h
	_t.session.apply_plain(_t.option("s2_go"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	var next_chapter: Dictionary = _t.disk_body()
	# Assert (AC-23): s2 is a node: one snapshot; the first scene of m_h replaces the list
	assert_int(in_node["schema"].size()).is_equal(1)
	assert_str(in_node["schema"][0]["position"]["scene"]).is_equal("s2")
	assert_int(next_chapter["schema"].size()).is_equal(1)
	assert_str(next_chapter["schema"][0]["position"]["chapter"]).is_equal(_t.hero.chapters[1].id)
	assert_str(_resume_of(next_chapter)["chapter"]).is_equal(_t.hero.chapters[1].id)


func test_ordinary_scene_adds_no_snapshot() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	# Act
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	_t.session.apply_plain(_t.option("s2_go"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	_t.session.apply_plain(_t.option("s1_go"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	# Assert: s1 of m_h is a start entry (one snapshot), s2 of m_h is an ordinary scene (still one)
	var body: Dictionary = _t.disk_body()
	assert_str(_resume_of(body)["scene"]).is_equal("s2")
	assert_int(body["schema"].size()).is_equal(1)


func test_snapshot_in_schema_is_a_copy_not_the_live_state() -> void:
	# Arrange: a node scene snapshot, then the live state changes
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	var flags_at_node: Array = _t.disk_body()["schema"][0]["state"]["flags"].duplicate()
	# Act
	_t.session.apply_plain(_t.option("s2_go"))
	_t.settle()
	# Assert
	assert_array(_t.disk_body()["schema"][0]["state"]["flags"]).is_equal(flags_at_node)


func test_load_does_not_write_and_resumes_the_saved_scene() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	_t.restart()
	var before: int = _t.writes()
	# Act
	var token: int = _t.session.load_saved()
	_t.settle()
	# Assert (AC-38, B2)
	assert_int(token).is_greater(0)
	assert_int(_t.loads.size()).is_equal(1)
	assert_int(_t.loads[0][0]).is_equal(LOAD_OK)
	assert_int(_t.loads[0][1].kind).is_equal(KIND.SCENE)
	assert_str(_t.loads[0][1].scene.id).is_equal("s2")
	assert_int(_t.writes() - before).is_equal(0)
	assert_bool(_t.session.has_flag("f_b")).is_true()


func test_load_refuses_a_missing_scene_without_a_run_or_a_write() -> void:
	# Arrange: gen 2 has a gone scene, gen 1 is good (AC-31)
	_t.started()
	var good: Dictionary = _t.disk_body()
	var bad: Dictionary = good.duplicate(true)
	bad["resume"]["position"]["scene"] = "s_gone"
	_t.rig.files.clear()
	_put(good, 1)
	_put(bad, 2)
	var slot_a: PackedByteArray = _t.rig.bytes(SessionRig.KEY, WriterRig.A)
	var slot_b: PackedByteArray = _t.rig.bytes(SessionRig.KEY, WriterRig.B)
	_t.restart()
	# Act
	_t.session.load_saved()
	_t.settle()
	var screen: StoryScreen = _t.session.advance()
	var again: StoryScreen = _t.session.apply_plain(null)
	# Assert
	assert_int(_t.loads[0][0]).is_equal(LOAD_CORRUPT)
	assert_int(_t.loads[0][1].kind).is_equal(KIND.ERROR)
	assert_bool(_t.session.active()).is_false()
	assert_object(screen).is_null()
	assert_object(again).is_null()
	assert_int(_t.writes()).is_equal(0)
	assert_array(_t.rig.bytes(SessionRig.KEY, WriterRig.A)).is_equal(slot_a)
	assert_array(_t.rig.bytes(SessionRig.KEY, WriterRig.B)).is_equal(slot_b)


func test_refused_restore_drops_the_record_and_the_next_commit_has_none() -> void:
	# Arrange: a record of a check the scene does not have
	_t.started()
	var body: Dictionary = _t.disk_body()
	body["roll"] = {"scene_id": "s1", "check_id": "gone", "stat_id": "strength", "roll": 14, "bonus": 4, "dc": 13, "rerolled": false, "applied": false}
	_t.rig.files.clear()
	_put(body, 1)
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	var logged: int = _t.logs.size()
	_t.session.report_stake_visible()
	# Act
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	# Assert (DD-022)
	assert_int(_t.loads[0][0]).is_equal(LOAD_OK)
	assert_int(logged).is_greater(0)
	assert_bool(_t.disk_body().has("roll")).is_false()
	assert_str(_resume_of(_t.disk_body())["pending_outcome"]).is_equal("oa")


func test_refused_commit_shows_at_once_for_each_waiting_transition() -> void:
	# Arrange: a hero id the writer refuses for a path (commit returns 0)
	_t = SessionRig.new("Bad Id")
	# Act
	var screen: StoryScreen = _t.session.start_new()
	var after_start: bool = _t.session.waiting()
	_t.session.apply_plain(_t.option("a"))
	var after_plain: bool = _t.session.waiting()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	var after_roll: bool = _t.session.waiting()
	_t.session.continue_check()
	var after_apply: bool = _t.session.waiting()
	_t.settle()
	# Assert (DD-022): no ticket, so no wait and no write
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_bool(after_start).is_false()
	assert_bool(after_plain).is_false()
	assert_bool(after_roll).is_false()
	assert_bool(after_apply).is_false()
	assert_int(_t.writes()).is_equal(0)
	assert_int(_t.rig.lines.size()).is_greater(0)


func test_error_screen_from_advance_writes_nothing() -> void:
	# Arrange: the last chapter ends with no chapter after it
	_t.hero.chapters.pop_back()
	_t.hero.chapter_ids.remove_at(1)
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.session.apply_plain(_t.option("s2_go"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	var before: int = _t.writes()
	# Act: the coda is on show, the next «Дальше» finds no chapter
	var screen: StoryScreen = _t.session.advance()
	_t.settle()
	# Assert
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_int(_t.writes() - before).is_equal(0)


# Round 1 (TD C1, C2, C3): regressions, written before the fixes.
func test_double_tap_on_a_plain_option_applies_and_commits_once() -> void:
	# Arrange
	_t.started()
	var tapped: OptionData = _t.option("c")
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	var journal: int = _t.session.journal_size()
	var before: int = _t.writes()
	# Act: a second option tapped while the outcome of the first is on show
	var again: StoryScreen = _t.session.apply_plain(tapped)
	_t.settle()
	# Assert (C1)
	assert_object(again).is_null()
	assert_int(_t.session.journal_size()).is_equal(journal)
	assert_bool(_t.session.has_flag("f_c")).is_false()
	assert_int(_t.writes() - before).is_equal(0)


func test_option_of_another_screen_changes_neither_state_nor_disk() -> void:
	# Arrange: s1's option while s2 is on show
	_t.started()
	var stale: OptionData = _t.option("c")
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	_t.settle()
	var journal: int = _t.session.journal_size()
	var before: int = _t.writes()
	# Act
	var screen: StoryScreen = _t.session.apply_plain(stale)
	_t.settle()
	# Assert (C1)
	assert_object(screen).is_null()
	assert_int(_t.session.journal_size()).is_equal(journal)
	assert_bool(_t.session.has_flag("f_c")).is_false()
	assert_int(_t.writes() - before).is_equal(0)


func test_choose_check_is_refused_while_a_turn_lives_so_no_reroll() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	var calls: int = _t.source.calls
	# Act
	var second: bool = _t.session.choose_check(_t.option("r"))
	var rerolled: D20Result = _t.session.roll()
	# Assert (C2)
	assert_bool(second).is_false()
	assert_object(rerolled).is_null()
	assert_int(_t.source.calls).is_equal(calls)


func test_continue_with_a_missing_outcome_neither_commits_7_nor_applies() -> void:
	# Arrange: the hero has no outcome `ow`
	for outcome: OutcomeData in _t.hero.chapters[0].outcomes.duplicate():
		if outcome.id == "ow":
			_t.hero.chapters[0].outcomes.erase(outcome)
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	var before: int = _t.writes()
	# Act
	var shown: StoryScreen = _t.session.continue_check()
	_t.settle()
	# Assert (C3): the record on disk is still not applied
	assert_object(shown).is_null()
	assert_int(_t.writes() - before).is_equal(0)
	assert_bool(_t.disk_body()["roll"]["applied"]).is_false()
	assert_int(_t.session.journal_size()).is_equal(0)


func test_new_run_tapped_twice_while_waiting_starts_once() -> void:
	# Arrange
	_t.session.start_new()
	# Act
	var second: StoryScreen = _t.session.start_new()
	_t.settle()
	# Assert (TD C4)
	assert_object(second).is_null()
	assert_int(_t.writes()).is_equal(2)
	assert_str(_t.disk_body()["run_id"]).is_equal("run1")


func test_cancel_before_the_roll_frees_the_choice_of_another_risky_option() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	var before: int = _t.writes()
	# Act
	var cancelled: bool = _t.session.cancel_check()
	var chosen: bool = _t.session.choose_check(_t.option("r"))
	var rolled: D20Result = _t.session.roll()
	# Assert (round 2): the cancel wrote nothing and consumed no roll
	assert_bool(cancelled).is_true()
	assert_bool(chosen).is_true()
	assert_object(rolled).is_not_null()
	assert_int(_t.source.calls).is_equal(1)
	assert_int(_t.writes() - before).is_equal(0)


func test_cancel_after_the_roll_is_refused() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	var before: int = _t.writes()
	# Act
	var cancelled: bool = _t.session.cancel_check()
	_t.settle()
	# Assert
	assert_bool(cancelled).is_false()
	assert_int(_t.writes() - before).is_equal(0)
	assert_bool(_t.disk_body()["roll"]["applied"]).is_false()
