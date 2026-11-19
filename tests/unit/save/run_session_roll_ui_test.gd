extends GdUnitTestSuite
## Unit tests of the Roll-screen core of RunSession (roll-screen.md, Dependencies Д-3, Д-4, Д-5, Д-6,
## Д-10; CEO 2026-11-18: a failed roll write is not shown to the player; story UI1).

var _t: SessionRig
var _outcomes: Array[int] = []


func before_test() -> void:
	_t = SessionRig.new()
	_outcomes = []
	_t.session.write_ended.connect(func(outcome: int) -> void: _outcomes.append(outcome))


func _rolled() -> void:
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()


func test_brief_after_choose_has_numbers_and_caption_before_any_roll() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	# Act
	var brief: CheckBrief = _t.session.check_brief()
	# Assert
	assert_int(_t.source.calls).is_equal(0)
	assert_int(brief.dc).is_equal(13)
	assert_int(brief.need).is_equal(9)
	assert_int(brief.chance).is_equal(60)
	assert_str(brief.stat_name).is_equal("Сила")
	assert_str(brief.level_word).is_equal("Средне")
	assert_str(brief.caption).is_equal("Сила +4 · Средне 13 · шанс 60 %")


func test_brief_without_a_turn_is_null() -> void:
	_t.started()
	assert_object(_t.session.check_brief()).is_null()


func test_the_brief_chance_equals_the_option_caption_chance() -> void:
	# Arrange
	_t.started()
	var caption: String = _t.session.option_views()[2].caption
	_t.session.choose_check(_t.option("r"))
	# Assert
	assert_str(_t.session.check_brief().caption).is_equal(caption)


func test_a_loaded_roll_gives_a_restored_turn_and_its_result() -> void:
	# Arrange
	_rolled()
	_t.settle()
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	# Act
	var result: D20Result = _t.session.restored_result()
	# Assert
	assert_bool(_t.session.has_restored_turn()).is_true()
	assert_int(result.roll).is_equal(SessionRig.FACE)
	assert_int(result.total).is_equal(SessionRig.FACE + 4)
	assert_int(_t.session.check_brief().dc).is_equal(13)


func test_no_restored_turn_for_a_fresh_roll_or_a_load_without_a_roll() -> void:
	# Arrange
	_rolled()
	var fresh: bool = _t.session.has_restored_turn()
	_t.settle()
	_t.session.continue_check()
	_t.settle()
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	# Assert
	assert_bool(fresh).is_false()
	assert_bool(_t.session.has_restored_turn()).is_false()
	assert_object(_t.session.restored_result()).is_null()


func test_restored_turn_ends_with_continue() -> void:
	# Arrange
	_rolled()
	_t.settle()
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	# Act
	var shown: StoryScreen = _t.session.continue_check()
	# Assert
	assert_int(shown.kind).is_equal(StoryScreen.Kind.OUTCOME)
	assert_bool(_t.session.has_restored_turn()).is_false()


func test_continue_is_refused_while_the_roll_write_waits() -> void:
	# Arrange
	_rolled()
	var waiting: bool = _t.session.waiting()
	var writes: int = _t.writes()
	# Act
	var early: StoryScreen = _t.session.continue_check()
	_t.settle()
	var later: StoryScreen = _t.session.continue_check()
	# Assert
	assert_bool(waiting).is_true()
	assert_object(early).is_null()
	assert_int(_t.session.journal_size()).is_greater(0)
	assert_object(later).is_not_null()
	assert_int(_t.writes()).is_greater(writes)


func test_close_check_is_refused_while_waiting_and_before_the_roll() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	var before_roll: bool = _t.session.close_check()
	_t.session.roll()
	# Assert
	assert_bool(before_roll).is_false()
	assert_bool(_t.session.close_check()).is_false()


func test_close_check_after_a_flow_error_closes_without_outcome_and_keeps_the_choice_blocked() -> void:
	# Arrange: the outcome is missing, so continue is a flow error
	for outcome: OutcomeData in _t.hero.chapters[0].outcomes.duplicate():
		if outcome.id == "ow":
			_t.hero.chapters[0].outcomes.erase(outcome)
	_rolled()
	_t.settle()
	var shown: StoryScreen = _t.session.continue_check()
	var writes: int = _t.writes()
	# Act
	var closed: bool = _t.session.close_check()
	_t.settle()
	# Assert
	assert_object(shown).is_null()
	assert_bool(closed).is_true()
	assert_int(_t.writes()).is_equal(writes)
	assert_int(_t.session.journal_size()).is_equal(0)
	assert_bool(_t.session.choose_check(_t.option("r"))).is_false()
	assert_bool(_t.session.close_check()).is_false()
	assert_object(_t.session.continue_check()).is_null()


func test_write_ended_carries_ok_before_show_released() -> void:
	# Act
	_rolled()
	_t.settle()
	# Assert
	assert_array(_outcomes).is_equal([SaveWriter.Outcome.OK, SaveWriter.Outcome.OK])


func test_a_failed_roll_write_is_reported_and_logged_but_the_flow_goes_on() -> void:
	# Arrange
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.rig.io.fail_writes = 1
	_outcomes = []
	var released: int = _t.released
	# Act
	var result: D20Result = _t.session.roll()
	_t.settle()
	# Assert
	assert_object(result).is_not_null()
	assert_bool(_t.session.waiting()).is_false()
	assert_array(_outcomes).is_equal([SaveWriter.Outcome.ERROR])
	assert_int(_t.released).is_equal(released + 1)
	assert_int(_t.logs.size()).is_greater(0)
	assert_object(_t.session.continue_check()).is_not_null()


func test_flow_error_is_visible_and_load_or_a_new_run_is_the_way_out() -> void:
	# Arrange: the outcome is missing, so continue is a flow error
	for outcome: OutcomeData in _t.hero.chapters[0].outcomes.duplicate():
		if outcome.id == "ow":
			_t.hero.chapters[0].outcomes.erase(outcome)
	_rolled()
	_t.settle()
	_t.session.continue_check()
	var before: bool = _t.session.flow_error()
	_t.session.close_check()
	var after: bool = _t.session.flow_error()
	# Act: «В меню» → a new run
	var screen: StoryScreen = _t.session.start_new()
	# Assert
	assert_bool(before).is_false()
	assert_bool(after).is_true()
	assert_object(screen).is_not_null()
	assert_bool(_t.session.flow_error()).is_false()
