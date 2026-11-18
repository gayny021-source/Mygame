extends GdUnitTestSuite
## Unit tests for SaveConfig (ADR-0002 §4: T_ожид from assets/data/config/save.json; story SV4).

const PATH := "res://assets/data/config/save.json"


func _raw(wait_ms: Variant = 2000) -> Dictionary:
	return {"schema_version": 1, "wait_ms": wait_ms}


func test_project_file_is_valid_and_gives_2000() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: SaveConfig = SaveConfig.load_file(PATH, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_bool(config.valid).is_true()
	assert_int(config.wait_ms).is_equal(2000)


func test_missing_key_is_dt03_and_falls_back_to_the_default() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: SaveConfig = SaveConfig.from_dict({"schema_version": 1}, "t", issues)
	# Assert
	assert_bool(config.valid).is_false()
	assert_str(issues[0].code).is_equal("DT-03")
	assert_int(config.wait_ms).is_equal(SaveConfig.DEFAULT_WAIT_MS)


func test_unknown_key_is_dt04() -> void:
	var issues: Array[DataIssue] = []
	var raw: Dictionary = _raw()
	raw["extra"] = 1
	var config: SaveConfig = SaveConfig.from_dict(raw, "t", issues)
	assert_bool(config.valid).is_false()
	assert_str(issues[0].code).is_equal("DT-04")


func test_fraction_is_dt02() -> void:
	var issues: Array[DataIssue] = []
	var config: SaveConfig = SaveConfig.from_dict(_raw(1500.5), "t", issues)
	assert_bool(config.valid).is_false()
	assert_str(issues[0].code).is_equal("DT-02")


func test_out_of_range_is_dt02_at_both_ends_and_the_ends_pass() -> void:
	for wait: int in [SaveConfig.WAIT_MIN_MS - 1, SaveConfig.WAIT_MAX_MS + 1]:
		var issues: Array[DataIssue] = []
		var config: SaveConfig = SaveConfig.from_dict(_raw(wait), "t", issues)
		assert_bool(config.valid).is_false()
		assert_str(issues[0].code).is_equal("DT-02")
		assert_int(config.wait_ms).is_equal(SaveConfig.DEFAULT_WAIT_MS)
	for wait: int in [SaveConfig.WAIT_MIN_MS, SaveConfig.WAIT_MAX_MS]:
		var issues: Array[DataIssue] = []
		var config: SaveConfig = SaveConfig.from_dict(_raw(wait), "t", issues)
		assert_bool(config.valid).is_true()
		assert_int(config.wait_ms).is_equal(wait)


func test_missing_file_is_dt01_and_default() -> void:
	var issues: Array[DataIssue] = []
	var config: SaveConfig = SaveConfig.load_file("res://assets/data/config/none.json", issues)
	assert_str(issues[0].code).is_equal("DT-01")
	assert_bool(config.valid).is_false()
	assert_int(config.wait_ms).is_equal(SaveConfig.DEFAULT_WAIT_MS)
