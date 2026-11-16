extends GdUnitTestSuite
## Unit tests for BS-13, BS-14, BS-15 and BS-18 (branching-story.md, F2, F3, F7; AC-13, AC-14, AC-15, AC-18)
## and for the path walker ChapterPaths. Chains are built by letters: P risky, v/u breath or node, l linear.


func _issues(data: Dictionary, options: ValidatorOptions = null) -> Array[DataIssue]:
	var used: ValidatorOptions = options if options != null else ValidatorOptions.new()
	return DataValidator.validate(MeaningFixtures.hero_of([data], MeaningFixtures.flags()), used)


func _n(data: Dictionary, code: String, options: ValidatorOptions = null) -> int:
	return GraphFixtures.count(_issues(data, options), code, DataIssue.WARNING)


# --- BS-13: rhythm (F7) ---

func test_bs13_f7_example_spine_passes() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvPvlPvuvP"), "BS-13")).is_equal(0)


func test_bs13_two_risky_scenes_in_a_row_warn() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PP"), "BS-13")).is_equal(1)


func test_bs13_a_linear_scene_between_two_risky_scenes_passes() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PlP"), "BS-13")).is_equal(0)


func test_bs13_two_linear_scenes_pass_and_three_warn() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("ll"), "BS-13")).is_equal(0)
	assert_int(_n(MeaningFixtures.shape("lll"), "BS-13")).is_equal(1)


# --- BS-14: budget of checks (F2) ---

func test_bs14_four_risky_choices_on_the_spine_pass() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvPvPvPvv"), "BS-14")).is_equal(0)


func test_bs14_fifth_risky_choice_on_the_spine_warns() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvPvPvPvPv"), "BS-14")).is_equal(1)


func test_bs14_sixth_risky_choice_warns_once() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvPvPvPvPvPv"), "BS-14")).is_equal(1)


func test_bs14_fifth_choice_through_a_branch_without_a_risky_choice_warns_on_both_paths() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.shape("PvPvPvPvPvv")
	GraphFixtures.add_branch(data, "o_s2", "b1", "s3")
	# Act / Assert
	assert_int(_n(data, "BS-14")).is_equal(2)


func test_bs14_branch_that_carries_the_fifth_risky_choice_passes() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.shape("PvPvPvPvvv")
	GraphFixtures.add_branch(data, "o_s2", "b1", "s3")
	var branch: Dictionary = GraphFixtures.find(data["scenes"], "b1")
	branch["options"] = [GraphFixtures.risky("b1_r", "o_b1", "o_b1_f"), GraphFixtures.safe("b1_s", "o_b1_s")]
	for extra: String in ["o_b1_f", "o_b1_s"]:
		data["outcomes"].append(GraphFixtures.outcome(extra, ["t_b1_out"]))
	# Act / Assert
	assert_int(_n(data, "BS-14")).is_equal(0)


func test_bs14_floor_eight_scenes_with_two_checks_warn() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvvPvvvv"), "BS-14")).is_equal(1)


func test_bs14_floor_eight_scenes_with_three_checks_pass() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvvPvvPv"), "BS-14")).is_equal(0)


func test_bs14_floor_seven_scenes_with_two_checks_pass() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("PvvPvvv"), "BS-14")).is_equal(0)


# --- BS-15: short path ---

func test_bs15_seven_scenes_without_an_early_ending_warn() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("vvvvvvv"), "BS-15")).is_equal(1)


func test_bs15_eight_scenes_pass() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.shape("vvvvvvvv"), "BS-15")).is_equal(0)


func test_bs15_seven_scenes_that_end_in_an_early_ending_pass() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.shape("vvvvvvv")
	data["transitions"][-1] = {"id": "t_s7", "to": "ending:e_dead", "early": true}
	# Act / Assert
	assert_int(_n(data, "BS-15")).is_equal(0)


# --- BS-18: words on a path (F3) ---

func test_bs18_path_words_at_the_edges() -> void:
	# Arrange / Act / Assert
	assert_int(_n(MeaningFixtures.chain_of_words(1499), "BS-18")).is_equal(1)
	assert_int(_n(MeaningFixtures.chain_of_words(1500), "BS-18")).is_equal(0)
	assert_int(_n(MeaningFixtures.chain_of_words(2000), "BS-18")).is_equal(0)
	assert_int(_n(MeaningFixtures.chain_of_words(2001), "BS-18")).is_equal(1)


func test_bs18_limits_come_from_the_options() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.path_words_max = 1800
	# Act / Assert
	assert_int(_n(MeaningFixtures.chain_of_words(1900), "BS-18", options)).is_equal(1)


func test_bs18_conditional_paragraph_counts_in_the_worst_case() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain_of_words(1990)
	MeaningFixtures.read_in_scene(data, "s2", "f_a")
	GraphFixtures.find(data["scenes"], "s2")["paragraphs"][0]["text"] = MeaningFixtures.words(20)
	# Act / Assert
	assert_int(_n(data, "BS-18")).is_equal(1)


# --- ChapterPaths ---

func test_paths_of_a_loop_are_not_walked_and_say_so() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_scene("t_s2", "s1")
	var graph: StoryGraph = StoryGraph.new(MeaningFixtures.hero_of([data], MeaningFixtures.flags()).chapters[0])
	# Act
	var paths: ChapterPaths = ChapterPaths.new(graph)
	# Assert
	assert_bool(paths.has_loop).is_true()
	assert_array(paths.paths).is_empty()


func test_paths_count_scenes_words_and_checks_of_the_branch_chapter() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.shape("PvPvv")
	GraphFixtures.add_branch(data, "o_s2", "b1", "s3")
	var graph: StoryGraph = StoryGraph.new(MeaningFixtures.hero_of([data], MeaningFixtures.flags()).chapters[0])
	# Act
	var paths: ChapterPaths = ChapterPaths.new(graph)
	var lengths: Array = paths.paths.map(func(p: ChapterPaths.PathInfo) -> int: return p.scenes.size())
	lengths.sort()
	# Assert
	assert_array(lengths).is_equal([5, 6])
	assert_int(paths.paths[0].risky).is_equal(2)
