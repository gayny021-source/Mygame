extends GdUnitTestSuite
## Integration tests for ChapterLoader on fixture files (ADR-0001 §4, story S1):
## load_file, read_object, DT-01 and the file form of DT-02. The tests that need no
## file are in tests/unit/story/chapter_loader_test.gd.

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


func _lines(result: LoadResult) -> Array[String]:
	var lines: Array[String] = []
	for issue: DataIssue in result.issues:
		lines.append("%s %s %s" % [issue.code, issue.path, issue.message])
	return lines


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
	var result: LoadResult = ChapterLoader.load_from_dict(chapter, SOURCE)
	# Assert
	assert_int(_count(result, "BS-01")).is_equal(M_REFS_CHAPTER_ERRORS - 1)
