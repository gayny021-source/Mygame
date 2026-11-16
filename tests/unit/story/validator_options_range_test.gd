extends GdUnitTestSuite
## Unit tests for the range checks of ValidatorOptions.from_dict (TD S5 round 1, C2): a negative limit or a pair
## with low above high is DT-02 and keeps the defaults; zero is a value.


func _options(data: Dictionary, issues: Array[DataIssue]) -> ValidatorOptions:
	var file: Dictionary = {"schema_version": 1}
	file.merge(data)
	return ValidatorOptions.from_dict(file, "t", issues)


func test_zero_limit_is_read_without_findings() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = _options({"options_max": 0}, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(options.options_max).is_equal(0)


func test_negative_limit_is_dt02_and_keeps_the_default() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = _options({"options_max": -1}, issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-02")).is_equal(1)
	assert_int(options.options_max).is_equal(ValidatorOptions.new().options_max)


func test_low_above_high_is_dt02_and_keeps_both_defaults() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var defaults: ValidatorOptions = ValidatorOptions.new()
	# Act
	var options: ValidatorOptions = _options({"path_words_min": 2100, "path_words_max": 2000}, issues)
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-02")).is_equal(1)
	assert_int(options.path_words_min).is_equal(defaults.path_words_min)
	assert_int(options.path_words_max).is_equal(defaults.path_words_max)


func test_low_equal_to_high_passes() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = _options({"k_min": 4, "k_budget": 4}, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(options.k_min).is_equal(4)


func test_path_cap_is_read_from_the_config() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var options: ValidatorOptions = _options({"path_enum_max": 10}, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_int(options.path_enum_max).is_equal(10)
