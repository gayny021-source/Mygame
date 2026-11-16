extends GdUnitTestSuite
## Unit tests for the path cap of ChapterPaths and DataValidator (ValidatorOptions.path_enum_max; TD S5 round 1,
## G5 + C1): a chapter whose path count doubles per layer stops the walk and every path check says it did not run.


# Layers of two scenes l<k>a and l<k>b; each scene leads into both scenes of the next layer, the last ends the
# chapter. One start on l0a: 2^(layers - 1) paths.
func _ladder(layers: int) -> Dictionary:
	var scenes: Array = []
	var outcomes: Array = []
	var transitions: Array = []
	for k: int in layers:
		for side: String in ["a", "b"]:
			var id: String = "l%d%s" % [k, side]
			scenes.append(GraphFixtures.scene(id, [GraphFixtures.normal(id + "_x", "o_%s_x" % id), GraphFixtures.normal(id + "_y", "o_%s_y" % id)]))
			for next: String in ["x", "y"]:
				var transition: String = "t_%s_%s" % [id, next]
				outcomes.append(GraphFixtures.outcome("o_%s_%s" % [id, next], [transition]))
				var target: String = "l%d%s" % [k + 1, "a" if next == "x" else "b"]
				transitions.append(GraphFixtures.to_scene(transition, target) if k + 1 < layers else GraphFixtures.to_end(transition))
	return GraphFixtures.chapter(scenes, outcomes, transitions)


func _graph(layers: int) -> StoryGraph:
	return StoryGraph.new(MeaningFixtures.hero_of([_ladder(layers)], MeaningFixtures.flags()).chapters[0])


func test_walk_at_exactly_the_limit_is_complete() -> void:
	# Arrange
	var graph: StoryGraph = _graph(3)
	# Act
	var paths: ChapterPaths = ChapterPaths.new(graph, 4)
	# Assert
	assert_bool(paths.truncated).is_false()
	assert_int(paths.paths.size()).is_equal(4)


func test_walk_one_past_the_limit_stops_and_says_so() -> void:
	# Arrange
	var graph: StoryGraph = _graph(3)
	# Act
	var paths: ChapterPaths = ChapterPaths.new(graph, 3)
	# Assert
	assert_bool(paths.truncated).is_true()
	assert_int(paths.paths.size()).is_equal(3)


func test_thirty_scene_ladder_stops_at_the_config_limit_and_skips_every_path_check() -> void:
	# Arrange
	var hero: HeroData = MeaningFixtures.hero_of([_ladder(15)], MeaningFixtures.flags())
	var options: ValidatorOptions = ValidatorOptions.new()
	# Act
	var issues: Array[DataIssue] = DataValidator.validate(hero, options)
	# Assert
	for code: String in BsBudget.PATH_CODES:
		var skipped: Array[DataIssue] = issues.filter(func(i: DataIssue) -> bool: return i.code == code and i.message.contains("path_enum_max"))
		assert_int(skipped.size()).is_equal(1)
		assert_str(skipped[0].severity).is_equal(DataIssue.WARNING)
