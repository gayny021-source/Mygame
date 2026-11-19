extends GdUnitTestSuite
## Unit tests for the loading of ValidatorOptions from the external config (ADR-0001, Key Interfaces and
## Implementation Guidelines: limits F1–F8 come from the config, not from code). Story S5.

const CONFIG := "res://assets/data/config/story_limits.json"


func test_from_dict_overrides_only_named_limits() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = ValidatorOptions.from_dict({"schema_version": 1, "options_max": 3, "path_words_max": 2300}, "t", issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(options.options_max).is_equal(3)
	assert_int(options.path_words_max).is_equal(2300)
	assert_int(options.finales_base).is_equal(3)


func test_from_dict_unknown_key_is_dt04() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	ValidatorOptions.from_dict({"schema_version": 1, "options_maxx": 3}, "t", issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-04")).is_equal(1)


func test_from_dict_fraction_is_dt02() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	ValidatorOptions.from_dict({"schema_version": 1, "options_max": 3.5}, "t", issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-02")).is_equal(1)


func test_from_dict_other_schema_version_is_dt07() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	ValidatorOptions.from_dict({"schema_version": 2}, "t", issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-07")).is_equal(1)


func test_from_dict_bs25_switch_is_read() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = ValidatorOptions.from_dict({"schema_version": 1, "bs25_is_error": true}, "t", issues)
	# Assert
	assert_bool(options.bs25_is_error).is_true()


func test_load_file_missing_is_dt01() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	ValidatorOptions.load_file("res://tests/fixtures/story/no_such_config.json", issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-01")).is_equal(1)


func test_project_config_matches_the_gdd_limits() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var loaded: ValidatorOptions = ValidatorOptions.load_file(CONFIG, issues)
	var defaults: ValidatorOptions = ValidatorOptions.new()
	# Assert
	assert_array(issues).is_empty()
	assert_int(loaded.options_max).is_equal(4)
	assert_int(loaded.path_words_min).is_equal(1500)
	assert_int(loaded.path_words_max).is_equal(2000)
	assert_int(loaded.k_budget).is_equal(5)
	assert_int(loaded.s_chapter_max).is_equal(defaults.s_chapter_max)
	assert_int(loaded.paragraph_words_max).is_equal(60)
	assert_int(loaded.stake_max).is_equal(120)


func test_skipped_checks_name_every_check_without_input() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	# Act
	var skipped: PackedStringArray = options.skipped_checks()
	options.frames = PackedStringArray(["f"])
	options.characters = PackedStringArray(["c"])
	options.ending_frames = {"e": "f"}
	# Assert
	assert_int(skipped.size()).is_equal(3)
	assert_array(options.skipped_checks()).is_empty()


func test_from_dict_stake_max_is_read() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = ValidatorOptions.from_dict({"schema_version": 1, "stake_max": 50}, "t", issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(options.stake_max).is_equal(50)
