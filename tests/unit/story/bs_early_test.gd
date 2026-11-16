extends GdUnitTestSuite
## Unit tests for BS-16, early endings (branching-story.md, Core Rules 11, Edge Cases; AC-16).
## Only the structure is checked: the frequency of F5 and the MVP ban (AC-32, AC-63) are not part of story S5.
## Baseline: s2 is a plain check (first of the hero); s3 is a fatal scene (conditional risky option, failure is early).


func _baseline() -> Dictionary:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2", "s3", "s4"])
	_risky(data, "s2", "t_s2", "t_s2")
	_risky(data, "s3", "t_s3", "t_early")
	GraphFixtures.find(data["scenes"], "s3")["options"][0]["if"] = "f_a"
	data["transitions"].append({"id": "t_early", "to": "ending:e_dead", "early": true})
	return data


# The scene gets a risky option (success route, failure route) and a safe one that leads on as the success does.
func _risky(data: Dictionary, scene_id: String, success_transition: String, failure_transition: String) -> void:
	var scene: Dictionary = GraphFixtures.find(data["scenes"], scene_id)
	var id: String = "o_" + scene_id
	scene["options"] = [GraphFixtures.risky(scene_id + "_r", id + "_w", id + "_f"), GraphFixtures.safe(scene_id + "_s", id)]
	var safe_outcome: Dictionary = GraphFixtures.find(data["outcomes"], id)
	data["outcomes"].append(GraphFixtures.outcome(id + "_w", [success_transition]))
	data["outcomes"].append(GraphFixtures.outcome(id + "_f", [failure_transition]))
	safe_outcome["routes"] = [{"transition": "t_" + scene_id}]


func _errors(data: Dictionary) -> int:
	return GraphFixtures.count(DataValidator.validate(MeaningFixtures.hero_of([data], MeaningFixtures.flags()), ValidatorOptions.new()), "BS-16", DataIssue.ERROR)


func test_baseline_early_structure_has_no_findings() -> void:
	# Arrange / Act / Assert
	assert_int(_errors(_baseline())).is_equal(0)


func test_early_ending_on_success_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	GraphFixtures.find(data["outcomes"], "o_s3_w")["routes"] = [{"transition": "t_early"}]
	# Act / Assert
	assert_int(_errors(data)).is_equal(1)


func test_early_ending_in_an_entry_scene_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	_risky(data, "s1", "t_s1", "t_early")
	GraphFixtures.find(data["scenes"], "s1")["options"][0]["if"] = "f_a"
	# Act / Assert
	assert_int(_errors(data)).is_greater_equal(1)


func test_early_ending_on_the_first_check_of_the_hero_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	GraphFixtures.find(data["outcomes"], "o_s2_f")["routes"] = [{"transition": "t_early"}]
	GraphFixtures.find(data["scenes"], "s2")["options"][0]["if"] = "f_a"
	# Act / Assert
	assert_int(_errors(data)).is_equal(1)


func test_second_early_ending_in_a_chapter_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	data["transitions"].append({"id": "t_early2", "to": "ending:e_dead2", "early": true})
	_risky(data, "s4", "t_s4", "t_early2")
	GraphFixtures.find(data["scenes"], "s4")["options"][0]["if"] = "f_a"
	# Act / Assert
	assert_int(_errors(data)).is_greater_equal(1)


func test_early_ending_out_of_the_final_node_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	var last: Dictionary = GraphFixtures.find(data["scenes"], "s4")
	last["final"] = true
	_risky(data, "s4", "t_s4", "t_early")
	last["options"][0]["if"] = "f_a"
	data["transitions"].erase(GraphFixtures.find(data["transitions"], "t_early2"))
	# Act / Assert
	assert_int(_errors(data)).is_greater_equal(1)


func test_fatal_option_without_a_condition_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	GraphFixtures.find(data["scenes"], "s3")["options"][0].erase("if")
	# Act / Assert
	assert_int(_errors(data)).is_equal(1)


func test_fatal_condition_that_reads_a_flag_set_in_the_same_scene_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _baseline()
	GraphFixtures.find(data["outcomes"], "o_s3")["sets"] = ["f_a"]
	# Act / Assert
	assert_int(_errors(data)).is_equal(1)
