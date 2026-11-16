extends GdUnitTestSuite
## Unit tests for BS-07, BS-08, BS-11, BS-12, BS-17 and BS-24 (branching-story.md, AC-07, AC-08, AC-11,
## AC-12, AC-17, AC-24), through DataValidator. A test on a code looks only at findings with that code.


func _issues(data: Dictionary) -> Array[DataIssue]:
	return DataValidator.validate(MeaningFixtures.hero_of([data], MeaningFixtures.flags()), ValidatorOptions.new())


func _n(data: Dictionary, code: String, severity: String) -> int:
	return GraphFixtures.count(_issues(data), code, severity)


func _outcome(data: Dictionary, id: String) -> Dictionary:
	return GraphFixtures.find(data["outcomes"], id)


# --- BS-07 ---

func test_bs07_equal_traces_are_an_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(1)


func test_bs07_empty_trace_is_an_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	_outcome(data, "ob")["routes"] = []
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_greater_equal(1)


func test_bs07_traces_that_differ_only_by_target_pass() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	data["transitions"].append(GraphFixtures.to_end("t_alt"))
	_outcome(data, "ob")["routes"] = [{"transition": "t_alt"}]
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(0)


func test_bs07_traces_that_differ_by_an_unread_flag_are_an_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	_outcome(data, "ob")["sets"] = ["f_b"]
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(1)


func test_bs07_traces_that_differ_by_a_read_flag_pass() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	_outcome(data, "ob")["sets"] = ["f_a"]
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(0)


func test_bs07_exception_on_an_option_lifts_the_error() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(data["scenes"], "s1")["options"][1]["exception"] = "Так задумано."
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(0)


func test_bs07_linear_scene_is_not_checked() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	# Act / Assert
	assert_int(_n(data, "BS-07", DataIssue.ERROR)).is_equal(0)


# --- BS-08 ---

func test_bs08_success_and_failure_with_one_trace_warn() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.risky_fork()
	# Act / Assert
	assert_int(_n(data, "BS-08", DataIssue.WARNING)).is_equal(1)
	assert_int(_n(data, "BS-08", DataIssue.ERROR)).is_equal(0)


func test_bs08_failure_that_sets_a_read_flag_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.risky_fork()
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	_outcome(data, "of")["sets"] = ["f_a"]
	# Act / Assert
	assert_int(_n(data, "BS-08", DataIssue.WARNING)).is_equal(0)


func test_bs08_exception_lifts_the_warning() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.risky_fork()
	GraphFixtures.find(data["scenes"], "s1")["options"][0]["exception"] = "Так задумано."
	# Act / Assert
	assert_int(_n(data, "BS-08", DataIssue.WARNING)).is_equal(0)


# --- BS-11 and BS-12 ---

func test_bs11_flag_read_but_never_set_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	# Act / Assert
	assert_int(_n(data, "BS-11", DataIssue.WARNING)).is_equal(1)


func test_bs11_flag_set_by_an_outcome_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	_outcome(data, "o_s1")["sets"] = ["f_a"]
	# Act / Assert
	assert_int(_n(data, "BS-11", DataIssue.WARNING)).is_equal(0)


func test_bs11_flag_set_in_another_chapter_of_the_hero_passes() -> void:
	# Arrange
	var first: Dictionary = MeaningFixtures.chain(["s1", "s2"], "m_one")
	_outcome(first, "o_s1")["sets"] = ["f_a"]
	var second: Dictionary = MeaningFixtures.chain(["t1", "t2"], "m_two")
	MeaningFixtures.read_in_scene(second, "t2", "f_a")
	# Act
	var issues: Array[DataIssue] = DataValidator.validate(MeaningFixtures.hero_of([first, second], MeaningFixtures.flags()), ValidatorOptions.new())
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-11")).is_equal(0)


func test_bs11_and_bs12_goal_fail_flag_that_nothing_sets() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["goal_fail_flag"] = "f_fail"
	# Act
	var issues: Array[DataIssue] = _issues(data)
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-11", DataIssue.WARNING)).is_equal(1)
	assert_int(GraphFixtures.count(issues, "BS-12", DataIssue.WARNING)).is_equal(1)


func test_bs12_route_below_an_unconditional_route_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_outcome(data, "o_s1")["routes"] = [{"transition": "t_s1"}, {"if": "f_a", "transition": "t_s1"}]
	# Act / Assert
	assert_int(_n(data, "BS-12", DataIssue.WARNING)).is_equal(1)


func test_bs12_two_flags_of_one_group_at_once_warn() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(data["scenes"], "s1")["options"][0]["if"] = "f_g1 and f_g2"
	# Act / Assert
	assert_int(_n(data, "BS-12", DataIssue.WARNING)).is_equal(1)


func test_bs12_flags_of_different_groups_pass() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(data["scenes"], "s1")["options"][0]["if"] = "f_g1 and f_a"
	# Act / Assert
	assert_int(_n(data, "BS-12", DataIssue.WARNING)).is_equal(0)


# --- BS-17 ---

func test_bs17_node_that_reads_nothing_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s2")["node"] = true
	# Act / Assert
	assert_int(_n(data, "BS-17", DataIssue.WARNING)).is_equal(1)


func test_bs17_node_that_reads_in_a_paragraph_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s2")["node"] = true
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	# Act / Assert
	assert_int(_n(data, "BS-17", DataIssue.WARNING)).is_equal(0)


func test_bs17_node_that_reads_only_in_routes_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s2")["node"] = true
	_outcome(data, "o_s2")["routes"] = [{"if": "f_a", "transition": "t_s2"}, {"transition": "t_s2"}]
	# Act / Assert
	assert_int(_n(data, "BS-17", DataIssue.WARNING)).is_equal(1)


func test_bs17_start_node_of_the_first_chapter_is_exempt_but_not_of_the_next() -> void:
	# Arrange
	var first: Dictionary = MeaningFixtures.chain(["s1", "s2"], "m_one")
	GraphFixtures.find(first["scenes"], "s1")["node"] = true
	var second: Dictionary = MeaningFixtures.chain(["t1", "t2"], "m_two")
	GraphFixtures.find(second["scenes"], "t1")["node"] = true
	# Act
	var issues: Array[DataIssue] = DataValidator.validate(MeaningFixtures.hero_of([first, second], MeaningFixtures.flags()), ValidatorOptions.new())
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-17", DataIssue.WARNING)).is_equal(1)
	assert_str(issues.filter(func(i: DataIssue) -> bool: return i.code == "BS-17")[0].object_id).is_equal("t1")


# --- BS-24 ---

func test_bs24_wound_without_damage_in_the_outcome_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_outcome(data, "o_s1")["sets"] = ["hurt"]
	# Act / Assert
	assert_int(_n(data, "BS-24", DataIssue.WARNING)).is_equal(1)


func test_bs24_damage_in_a_paragraph_of_the_outcome_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_outcome(data, "o_s1")["sets"] = ["hurt"]
	_outcome(data, "o_s1")["paragraphs"] = [{"text": "Удар.", "damage": "troll"}]
	# Act / Assert
	assert_int(_n(data, "BS-24", DataIssue.WARNING)).is_equal(0)


func test_bs24_damage_in_another_outcome_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_outcome(data, "o_s1")["sets"] = ["hurt"]
	_outcome(data, "o_s2")["paragraphs"] = [{"text": "Удар.", "damage": "troll"}]
	# Act / Assert
	assert_int(_n(data, "BS-24", DataIssue.WARNING)).is_equal(1)


func test_bs24_other_category_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_outcome(data, "o_s1")["sets"] = ["f_a"]
	# Act / Assert
	assert_int(_n(data, "BS-24", DataIssue.WARNING)).is_equal(0)
