extends GdUnitTestSuite
## Unit tests for duplicate keys written with escapes (JsonLint; TD S5 round 1, C5): the parser unescapes a key,
## so "a" and "a" are one key and the last value wins silently.


func _lint(text: String) -> Array[DataIssue]:
	return JsonLint.check(text.to_utf8_buffer(), "t.json")


func test_unicode_escape_of_a_key_is_a_duplicate() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _lint('{"a": 1, "\\u0061": 2}')
	# Assert
	assert_int(GraphFixtures.count(issues, "DT-01")).is_equal(1)
	assert_str(issues[0].message).contains("«a»")


func test_letter_escape_and_unicode_escape_of_one_key_are_a_duplicate() -> void:
	# Arrange / Act / Assert
	assert_int(_lint('{"a\\n": 1, "a\\u000a": 2}').size()).is_equal(1)


func test_escaped_quote_key_is_a_duplicate() -> void:
	# Arrange / Act / Assert
	assert_int(_lint('{"\\"": 1, "\\u0022": 2}').size()).is_equal(1)


func test_escaped_backslash_differs_from_the_plain_letter() -> void:
	# Arrange / Act / Assert
	assert_array(_lint('{"a\\\\": 1, "a": 2}')).is_empty()
