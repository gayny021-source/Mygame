extends GdUnitTestSuite
## Unit tests of the Roll-screen data of CheckTurn (roll-screen.md, Dependencies Д-3, Д-4, Д-6; story UI1).

const PHASE := CheckTurn.Phase

var _commits: int
var _errors: Array[String] = []


func before_test() -> void:
	_commits = 0
	_errors = []


func _screen() -> StoryScreen:
	var risky: OptionData = OptionData.new()
	risky.id = "bridge"
	risky.text = "Перебежать мост"
	risky.reason = "Гарзуг рядом"
	risky.kind = OptionData.KIND_RISKY
	risky.check = CheckFixtures.check()
	var scene: SceneData = SceneData.new()
	scene.id = "s_bridge"
	scene.options = [risky]
	var screen: StoryScreen = StoryScreen.new(StoryScreen.Kind.SCENE)
	screen.scene = scene
	return screen


func _turn(bonus: int = 4) -> CheckTurn:
	var screen: StoryScreen = _screen()
	var commit: Callable = func(_t: int, _r: RollRecord) -> void: _commits += 1
	var log: Callable = func(message: String) -> void: _errors.append(message)
	var d20: D20Check = D20Check.new(CheckFixtures.config(), CountingD20Source.new(14))
	return CheckTurn.choose(screen, screen.scene.options[0], CheckFixtures.hero("strength", bonus), d20, commit, log)


func _restored() -> CheckTurn:
	var record: RollRecord = RollRecord.of("s_bridge", D20Check.resolve(CheckFixtures.check(), 4, 13, 14, false))
	var commit: Callable = func(_t: int, _r: RollRecord) -> void: _commits += 1
	var log: Callable = func(message: String) -> void: _errors.append(message)
	return CheckTurn.restore(_screen(), record, commit, log)


func test_brief_before_the_roll_has_dc_bonus_need_chance_and_texts() -> void:
	# Act
	var brief: CheckBrief = _turn().brief()
	# Assert: Сила +4 against Средне 13: need 9, 60 %
	assert_int(brief.dc).is_equal(13)
	assert_int(brief.bonus).is_equal(4)
	assert_int(brief.need).is_equal(9)
	assert_int(brief.chance).is_equal(60)
	assert_str(brief.level).is_equal("medium")
	assert_str(brief.stat_id).is_equal("strength")
	assert_str(brief.option_text).is_equal("Перебежать мост")
	assert_str(brief.option_reason).is_equal("Гарзуг рядом")


func test_brief_chance_is_the_function_of_the_caption() -> void:
	assert_int(_turn(-1).brief().chance).is_equal(D20Check.chance(13, -1))


func test_brief_of_a_restored_turn_uses_the_record_numbers() -> void:
	# Act
	var brief: CheckBrief = _restored().brief()
	# Assert
	assert_int(brief.dc).is_equal(13)
	assert_int(brief.bonus).is_equal(4)
	assert_int(brief.chance).is_equal(60)


func test_only_a_restored_turn_is_marked_restored() -> void:
	assert_bool(_restored().restored).is_true()
	assert_bool(_turn().restored).is_false()


func test_close_works_only_from_rolled_and_commits_nothing() -> void:
	# Arrange
	var turn: CheckTurn = _turn()
	var before_roll: bool = turn.close()
	turn.roll()
	var commits: int = _commits
	# Act
	var closed: bool = turn.close()
	# Assert
	assert_bool(before_roll).is_false()
	assert_bool(closed).is_true()
	assert_int(turn.phase).is_equal(PHASE.CLOSED)
	assert_int(_commits).is_equal(commits)
	assert_object(turn.proceed()).is_null()
	assert_bool(turn.close()).is_false()
