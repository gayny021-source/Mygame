extends GdUnitTestSuite
## Unit tests for BS-02…BS-06 and BS-09 (branching-story.md, AC-02…AC-06, AC-09), through
## GraphValidator. A test on a code looks only at findings with that code (AC preamble).
## Each case is a fresh mini-chapter from GraphFixtures.

const FLAG_A := "f_a"


func _flags() -> Array:
	return [
		StoryFixtures.flag(FLAG_A),
		StoryFixtures.flag("price_a", "price"),
		StoryFixtures.flag("price_b", "price"),
		StoryFixtures.flag("hurt", "wound"),
		{"id": "f_ch", "category": "story", "title": "Глава", "visible": false, "scope": "chapter"},
	]


func _issues(data: Dictionary) -> Array[DataIssue]:
	return GraphValidator.validate(GraphFixtures.hero(data, _flags()), ValidatorOptions.new())


func _errors(data: Dictionary, code: String) -> int:
	return GraphFixtures.count(_issues(data), code, DataIssue.ERROR)


# --- BS-02 ---

func test_bs02_risky_option_without_check_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"][0]["kind"] = "risky"
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_normal_option_with_check_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	var option: Dictionary = GraphFixtures.risky("s1_go", "o_s1", "o_fail")
	option["kind"] = "normal"
	data["scenes"][0]["options"] = [option]
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_normal_option_without_outcome_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"][0].erase("outcome")
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_risky_option_with_an_outcome_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	var option: Dictionary = GraphFixtures.risky("s1_r", "o_s1", "o_fail")
	option["outcome"] = "o_s1"
	data["scenes"][0]["options"] = [option]
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_success_and_failure_on_one_outcome_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_s1", "o_s1")]
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_outcome_named_by_two_options_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_s1"))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_transition_named_by_outcomes_of_two_scenes_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3"])
	data["scenes"][1]["options"] = [GraphFixtures.normal("s2_go", "o_s2")]
	data["outcomes"][1]["routes"] = [{"transition": "t_s1"}]
	data["transitions"][0] = GraphFixtures.to_scene("t_s1", "s3")
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_to_s2"]))
	data["transitions"].append(GraphFixtures.to_scene("t_to_s2", "s2"))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_two_outcomes_of_a_foreign_scene_on_one_transition_are_one_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3"])
	data["transitions"][0] = GraphFixtures.to_scene("t_s1", "s3")
	data["outcomes"][1]["routes"] = [{"transition": "t_s1"}]
	data["scenes"][1]["options"].append(GraphFixtures.normal("s2_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_s1"]))
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_to2", "o_to2"))
	data["outcomes"].append(GraphFixtures.outcome("o_to2", ["t_to2"]))
	data["transitions"].append(GraphFixtures.to_scene("t_to2", "s2"))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(1)


func test_bs02_outcomes_of_one_scene_sharing_a_transition_are_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-02")).is_equal(0)


# --- BS-03 ---

func test_bs03_scene_with_one_risky_option_is_a_dead_end() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_s1", "o_fail")]
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(1)


func test_bs03_only_option_with_a_condition_is_a_dead_end() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"][0]["if"] = FLAG_A
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(1)


func test_bs03_outcome_without_routes_is_a_dead_end() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["outcomes"][0]["routes"] = []
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(1)


func test_bs03_failure_outcome_leading_back_into_the_scene_of_its_check_is_a_dead_end() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_s1", "o_fail"), GraphFixtures.normal("s1_safe", "o_safe")]
	data["outcomes"].append(GraphFixtures.outcome("o_safe", ["t_s1"]))
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_back"]))
	data["transitions"].append(GraphFixtures.to_scene("t_back", "s1"))
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(1)


func test_bs03_open_option_beside_a_risky_one_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_s1", "o_fail"), GraphFixtures.normal("s1_safe", "o_safe")]
	data["outcomes"].append(GraphFixtures.outcome("o_safe", ["t_s1"]))
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(0)


func test_bs03_linear_scene_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	# Act / Assert
	assert_int(_errors(data, "BS-03")).is_equal(0)


# --- BS-04 ---

func test_bs04_unreachable_scene_unused_outcome_and_unused_transition_are_three_errors() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"].append(GraphFixtures.scene("s_orphan", [GraphFixtures.normal("orph_go", "o_orph")]))
	data["outcomes"].append(GraphFixtures.outcome("o_orph", ["t_orph"]))
	data["transitions"].append(GraphFixtures.to_end("t_orph"))
	data["outcomes"].append(GraphFixtures.outcome("o_unused", ["t_s1"]))
	data["transitions"].append(GraphFixtures.to_end("t_unused"))
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-04", DataIssue.ERROR)).is_equal(3)


func test_bs04_second_entry_scene_without_incoming_transition_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3"])
	data["starts"] = [{"id": "st_alt", "if": FLAG_A, "scene": "s2"}, {"id": "st_main", "scene": "s1"}]
	# Act / Assert
	assert_int(_errors(data, "BS-04")).is_equal(0)


func test_bs04_deprecated_scene_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	var orphan: Dictionary = GraphFixtures.scene("s_old", [GraphFixtures.normal("old_go", "o_old")])
	orphan["deprecated"] = true
	data["scenes"].append(orphan)
	data["outcomes"].append(GraphFixtures.outcome("o_old", ["t_s2"]))
	# Act / Assert
	assert_int(_errors(data, "BS-04")).is_equal(0)


func test_bs04_scene_reachable_only_through_a_conditional_route_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3"])
	data["outcomes"][0]["routes"] = [{"if": FLAG_A, "transition": "t_to_s3"}, {"transition": "t_s1"}]
	data["transitions"].append(GraphFixtures.to_scene("t_to_s3", "s3"))
	data["outcomes"][1]["routes"] = [{"transition": "t_s2"}]
	data["transitions"][1] = GraphFixtures.to_end("t_s2")
	# Act / Assert
	assert_int(_errors(data, "BS-04")).is_equal(0)


# --- BS-05 ---

func test_bs05_two_scene_loop_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_scene("t_s2", "s1")
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_scene_leading_into_itself_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1"])
	data["transitions"][0] = GraphFixtures.to_scene("t_s1", "s1")
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_four_scene_loop_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3", "s4"])
	data["transitions"][3] = GraphFixtures.to_scene("t_s4", "s1")
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_last_start_with_a_condition_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["starts"] = [{"id": "st_main", "if": FLAG_A, "scene": "s1"}]
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_last_route_with_a_condition_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["outcomes"][0]["routes"] = [{"if": FLAG_A, "transition": "t_s1"}]
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_start_condition_reading_a_chapter_flag_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["starts"] = [{"id": "st_alt", "if": "f_ch", "scene": "s1"}, {"id": "st_main", "scene": "s1"}]
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(1)


func test_bs05_start_condition_reading_a_run_flag_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["starts"] = [{"id": "st_alt", "if": FLAG_A, "scene": "s1"}, {"id": "st_main", "scene": "s1"}]
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(0)


func test_bs05_chain_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3", "s4"])
	# Act / Assert
	assert_int(_errors(data, "BS-05")).is_equal(0)


# --- BS-06 ---

func test_bs06_scene_without_an_unconditional_paragraph_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["paragraphs"] = [{"text": "Только при флаге.", "if": FLAG_A}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_outcome_without_an_unconditional_paragraph_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_s1"]))
	data["outcomes"][0]["paragraphs"] = [{"text": "Только при флаге.", "if": FLAG_A}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_outcome_of_a_linear_scene_without_paragraphs_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["outcomes"][0]["paragraphs"] = []
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(0)


func test_bs06_bridge_of_two_paragraphs_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0]["bridge"]["base"] = "Первый.\nВторой."
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_transition_into_a_scene_without_a_bridge_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0].erase("bridge")
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_chapter_end_without_a_coda_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][1].erase("coda")
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_choice_scene_with_a_conditional_last_paragraph_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["paragraphs"] = ["Первый.", {"text": "Условный.", "if": FLAG_A}]
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_linear_scene_with_a_conditional_last_paragraph_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["paragraphs"] = ["Первый.", {"text": "Условный.", "if": FLAG_A}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(0)


func test_bs06_conditional_last_coda_paragraph_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][1]["coda"] = ["Кода.", {"text": "Условная.", "if": FLAG_A}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_bridge_with_inserts_but_no_mark_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0]["bridge"]["inserts"] = [{"if": FLAG_A, "text": "Вставка."}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_bridge_with_a_mark_but_no_inserts_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0]["bridge"]["base"] = "Мост {insert}."
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_bridge_with_two_marks_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0]["bridge"]["base"] = "{insert} Мост {insert}."
	data["transitions"][0]["bridge"]["inserts"] = [{"if": FLAG_A, "text": "Вставка."}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


func test_bs06_bridge_with_one_mark_and_one_insert_is_clean() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][0]["bridge"]["base"] = "Мост {insert}."
	data["transitions"][0]["bridge"]["inserts"] = [{"if": FLAG_A, "text": "Вставка."}]
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(0)


func test_bs06_scene_with_more_options_than_the_limit_is_an_error() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	for i: int in 4:
		var outcome_id: String = "o_x%d" % i
		data["scenes"][0]["options"].append(GraphFixtures.normal("s1_x%d" % i, outcome_id))
		data["outcomes"].append(GraphFixtures.outcome(outcome_id, ["t_s1"]))
	# Act / Assert
	assert_int(_errors(data, "BS-06")).is_equal(1)


# --- BS-09 ---

func _risky_scene(safe_option: Dictionary, safe_sets: Array) -> Dictionary:
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_win", "o_fail")]
	data["outcomes"].append(GraphFixtures.outcome("o_win", ["t_s1"]))
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_s1"]))
	if not safe_option.is_empty():
		data["scenes"][0]["options"].append(safe_option)
		data["outcomes"].append(GraphFixtures.outcome("o_safe", ["t_s1"], safe_sets))
	return data


func test_bs09_risky_scene_without_a_safe_option_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _risky_scene({}, [])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(1)


func test_bs09_only_safe_option_with_a_condition_is_an_error() -> void:
	# Arrange
	var option: Dictionary = GraphFixtures.safe("s1_safe", "o_safe")
	option["if"] = FLAG_A
	var data: Dictionary = _risky_scene(option, ["price_a"])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(1)


func test_bs09_safe_option_setting_no_price_flag_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _risky_scene(GraphFixtures.safe("s1_safe", "o_safe"), [])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(1)


func test_bs09_safe_option_setting_two_price_flags_is_an_error() -> void:
	# Arrange
	var data: Dictionary = _risky_scene(GraphFixtures.safe("s1_safe", "o_safe"), ["price_a", "price_b"])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(1)


func test_bs09_safe_option_setting_exactly_one_price_flag_is_clean() -> void:
	# Arrange
	var data: Dictionary = _risky_scene(GraphFixtures.safe("s1_safe", "o_safe"), ["price_a"])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(0)


func test_bs09_flags_of_other_categories_do_not_count_as_price() -> void:
	# Arrange
	var data: Dictionary = _risky_scene(GraphFixtures.safe("s1_safe", "o_safe"), ["price_a", "hurt"])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(0)


func test_bs09_scene_without_a_risky_option_needs_no_safe_one() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	# Act / Assert
	assert_int(_errors(data, "BS-09")).is_equal(0)


# --- findings carry where they are ---

func test_finding_names_the_chapter_path_and_the_object_id() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"][0]["kind"] = "risky"
	# Act
	var found: DataIssue = null
	for issue: DataIssue in _issues(data):
		if issue.code == "BS-02":
			found = issue
	# Assert
	assert_str(found.object_id).is_equal("s1_go")
	assert_str(found.path).contains("m_g")
	assert_str(found.path).contains("s1_go")
	assert_str(found.severity).is_equal(DataIssue.ERROR)
