extends GdUnitTestSuite
## Unit tests for GraphValidator and ValidatorOptions (ADR-0001, Key Interfaces; story S4).
## The checks themselves are in bs_structure_test.gd and tests/integration/story/bs_shape_test.gd.


func test_options_defaults_hold_the_gdd_limits() -> void:
	# Arrange / Act
	var options: ValidatorOptions = ValidatorOptions.new()
	# Assert
	assert_int(options.options_max).is_equal(4)
	assert_int(options.finales_base).is_equal(3)
	assert_int(options.finales_past).is_equal(1)
	assert_int(options.s_chapter_min).is_equal(8)
	assert_int(options.s_chapter_max).is_equal(16)
	assert_int(options.n_node_min).is_equal(4)
	assert_int(options.n_node_max).is_equal(7)
	assert_int(options.branch_max).is_equal(2)


func test_validate_collects_findings_of_the_structure_and_the_shape_checks() -> void:
	# Arrange
	var hero: HeroData = GraphFixtures.hero(GraphFixtures.chain(["s1", "s2"]))
	# Act
	var issues: Array[DataIssue] = GraphValidator.validate(hero, ValidatorOptions.new())
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_greater(0)


func test_validate_chapter_with_a_loop_skips_the_shape_check_and_says_so() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_scene("t_s2", "s1")
	var hero: HeroData = GraphFixtures.hero(data)
	# Act
	var issues: Array[DataIssue] = GraphValidator.validate(hero, ValidatorOptions.new())
	# Assert
	assert_int(GraphFixtures.count(issues, "BS-05", DataIssue.ERROR)).is_equal(1)
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.ERROR)).is_equal(0)
	assert_int(GraphFixtures.count(issues, "BS-10", DataIssue.WARNING)).is_greater(0)


func test_validate_hero_without_chapters_returns_no_findings() -> void:
	# Arrange
	var hero: HeroData = HeroData.new()
	# Act
	var issues: Array[DataIssue] = GraphValidator.validate(hero, ValidatorOptions.new())
	# Assert
	assert_array(issues).is_empty()


func test_validate_is_repeatable_on_the_same_hero() -> void:
	# Arrange
	var hero: HeroData = GraphFixtures.hero(GraphFixtures.chain(["s1", "s2"]))
	# Act
	var first: int = GraphValidator.validate(hero, ValidatorOptions.new()).size()
	var second: int = GraphValidator.validate(hero, ValidatorOptions.new()).size()
	# Assert
	assert_int(second).is_equal(first)


func test_graph_fixtures_chain_loads_without_loader_findings() -> void:
	# Arrange / Act
	GraphFixtures.hero(GraphFixtures.chain(["s1", "s2", "s3"]))
	# Assert
	assert_array(GraphFixtures.last_issues).is_empty()
