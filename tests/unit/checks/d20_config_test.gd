extends GdUnitTestSuite
## Unit tests for D20Config: the levels from assets/data/config/d20.json and formula 3 (d20-checks.md,
## formulas 2-3, Edge Cases «конфиг уровней»; AC-08; story S7, TD round 1: B1, C3, C4, G1), and the
## CLI tools/validate_data.gd reading it. The values live only in the file: no defaults in code.

const Cli := preload("res://tools/validate_data.gd")
const BROKEN := "res://tests/fixtures/checks/d20_hard_16.json"


# The project config with `values` written over it.
func _config(values: Dictionary, issues: Array[DataIssue]) -> D20Config:
	var data: Dictionary = ChapterLoader.read_object(D20Config.PATH, issues)
	data.merge(values, true)
	return D20Config.from_dict(data, "d20", issues)


func _levels(config: D20Config) -> Array[int]:
	var issues: Array[DataIssue] = []
	return [config.dc("easy", issues), config.dc("medium", issues), config.dc("hard", issues)]


func test_real_d20_json_loads_valid_11_13_15() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = D20Config.load_file(D20Config.PATH, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_bool(config.valid).is_true()
	assert_array(_levels(config)).contains_exactly([11, 13, 15])


func test_new_config_is_invalid_until_read() -> void:
	# Arrange / Act / Assert: no balance values in code, so nothing to fall back on (C4, G1)
	assert_bool(D20Config.new().valid).is_false()


func test_medium_14_gives_need_10_and_55() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var patched: D20Config = _config({"dc_medium": 14}, issues)
	var back: D20Config = _config({"dc_medium": 13}, issues)
	var medium_patched: int = patched.dc("medium", issues)
	var medium_back: int = back.dc("medium", issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(D20Check.need(medium_patched, 4)).is_equal(10)
	assert_int(D20Check.chance(medium_patched, 4)).is_equal(55)
	assert_int(D20Check.need(medium_back, 4)).is_equal(9)
	assert_int(D20Check.chance(medium_back, 4)).is_equal(60)


func test_levels_valid_examples() -> void:
	# Arrange: [values, violated condition or 0, text of the finding]
	var cases: Array[Array] = [
		[{}, 0, ""],
		[{"dc_hard": 16}, 5, "20 %"],
		[{"dc_easy": 10}, 4, "80 %"],
		[{"dc_medium": 12}, 0, ""],
		[{"dc_medium": 14}, 0, ""],
		[{"dc_easy": 13, "dc_medium": 13}, 1, "13, 13, 15"],
	]
	for case: Array in cases:
		var issues: Array[DataIssue] = []
		# Act
		var config: D20Config = _config(case[0], issues)
		# Assert: a broken level set reports its condition and leaves the config invalid, no fallback
		assert_bool(config.valid).is_equal(case[1] == 0)
		if case[1] == 0:
			assert_array(issues).is_empty()
			continue
		assert_int(issues.size()).is_equal(1)
		assert_str(issues[0].code).is_equal("DT-02")
		assert_str(issues[0].message).contains("условие %d" % case[1])
		assert_str(issues[0].message).contains(case[2])


func test_frozen_stat_bonus_bounds_are_code_constants_not_config() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"stat_bonus_min": -1}, issues)
	# Assert (B1: GDD formula 3, B_min/B_max are frozen product constants)
	assert_int(D20Config.STAT_BONUS_MIN).is_equal(-1)
	assert_int(D20Config.STAT_BONUS_MAX).is_equal(5)
	assert_str(issues[0].code).is_equal("DT-04")
	assert_bool(config.valid).is_false()


func test_negative_value_is_allowed() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"profile_floor_max": -1}, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_bool(config.valid).is_true()


func test_chance_window_outside_0_100_is_dt02() -> void:
	# Arrange: negative levels pass every inequality of formula 3 under a window of ±1000
	var cases: Array[Dictionary] = [
		{"chance_window_low": -1000, "chance_window_high": 1000, "dc_easy": -10, "dc_medium": -8, "dc_hard": -6},
		{"chance_window_low": 75, "chance_window_high": 25},
	]
	for values: Dictionary in cases:
		var issues: Array[DataIssue] = []
		# Act
		var config: D20Config = _config(values, issues)
		# Assert
		assert_bool(config.valid).is_false()
		assert_str(issues[0].code).is_equal("DT-02")
		assert_str(issues[0].message).contains("окно")


func test_unknown_key_is_dt04() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"dc_extreme": 17}, issues)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-04")
	assert_bool(config.valid).is_false()


func test_fraction_is_dt02_and_invalid() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"dc_medium": 13.5}, issues)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-02")
	assert_bool(config.valid).is_false()


func test_missing_key_is_dt03_and_invalid() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var data: Dictionary = ChapterLoader.read_object(D20Config.PATH, issues)
	data.erase("dc_hard")
	# Act
	var config: D20Config = D20Config.from_dict(data, "d20", issues)
	# Assert
	assert_str(issues[0].code).is_equal("DT-03")
	assert_bool(config.valid).is_false()


func test_other_schema_version_keeps_its_code() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"schema_version": 2}, issues)
	# Assert
	assert_bool(config.valid).is_false()
	assert_str(config.issue_code).is_equal("DT-07")


func test_unreadable_file_is_dt01_and_invalid() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = D20Config.load_file("res://tests/fixtures/checks/no_such.json", issues)
	# Assert
	assert_str(issues[0].code).is_equal("DT-01")
	assert_bool(config.valid).is_false()


func test_unknown_level_is_dt02_and_minus_one() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var config: D20Config = CheckFixtures.config()
	# Act
	var dc: int = config.dc("legendary", issues)
	# Assert (C3: no silent Hard)
	assert_int(dc).is_equal(-1)
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-02")


# --- The CLI checks formula 3 (TD S7 (а)) ---

func test_cli_configs_of_the_project_have_no_findings() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	Cli.read_configs(Cli.CONFIG, Cli.D20_CONFIG, issues)
	# Assert
	assert_array(issues).is_empty()


func test_cli_reports_a_d20_config_breaking_formula_3() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	Cli.read_configs(Cli.CONFIG, BROKEN, issues)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-02")
	assert_str(issues[0].path).starts_with(BROKEN)
	assert_str(issues[0].message).contains("условие 5")
