extends GdUnitTestSuite
## Integration of RunSession, SaveWriter, the codec, RunState snapshots, CheckTurn and StoryNavigator over
## a restart (DD-021 plan of control: «запись applied + снимок через RunState.to_dict -> загрузка -> исход
## один раз, флаги стоят»; DD-022; save-system.md AC-25, AC-38; story SV4). A restart is a new writer and
## a new session over the same fake files.

const KIND := StoryScreen.Kind

var _t: SessionRig


func before_test() -> void:
	_t = SessionRig.new()


# Plays s1 up to the roll on disk (and «Продолжить» when `applied`), then restarts and loads.
func _play_and_load(applied: bool) -> StoryScreen:
	_t.started()
	_t.session.choose_check(_t.option("r"))
	_t.session.roll()
	_t.settle()
	if applied:
		_t.session.continue_check()
		_t.settle()
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	return _t.loads[0][1]


func test_applied_record_and_to_dict_snapshot_load_applies_the_outcome_once_and_flags_stand() -> void:
	# Arrange
	var screen: StoryScreen = _play_and_load(true)
	var calls: int = _t.source.calls
	var before: int = _t.writes()
	# Act
	var shown: StoryScreen = _t.session.continue_check()
	var second: StoryScreen = _t.session.continue_check()
	var rerolled: D20Result = _t.session.roll()
	_t.settle()
	# Assert
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_int(shown.kind).is_equal(KIND.OUTCOME)
	assert_str(shown.outcome.id).is_equal("ow")
	assert_bool(_t.session.has_flag("f_a")).is_true()
	assert_int(_t.session.journal_size()).is_equal(1)
	assert_object(second).is_null()
	assert_object(rerolled).is_null()
	assert_int(_t.source.calls).is_equal(calls)
	assert_int(_t.writes() - before).is_equal(0)
	assert_bool(_t.session.waiting()).is_false()


func test_unapplied_record_after_load_commits_7_once_then_applies_once() -> void:
	# Arrange
	_play_and_load(false)
	var before: int = _t.writes()
	# Act
	var shown: StoryScreen = _t.session.continue_check()
	_t.settle()
	var second: StoryScreen = _t.session.continue_check()
	# Assert
	assert_int(shown.kind).is_equal(KIND.OUTCOME)
	assert_object(second).is_null()
	assert_int(_t.writes() - before).is_equal(1)
	assert_bool(_t.disk_body()["roll"]["applied"]).is_true()
	assert_bool(_t.session.has_flag("f_a")).is_true()
	assert_int(_t.session.journal_size()).is_equal(1)


func test_flags_survive_a_second_restart_after_the_outcome_scene_was_entered() -> void:
	# Arrange: applied -> outcome -> «Дальше» (commit 1 deletes the record) -> restart
	_play_and_load(true)
	_t.session.continue_check()
	_t.session.advance()
	_t.settle()
	_t.restart()
	# Act
	_t.session.load_saved()
	_t.settle()
	# Assert
	assert_int(_t.loads[0][0]).is_equal(SaveWriter.LoadCode.OK)
	assert_str(_t.loads[0][1].scene.id).is_equal("s2")
	assert_bool(_t.session.has_flag("f_a")).is_true()
	assert_int(_t.session.journal_size()).is_equal(1)
	assert_bool(_t.disk_body().has("roll")).is_false()
