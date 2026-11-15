extends GdUnitTestSuite
## Unit tests for HeroLoader (ADR-0001 §4, story S1): hero.json, its chapters and
## the hero part of BS-01 (branching-story.md, AC-01). flags.json is story S3.

const HERO_REFS_BS01 := 6
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
	assert_array(Array(hero.stat_ids)).is_equal(["strength", "charisma", "mind", "faith"])
	assert_array(Array(hero.endings)).is_equal(["end_a", "end_b", "end_c", "end_d"])
	assert_str(hero.accent).is_equal("carmine")
	assert_int(hero.chapters.size()).is_equal(1)
	assert_str(hero.chapters[0].id).is_equal("ch_f1")


func test_load_hero_stub_bonuses_are_whole_ints() -> void:
	# Act
	var hero: HeroData = _load("hero_stub").data
	# Assert
	assert_array(Array(hero.stat_bonuses)).is_equal(STUB_BONUSES)


func test_load_hero_missing_hero_returns_dt01() -> void:
	# Act
	var result: LoadResult = _load("no_such_hero")
	# Assert
	assert_object(result.data).is_null()
	assert_int(result.issues.size()).is_equal(1)
	assert_str(result.issues[0].code).is_equal("DT-01")


func test_load_hero_refs_returns_six_bs01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert: four inside m_refs, ending:ghost, id o_a in two chapters
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


func test_load_hero_refs_missing_chapter_file_returns_dt01() -> void:
	# Act
	var result: LoadResult = _load("hero_refs")
	# Assert
	var path: String = StoryFixtures.DIR + "/hero_refs/chapters/m_absent.json"
	assert_array(_paths(result, "DT-01")).is_equal([path])


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
