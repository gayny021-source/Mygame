extends GdUnitTestSuite
## Unit tests for the `if` wiring and flag references in ChapterLoader (ADR-0001 §5, story S3):
## DT-08 for an empty or broken `if`, BS-01 for names the hero does not declare, in every
## place a condition can stand; sets, clears and goal_fail_flag name declared flags.
## Without a vocabulary only the syntax is checked.

const SOURCE := "test"


func _load(chapter: Dictionary, known: ConditionVocabulary) -> LoadResult:
	return ChapterLoader.load_from_dict(chapter, SOURCE, known)


func _paths(result: LoadResult, code: String) -> Array[String]:
	var paths: Array[String] = []
	for issue: DataIssue in result.issues:
		if issue.code == code:
			paths.append(issue.path)
	return paths


func _codes(result: LoadResult) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in result.issues:
		codes.append(issue.code)
	return codes


func test_load_known_names_in_conditions_are_clean() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = "cat(wound) and group(mood) == f_known"
	chapter["outcomes"][0]["sets"] = ["f_known"]
	chapter["outcomes"][0]["clears"] = ["f_other"]
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_codes(result)).is_empty()


func test_load_unknown_flag_in_every_condition_place_is_bs01_with_its_path() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = "f_x"
	chapter["scenes"][0]["paragraphs"].append({"text": "Условный.", "if": "f_x"})
	chapter["scenes"][0]["options"][0]["if"] = "f_x"
	chapter["outcomes"][0]["paragraphs"] = [{"text": "Исход.", "if": "f_x"}]
	chapter["outcomes"][0]["routes"].insert(0, {"if": "f_x", "transition": "t_end"})
	chapter["transitions"][0]["bridge"] = {"base": "Мост {insert}", "inserts": [{"if": "f_x", "text": "Вставка."}]}
	chapter["transitions"][0]["coda"].append({"text": "Кода.", "if": "f_x"})
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	var expected: Array[String] = [
		"test/starts/st_main/if",
		"test/scenes/s1/paragraphs/1/if",
		"test/scenes/s1/options/s1_go/if",
		"test/outcomes/o1/paragraphs/0/if",
		"test/outcomes/o1/routes/0/if",
		"test/transitions/t_end/bridge/inserts/0/if",
		"test/transitions/t_end/coda/1/if",
	]
	assert_array(_paths(result, "BS-01")).contains_exactly_in_any_order(expected)


func test_load_condition_issue_carries_owner_id() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["if"] = "f_x"
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].object_id).is_equal("s1_go")
	assert_str(result.issues[0].message).contains("f_x")


func test_load_flag_of_another_group_in_condition_is_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = "group(mood) == f_other"
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_load_empty_if_is_dt08() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = ""
	# Act
	var result: LoadResult = _load(chapter, null)
	# Assert
	assert_array(_codes(result)).is_equal(["DT-08"] as Array[String])
	assert_str(result.issues[0].path).is_equal("test/starts/st_main/if")


func test_load_broken_if_is_dt08_even_without_vocabulary() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["scenes"][0]["options"][0]["if"] = "f_a and or f_b"
	# Act
	var result: LoadResult = _load(chapter, null)
	# Assert
	assert_array(_codes(result)).is_equal(["DT-08"] as Array[String])


func test_load_unknown_names_without_vocabulary_are_not_reported() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = "f_x"
	chapter["outcomes"][0]["sets"] = ["f_y"]
	# Act
	var result: LoadResult = _load(chapter, null)
	# Assert
	assert_array(_codes(result)).is_empty()
	assert_object(result.data).is_not_null()


func test_load_undeclared_sets_and_clears_are_bs01_with_index_path() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["outcomes"][0]["sets"] = ["f_known", "f_nope"]
	chapter["outcomes"][0]["clears"] = ["f_gone"]
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_paths(result, "BS-01")).is_equal(["test/outcomes/o1/sets/1", "test/outcomes/o1/clears/0"] as Array[String])


func test_load_empty_id_inside_sets_and_clears_is_dt02() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["outcomes"][0]["sets"] = ["f_known", ""]
	chapter["outcomes"][0]["clears"] = [""]
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_paths(result, "DT-02")).is_equal(["test/outcomes/o1/sets/1", "test/outcomes/o1/clears/0"] as Array[String])
	assert_array(_codes(result)).is_equal(["DT-02", "DT-02"] as Array[String])


func test_load_undeclared_goal_fail_flag_is_bs01() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["goal_fail_flag"] = "f_nope"
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_paths(result, "BS-01")).is_equal(["test/goal_fail_flag"] as Array[String])


func test_load_conditions_are_checked_in_a_chapter_without_a_scenes_list() -> void:
	# Arrange
	var chapter: Dictionary = StoryFixtures.minimal_chapter()
	chapter["starts"][0]["if"] = "f_x"
	chapter.erase("scenes")
	# Act
	var result: LoadResult = _load(chapter, StoryFixtures.vocabulary())
	# Assert
	assert_array(_codes(result)).is_equal(["DT-03", "BS-01"] as Array[String])
