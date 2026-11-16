extends GdUnitTestSuite
## Unit tests for FlagLoader (ADR-0001 §1 "Флаг", flags.json form; story S3; run-state.md,
## Core Rules 1 and AC-02). Declarations come as dictionaries, no file is read.
## Reading flags.json from a folder is in tests/integration/story/hero_flags_test.gd.

const SOURCE := "flags.json"
const STATS: PackedStringArray = ["strength", "faith"]


var _flags: Array[FlagDecl] = []


func _parse(data: Dictionary) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	_flags = FlagLoader.parse(data, SOURCE, STATS, result.issues)
	return result


func _with(flag: Dictionary) -> Dictionary:
	return StoryFixtures.flags_file([flag])


func _first(result: LoadResult, code: String) -> DataIssue:
	for issue: DataIssue in result.issues:
		if issue.code == code:
			return issue
	return null


func _codes(result: LoadResult) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in result.issues:
		codes.append(issue.code)
	return codes


func test_parse_full_declaration_fills_every_field() -> void:
	# Arrange
	var flag: Dictionary = {"id": "wound_a", "category": "wound", "title": "Рана", "scope": "chapter", "group": "wounds", "visible": true, "exception": "никто не лечит", "deprecated": true, "blocks": ["strength"]}
	# Act
	var result: LoadResult = _parse(_with(flag))
	# Assert
	assert_array(_codes(result)).is_empty()
	var decl: FlagDecl = _flags[0]
	assert_str(decl.id).is_equal("wound_a")
	assert_str(decl.category).is_equal("wound")
	assert_str(decl.title).is_equal("Рана")
	assert_str(decl.scope).is_equal("chapter")
	assert_str(decl.group).is_equal("wounds")
	assert_bool(decl.visible).is_true()
	assert_str(decl.exception).is_equal("никто не лечит")
	assert_bool(decl.deprecated).is_true()
	assert_array(Array(decl.blocks)).is_equal(["strength"])


func test_parse_minimal_declaration_defaults_scope_to_run() -> void:
	# Act
	var result: LoadResult = _parse(_with(StoryFixtures.flag("f_a")))
	# Assert
	assert_array(_codes(result)).is_empty()
	var decl: FlagDecl = _flags[0]
	assert_str(decl.scope).is_equal("run")
	assert_str(decl.group).is_empty()
	assert_bool(decl.visible).is_false()
	assert_bool(decl.deprecated).is_false()
	assert_array(Array(decl.blocks)).is_empty()


func test_parse_empty_flag_list_is_clean() -> void:
	# Act
	var result: LoadResult = _parse(StoryFixtures.flags_file([]))
	# Assert
	assert_array(_codes(result)).is_empty()


func test_parse_missing_flags_list_is_dt03() -> void:
	# Act
	var result: LoadResult = _parse({"schema_version": 1})
	# Assert
	assert_array(_codes(result)).is_equal(["DT-03"] as Array[String])


func test_parse_other_schema_version_is_dt07() -> void:
	# Act
	var result: LoadResult = _parse({"schema_version": 2, "flags": []})
	# Assert
	assert_array(_codes(result)).is_equal(["DT-07"] as Array[String])


func test_parse_unknown_root_and_flag_keys_are_dt04() -> void:
	# Arrange
	var flag: Dictionary = StoryFixtures.flag("f_a")
	flag["color"] = "red"
	var data: Dictionary = _with(flag)
	data["extra"] = 1
	# Act
	var result: LoadResult = _parse(data)
	# Assert
	assert_array(_codes(result)).is_equal(["DT-04", "DT-04"] as Array[String])


func test_parse_id_outside_the_pattern_is_dt06() -> void:
	# Act
	var result: LoadResult = _parse(_with(StoryFixtures.flag("Flag1")))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-06"] as Array[String])


func test_parse_every_reserved_word_as_flag_id_is_dt06() -> void:
	for word: String in ["and", "or", "not", "any", "cat", "group"]:
		# Act
		var result: LoadResult = _parse(_with(StoryFixtures.flag(word)))
		# Assert
		assert_array(_codes(result)).is_equal(["DT-06"] as Array[String])
		assert_str(_first(result, "DT-06").message).contains(word)


func test_parse_reserved_word_as_group_id_is_dt06() -> void:
	# Arrange
	var flag: Dictionary = StoryFixtures.flag("f_a")
	flag["group"] = "not"
	# Act
	var result: LoadResult = _parse(_with(flag))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-06"] as Array[String])
	assert_str(_first(result, "DT-06").path).ends_with("/group")


func test_parse_group_outside_the_pattern_or_empty_is_flagged() -> void:
	# Arrange
	var bad: Dictionary = StoryFixtures.flag("f_a")
	bad["group"] = "Mood"
	var empty: Dictionary = StoryFixtures.flag("f_b")
	empty["group"] = ""
	# Act
	var result: LoadResult = _parse(StoryFixtures.flags_file([bad, empty]))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-06", "DT-02"] as Array[String])


func test_parse_duplicate_id_is_bs01() -> void:
	# Act
	var result: LoadResult = _parse(StoryFixtures.flags_file([StoryFixtures.flag("f_a"), StoryFixtures.flag("f_a")]))
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])
	assert_str(_first(result, "BS-01").path).contains("f_a")


func test_parse_duplicate_id_is_declared_once() -> void:
	# Act
	_parse(StoryFixtures.flags_file([StoryFixtures.flag("f_a"), StoryFixtures.flag("f_a")]))
	# Assert
	assert_int(_flags.size()).is_equal(1)


func test_parse_missing_visible_is_dt03() -> void:
	# Arrange
	var flag: Dictionary = StoryFixtures.flag("f_a")
	flag.erase("visible")
	# Act
	var result: LoadResult = _parse(_with(flag))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-03"] as Array[String])
	assert_str(_first(result, "DT-03").path).ends_with("/visible")


func test_parse_blocks_without_visible_is_dt03_and_no_false_bs01() -> void:
	# Arrange
	var flag: Dictionary = StoryFixtures.flag("w_a", "wound")
	flag.merge({"scope": "run", "blocks": ["strength"]})
	flag.erase("visible")
	# Act
	var result: LoadResult = _parse(_with(flag))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-03"] as Array[String])


func test_parse_category_outside_the_seven_is_dt05() -> void:
	# Act
	var result: LoadResult = _parse(_with(StoryFixtures.flag("f_a", "mood")))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-05"] as Array[String])


func test_parse_every_known_category_is_clean() -> void:
	for category: String in ["wound", "item", "reputation", "debt", "companion", "price", "story"]:
		# Act
		var result: LoadResult = _parse(_with(StoryFixtures.flag("f_a", category)))
		# Assert
		assert_array(_codes(result)).is_empty()


func test_parse_scope_outside_run_and_chapter_is_dt05() -> void:
	# Arrange
	var flag: Dictionary = StoryFixtures.flag("f_a")
	flag["scope"] = "forever"
	# Act
	var result: LoadResult = _parse(_with(flag))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-05"] as Array[String])


func test_parse_empty_title_is_dt02_and_missing_title_is_dt03() -> void:
	# Arrange
	var empty: Dictionary = StoryFixtures.flag("f_a")
	empty["title"] = ""
	var missing: Dictionary = StoryFixtures.flag("f_b")
	missing.erase("title")
	# Act
	var result: LoadResult = _parse(StoryFixtures.flags_file([empty, missing]))
	# Assert
	assert_array(_codes(result)).is_equal(["DT-02", "DT-03"] as Array[String])


func test_parse_blocks_need_a_known_stat_visibility_and_scope() -> void:
	# Arrange
	var good: Dictionary = StoryFixtures.flag("w_ok", "wound")
	good.merge({"visible": true, "scope": "run", "blocks": ["strength"]}, true)
	var empty: Dictionary = StoryFixtures.flag("w_empty", "wound")
	empty.merge({"visible": true, "scope": "run", "blocks": []}, true)
	var unknown: Dictionary = StoryFixtures.flag("w_luck", "wound")
	unknown.merge({"visible": true, "scope": "run", "blocks": ["luck"]}, true)
	var hidden: Dictionary = StoryFixtures.flag("w_hidden", "wound")
	hidden.merge({"scope": "run", "blocks": ["faith"]})
	var no_scope: Dictionary = StoryFixtures.flag("w_noscope", "wound")
	no_scope.merge({"visible": true, "blocks": ["faith"]}, true)
	# Act
	var result: LoadResult = _parse(StoryFixtures.flags_file([good, empty, unknown, hidden, no_scope]))
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01", "BS-01", "BS-01", "BS-01"] as Array[String])
	var paths: Array[String] = []
	for issue: DataIssue in result.issues:
		paths.append(issue.object_id)
	assert_array(paths).is_equal(["w_empty", "w_luck", "w_hidden", "w_noscope"] as Array[String])


func test_declared_builds_vocabulary_from_flags_categories_and_groups() -> void:
	# Arrange
	var in_group: Dictionary = StoryFixtures.flag("f_a", "wound")
	in_group["group"] = "mood"
	_parse(StoryFixtures.flags_file([in_group, StoryFixtures.flag("f_b", "item")]))
	# Act
	var known: ConditionVocabulary = FlagLoader.vocabulary(_flags)
	# Assert
	assert_array(Array(known.flags)).is_equal(["f_a", "f_b"])
	assert_array(Array(known.categories)).is_equal(["wound", "item"])
	assert_array(Array(known.groups)).is_equal(["mood"])
	assert_str(known.flag_groups.get("f_a", "")).is_equal("mood")
	assert_bool(known.flag_groups.has("f_b")).is_false()
