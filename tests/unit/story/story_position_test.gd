extends GdUnitTestSuite
## Unit tests for StoryPosition: the resume point {chapter, scene, entry transition, pending outcome}
## (branching-story.md, rule 8; AC-42; story S6).


func _raw() -> Dictionary:
	return {"chapter": "ch_a", "scene": "s1", "transition": "t_in", "pending_outcome": "o1"}


func test_position_round_trip_keeps_all_four_keys() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var position: StoryPosition = StoryPosition.new("ch_a", "s1", "t_in", "o1")
	# Act
	var back: StoryPosition = StoryPosition.from_dict(position.to_dict(), "save", issues)
	# Assert
	assert_array(issues).is_empty()
	assert_dict(back.to_dict()).is_equal(_raw())


func test_position_to_dict_writes_empty_strings_not_null() -> void:
	# Arrange
	var position: StoryPosition = StoryPosition.new("ch_a", "s1")
	# Act
	var raw: Dictionary = position.to_dict()
	# Assert
	assert_dict(raw).is_equal({"chapter": "ch_a", "scene": "s1", "transition": "", "pending_outcome": ""})


func test_position_optional_keys_may_be_absent() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var back: StoryPosition = StoryPosition.from_dict({"chapter": "ch_a", "scene": "s1"}, "save", issues)
	# Assert
	assert_array(issues).is_empty()
	assert_str(back.transition).is_empty()
	assert_str(back.pending_outcome).is_empty()


func test_position_missing_key_is_dt03_and_null() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var raw: Dictionary = _raw()
	raw.erase("scene")
	# Act
	var back: StoryPosition = StoryPosition.from_dict(raw, "save", issues)
	# Assert
	assert_object(back).is_null()
	assert_int(GraphFixtures.count(issues, "DT-03")).is_equal(1)


func test_position_value_of_another_type_is_dt02_and_null() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var raw: Dictionary = _raw()
	raw["pending_outcome"] = 7
	# Act
	var back: StoryPosition = StoryPosition.from_dict(raw, "save", issues)
	# Assert
	assert_object(back).is_null()
	assert_int(GraphFixtures.count(issues, "DT-02")).is_equal(1)


func test_position_unknown_key_is_dt04_and_null() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var raw: Dictionary = _raw()
	raw["roll"] = "x"
	# Act
	var back: StoryPosition = StoryPosition.from_dict(raw, "save", issues)
	# Assert
	assert_object(back).is_null()
	assert_int(GraphFixtures.count(issues, "DT-04")).is_equal(1)


func test_position_scene_that_is_not_an_id_is_dt06_and_null() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var raw: Dictionary = _raw()
	raw["scene"] = "Сцена 1"
	# Act
	var back: StoryPosition = StoryPosition.from_dict(raw, "save", issues)
	# Assert
	assert_object(back).is_null()
	assert_int(GraphFixtures.count(issues, "DT-06")).is_equal(1)
