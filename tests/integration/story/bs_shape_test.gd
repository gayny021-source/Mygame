extends GdUnitTestSuite
## Integration tests for BS-10 and for the whole S4 validator on the ch_f1 fixture
## (branching-story.md, AC-10; ADR-0001 plan, story S4). `m_shape` of the GDD is ch_f1
## with one thing broken per test; ch_f1 itself must stay clean. Reads files in tests/fixtures/story.

const NEXT_CHAPTER := "ch_next"
const F1_SCENES := 12
const F1_NODES := 5
const F1_BRANCH := 1


func _hero(data: Dictionary, chapter_ids: Array = []) -> HeroData:
	return GraphFixtures.hero(data, GraphFixtures.f1_flags(), chapter_ids)


func _issues(data: Dictionary, options: ValidatorOptions = null, chapter_ids: Array = []) -> Array[DataIssue]:
	var used: ValidatorOptions = options if options != null else ValidatorOptions.new()
	return GraphValidator.validate(_hero(data, chapter_ids), used)


func _shape_errors(data: Dictionary, chapter_ids: Array = []) -> int:
	return GraphFixtures.count(_issues(data, null, chapter_ids), "BS-10", DataIssue.ERROR)


func _shape_warnings(options: ValidatorOptions) -> int:
	return GraphFixtures.count(_issues(GraphFixtures.f1_chapter(), options), "BS-10", DataIssue.WARNING)


func _drop_option(data: Dictionary, scene_id: String, option_id: String) -> void:
	var options: Array = GraphFixtures.find(data["scenes"], scene_id)["options"]
	for i: int in options.size():
		if options[i]["id"] == option_id:
			options.remove_at(i)
			return


# --- the valid chapter ---

func test_ch_f1_fixture_loads_without_loader_findings() -> void:
	# Arrange / Act
	_hero(GraphFixtures.f1_chapter())
	# Assert
	assert_array(GraphFixtures.last_issues).is_empty()


func test_ch_f1_has_no_findings_of_any_check() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _issues(GraphFixtures.f1_chapter())
	# Assert
	assert_array(issues.map(func(issue: DataIssue) -> String: return "%s %s" % [issue.code, issue.message])).is_empty()


func test_hero_stub_from_files_has_no_findings() -> void:
	# Arrange
	var loaded: LoadResult = HeroLoader.load_hero("hero_stub", StoryFixtures.DIR)
	# Act
	var issues: Array[DataIssue] = GraphValidator.validate(loaded.data as HeroData, ValidatorOptions.new())
	# Assert
	assert_array(loaded.issues).is_empty()
	assert_array(issues).is_empty()


# --- AC-10 (а): one side branch that rejoins the spine ---

func test_bs10_second_side_branch_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.add_branch(data, "o_s07_fail", "b2", "s08")
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_branch_that_does_not_return_to_the_spine_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	data["transitions"].append(GraphFixtures.to_ending("t_b1_end", "end_a"))
	GraphFixtures.find(data["outcomes"], "o_b1_a")["routes"] = [{"transition": "t_b1_end"}]
	GraphFixtures.find(data["outcomes"], "o_b1_b")["routes"] = [{"transition": "t_b1_end"}]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_chapter_without_a_side_branch_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(data["outcomes"], "o_s04_fail")["routes"] = [{"transition": "t_s04_s05"}]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


# --- (б) entry options: one scene each, leading to the first common scene ---

func test_bs10_entry_option_with_two_scenes_before_the_common_one_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	data["scenes"].append(GraphFixtures.scene("e2", [GraphFixtures.normal("e2_go", "o_e2")]))
	data["scenes"].append(GraphFixtures.scene("e2_next", [GraphFixtures.normal("e2n_go", "o_e2n")]))
	data["outcomes"].append(GraphFixtures.outcome("o_e2", ["t_e2_next"]))
	data["outcomes"].append(GraphFixtures.outcome("o_e2n", ["t_e2n_s02"]))
	data["transitions"].append(GraphFixtures.to_scene("t_e2_next", "e2_next"))
	data["transitions"].append(GraphFixtures.to_scene("t_e2n_s02", "s02"))
	data["starts"] = [{"id": "st_alt", "if": "f_past", "scene": "e2"}, {"id": "st_main", "scene": "s01"}]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_two_entry_scenes_leading_to_the_same_common_scene_are_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	data["scenes"].append(GraphFixtures.scene("e2", [GraphFixtures.normal("e2_go", "o_e2")]))
	data["outcomes"].append(GraphFixtures.outcome("o_e2", ["t_e2_s02"]))
	data["transitions"].append(GraphFixtures.to_scene("t_e2_s02", "s02"))
	data["starts"] = [{"id": "st_alt", "if": "f_past", "scene": "e2"}, {"id": "st_main", "scene": "s01"}]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(0)


func test_bs10_chapter_without_starts_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	data["starts"] = []
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_chapter_missing_from_the_hero_chapter_list_is_a_warning() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	# Act
	var issues: Array[DataIssue] = _issues(data, null, ["ch_other"])
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.WARNING)).is_equal(1)
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_equal(0)


# --- (в) exactly one final node ---

func test_bs10_chapter_without_a_final_scene_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(data["scenes"], "s11")["final"] = false
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_chapter_with_two_final_scenes_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(data["scenes"], "s09")["final"] = true
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


# --- (г) nodes sit on the spine ---

func test_bs10_node_scene_on_the_side_branch_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(data["scenes"], "b1")["node"] = true
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


# --- (д) finales: FINALES_BASE open ones and FINALES_PAST past-dependent ---

func test_bs10_two_base_finales_and_one_past_finale_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	_drop_option(data, "s11", "s11_safe")
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_three_base_finales_and_no_past_finale_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	_drop_option(data, "s11", "s11_open")
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_past_finale_reachable_without_a_condition_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(GraphFixtures.find(data["scenes"], "s11")["options"], "s11_open").erase("if")
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_base_finale_reachable_only_through_a_condition_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	var options: Array = GraphFixtures.find(data["scenes"], "s11")["options"]
	for option: Dictionary in options:
		if option["id"] == "s11_safe":
			option["if"] = "f_past"
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_finale_behind_a_conditional_route_counts_as_past() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	_drop_option(data, "s11", "s11_open")
	GraphFixtures.find(data["outcomes"], "o_s11_safe")["routes"] = [{"if": "f_past", "transition": "t_s11_end_d"}, {"transition": "t_s11_end_c"}]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(0)


# --- (е) terminals by the place of the chapter ---

func test_bs10_final_of_a_chapter_that_is_not_last_leading_to_an_ending_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	# Act / Assert
	assert_int(_shape_errors(data, ["ch_f1", NEXT_CHAPTER])).is_equal(1)


func test_bs10_final_of_the_last_chapter_leading_to_chapter_end_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	for transition: Dictionary in data["transitions"]:
		if transition["to"].begins_with("ending:"):
			transition["to"] = "chapter_end"
			transition["coda"] = ["Кода."]
	# Act / Assert
	assert_int(_shape_errors(data)).is_equal(1)


func test_bs10_final_of_a_chapter_that_is_not_last_leading_to_chapter_end_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	for transition: Dictionary in data["transitions"]:
		if transition["to"].begins_with("ending:"):
			transition["to"] = "chapter_end"
			transition["coda"] = ["Кода."]
	# Act / Assert
	assert_int(_shape_errors(data, ["ch_f1", NEXT_CHAPTER])).is_equal(0)


# --- sizes outside F1 are warnings, not errors ---

func test_bs10_chapter_smaller_than_the_limit_is_a_warning() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.s_chapter_min = F1_SCENES + 1
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(1)


func test_bs10_chapter_larger_than_the_limit_is_a_warning() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.s_chapter_max = F1_SCENES - 1
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(1)


func test_bs10_chapter_exactly_on_its_size_limits_is_clean() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.s_chapter_min = F1_SCENES
	options.s_chapter_max = F1_SCENES
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(0)


func test_bs10_fewer_node_scenes_than_the_limit_is_a_warning() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.n_node_min = F1_NODES + 1
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(1)


func test_bs10_more_node_scenes_than_the_limit_is_a_warning() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.n_node_max = F1_NODES - 1
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(1)


func test_bs10_node_count_exactly_on_its_limits_is_clean() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.n_node_min = F1_NODES
	options.n_node_max = F1_NODES
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(0)


func test_bs10_side_branch_larger_than_the_limit_is_a_warning() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.branch_max = F1_BRANCH - 1
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(1)


func test_bs10_side_branch_exactly_on_the_limit_is_clean() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.branch_max = F1_BRANCH
	# Act / Assert
	assert_int(_shape_warnings(options)).is_equal(0)


func test_bs10_size_warnings_leave_the_error_count_at_zero() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.s_chapter_min = F1_SCENES + 1
	# Act
	var issues: Array[DataIssue] = _issues(GraphFixtures.f1_chapter(), options)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_equal(0)


# --- AC-27 (part): a mutation of ch_f1 is caught by the code it breaks ---

func test_mutation_variant_in_ch_f1_is_caught_by_bs02() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(GraphFixtures.find(data["scenes"], "s02")["options"], "s02_risk")["kind"] = "normal"
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-02", DataIssue.ERROR)).is_equal(1)


func test_mutation_loop_in_ch_f1_is_caught_by_bs05() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.find(data["transitions"], "t_s05_s06")["to"] = "scene:s03"
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-05", DataIssue.ERROR)).is_equal(1)


func test_mutation_extra_branch_in_ch_f1_is_caught_by_bs10() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.f1_chapter()
	GraphFixtures.add_branch(data, "o_s07_fail", "b2", "s08")
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_equal(1)
