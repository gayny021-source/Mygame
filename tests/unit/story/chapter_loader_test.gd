extends GdUnitTestSuite
## Unit tests for ChapterLoader (ADR-0001 §4, story S1): DT-01…DT-07 and the
## chapter part of BS-01 (branching-story.md, AC-01). A test on a code looks only
## at findings with that code, as the GDD Acceptance Criteria preamble requires.

const SOURCE := "test"
const CH_F1_SCENES := 12
const CH_F1_FINAL_OPTIONS := 3
const M_REFS_CHAPTER_ERRORS := 4


func _count(result: LoadResult, code: String) -> int:
	var count: int = 0
	for issue: DataIssue in result.issues:
		if issue.code == code:
			count += 1
	return count


func _first(result: LoadResult, code: String) -> DataIssue:
	for issue: DataIssue in result.issues:
		if issue.code == code:
			return issue
	return null


func _lines(result: LoadResult) -> Array[String]:
	var lines: Array[String] = []
	for issue: DataIssue in result.issues:
		lines.append("%s %s %s" % [issue.code, issue.path, issue.message])
	return lines


func _load(chapter: Dictionary) -> LoadResult:
	return ChapterLoader.load_from_dict(chapter, SOURCE)


# --- valid data ---

func test_load_file_ch_f1_returns_chapter_without_issues() -> void:
	# Act
	var result: LoadResult = ChapterLoader.load_file(StoryFixtures.CH_F1)
	# Assert
	assert_array(_lines(result)).is_empty()
	var chapter: ChapterData = result.data
	assert_str(chapter.id).is_equal("ch_f1")
	assert_int(chapter.scenes.size()).is_equal(CH_F1_SCENES)
	assert_int(chapter.starts.size()).is_equal(1)
	var final_scene: SceneData = chapter.scenes[CH_F1_SCENES - 1]
	assert_str(final_scene.id).is_equal("s11")
	assert_bool(final_scene.final).is_true()
	assert_bool(final_scene.node).is_true()
	assert_int(final_scene.options.size()).is_equal(CH_F1_FINAL_OPTIONS)


func test_load_file_ch_f1_keeps_condition_text_and_check() -> void:
	# Act
	var chapter: ChapterData = ChapterLoader.load_file(StoryFixtures.CH_F1).data
	# Assert
	var final_scene: SceneData = chapter.scenes[CH_F1_SCENES - 1]
	var risky: OptionData = final_scene.options[0]
	var open: OptionData = final_scene.options[CH_F1_FINAL_OPTIONS - 1]
	assert_str(open.condition).is_equal("f_past")
	assert_object(open.check).is_null()
	assert_str(risky.check.success).is_equal("o_s11_win")
	assert_str(risky.check.failure).is_equal("o_s11_fail")
	assert_str(risky.outcome).is_empty()


func test_load_file_ch_f1_reads_transition_targets() -> void:
	# Act
	var chapter: ChapterData = ChapterLoader.load_file(StoryFixtures.CH_F1).data
	# Assert
	var first: TransitionData = chapter.transitions[0]
	var last: TransitionData = chapter.transitions[chapter.transitions.size() - 1]
	assert_str(first.to_kind).is_equal(TransitionData.TO_SCENE)
	assert_str(first.to_id).is_equal("s02")
	assert_object(first.bridge).is_not_null()
	assert_str(last.to_kind).is_equal(TransitionData.TO_ENDING)
	assert_str(last.to_id).is_equal("end_d")
	assert_object(last.bridge).is_null()


func test_load_from_dict_minimal_chapter_returns_chapter_without_issues() -> void:
	# Act
	var result: LoadResult = _load(StoryFixtures.minimal_chapter())
	# Assert
	assert_array(_lines(result)).is_empty()
	var chapter: ChapterData = result.data
	assert_str(chapter.transitions[0].to_kind).is_equal(TransitionData.TO_CHAPTER_END)
	assert_int(chapter.transitions[0].coda.size()).is_equal(1)


func test_load_from_dict_paragraph_string_and_object_give_same_structure() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	var marked: Dictionary = {"text": "Реплика.", "if": "f_past", "speaks": "garzug", "damage": "rovend"}
	chapter["scenes"][0]["paragraphs"] = ["Просто текст.", marked]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()
	var loaded: ChapterData = result.data
	var plain: ParagraphData = loaded.scenes[0].paragraphs[0]
	var rich: ParagraphData = loaded.scenes[0].paragraphs[1]
	assert_str(plain.text).is_equal("Просто текст.")
	assert_str(plain.condition).is_empty()
	assert_str(rich.text).is_equal("Реплика.")
	assert_str(rich.condition).is_equal("f_past")
	assert_str(rich.speaks).is_equal("garzug")
	assert_str(rich.damage).is_equal("rovend")


func test_load_from_dict_underscore_key_is_ignored() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["_note"] = "заметка сценариста"
	chapter["scenes"][0]["_todo"] = 1
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()


# --- DT-01: JSON syntax, file access ---

func test_load_file_broken_json_returns_dt01_with_line() -> void:
	# Act
	var result: LoadResult = ChapterLoader.load_file(StoryFixtures.DT01_BROKEN)
	# Assert: the comma is missing before line 5 of the file
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-01")
	assert_str(result.issues[0].severity).is_equal(DataIssue.ERROR)
	assert_str(result.issues[0].path).is_equal(StoryFixtures.DT01_BROKEN + ":5")


func test_load_file_missing_file_returns_dt01() -> void:
	# Act
	var result: LoadResult = ChapterLoader.load_file(StoryFixtures.MISSING_FILE)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-01")
	assert_str(result.issues[0].path).is_equal(StoryFixtures.MISSING_FILE)


# --- DT-02: types ---

func test_load_file_root_array_returns_dt02() -> void:
	# Act
	var result: LoadResult = ChapterLoader.load_file(StoryFixtures.DT02_ROOT_ARRAY)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-02")).is_equal(1)


func test_load_from_dict_number_instead_of_string_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["title"] = 5
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-02")).is_equal(1)
	assert_str(_first(result, "DT-02").path).is_equal("test/title")
	assert_str(_first(result, "DT-02").object_id).is_equal("m_min")


func test_load_from_dict_scene_that_is_not_object_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"].append("s2")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-02")).is_equal(1)
	assert_str(_first(result, "DT-02").path).is_equal("test/scenes/1")


func test_load_from_dict_fractional_step_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": 1.5}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-02")).is_equal(1)
	assert_str(_first(result, "DT-02").path).is_equal("test/milestones/m1/step")


func test_load_from_dict_whole_float_step_becomes_int() -> void:
	# Arrange: JSON numbers arrive as float (story_json_engine_test.gd)
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": 2.0}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()
	var loaded: ChapterData = result.data
	assert_int(loaded.milestones[0].step).is_equal(2)


# --- DT-03: required keys ---

func test_load_from_dict_missing_goal_returns_dt03() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter.erase("goal")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-03")).is_equal(1)
	assert_str(_first(result, "DT-03").path).is_equal("test/goal")


func test_load_from_dict_missing_illustration_returns_dt03_with_scene_path() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0].erase("illustration")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-03")).is_equal(1)
	assert_str(_first(result, "DT-03").path).is_equal("test/scenes/s1/illustration")
	assert_str(_first(result, "DT-03").object_id).is_equal("s1")


func test_load_from_dict_missing_schema_version_returns_dt03_and_no_chapter() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter.erase("schema_version")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-03")).is_equal(1)
	assert_int(_count(result, "DT-07")).is_equal(0)


# --- DT-04: unknown keys ---

func test_load_from_dict_unknown_chapter_key_returns_dt04() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["titel"] = "опечатка"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-04")).is_equal(1)
	assert_str(_first(result, "DT-04").path).is_equal("test/titel")


func test_load_from_dict_unknown_option_key_returns_dt04_with_option_path() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["условие"] = "f_past"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-04")).is_equal(1)
	assert_str(_first(result, "DT-04").path).is_equal("test/scenes/s1/options/s1_go/условие")


# --- DT-05: enumerations ---

func test_load_from_dict_russian_kind_returns_dt05() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["kind"] = "обычный"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-05")).is_equal(1)
	assert_str(_first(result, "DT-05").path).is_equal("test/scenes/s1/options/s1_go/kind")


func test_load_from_dict_unknown_level_returns_dt05() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.chapter_with_check()
	chapter["scenes"][0]["options"][0]["check"]["level"] = "13"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-05")).is_equal(1)


@warning_ignore("unused_parameter")
func test_load_from_dict_malformed_to_returns_dt05(to: String, test_parameters := [
	["сцена:s1"],
	["scene"],
	["scene:"],
	["ending:"],
	["chapter_end:s1"],
	[""],
]) -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["transitions"][0]["to"] = to
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-05")).is_equal(1)


# --- DT-06: id format ^[a-z][a-z0-9_]*$ ---

@warning_ignore("unused_parameter")
func test_load_from_dict_bad_scene_id_returns_dt06(id: String, test_parameters := [
	["Scene1"],
	["1a"],
	[""],
	["s 1"],
	["сцена"],
	["s1\n"],
]) -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["id"] = id
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-06")).is_equal(1)


@warning_ignore("unused_parameter")
func test_load_from_dict_good_chapter_id_returns_no_dt06(id: String, test_parameters := [
	["a"],
	["ch_f1"],
	["s01_b"],
	["x9_"],
]) -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["id"] = id
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()


# --- DT-07: schema version ---

func test_load_from_dict_schema_version_two_returns_dt07_and_no_chapter() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["schema_version"] = 2
	chapter["titel"] = "при чужой версии файл дальше не читается"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-07")


func test_load_from_dict_fractional_schema_version_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["schema_version"] = 1.5
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "DT-02")).is_equal(1)
	assert_int(_count(result, "DT-07")).is_equal(0)


# --- BS-01: references and unique ids inside a chapter (AC-01, S1 part) ---

func test_load_file_m_refs_returns_four_bs01() -> void:
	# Act
	var result: LoadResult = ChapterLoader.load_file(StoryFixtures.M_REFS)
	# Assert: start -> nope, option -> o_missing, scene:ghost, two objects with id a
	assert_object(result.data).is_null()
	assert_int(_count(result, "BS-01")).is_equal(M_REFS_CHAPTER_ERRORS)
	assert_int(result.issues.size()).is_equal(M_REFS_CHAPTER_ERRORS)


func test_load_from_dict_m_refs_with_one_error_fixed_returns_one_bs01_less() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var chapter: Dictionary = ChapterLoader.read_object(StoryFixtures.M_REFS, issues)
	chapter["starts"][0]["scene"] = "a"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(M_REFS_CHAPTER_ERRORS - 1)


func test_load_from_dict_start_to_missing_scene_returns_bs01_with_field_and_id() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["scene"] = "nope"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_str(_first(result, "BS-01").path).is_equal("test/starts/st_main/scene")
	assert_str(_first(result, "BS-01").object_id).is_equal("st_main")
	assert_str(_first(result, "BS-01").severity).is_equal(DataIssue.ERROR)


func test_load_from_dict_check_failure_to_missing_outcome_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.chapter_with_check()
	chapter["scenes"][0]["options"][0]["check"]["failure"] = "o_missing"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_str(_first(result, "BS-01").path).is_equal("test/scenes/s1/options/s1_risk/check/failure")


func test_load_from_dict_route_to_missing_transition_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["outcomes"][0]["routes"][0]["transition"] = "t_missing"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_str(_first(result, "BS-01").path).is_equal("test/outcomes/o1/routes/0/transition")


func test_load_from_dict_option_id_equal_to_scene_id_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["id"] = "s1"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_str(_first(result, "BS-01").object_id).is_equal("s1")


func test_load_from_dict_two_starts_with_one_id_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"].append({"id": "st_main", "scene": "s1"})
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)


func test_load_from_dict_no_scenes_returns_bs01() -> void:
	# Arrange: an empty graph is a BS-01 error; the start then points nowhere too
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"] = []
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(_count(result, "BS-01")).is_equal(2)
	assert_str(_first(result, "BS-01").path).is_equal("test/scenes")


func test_load_from_dict_no_starts_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"] = []
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_str(_first(result, "BS-01").path).is_equal("test/starts")
