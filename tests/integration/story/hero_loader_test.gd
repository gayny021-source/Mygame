extends GdUnitTestSuite
## Integration tests for HeroLoader on fixture folders (ADR-0001 §4, story S1):
## hero.json, its chapters and the hero part of BS-01 (branching-story.md, AC-01).
## flags.json is story S3.

const HERO_REFS_BS01 := 7
const HERO_WRONG_BS01 := 3
const HERO_LINKS_BS01 := 3
const HERO_LISTS_ISSUES := 4
const STUB_STAT_IDS: Array[String] = ["strength", "charisma", "mind", "faith"]
const STUB_BONUSES: Array[int] = [4, 2, 0, -1]


func _count(result: LoadResult, code: String) -> int:
	var count: int = 0
	for issue: DataIssue in result.issues:
		if issue.code == code:
			count += 1
	return count


func _paths(result: LoadResult, code: String) -> Array[String]:
	var paths: Array[String] = []
	for issue: DataIssue in result.issues:
		if issue.code == code:
			paths.append(issue.path)
	return paths


func _lines(result: LoadResult) -> Array[String]:
	var lines: Array[String] = []
	for issue: DataIssue in result.issues:
		lines.append("%s %s %s" % [issue.code, issue.path, issue.message])
	return lines


func _load(hero_id: String) -> LoadResult:
	return HeroLoader.load_hero(hero_id, StoryFixtures.DIR)


func test_load_hero_stub_returns_hero_without_issues() -> void:
	# Act
	var result: LoadResult = _load("hero_stub")
	# Assert
	assert_array(_lines(result)).is_empty()
	var hero: HeroData = result.data
	assert_str(hero.id).is_equal("hero_stub")
	assert_array(Array(hero.endings)).is_equal(["end_a", "end_b", "end_c", "end_d"])
	assert_str(hero.accent).is_equal("carmine")
	assert_int(hero.chapters.size()).is_equal(1)
	assert_str(hero.chapters[0].id).is_equal("ch_f1")


func test_load_hero_stub_stats_keep_ids_and_whole_int_bonuses() -> void:
	# Act
	var hero: HeroData = _load("hero_stub").data
	# Assert
	var ids: Array[String] = []
	var bonuses: Array[int] = []
	for stat: StatData in hero.stats:
		ids.append(stat.id)
		bonuses.append(stat.bonus)
	assert_array(ids).is_equal(STUB_STAT_IDS)
	assert_array(bonuses).is_equal(STUB_BONUSES)


func test_load_hero_missing_hero_returns_dt01() -> void:
	# Act
	var result: LoadResult = _load("no_such_hero")
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-01")


@warning_ignore("unused_parameter")
func test_load_hero_id_that_is_not_an_id_returns_dt06_and_reads_no_file(hero_id: String, test_parameters := [
	["hero_stub/../hero_stub"],
	["../story/hero_stub"],
	[""],
]) -> void:
	# Act: the first two would reach a real hero.json if the id went into the path unchecked
	var result: LoadResult = _load(hero_id)
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-06")


func test_load_hero_refs_returns_seven_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert: four inside m_refs, ending:ghost, id o_a in two chapters, m_absent without a file
	assert_object(result.data).is_null()
	assert_int(_count(result, "BS-01")).is_equal(HERO_REFS_BS01)


func test_load_hero_refs_ending_outside_hero_endings_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert
	var path: String = StoryFixtures.M_REFS + "/transitions/t_ghost_end/to"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_refs_id_in_two_chapters_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_refs/chapters/m_refs_b.json/o_a"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_refs_listed_chapter_without_file_returns_bs01_not_dt01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert: m_absent is the third entry of hero.chapters — a broken link, not a broken file
	var path: String = StoryFixtures.DIR + "/hero_refs/hero.json/chapters/2"
	assert_array(_paths(result, "BS-01")).contains([path])
	assert_int(_count(result, "DT-01")).is_equal(0)


func test_load_hero_bad_fractional_bonus_returns_dt02() -> void:
	# Act
	var result: LoadResult = _load("hero_bad")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_bad/hero.json/stats/strength/bonus"
	assert_object(result.data).is_null()
	assert_array(_paths(result, "DT-02")).is_equal([path])


func test_load_hero_bad_key_outside_adr_table_returns_dt04() -> void:
	# Act
	var result: LoadResult = _load("hero_bad")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_bad/hero.json/name"
	assert_array(_paths(result, "DT-04")).is_equal([path])


func test_load_hero_bad_chapter_id_with_path_returns_dt06_and_reads_no_file() -> void:
	# Act
	var result: LoadResult = _load("hero_bad")
	# Assert: the id is not turned into a file path, so nothing is read (no DT-01)
	assert_int(_count(result, "DT-06")).is_equal(1)
	assert_int(_count(result, "DT-01")).is_equal(0)


func test_load_hero_v2_schema_version_two_returns_only_dt07() -> void:
	# Act
	var result: LoadResult = _load("hero_v2")
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-07")
	assert_str(result.issues[0].path).is_equal(StoryFixtures.DIR + "/hero_v2/hero.json/schema_version")


func test_load_hero_wrong_missing_portrait_returns_dt03() -> void:
	# Act
	var result: LoadResult = _load("hero_wrong")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_wrong/hero.json/portrait"
	assert_object(result.data).is_null()
	assert_array(_paths(result, "DT-03")).is_equal([path])


func test_load_hero_wrong_returns_three_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_wrong")
	# Assert: id differs from the folder, strength twice, no chapters
	assert_int(_count(result, "BS-01")).is_equal(HERO_WRONG_BS01)


func test_load_hero_wrong_id_other_than_folder_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_wrong")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_wrong/hero.json/id"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_wrong_repeated_stat_id_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_wrong")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_wrong/hero.json/stats/strength/id"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_wrong_empty_chapters_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_wrong")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_wrong/hero.json/chapters"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_nochapters_chapters_of_wrong_type_returns_only_dt02() -> void:
	# Act
	var result: LoadResult = _load("hero_nochapters")
	# Assert: no BS-01 «нет ни одной главы» on top of the type finding
	assert_object(result.data).is_null()
	assert_array(_paths(result, "DT-02")).is_equal([StoryFixtures.DIR + "/hero_nochapters/hero.json/chapters"])
	assert_int(result.issues.size()).is_equal(1)


func test_load_hero_lists_broken_stats_and_endings_return_one_finding_each() -> void:
	# Act
	var result: LoadResult = _load("hero_lists")
	# Assert: m_quiet uses a stat and an ending, yet no BS-01 repeats the broken lists
	var hero_json: String = StoryFixtures.DIR + "/hero_lists/hero.json"
	assert_array(_paths(result, "DT-03")).is_equal([hero_json + "/stats"])
	assert_array(_paths(result, "DT-02")).is_equal([hero_json + "/chapters/0", hero_json + "/endings"])
	assert_int(_count(result, "BS-01")).is_equal(1)
	assert_int(result.issues.size()).is_equal(HERO_LISTS_ISSUES)


func test_load_hero_lists_finding_path_keeps_json_index_after_skipped_element() -> void:
	# Act
	var result: LoadResult = _load("hero_lists")
	# Assert: m_gone is chapters[1] in the file, though it is the first string of the list
	assert_array(_paths(result, "BS-01")).is_equal([StoryFixtures.DIR + "/hero_lists/hero.json/chapters/1"])


func test_load_hero_links_returns_three_bs01_and_nothing_else() -> void:
	# Act
	var result: LoadResult = _load("hero_links")
	# Assert: m_alien listed twice, its file holds id m_other, its check rolls on stat luck.
	# The repeated chapter is not loaded again, so its ids do not count as repeats.
	assert_object(result.data).is_null()
	assert_int(_count(result, "BS-01")).is_equal(HERO_LINKS_BS01)
	assert_int(result.issues.size()).is_equal(HERO_LINKS_BS01)


func test_load_hero_links_chapter_listed_twice_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_links")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_links/hero.json/chapters/1"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_links_chapter_file_with_another_id_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_links")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_links/chapters/m_alien.json/id"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_links_check_stat_outside_hero_stats_returns_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_links")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_links/chapters/m_alien.json/scenes/al_s1/options/al_risk/check/stat"
	assert_array(_paths(result, "BS-01")).contains([path])


func test_load_hero_stat_without_a_name_is_dt03() -> void:
	# Act
	var result: LoadResult = _load("hero_noname")
	# Assert: the player never reads a raw stat id (story UI1)
	var path: String = StoryFixtures.DIR + "/hero_noname/hero.json/stats/strength/name"
	assert_array(_paths(result, "DT-03")).contains([path])
