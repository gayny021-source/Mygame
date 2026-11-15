extends GdUnitTestSuite
## Unit tests for ChapterLoader (ADR-0001 §4, story S1): DT-02…DT-07 and the
## chapter part of BS-01 (branching-story.md, AC-01). A test on a code looks only
## at findings with that code, as the GDD Acceptance Criteria preamble requires.
## The tests that read a file are in tests/integration/story/chapter_loader_file_test.gd.

const SOURCE := "test"
const MAX_WHOLE_VERSION := 9007199254740992.0


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


# --- DT-02: types ---

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


func test_load_from_dict_whole_float_schema_version_is_read_as_int() -> void:
	# Arrange: JSON numbers arrive as float (story_json_engine_test.gd)
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["schema_version"] = 1.0
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_object(result.data).is_not_null()


@warning_ignore("unused_parameter")
func test_load_from_dict_schema_version_outside_whole_range_returns_dt02(version: float, test_parameters := [
	[1e20],
	[9007199254740994.0],
	[-1e20],
]) -> void:
	# Arrange: above 2^53 a float no longer holds every whole number (ADR-0001 §4)
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["schema_version"] = version
	# Act
	var result: LoadResult = _load(chapter)
	# Assert: not a whole number at all, so the version is not even compared (no DT-07)
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/schema_version")


func test_load_from_dict_schema_version_two_to_the_53rd_is_whole_and_returns_dt07() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["schema_version"] = MAX_WHOLE_VERSION
	# Act
	var result: LoadResult = _load(chapter)
	# Assert: read as a whole number — the only finding is about the version itself
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-07")


func test_load_from_dict_milestone_step_keeps_caption_text() -> void:
	# Arrange: step is the caption of the step, not a number (chapter-goal.md, rule 3)
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": "Мост"}, {"id": "m2", "step": "Тролль"}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()
	var loaded: ChapterData = result.data
	assert_str(loaded.milestones[0].step).is_equal("Мост")
	assert_str(loaded.milestones[1].step).is_equal("Тролль")


@warning_ignore("unused_parameter")
func test_load_from_dict_milestone_step_that_is_not_caption_returns_dt02(step: Variant, test_parameters := [
	[1],
	[2.0],
	[""],
]) -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": step}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/milestones/m1/step")


@warning_ignore("unused_parameter")
func test_load_from_dict_list_of_wrong_type_returns_only_dt02(key: String, test_parameters := [
	["starts"],
	["milestones"],
	["scenes"],
	["outcomes"],
	["transitions"],
]) -> void:
	# Arrange: the scene points at a milestone, so every list here has references to it
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": "Мост"}]
	chapter["scenes"][0]["milestone"] = "m1"
	chapter[key] = 5
	# Act
	var result: LoadResult = _load(chapter)
	# Assert: the broken list is the cause; BS-01 about references to it would only repeat it
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/" + key)


func test_load_from_dict_empty_title_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["title"] = ""
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/title")


func test_load_from_dict_empty_paragraph_text_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["paragraphs"] = [{"text": ""}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/paragraphs/0/text")


func test_load_from_dict_empty_start_scene_returns_dt02_without_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["scene"] = ""
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/starts/st_main/scene")


func test_load_from_dict_empty_to_returns_dt02_without_dt05() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["transitions"][0]["to"] = ""
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/transitions/t_end/to")


func test_load_from_dict_empty_scene_id_returns_dt06_without_dt02() -> void:
	# Arrange: an empty id is an id of a wrong format, not an empty required string
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["id"] = ""
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(_count(result, "DT-06")).is_equal(1)
	assert_int(_count(result, "DT-02")).is_equal(0)


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


func test_load_from_dict_milestone_without_step_returns_dt03() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1"}]
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-03")
	assert_str(result.issues[0].path).is_equal("test/milestones/m1/step")


@warning_ignore("unused_parameter")
func test_load_from_dict_missing_required_list_returns_only_dt03(key: String, test_parameters := [
	["starts"],
	["scenes"],
	["outcomes"],
	["transitions"],
]) -> void:
	# Arrange: the missing list is the cause; broken references to it would only repeat it
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter.erase(key)
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-03")
	assert_str(result.issues[0].path).is_equal("test/" + key)


func test_load_from_dict_missing_start_scene_returns_only_dt03() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0].erase("scene")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert: no BS-01 about a reference to the id «»
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-03")
	assert_str(result.issues[0].path).is_equal("test/starts/st_main/scene")


func test_load_from_dict_missing_check_success_returns_only_dt03() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.chapter_with_check()
	chapter["scenes"][0]["options"][0]["check"].erase("success")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-03")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/options/s1_risk/check/success")


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
	["scene:a:b"],
	["chapter_end:s1"],
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

func test_load_from_dict_option_without_outcome_and_check_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0].erase("outcome")
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("BS-01")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/options/s1_go/outcome")
	assert_str(result.issues[0].object_id).is_equal("s1_go")


func test_load_from_dict_option_with_empty_outcome_and_no_check_returns_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["outcome"] = ""
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-02")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/options/s1_go/outcome")


func test_load_from_dict_option_with_outcome_and_check_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.chapter_with_check()
	chapter["scenes"][0]["options"][0]["outcome"] = "o1"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("BS-01")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/options/s1_risk/outcome")


func test_load_from_dict_risky_option_with_outcome_and_no_check_returns_no_issues() -> void:
	# Arrange: whether kind agrees with check is BS-02, story S4 — the loader checks the form only
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["kind"] = "risky"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()


func test_load_from_dict_scene_milestone_outside_milestones_returns_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": "Мост"}]
	chapter["scenes"][0]["milestone"] = "m_ghost"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("BS-01")
	assert_str(result.issues[0].path).is_equal("test/scenes/s1/milestone")
	assert_str(result.issues[0].object_id).is_equal("s1")


func test_load_from_dict_scene_milestone_from_milestones_returns_no_issues() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["milestones"] = [{"id": "m1", "step": "Мост"}]
	chapter["scenes"][0]["milestone"] = "m1"
	# Act
	var result: LoadResult = _load(chapter)
	# Assert
	assert_array(_lines(result)).is_empty()


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
