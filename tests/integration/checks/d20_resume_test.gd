extends GdUnitTestSuite
## Integration of CheckTurn, StoryNavigator and RunState over a load with a roll record (d20-checks.md,
## AC-21, AC-24; DD-020 item 1, DD-021; story S7). The loader here plays the Save system by DD-021: the
## position always has an empty pending outcome, CheckTurn.restore shows the result again, «Продолжить»
## applies the outcome once. The snapshot of the flags is taken before the outcome (save-system.md, 7).
## Regression C1: a position whose pending outcome comes from the record shows the outcome but loses its flags.

const KIND := StoryScreen.Kind
const CHECK_ID := "r_check"

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


# s1: the risky option `r` (Strength, Medium; success `ow` sets f_a, failure `of`) and a safe one.
func _run() -> NavigatorHarness:
	var data: Dictionary = MeaningFixtures.risky_fork()
	GraphFixtures.find(data["outcomes"], "ow")["sets"] = ["f_a"]
	var run: NavigatorHarness = NavigatorHarness.of([data])
	var stat: StatData = StatData.new()
	stat.id = "strength"
	stat.bonus = 4
	run.hero.stats.append(stat)
	return run


# Plays s1 up to the roll (and «Продолжить» when `applied`) and returns the save body: the position
# and the record, both as dictionaries through JSON text, as a file would hold them.
func _play(applied: bool) -> Dictionary:
	var run: NavigatorHarness = _run()
	var screen: StoryScreen = run.nav.resume(StoryPosition.new("m_g", "s1"), run.state)
	var d20: D20Check = D20Check.new(CheckFixtures.config(), _source)
	var turn: CheckTurn = CheckTurn.choose(screen, screen.scene.options[0], run.hero, d20, _commit(), _log())
	turn.roll()
	if applied:
		turn.proceed()
	var body: Dictionary = {"position": run.nav.position().to_dict(), "roll": turn.record.to_dict()}
	return JSON.parse_string(JSON.stringify(body))


# The load of DD-021: pending outcome empty for any record. `pending_from_record` is the C1 trap.
func _load(body: Dictionary, pending_from_record: bool = false) -> Array:
	var issues: Array[DataIssue] = []
	var position: StoryPosition = StoryPosition.from_dict(body["position"], "save/position", issues)
	var record: RollRecord = RollRecord.from_dict(body["roll"], "save/roll", issues)
	assert_array(issues).is_empty()
	if pending_from_record:
		position.pending_outcome = D20Check.restore(record, _check_of(record)).outcome_id
	var run: NavigatorHarness = _run()
	run.nav.resume(position, run.state)
	_commits = []
	var turn: CheckTurn = CheckTurn.restore(run.nav.screen(), record, _commit(), _log())
	return [run, turn]


func _check_of(record: RollRecord) -> CheckData:
	var check: CheckData = CheckData.new()
	check.id = record.check_id
	check.stat = record.stat_id
	check.success = "ow"
	check.failure = "of"
	return check


func test_applied_record_and_scene_after_load_show_outcome_once_without_reroll() -> void:
	# Arrange
	var body: Dictionary = _play(true)
	var calls: int = _source.calls
	var loaded: Array = _load(body)
	var run: NavigatorHarness = loaded[0]
	var turn: CheckTurn = loaded[1]
	# Act: «Продолжить», the Choice system applies, the navigator shows the outcome, «Дальше»
	var reroll: D20Result = turn.roll()
	var result: D20Result = turn.proceed()
	var shown: StoryScreen = run.choose(result.outcome_id)
	var second: D20Result = turn.proceed()
	var again: StoryScreen = run.nav.outcome_applied(result.outcome_id)
	var next: StoryScreen = run.nav.advance()
	# Assert
	assert_object(reroll).is_null()
	assert_int(_source.calls).is_equal(calls)
	assert_array(_commits).is_empty()
	assert_int(result.roll).is_equal(14)
	assert_str(result.outcome_id).is_equal("ow")
	assert_int(shown.kind).is_equal(KIND.OUTCOME)
	assert_str(shown.outcome.id).is_equal("ow")
	assert_bool(run.state.has_flag("f_a")).is_true()
	assert_int(run.state.journal().size()).is_equal(1)
	assert_int(run.state.applied).is_equal(1)
	assert_object(second).is_null()
	assert_object(again).is_null()
	assert_str(NavigatorHarness.describe(next)).is_equal(NavigatorHarness.describe(_straight_next()))


func test_c1_trap_pending_outcome_from_record_loses_outcome_flags() -> void:
	# Arrange
	var loaded: Array = _load(_play(true), true)
	var run: NavigatorHarness = loaded[0]
	var turn: CheckTurn = loaded[1]
	# Act
	var screen: StoryScreen = run.nav.screen()
	# Assert: the outcome is on screen, its flags never reached the state, and no check can apply them
	assert_int(screen.kind).is_equal(KIND.OUTCOME)
	assert_bool(run.state.has_flag("f_a")).is_false()
	assert_object(turn).is_null()
	assert_object(run.nav.outcome_applied("ow")).is_null()


func test_unapplied_record_after_load_commits_7_once_then_applies_once() -> void:
	# Arrange
	var loaded: Array = _load(_play(false))
	var run: NavigatorHarness = loaded[0]
	var turn: CheckTurn = loaded[1]
	# Act
	var result: D20Result = turn.proceed()
	var shown: StoryScreen = run.choose(result.outcome_id)
	var second: D20Result = turn.proceed()
	# Assert
	assert_array(_commits).contains_exactly([[CheckTurn.COMMIT_APPLIED, true]])
	assert_int(shown.kind).is_equal(KIND.OUTCOME)
	assert_bool(run.state.has_flag("f_a")).is_true()
	assert_int(run.state.applied).is_equal(1)
	assert_object(second).is_null()


func test_resume_error_screen_gives_no_turn_and_no_commit() -> void:
	# Arrange
	var body: Dictionary = _play(true)
	body["position"]["scene"] = "s_gone"
	var calls: int = _source.calls
	# Act
	var loaded: Array = _load(body)
	var run: NavigatorHarness = loaded[0]
	# Assert
	assert_int(run.nav.screen().kind).is_equal(KIND.ERROR)
	assert_object(loaded[1]).is_null()
	assert_array(_commits).is_empty()
	assert_int(_source.calls).is_equal(calls)
	assert_int(_errors.size()).is_equal(1)


func test_applied_record_continue_tapped_twice_commits_nothing_and_applies_once() -> void:
	# Arrange: the caller of «Продолжить» applies whatever proceed returns (round 2, chaos)
	var loaded: Array = _load(_play(true))
	var run: NavigatorHarness = loaded[0]
	var turn: CheckTurn = loaded[1]
	var outcomes: Array[String] = []
	# Act
	for tap: int in 2:
		var result: D20Result = turn.proceed()
		if result != null:
			outcomes.append(result.outcome_id)
			run.choose(result.outcome_id)
	# Assert
	assert_array(outcomes).contains_exactly(["ow"])
	assert_array(_commits).is_empty()
	assert_int(run.state.applied).is_equal(1)
	assert_int(run.state.journal().size()).is_equal(1)


# The screen after «Дальше» on `ow` in a run that was never unloaded.
func _straight_next() -> StoryScreen:
	var run: NavigatorHarness = _run()
	run.nav.resume(StoryPosition.new("m_g", "s1"), run.state)
	run.choose("ow")
	return run.nav.advance()
