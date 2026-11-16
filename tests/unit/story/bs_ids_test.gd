extends GdUnitTestSuite
## Unit tests for BS-19…BS-23 and BS-25 (branching-story.md, AC-19…AC-23, AC-25), through DataValidator.
## BS-20 and BS-23 run on catalogs the test passes in: the real catalog and character registry do not exist (O-18).


func _flags() -> Array:
	return MeaningFixtures.flags()


func _validate(chapters: Array, options: ValidatorOptions = null) -> Array[DataIssue]:
	var used: ValidatorOptions = options if options != null else ValidatorOptions.new()
	return DataValidator.validate(MeaningFixtures.hero_of(chapters, _flags()), used)


func _count(issues: Array[DataIssue], code: String, severity: String = "") -> int:
	return GraphFixtures.count(issues, code, severity)


# A chapter of the goal pair: the first sets nothing, may name a goal_fail_flag; the next reads it in a start.
func _first() -> Dictionary:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"], "m_one")
	data["goal_fail_flag"] = "f_fail"
	GraphFixtures.find(data["outcomes"], "o_s1")["sets"] = ["f_fail"]
	return data


func _next() -> Dictionary:
	var data: Dictionary = MeaningFixtures.chain(["t1", "t2"], "m_two")
	data["starts"] = [{"id": "st_fail", "if": "f_fail", "scene": "t1"}, {"id": "st_main", "scene": "t1"}]
	return data


# --- BS-19 ---

func test_bs19_valid_goal_pair_has_no_findings() -> void:
	# Arrange / Act / Assert
	assert_int(_count(_validate([_first(), _next()]), "BS-19")).is_equal(0)


func test_bs19_flag_of_another_category_is_an_error() -> void:
	# Arrange
	var flags: Array = _flags()
	flags[8]["category"] = "item"
	var hero: HeroData = MeaningFixtures.hero_of([_first(), _next()], flags)
	# Act / Assert
	assert_int(_count(DataValidator.validate(hero, ValidatorOptions.new()), "BS-19", DataIssue.ERROR)).is_equal(1)


func test_bs19_flag_of_scope_chapter_is_an_error() -> void:
	# Arrange
	var flags: Array = _flags()
	flags[8]["scope"] = "chapter"
	var hero: HeroData = MeaningFixtures.hero_of([_first(), _next()], flags)
	# Act / Assert
	assert_int(_count(DataValidator.validate(hero, ValidatorOptions.new()), "BS-19", DataIssue.ERROR)).is_greater_equal(1)


func test_bs19_flag_in_a_displacement_group_is_an_error() -> void:
	# Arrange
	var flags: Array = _flags()
	flags[8]["group"] = "mood"
	var hero: HeroData = MeaningFixtures.hero_of([_first(), _next()], flags)
	# Act / Assert
	assert_int(_count(DataValidator.validate(hero, ValidatorOptions.new()), "BS-19", DataIssue.ERROR)).is_equal(1)


func test_bs19_outcome_that_clears_the_flag_is_an_error() -> void:
	# Arrange
	var first: Dictionary = _first()
	GraphFixtures.find(first["outcomes"], "o_s2")["clears"] = ["f_fail"]
	# Act / Assert
	assert_int(_count(_validate([first, _next()]), "BS-19", DataIssue.ERROR)).is_equal(1)


func test_bs19_next_chapter_without_a_start_for_the_failure_is_an_error() -> void:
	# Arrange
	var next: Dictionary = _next()
	next["starts"] = [{"id": "st_main", "scene": "t1"}]
	# Act / Assert
	assert_int(_count(_validate([_first(), next]), "BS-19", DataIssue.ERROR)).is_equal(1)


func test_bs19_last_chapter_needs_no_start_of_the_next() -> void:
	# Arrange / Act / Assert
	assert_int(_count(_validate([_first()]), "BS-19")).is_equal(0)


# --- BS-20 ---

func test_bs20_illustration_outside_the_catalog_is_an_error() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.frames = PackedStringArray(["ill_s1"])
	# Act
	var issues: Array[DataIssue] = _validate([MeaningFixtures.chain(["s1", "s2"])], options)
	# Assert
	assert_int(_count(issues, "BS-20", DataIssue.ERROR)).is_equal(1)


func test_bs20_speaker_and_damage_target_outside_the_registry_are_errors() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.characters = PackedStringArray(["troll"])
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s1")["paragraphs"] = [{"text": "Реплика.", "speaks": "ghost"}]
	GraphFixtures.find(data["outcomes"], "o_s1")["paragraphs"] = [{"text": "Удар.", "damage": "troll"}, {"text": "Ещё.", "damage": "nobody"}]
	# Act
	var issues: Array[DataIssue] = _validate([data], options)
	# Assert
	assert_int(_count(issues, "BS-20", DataIssue.ERROR)).is_equal(2)


func test_bs20_without_a_catalog_makes_no_findings() -> void:
	# Arrange / Act
	var issues: Array[DataIssue] = _validate([MeaningFixtures.chain(["s1", "s2"])])
	# Assert
	assert_int(_count(issues, "BS-20")).is_equal(0)


# --- BS-21 ---

func test_bs21_one_frame_in_two_scenes_in_a_row_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s2")["illustration"] = "ill_s1"
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-21", DataIssue.WARNING)).is_equal(1)


func test_bs21_one_frame_in_two_nodes_of_a_chapter_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2", "s3"])
	for id: String in ["s1", "s3"]:
		GraphFixtures.find(data["scenes"], id)["node"] = true
		GraphFixtures.find(data["scenes"], id)["illustration"] = "ill_same"
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-21", DataIssue.WARNING)).is_equal(1)


func test_bs21_different_frames_pass() -> void:
	# Arrange / Act / Assert
	assert_int(_count(_validate([MeaningFixtures.chain(["s1", "s2", "s3"])]), "BS-21")).is_equal(0)


# --- BS-22 ---

func test_bs22_final_scene_of_a_chapter_that_is_not_last_without_a_frame_is_an_error() -> void:
	# Arrange
	var first: Dictionary = MeaningFixtures.chain(["s1", "s2"], "m_one")
	GraphFixtures.find(first["scenes"], "s2")["final"] = true
	GraphFixtures.find(first["scenes"], "s2")["illustration"] = ""
	# Act
	var issues: Array[DataIssue] = _validate([first, MeaningFixtures.chain(["t1", "t2"], "m_two")])
	# Assert
	assert_int(_count(issues, "BS-22", DataIssue.ERROR)).is_equal(1)


func test_bs22_final_scene_of_the_last_chapter_may_have_no_frame() -> void:
	# Arrange
	var only: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(only["scenes"], "s2")["final"] = true
	GraphFixtures.find(only["scenes"], "s2")["illustration"] = ""
	# Act / Assert
	assert_int(_count(_validate([only]), "BS-22")).is_equal(0)


# --- BS-23 ---

func test_bs23_ending_without_a_frame_is_an_error() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.ending_frames = {"e1": "frame_e1"}
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_ending("t_s2", "e2")
	# Act / Assert
	assert_int(_count(_validate([data], options), "BS-23", DataIssue.ERROR)).is_equal(1)


func test_bs23_ending_frame_used_by_a_scene_is_an_error() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.ending_frames = {"e1": "ill_s1"}
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_ending("t_s2", "e1")
	# Act / Assert
	assert_int(_count(_validate([data], options), "BS-23", DataIssue.ERROR)).is_equal(1)


func test_bs23_two_endings_with_one_frame_are_an_error() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.ending_frames = {"e1": "frame_x", "e2": "frame_x"}
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_ending("t_s2", "e1")
	# Act / Assert
	assert_int(_count(_validate([data], options), "BS-23", DataIssue.ERROR)).is_equal(1)


# --- BS-25 ---

func _points() -> Dictionary:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2", "s3"])
	for id: String in ["s1", "s2", "s3"]:
		GraphFixtures.find(data["scenes"], id)["title"] = "Заголовок " + id
	GraphFixtures.find(data["scenes"], "s2")["node"] = true
	return data


func test_bs25_distinct_titles_pass_even_with_one_frame() -> void:
	# Arrange
	var data: Dictionary = _points()
	GraphFixtures.find(data["scenes"], "s2")["illustration"] = "ill_s1"
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-25")).is_equal(0)


func test_bs25_empty_title_of_a_point_warns() -> void:
	# Arrange
	var data: Dictionary = _points()
	GraphFixtures.find(data["scenes"], "s2")["title"] = ""
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-25", DataIssue.WARNING)).is_equal(1)


func test_bs25_equal_titles_of_two_points_warn() -> void:
	# Arrange
	var data: Dictionary = _points()
	GraphFixtures.find(data["scenes"], "s2")["title"] = "Заголовок s1"
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-25", DataIssue.WARNING)).is_equal(1)


func test_bs25_is_an_error_when_the_switch_says_so() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.bs25_is_error = true
	var data: Dictionary = _points()
	GraphFixtures.find(data["scenes"], "s2")["title"] = ""
	# Act / Assert
	assert_int(_count(_validate([data], options), "BS-25", DataIssue.ERROR)).is_equal(1)


func test_bs25_scene_that_is_not_a_point_is_not_checked() -> void:
	# Arrange
	var data: Dictionary = _points()
	GraphFixtures.find(data["scenes"], "s3")["title"] = ""
	# Act / Assert
	assert_int(_count(_validate([data]), "BS-25")).is_equal(0)
