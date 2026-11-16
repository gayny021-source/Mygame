extends GdUnitTestSuite
## Unit tests for JsonLint (ADR-0001, Decision 4 and the S1 findings: duplicate keys, trailing commas, BOM, not UTF-8).
## The parser of the engine accepts all of them, so only this text pass sees them.


func _lint(text: String) -> Array[DataIssue]:
	return JsonLint.check(text.to_utf8_buffer(), "t.json")


func test_clean_text_has_no_findings() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _lint('{"a": 1, "b": {"a": [1, 2], "c": "x, ]"}}')
	# Assert
	assert_array(issues).is_empty()


func test_duplicate_key_in_one_object_is_reported_with_its_line() -> void:
	# Arrange
	var text: String = '{\n"a": 1,\n"b": 2,\n"a": 3\n}'
	# Act
	var issues: Array[DataIssue] = _lint(text)
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].code).is_equal("DT-01")
	assert_str(issues[0].path).is_equal("t.json:4")
	assert_str(issues[0].message).contains("«a»")


func test_same_key_in_sibling_objects_is_not_a_duplicate() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _lint('[{"a": 1}, {"a": 2}, {"x": {"a": 3}, "a": 4}]')
	# Assert
	assert_array(issues).is_empty()


func test_key_text_inside_a_string_value_is_not_a_key() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _lint('{"a": "\\"a\\": 1", "b": "a"}')
	# Assert
	assert_array(issues).is_empty()


func test_trailing_comma_in_array_and_object_is_reported() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _lint('{"a": [1, 2,],\n"b": 1,\n}')
	# Assert
	assert_int(issues.size()).is_equal(2)
	assert_str(issues[0].path).is_equal("t.json:1")
	assert_str(issues[1].path).is_equal("t.json:3")


func test_bom_is_reported() -> void:
	# Arrange
	var bytes: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array('{"a": 1}'.to_utf8_buffer())
	# Act
	var issues: Array[DataIssue] = JsonLint.check(bytes, "t.json")
	# Assert
	assert_int(issues.size()).is_equal(1)
	assert_str(issues[0].message).contains("BOM")


func test_bytes_that_are_not_utf8_are_reported() -> void:
	# Arrange
	var bytes: PackedByteArray = '{"a": "'.to_utf8_buffer()
	bytes.append_array(PackedByteArray([0xFF, 0xFE]))
	bytes.append_array('"}'.to_utf8_buffer())
	# Act
	var issues: Array[DataIssue] = JsonLint.check(bytes, "t.json")
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-01")).is_greater(0)
	assert_str(issues[0].message).contains("UTF-8")


func test_empty_file_has_no_lint_findings() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = JsonLint.check(PackedByteArray(), "t.json")
	# Assert
	assert_array(issues).is_empty()
