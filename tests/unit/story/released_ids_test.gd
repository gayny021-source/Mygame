extends GdUnitTestSuite
## Unit tests for ReleasedIds (BS-26, AC-26; ADR-0001 §3): the list of released ids, the comparison
## with current data and the freeze. Pure code over HeroData and Dictionaries; the file is read in
## tests/integration/story/data_validator_test.gd.


func _hero() -> HeroData:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_ending("t_s2", "e1")
	var hero: HeroData = MeaningFixtures.hero_of([data], MeaningFixtures.flags())
	hero.endings = PackedStringArray(["e1"])
	return hero


func _released() -> Dictionary:
	return ReleasedIds.freeze(_hero(), "2026-11-16")


func test_freeze_lists_every_kind_of_id_sorted() -> void:
	# Arrange / Act
	var file: Dictionary = _released()
	var ids: Dictionary = file["ids"]
	# Assert
	assert_int(file["schema_version"]).is_equal(1)
	assert_str(file["released_at"]).is_equal("2026-11-16")
	assert_array(ids["chapters"]).is_equal(["m_g"])
	assert_array(ids["scenes"]).is_equal(["s1", "s2"])
	assert_array(ids["outcomes"]).is_equal(["o_s1", "o_s2"])
	assert_array(ids["transitions"]).is_equal(["t_s1", "t_s2"])
	assert_array(ids["endings"]).is_equal(["e1"])
	assert_array(ids["starts"]).is_equal(["m_g/st_main"])
	assert_bool(ids["flags"].has("f_a")).is_true()


func test_diff_of_a_hero_against_its_own_freeze_is_empty() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = ReleasedIds.diff(_hero(), _released())
	# Assert
	assert_array(issues).is_empty()


func test_diff_reports_each_missing_id_as_bs26() -> void:
	# Arrange
	var file: Dictionary = _released()
	file["ids"]["scenes"].append("s9")
	file["ids"]["outcomes"].append("o_gone")
	file["ids"]["transitions"].append("t_gone")
	file["ids"]["endings"].append("e_gone")
	file["ids"]["chapters"].append("m_gone")
	file["ids"]["starts"].append("m_g/st_gone")
	file["ids"]["flags"].append("f_gone")
	# Act
	var issues: Array[DataIssue] = ReleasedIds.diff(_hero(), file)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-26", DataIssue.ERROR)).is_equal(7)


func test_diff_ignores_ids_that_are_new() -> void:
	# Arrange
	var file: Dictionary = _released()
	file["ids"]["scenes"].erase("s2")
	# Act / Assert
	assert_array(ReleasedIds.diff(_hero(), file)).is_empty()


func test_diff_scene_marked_deprecated_stays_present_and_passes() -> void:
	# Arrange
	var hero: HeroData = _hero()
	hero.chapters[0].scenes[1].deprecated = true
	# Act / Assert
	assert_array(ReleasedIds.diff(hero, _released())).is_empty()


func test_diff_of_a_file_without_ids_is_dt03() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = ReleasedIds.diff(_hero(), {"schema_version": 1, "released_at": "2026-11-16"})
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-03")).is_equal(1)


func test_diff_of_another_schema_version_is_dt07() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = ReleasedIds.diff(_hero(), {"schema_version": 2, "released_at": "x", "ids": {}})
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-07")).is_equal(1)
