extends GdUnitTestSuite
## Integration tests for AC-27 of branching-story.md (all codes BS-01…BS-19 on the ch_f1 fixture, story S5).
## The chapter is MeaningFixtures.f1_clean(): ch_f1 of tests/fixtures/story/hero_stub made clean for the meaning checks.
## Every test builds its own data; nothing is shared and nothing is written.

const FIRST_CODE := 1
const LAST_CODE := 19
const RISKY_ON_PATH := 4
const SPINE_SCENES := 11
const BRANCH_SCENES := 12
const WORDS_SPINE := 1790
const WORDS_BRANCH := 1970
const ENDINGS_TOTAL := 4
const ENDINGS_OPEN := 1


func _hero(data: Dictionary) -> HeroData:
	return GraphFixtures.hero(data, GraphFixtures.f1_flags())


func _issues(data: Dictionary) -> Array[DataIssue]:
	return DataValidator.validate(_hero(data), ValidatorOptions.new())


func _paths(data: Dictionary) -> ChapterPaths:
	return ChapterPaths.new(StoryGraph.new(_hero(data).chapters[0]))


func _path_with(paths: ChapterPaths, scene_count: int) -> ChapterPaths.PathInfo:
	for info: ChapterPaths.PathInfo in paths.paths:
		if info.scenes.size() == scene_count:
			return info
	return null


## Findings of the codes BS-01…BS-19 as "code severity message" strings, for a readable failure.
func _findings_of_bs_01_to_19(issues: Array[DataIssue]) -> Array:
	var found: Array = []
	for code_number: int in range(FIRST_CODE, LAST_CODE + 1):
		var code: String = "BS-%02d" % code_number
		for issue: DataIssue in issues:
			if issue.code == code:
				found.append("%s %s %s" % [issue.code, issue.severity, issue.message])
	return found


# --- AC-27: the clean chapter ---

func test_ch_f1_clean_has_no_errors_and_no_warnings_of_bs_01_to_bs_19() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.f1_clean()
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert  # AC-27
	assert_array(_findings_of_bs_01_to_19(issues)).is_empty()


func test_ch_f1_clean_has_risky_count_four_on_both_paths() -> void:
	# Arrange
	var paths: ChapterPaths = _paths(MeaningFixtures.f1_clean())
	# Act / Assert  # AC-27
	assert_int(paths.paths.size()).is_equal(2)
	for info: ChapterPaths.PathInfo in paths.paths:
		assert_int(info.risky).is_equal(RISKY_ON_PATH)


func test_ch_f1_clean_has_one_path_of_eleven_scenes_and_one_of_twelve() -> void:
	# Arrange
	var paths: ChapterPaths = _paths(MeaningFixtures.f1_clean())
	# Act
	var lengths: Array = paths.paths.map(func(info: ChapterPaths.PathInfo) -> int: return info.scenes.size())
	lengths.sort()
	# Assert  # AC-27
	assert_array(lengths).is_equal([SPINE_SCENES, BRANCH_SCENES])


func test_ch_f1_clean_words_of_the_paths_are_1790_and_1970() -> void:
	# Arrange
	# The file itself: f1_clean() moves 35 words of each node scene into a conditional paragraph.
	var paths: ChapterPaths = _paths(GraphFixtures.f1_chapter())
	# Act
	var spine: ChapterPaths.PathInfo = _path_with(paths, SPINE_SCENES)
	var branch: ChapterPaths.PathInfo = _path_with(paths, BRANCH_SCENES)
	# Assert  # AC-27 (W of F3 without conditional paragraphs, AC-30)
	assert_object(spine).is_not_null()
	assert_object(branch).is_not_null()
	assert_int(spine.words_min).is_equal(WORDS_SPINE)
	assert_int(branch.words_min).is_equal(WORDS_BRANCH)


func test_ch_f1_clean_has_four_endings_of_which_one_is_open() -> void:
	# Arrange
	var chapter: ChapterData = _hero(MeaningFixtures.f1_clean()).chapters[0]
	var endings: Dictionary = {}
	for transition: TransitionData in chapter.transitions:
		if transition.to_kind == TransitionData.TO_ENDING:
			endings[transition.to_id] = true
	var open_options: int = 0
	for scene: SceneData in chapter.scenes:
		for option: OptionData in scene.options:
			if option.outcome == "o_s11_open":
				open_options += 1
	# Act / Assert  # AC-27
	assert_int(endings.size()).is_equal(ENDINGS_TOTAL)
	assert_int(open_options).is_equal(ENDINGS_OPEN)


# --- AC-27: mutations, one error each ---

func test_ch_f1_clean_without_outcome_of_a_normal_option_gives_one_bs02_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.f1_clean()
	GraphFixtures.find(GraphFixtures.find(data["scenes"], "s01")["options"], "s01_go").erase("outcome")
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert  # AC-27
	assert_int(GraphFixtures.count(issues, "BS-02", DataIssue.ERROR)).is_equal(1)


func test_ch_f1_clean_with_a_transition_into_an_ancestor_gives_one_bs05_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.f1_clean()
	GraphFixtures.find(data["transitions"], "t_s05_s06")["to"] = "scene:s03"
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert  # AC-27
	assert_int(GraphFixtures.count(issues, "BS-05", DataIssue.ERROR)).is_equal(1)


func test_ch_f1_clean_with_a_second_final_scene_gives_one_bs10_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.f1_clean()
	GraphFixtures.find(data["scenes"], "s10")["final"] = true
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert  # AC-27
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_equal(1)
