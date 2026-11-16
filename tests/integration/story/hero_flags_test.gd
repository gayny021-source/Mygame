extends GdUnitTestSuite
## Integration tests: HeroLoader reads flags.json from fixture folders and checks the hero's
## chapters against it (ADR-0001 §2, §4, story S3; branching-story.md AC-01, run-state.md AC-01/AC-02).

func _load(hero_id: String) -> LoadResult:
	return HeroLoader.load_hero(hero_id, StoryFixtures.DIR)


func _lines(result: LoadResult, code: String) -> Array[String]:
	var lines: Array[String] = []
	for issue: DataIssue in result.issues:
		if issue.code == code:
			lines.append("%s %s" % [issue.path, issue.message])
	return lines


func _codes(result: LoadResult) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in result.issues:
		codes.append(issue.code)
	return codes


func test_load_hero_with_flags_json_reads_declarations_and_has_no_findings() -> void:
	# Act
	var result: LoadResult = _load("hero_stub")
	# Assert
	assert_array(_lines(result, "BS-01")).is_empty()
	assert_array(_codes(result)).is_empty()
	var hero: HeroData = result.data
	assert_int(hero.flags.size()).is_equal(5)
	assert_str(hero.flags[4].id).is_equal("f_past")
	assert_str(hero.flags[0].category).is_equal("price")


func test_load_hero_names_every_undeclared_flag_group_mismatch_and_unused_ref() -> void:
	# Act
	var result: LoadResult = _load("hero_flags_use")
	# Assert
	var lines: Array[String] = _lines(result, "BS-01")
	assert_int(lines.size()).is_equal(4)
	var joined: String = "\n".join(lines)
	assert_str(joined).contains("f_ghost").contains("paragraphs/1/if")
	assert_str(joined).contains("не из группы «mood»").contains("options/s1_go/if")
	assert_str(joined).contains("f_nope").contains("sets/1")
	assert_str(joined).contains("f_gone").contains("clears/0")
	assert_array(_codes(result)).is_equal(["BS-01", "BS-01", "BS-01", "BS-01"] as Array[String])


func test_load_hero_without_flags_json_treats_every_flag_as_undeclared() -> void:
	# Act
	var result: LoadResult = _load("hero_flags_none")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])
	assert_str(_lines(result, "BS-01")[0]).contains("f_x")


func test_load_hero_with_broken_flags_json_reports_it_and_skips_flag_references() -> void:
	# Act
	var result: LoadResult = _load("hero_flags_bad")
	# Assert
	assert_array(_codes(result)).is_equal(["DT-05"] as Array[String])
	assert_str(_lines(result, "DT-05")[0]).contains("flags.json")
	assert_object(result.data).is_null()
