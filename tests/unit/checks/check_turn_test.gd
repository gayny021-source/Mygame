extends GdUnitTestSuite
## Unit tests for CheckTurn, the life of one d20 check (d20-checks.md, States, the event rule; AC-16,
## AC-21, AC-24; DD-020, DD-021; story S7). The commit spy keeps [transition, applied] at call time.

const PHASE := CheckTurn.Phase

var _commits: Array[Array] = []
var _errors: Array[String] = []
var _source: CountingD20Source


func before_test() -> void:
	_commits = []
	_errors = []
	_source = CountingD20Source.new(14)


func _commit() -> Callable:
	return func(transition: int, record: RollRecord) -> void: _commits.append([transition, record.applied])


func _log() -> Callable:
	return func(message: String) -> void: _errors.append(message)


# A scene `s_bridge` with the risky option of the reference check and one safe option.
func _screen() -> StoryScreen:
	var risky: OptionData = OptionData.new()
	risky.id = "bridge"
	risky.kind = OptionData.KIND_RISKY
	risky.check = CheckFixtures.check()
	var safe: OptionData = OptionData.new()
	safe.id = "ford"
	safe.kind = OptionData.KIND_SAFE
	safe.outcome = "ford_wet"
	var scene: SceneData = SceneData.new()
	scene.id = "s_bridge"
	scene.options = [risky, safe]
	var screen: StoryScreen = StoryScreen.new(StoryScreen.Kind.SCENE)
	screen.scene = scene
	return screen


func _d20(config: D20Config = CheckFixtures.config()) -> D20Check:
	return D20Check.new(config, _source)


func _chosen(screen: StoryScreen = _screen(), bonus: int = 4) -> CheckTurn:
	return CheckTurn.choose(screen, screen.scene.options[0], CheckFixtures.hero("strength", bonus), _d20(), _commit(), _log())


# AC-21: n = 14, +4, DC 13, not applied.
func _record(applied: bool = false) -> RollRecord:
	var record: RollRecord = RollRecord.of("s_bridge", D20Check.resolve(CheckFixtures.check(), 4, 13, 14, false))
	record.applied = applied
	return record


func test_roll_calls_source_once_and_commits_transition_3_unapplied() -> void:
	# Arrange
	var turn: CheckTurn = _chosen()
	# Act
	var result: D20Result = turn.roll()
	# Assert
	assert_int(_source.calls).is_equal(1)
	assert_int(turn.phase).is_equal(PHASE.ROLLED)
	assert_int(result.roll).is_equal(14)
	assert_array(_commits).contains_exactly([[CheckTurn.COMMIT_ROLLED, false]])
	assert_dict(turn.record.to_dict()).is_equal(_record().to_dict())


func test_second_roll_is_refused_without_source_call() -> void:
	# Arrange
	var turn: CheckTurn = _chosen()
	var first: D20Result = turn.roll()
	# Act
	var others: Array = [turn.roll(), turn.roll(), turn.roll()]
	# Assert
	assert_object(first).is_not_null()
	assert_array(others).contains_exactly([null, null, null])
	assert_int(_source.calls).is_equal(1)
	assert_int(_commits.size()).is_equal(1)


func test_cancel_after_roll_is_refused_and_roll_after_cancel_does_not_roll() -> void:
	# Arrange
	var rolled: CheckTurn = _chosen()
	var cancelled: CheckTurn = _chosen()
	# Act
	rolled.roll()
	var late_cancel: bool = rolled.cancel()
	var cancel: bool = cancelled.cancel()
	var late_roll: D20Result = cancelled.roll()
	# Assert
	assert_bool(late_cancel).is_false()
	assert_int(rolled.phase).is_equal(PHASE.ROLLED)
	assert_bool(cancel).is_true()
	assert_object(late_roll).is_null()
	assert_int(cancelled.phase).is_equal(PHASE.CANCELLED)
	assert_int(_source.calls).is_equal(1)
	assert_int(_commits.size()).is_equal(1)


func test_proceed_twice_returns_result_once_and_commits_7_once_applied() -> void:
	# Arrange
	var turn: CheckTurn = _chosen()
	var before: D20Result = turn.proceed()
	var rolled: D20Result = turn.roll()
	# Act
	var first: D20Result = turn.proceed()
	var second: D20Result = turn.proceed()
	var cancel: bool = turn.cancel()
	# Assert
	assert_object(before).is_null()
	assert_object(first).is_same(rolled)
	assert_object(second).is_null()
	assert_bool(cancel).is_false()
	assert_int(turn.phase).is_equal(PHASE.APPLIED)
	assert_array(_commits).contains_exactly([[CheckTurn.COMMIT_ROLLED, false], [CheckTurn.COMMIT_APPLIED, true]])


func test_restore_unapplied_refuses_roll_and_cancel_calls_nothing_then_proceed_commits_7() -> void:
	# Arrange
	var turn: CheckTurn = CheckTurn.restore(_screen(), _record(), _commit(), _log())
	# Act
	var roll: D20Result = turn.roll()
	var cancel: bool = turn.cancel()
	var commits_before: int = _commits.size()
	var result: D20Result = turn.proceed()
	# Assert
	assert_int(turn.phase).is_equal(PHASE.APPLIED)
	assert_object(roll).is_null()
	assert_bool(cancel).is_false()
	assert_int(commits_before).is_equal(0)
	assert_int(_source.calls).is_equal(0)
	assert_int(result.roll).is_equal(14)
	assert_int(result.total).is_equal(18)
	assert_bool(result.success).is_true()
	assert_bool(result.rerolled).is_false()
	assert_array(_commits).contains_exactly([[CheckTurn.COMMIT_APPLIED, true]])
	assert_array(_errors).is_empty()


func test_restore_applied_proceed_returns_once_without_commit() -> void:
	# Arrange
	var turn: CheckTurn = CheckTurn.restore(_screen(), _record(true), _commit(), _log())
	# Act
	var first: D20Result = turn.proceed()
	var second: D20Result = turn.proceed()
	# Assert
	assert_str(first.outcome_id).is_equal(CheckFixtures.SUCCESS)
	assert_object(second).is_null()
	assert_array(_commits).is_empty()
	assert_int(_source.calls).is_equal(0)


func test_restore_keeps_record_numbers_after_balance_patch() -> void:
	# Arrange: Medium 14 now, and Strength +3
	var issues: Array[DataIssue] = []
	var data: Dictionary = ChapterLoader.read_object(D20Config.PATH, issues)
	data["dc_medium"] = 14
	var patched: D20Config = D20Config.from_dict(data, "d20", issues)
	var record: RollRecord = _record()
	record.roll = 9
	record.rerolled = true
	# Act: the saved reroll to 9 of the +4 / Medium 13 roll
	var turn: CheckTurn = CheckTurn.restore(_screen(), record, _commit(), _log())
	var fresh_need: int = D20Check.need(patched.dc("medium", issues), 3)
	# Assert: the restored roll keeps its numbers (13 against 13), a new check takes the new ones
	assert_array(issues).is_empty()
	assert_int(turn.result.total).is_equal(13)
	assert_int(turn.result.dc).is_equal(13)
	assert_bool(turn.result.success).is_true()
	assert_bool(turn.result.rerolled).is_true()
	assert_int(fresh_need).is_equal(11)


func test_choose_or_restore_on_error_or_null_screen_returns_null_and_commits_nothing() -> void:
	# Arrange
	var error: StoryScreen = StoryScreen.new(StoryScreen.Kind.ERROR)
	var scene: StoryScreen = _screen()
	var hero: HeroData = CheckFixtures.hero("strength", 4)
	var risky: OptionData = scene.scene.options[0]
	var foreign: OptionData = _screen().scene.options[0]
	# Act
	var turns: Array = [
		CheckTurn.choose(null, risky, hero, _d20(), _commit(), _log()),
		CheckTurn.choose(error, risky, hero, _d20(), _commit(), _log()),
		CheckTurn.choose(scene, scene.scene.options[1], hero, _d20(), _commit(), _log()),
		CheckTurn.choose(scene, foreign, hero, _d20(), _commit(), _log()),
		CheckTurn.restore(null, _record(), _commit(), _log()),
		CheckTurn.restore(error, _record(), _commit(), _log()),
	]
	# Assert
	assert_array(turns).contains_exactly([null, null, null, null, null, null])
	assert_array(_commits).is_empty()
	assert_int(_source.calls).is_equal(0)
	assert_int(_errors.size()).is_equal(2)


func test_restore_with_foreign_scene_or_missing_check_returns_null_and_logs_once() -> void:
	for field: String in ["scene_id", "check_id"]:
		# Arrange
		_errors = []
		var record: RollRecord = _record()
		record.set(field, "gone")
		# Act
		var turn: CheckTurn = CheckTurn.restore(_screen(), record, _commit(), _log())
		# Assert
		assert_object(turn).is_null()
		assert_int(_errors.size()).is_equal(1)
		assert_str(_errors[0]).contains("gone")
	assert_array(_commits).is_empty()


# --- Audit round 1 (TD S7): C1-C5 ---

func test_roll_with_unknown_level_stays_chosen_and_calls_nothing() -> void:
	# Arrange: C1 + C3, no result means no record, no phase change and no commit
	var screen: StoryScreen = _screen()
	screen.scene.options[0].check.level = "legendary"
	var turn: CheckTurn = _chosen(screen)
	# Act
	var result: D20Result = turn.roll()
	var proceeded: D20Result = turn.proceed()
	# Assert
	assert_object(result).is_null()
	assert_object(proceeded).is_null()
	assert_int(turn.phase).is_equal(PHASE.CHOSEN)
	assert_object(turn.record).is_null()
	assert_int(_source.calls).is_equal(0)
	assert_array(_commits).is_empty()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("DT-02")


func test_proceed_without_record_is_refused_and_logged() -> void:
	# Arrange (C1)
	var turn: CheckTurn = CheckTurn.restore(_screen(), _record(), _commit(), _log())
	turn.record = null
	# Act
	var result: D20Result = turn.proceed()
	# Assert
	assert_object(result).is_null()
	assert_array(_commits).is_empty()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("DT-02")


func test_restore_with_bonus_out_of_window_or_other_stat_is_dropped() -> void:
	# Arrange: [field, value] of a record that does not fit the check (C2; the DC is not compared, AC-21)
	var cases: Array[Array] = [["bonus", 6], ["bonus", -2], ["stat_id", "faith"]]
	for case: Array in cases:
		_errors = []
		var record: RollRecord = _record()
		record.set(case[0], case[1])
		# Act
		var turn: CheckTurn = CheckTurn.restore(_screen(), record, _commit(), _log())
		# Assert
		assert_object(turn).is_null()
		assert_int(_errors.size()).is_equal(1)
		assert_str(_errors[0]).contains("DT-02")
	assert_array(_commits).is_empty()


func test_restore_null_record_is_dropped() -> void:
	# Arrange / Act (C5)
	var turn: CheckTurn = CheckTurn.restore(_screen(), null, _commit(), _log())
	# Assert
	assert_object(turn).is_null()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("DT-02")


func test_choose_with_invalid_config_hides_the_check() -> void:
	# Arrange: a config that did not read (C4: risky options hidden, no fallback)
	var screen: StoryScreen = _screen()
	var hero: HeroData = CheckFixtures.hero("strength", 4)
	# Act
	var turn: CheckTurn = CheckTurn.choose(screen, screen.scene.options[0], hero, _d20(D20Config.new()), _commit(), _log())
	# Assert
	assert_object(turn).is_null()
	assert_int(_source.calls).is_equal(0)
	assert_array(_commits).is_empty()
