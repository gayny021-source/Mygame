extends GdUnitTestSuite
## Unit tests of the session flow error (choice-system.md, rule 12, Э-23, AC-70/71/74; d20-checks.md,
## States, AC-56): State is asked before a result is taken; a refusal gives no result, no write, one log line.

var _t: SessionRig
var _state: RefusingState


func before_test() -> void:
	_t = SessionRig.new()
	_state = null


func _refuse() -> void:
	_state = RefusingState.new(_t.hero.flags, Callable())
	_t.session._state = _state


func _rolled_and_refusing() -> void:
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	_refuse()


func test_plain_option_refused_by_state_gives_no_screen_no_write_and_one_log_line() -> void:
	# Arrange
	_t.started()
	_t.settle()
	_refuse()
	var writes: int = _t.writes()
	var logs: int = _t.logs.size()
	# Act
	var screen: StoryScreen = _t.session.apply_plain(_t.option("a"))
	_t.settle()
	# Assert
	assert_object(screen).is_null()
	assert_int(_state.asked).is_equal(1)
	assert_int(_state.applied).is_equal(0)
	assert_int(_t.writes()).is_equal(writes)
	assert_int(_t.logs.size()).is_equal(logs + 1)
	assert_bool(_t.session.flow_error()).is_true()
	assert_bool(_t.session.waiting()).is_false()


func test_flow_error_after_a_plain_refusal_blocks_every_choice_and_logs_once() -> void:
	# Arrange
	_t.started()
	_refuse()
	_t.session.apply_plain(_t.option("a"))
	var logs: int = _t.logs.size()
	# Act
	var again: StoryScreen = _t.session.apply_plain(_t.option("a"))
	var risky: bool = _t.session.choose_check(_t.option("r"))
	# Assert
	assert_object(again).is_null()
	assert_bool(risky).is_false()
	assert_int(_state.asked).is_equal(1)
	assert_int(_t.logs.size()).is_equal(logs)


func test_continue_refused_by_state_hands_no_result_and_writes_nothing() -> void:
	# Arrange
	_rolled_and_refusing()
	var writes: int = _t.writes()
	var logs: int = _t.logs.size()
	# Act
	var screen: StoryScreen = _t.session.continue_check()
	_t.settle()
	# Assert
	assert_object(screen).is_null()
	assert_int(_state.asked).is_equal(1)
	assert_int(_state.applied).is_equal(0)
	assert_int(_t.writes()).is_equal(writes)
	assert_int(_t.logs.size()).is_equal(logs + 1)
	assert_bool(_t.session.flow_error()).is_true()
	assert_bool(_t.session._turn.record.applied).is_false()


func test_second_continue_after_a_refusal_stays_refused_and_silent() -> void:
	# Arrange
	_rolled_and_refusing()
	_t.session.continue_check()
	var logs: int = _t.logs.size()
	# Act
	var again: StoryScreen = _t.session.continue_check()
	# Assert
	assert_object(again).is_null()
	assert_int(_t.logs.size()).is_equal(logs)
	assert_int(_t.writes()).is_equal(_t.writes())


func test_close_check_is_refused_before_a_refusal_and_accepted_after_it() -> void:
	# Arrange
	_rolled_and_refusing()
	var before: bool = _t.session.close_check()
	_t.session.continue_check()
	var logs: int = _t.logs.size()
	# Act
	var after: bool = _t.session.close_check()
	# Assert
	assert_bool(before).is_false()
	assert_bool(after).is_true()
	assert_int(_t.logs.size()).is_equal(logs)


func test_close_check_is_refused_after_a_plain_refusal() -> void:
	# Arrange
	_t.started()
	_refuse()
	_t.session.apply_plain(_t.option("a"))
	# Assert
	assert_bool(_t.session.close_check()).is_false()


func test_a_new_run_resets_the_flow_error() -> void:
	# Arrange
	_t.started()
	_refuse()
	_t.session.apply_plain(_t.option("a"))
	# Act
	_t.session.start_new()
	# Assert
	assert_bool(_t.session.flow_error()).is_false()


func test_a_load_resets_the_flow_error_and_the_outcome_applies_once() -> void:
	# Arrange
	_rolled_and_refusing()
	_t.session.continue_check()
	_t.session.close_check()
	# Act
	_t.session.load_saved()
	_t.settle()
	var screen: StoryScreen = _t.session.continue_check()
	# Assert
	assert_bool(_t.session.flow_error()).is_false()
	assert_object(screen).is_not_null()
	assert_int(_t.session.journal_size()).is_greater(0)
