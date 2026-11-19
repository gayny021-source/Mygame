extends GdUnitTestSuite
## Shipped chapter 1 of Rovend (design/narrative/chapter-01-sheet.md, DATA2): loads clean, every scene is
## reachable, every path ends in an ending, milestones, stake, check budget (d20-checks.md, formula 7),
## the goal-fail flag is set only by the s11 failure.

const LIMITS := "res://assets/data/config/story_limits.json"
const MILESTONE_IDS: Array[String] = ["ch1_start", "ch1_bridge", "ch1_village", "ch1_forest", "ch1_hill", "ch1_temple"]
const RISKY_SCENES: Array[String] = ["s03_bridge", "s05_village", "s07_forest", "s11_temple"]
const CHECKS_PER_PATH := 4
const SCENE_COUNT := 12
## Temporary dialogue box limit (narrative.md); the real one is an open question of d20-checks (OQ).
const CRIT_LINE_MAX := 120

var _hero: HeroData
var _chapter: ChapterData
var _scenes: Dictionary[String, SceneData] = {}
var _outcomes: Dictionary[String, OutcomeData] = {}
var _transitions: Dictionary[String, TransitionData] = {}


func before_test() -> void:
	var result: LoadResult = HeroLoader.load_hero("rovend")
	assert_array(result.issues).is_empty()
	_hero = result.data
	_chapter = _hero.chapters[0]
	_scenes.clear()
	_outcomes.clear()
	_transitions.clear()
	for scene: SceneData in _chapter.scenes:
		_scenes[scene.id] = scene
	for outcome: OutcomeData in _chapter.outcomes:
		_outcomes[outcome.id] = outcome
	for transition: TransitionData in _chapter.transitions:
		_transitions[transition.id] = transition


# Every complete path (checks = scenes with a risky option, R(p) of formula 7): {scenes: Array[String], checks: Array[String], sets: Array[String], end: String}.
func _paths(scene_id: String, trail: Array[String], checks: Array[String], sets: Array[String]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var here: Array[String] = trail.duplicate()
	here.append(scene_id)
	assert_int(here.size()).is_less(20)
	var risky: Array[String] = checks.duplicate()
	for option: OptionData in _scenes[scene_id].options:
		if option.kind == OptionData.KIND_RISKY and not risky.has(scene_id):
			risky.append(scene_id)
	for option: OptionData in _scenes[scene_id].options:
		var taken: Array[String] = risky
		var branches: Array[String] = []
		if option.kind == OptionData.KIND_RISKY:
			assert_object(option.check).is_not_null()
		if option.check != null:
			branches.append(option.check.success)
			branches.append(option.check.failure)
		else:
			branches.append(option.outcome)
		for outcome_id: String in branches:
			var outcome: OutcomeData = _outcomes[outcome_id]
			var flags: Array[String] = sets.duplicate()
			for flag_id: String in outcome.sets:
				flags.append(flag_id)
			var transition: TransitionData = _transitions[outcome.routes[-1].transition]
			if transition.to_kind == TransitionData.TO_SCENE:
				found.append_array(_paths(transition.to_id, here, taken, flags))
			else:
				found.append({"scenes": here, "checks": taken, "sets": flags, "end": transition.to_id})
	return found


func _limits() -> Dictionary:
	var issues: Array[DataIssue] = []
	return ChapterLoader.read_object(LIMITS, issues)


func test_chapter_loads_and_hero_lists_it() -> void:
	assert_str(_chapter.id).is_equal("ch1")
	assert_int(_hero.chapter_ids.size()).is_equal(1)
	assert_int(_hero.endings.size()).is_equal(4)
	assert_int(_chapter.scenes.size()).is_equal(SCENE_COUNT)


func test_every_scene_is_reachable() -> void:
	var seen: Dictionary[String, bool] = {}
	for path: Dictionary in _paths(_chapter.starts[0].scene, [], [], []):
		for scene_id: String in path["scenes"]:
			seen[scene_id] = true
	assert_int(seen.size()).is_equal(SCENE_COUNT)


func test_every_path_reaches_an_ending() -> void:
	var paths: Array[Dictionary] = _paths(_chapter.starts[0].scene, [], [], [])
	assert_int(paths.size()).is_greater(0)
	for path: Dictionary in paths:
		assert_bool(_hero.endings.has(path["end"])).is_true()
		assert_str(path["scenes"][-1]).is_equal("s11_temple")


func test_milestones_and_steps_match_the_sheet() -> void:
	var ids: Array[String] = []
	for milestone: MilestoneData in _chapter.milestones:
		ids.append(milestone.id)
		assert_str(milestone.step).is_not_empty()
	assert_array(ids).is_equal(MILESTONE_IDS)
	var on_scenes: Array[String] = []
	for scene: SceneData in _chapter.scenes:
		if not scene.milestone.is_empty():
			on_scenes.append(scene.milestone)
	assert_array(on_scenes).contains_exactly_in_any_order(MILESTONE_IDS)
	assert_str(_chapter.goal).is_equal("Донести урну в храм до заката")


func test_stake_fits_the_limit() -> void:
	var issues: Array[DataIssue] = []
	var limits: Dictionary = ChapterLoader.read_object(LIMITS, issues)
	assert_str(_chapter.stake).is_not_empty()
	assert_int(_chapter.stake.length()).is_less_equal(int(limits["stake_max"]))


func test_four_checks_on_every_path_within_budget() -> void:
	for path: Dictionary in _paths(_chapter.starts[0].scene, [], [], []):
		assert_int(path["checks"].size()).is_equal(CHECKS_PER_PATH)
		assert_int(path["checks"].size()).is_less_equal(int(_limits()["k_budget"]))
		assert_array(path["checks"]).is_equal(RISKY_SCENES)


func test_goal_fail_flag_is_set_only_by_the_s11_failure() -> void:
	assert_str(_chapter.goal_fail_flag).is_equal("goal_failed")
	for outcome: OutcomeData in _chapter.outcomes:
		var sets_it: bool = outcome.sets.has(_chapter.goal_fail_flag)
		assert_bool(sets_it).is_equal(outcome.id == "s11_temple_1_failure")


func test_cartouches_sit_on_the_three_failures_of_the_sheet() -> void:
	var found: Dictionary[String, String] = {}
	for outcome: OutcomeData in _chapter.outcomes:
		if not outcome.cartouche.is_empty():
			found[outcome.id] = outcome.cartouche
	assert_dict(found).is_equal({"s03_bridge_1_failure": "bonk", "s07_forest_1_failure": "bonk", "s11_temple_1_failure": "censor"})
	assert_str(_scenes["s01_intro"].title).is_equal("Полтора килограмма бога")


func test_every_check_has_crit_lines_within_the_dialogue_limit() -> void:
	var checks: int = 0
	for scene: SceneData in _chapter.scenes:
		for option: OptionData in scene.options:
			if option.check == null:
				continue
			checks += 1
			assert_str(option.check.crit_success_line).is_not_empty()
			assert_str(option.check.crit_failure_line).is_not_empty()
			assert_int(option.check.crit_success_line.length()).is_less_equal(CRIT_LINE_MAX)
			assert_int(option.check.crit_failure_line.length()).is_less_equal(CRIT_LINE_MAX)
	assert_int(checks).is_equal(CHECKS_PER_PATH)
