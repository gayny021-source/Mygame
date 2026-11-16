extends GdUnitTestSuite
## Unit tests for D20Config: the levels from the config and formula 3 (d20-checks.md, formulas 2-3; AC-08;
## story S7), and the CLI tools/validate_data.gd reading it.

const Cli := preload("res://tools/validate_data.gd")
const BROKEN := "res://tests/fixtures/checks/d20_hard_16.json"


func _config(values: Dictionary, issues: Array[DataIssue]) -> D20Config:
	var data: Dictionary = {"schema_version": 1}
	data.merge(values)
	return D20Config.from_dict(data, "d20", issues)


func _levels(config: D20Config) -> Array[int]:
	return [config.dc("easy"), config.dc("medium"), config.dc("hard")]


func test_defaults_are_11_13_15() -> void:
	# Arrange / Act / Assert
	assert_array(_levels(D20Config.new())).contains_exactly([11, 13, 15])


func test_real_d20_json_loads_without_issues() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = D20Config.load_file(D20Config.PATH, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_array(_levels(config)).contains_exactly([11, 13, 15])


func test_medium_14_gives_need_10_and_55() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var check: CheckData = CheckFixtures.check("medium")
	# Act
	var patched: D20Check = D20Check.new(_config({"dc_medium": 14}, issues), CountingD20Source.new())
	var back: D20Check = D20Check.new(_config({"dc_medium": 13}, issues), CountingD20Source.new())
	# Assert
	assert_array(issues).is_empty()
	assert_int(D20Check.need(patched.dc_of(check), 4)).is_equal(10)
	assert_int(D20Check.chance(patched.dc_of(check), 4)).is_equal(55)
	assert_int(D20Check.need(back.dc_of(check), 4)).is_equal(9)
	assert_int(D20Check.chance(back.dc_of(check), 4)).is_equal(60)


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
		# Assert: a broken level set reports its condition and falls back to the defaults
		if case[1] == 0:
			assert_array(issues).is_empty()
			continue
		assert_int(issues.size()).is_equal(1)
		assert_str(issues[0].code).is_equal("DT-02")
		assert_str(issues[0].message).contains("условие %d" % case[1])
		assert_str(issues[0].message).contains(case[2])
		assert_array(_levels(config)).contains_exactly([11, 13, 15])


func test_negative_stat_bonus_min_is_allowed() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"stat_bonus_min": -1, "profile_floor_max": 0}, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(config.stat_bonus_min).is_equal(-1)


func test_unknown_key_is_dt04() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	_config({"dc_extreme": 17}, issues)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-04")


func test_fraction_is_dt02() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = _config({"dc_medium": 13.5}, issues)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-02")
	assert_int(config.dc_medium).is_equal(13)


func test_missing_file_is_dt01_with_defaults() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: D20Config = D20Config.load_file("res://tests/fixtures/checks/no_such.json", issues)
	# Assert
	assert_str(issues[0].code).is_equal("DT-01")
	assert_array(_levels(config)).contains_exactly([11, 13, 15])


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
