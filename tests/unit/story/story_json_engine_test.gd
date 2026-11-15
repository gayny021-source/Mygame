extends GdUnitTestSuite
## Pins the Godot 4.7.2 behaviour that ADR-0001 lists as NOT SOURCEABLE (Engine
## Compatibility) and that the story loaders rely on. A red test here means the
## engine changed under the loader, not that the loader is wrong. The probes that
## need a file are in tests/integration/story/story_file_engine_test.gd.

const FOUR_LINES_ERROR_ON_LAST := "{\n  \"a\": 1,\n  \"b\": [1, 2\n  \"c\": 3\n}"
const ZERO_BASED_ERROR_LINE := 3


func test_json_parse_whole_number_arrives_as_float() -> void:
	# Arrange
	var json: JSON = JSON.new()
	# Act
	var error: Error = json.parse("{\"schema_version\": 1, \"bonus\": -1}")
	# Assert
	var data: Dictionary = json.data
	assert_int(error).is_equal(OK)
	assert_int(typeof(data["schema_version"])).is_equal(TYPE_FLOAT)
	assert_int(typeof(data["bonus"])).is_equal(TYPE_FLOAT)


func test_json_parse_duplicate_key_last_value_wins_without_error() -> void:
	# Arrange
	var json: JSON = JSON.new()
	# Act
	var error: Error = json.parse("{\"id\": \"first\", \"id\": \"second\"}")
	# Assert: the loader cannot see the duplicate, hence the text linter of story S5
	var data: Dictionary = json.data
	assert_int(error).is_equal(OK)
	assert_int(data.size()).is_equal(1)
	assert_str(data["id"]).is_equal("second")


func test_json_parse_broken_text_returns_error_and_zero_based_line() -> void:
	# Arrange
	var json: JSON = JSON.new()
	# Act
	var error: Error = json.parse(FOUR_LINES_ERROR_ON_LAST)
	# Assert
	assert_int(error).is_equal(ERR_PARSE_ERROR)
	assert_int(json.get_error_line()).is_equal(ZERO_BASED_ERROR_LINE)
	assert_str(json.get_error_message()).is_not_empty()


func test_json_parse_trailing_comma_is_accepted() -> void:
	# Arrange
	var json: JSON = JSON.new()
	# Act
	var error: Error = json.parse("{\"a\": [1, 2,],}")
	# Assert: Godot is laxer than RFC 8259, so DT-01 does not catch this
	assert_int(error).is_equal(OK)


func test_json_parse_empty_text_returns_error() -> void:
	# Arrange
	var json: JSON = JSON.new()
	# Act
	var error: Error = json.parse("")
	# Assert
	assert_int(error).is_equal(ERR_PARSE_ERROR)


func test_regex_dollar_matches_before_trailing_newline() -> void:
	# Arrange: why DictReader.is_id compares the whole match with the value
	var pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	# Act
	var found: RegExMatch = pattern.search("s1\n")
	# Assert
	assert_object(found).is_not_null()
	assert_str(found.get_string()).is_equal("s1")


func test_typed_array_of_class_stays_typed_when_filled_by_append() -> void:
	# Arrange: why loaders fill Array[T] with append() and never assign a raw Array
	var scene: SceneData = SceneData.new()
	var option: OptionData = OptionData.new()
	var raw: Array = [option]
	# Act
	scene.options.append(option)
	scene.options.append_array(raw)
	# Assert
	assert_int(scene.options.size()).is_equal(2)
	assert_bool(scene.options.is_typed()).is_true()
	assert_bool(raw.is_typed()).is_false()
	assert_bool(scene.options.is_same_typed(raw)).is_false()
