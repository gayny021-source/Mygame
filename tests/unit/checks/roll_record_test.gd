extends GdUnitTestSuite
## Unit tests for RollRecord, the roll record handed to the Save system (d20-checks.md, rule 9; DD-020,
## DD-021; story S7): a round trip through JSON and the findings of a broken record.


func _raw() -> Dictionary:
	var result: D20Result = D20Check.resolve(CheckFixtures.check(), 4, 13, 14, false)
	return RollRecord.of("s_bridge", result).to_dict()


func _read(raw: Dictionary, issues: Array[DataIssue]) -> RollRecord:
	return RollRecord.from_dict(raw, "save/roll", issues)


func test_to_dict_from_dict_round_trip_is_equal() -> void:
	# Arrange: through JSON text, where every number comes back a float
	var raw: Dictionary = _raw()
	raw["applied"] = true
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(raw))
	var issues: Array[DataIssue] = []
	# Act
	var record: RollRecord = _read(parsed, issues)
	# Assert
	assert_array(issues).is_empty()
	assert_dict(record.to_dict()).is_equal(raw)
	assert_dict(raw).contains_keys(Array(RollRecord.KEYS))
	assert_int(raw.size()).is_equal(RollRecord.KEYS.size())


func test_roll_0_or_21_or_fraction_is_dt02_and_null() -> void:
	for face: Variant in [0, 21, 12.5, "14"]:
		# Arrange
		var raw: Dictionary = _raw()
		raw["roll"] = face
		var issues: Array[DataIssue] = []
		# Act
		var record: RollRecord = _read(raw, issues)
		# Assert
		assert_object(record).is_null()
		assert_int(issues.size()).is_equal(1)
		assert_str(issues[0].code).is_equal("DT-02")


func test_unknown_key_dt04() -> void:
	# Arrange
	var raw: Dictionary = _raw()
	raw["rng_state"] = 1
	var issues: Array[DataIssue] = []
	# Act / Assert
	assert_object(_read(raw, issues)).is_null()
	assert_str(issues[0].code).is_equal("DT-04")


func test_bad_id_dt06() -> void:
	# Arrange
	var raw: Dictionary = _raw()
	raw["check_id"] = "Bridge Strength"
	var issues: Array[DataIssue] = []
	# Act / Assert
	assert_object(_read(raw, issues)).is_null()
	assert_str(issues[0].code).is_equal("DT-06")


func test_missing_key_reports_and_null() -> void:
	for key: String in RollRecord.KEYS:
		# Arrange
		var raw: Dictionary = _raw()
		raw.erase(key)
		var issues: Array[DataIssue] = []
		# Act / Assert
		assert_object(_read(raw, issues)).is_null()
		assert_str(issues[0].code).is_equal("DT-03")
