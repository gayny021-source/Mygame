extends GdUnitTestSuite
## Unit tests for StoryGraph (ADR-0001 §6, story S4): indexes, scene-to-scene edges through
## outcomes and transitions, reachability, back edges. Conditions are never evaluated.


func _graph(data: Dictionary, flag_dicts: Array = []) -> StoryGraph:
	return StoryGraph.new(GraphFixtures.chapter_data(data, flag_dicts))


func test_successors_follow_option_outcome_and_transition_to_the_next_scene() -> void:
	# Arrange
	var graph: StoryGraph = _graph(GraphFixtures.chain(["s1", "s2", "s3"]))
	# Act
	var next: PackedStringArray = graph.successors("s1")
	# Assert
	assert_array(Array(next)).is_equal(["s2"])


func test_successors_of_a_scene_that_ends_the_chapter_are_empty() -> void:
	# Arrange
	var graph: StoryGraph = _graph(GraphFixtures.chain(["s1", "s2"]))
	# Act
	var next: PackedStringArray = graph.successors("s2")
	# Assert
	assert_array(Array(next)).is_empty()


func test_successors_of_a_risky_option_include_both_outcomes() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2", "s3"])
	data["scenes"][0]["options"] = [GraphFixtures.risky("s1_r", "o_s1", "o_fail")]
	data["outcomes"].append(GraphFixtures.outcome("o_fail", ["t_skip"]))
	data["transitions"].append(GraphFixtures.to_scene("t_skip", "s3"))
	var graph: StoryGraph = _graph(data)
	# Act
	var next: PackedStringArray = graph.successors("s1")
	# Assert
	assert_array(Array(next)).contains_exactly(["s2", "s3"])


func test_successors_list_a_shared_target_once() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"][0]["options"].append(GraphFixtures.normal("s1_alt", "o_alt"))
	data["outcomes"].append(GraphFixtures.outcome("o_alt", ["t_s1"]))
	var graph: StoryGraph = _graph(data)
	# Act
	var next: PackedStringArray = graph.successors("s1")
	# Assert
	assert_array(Array(next)).is_equal(["s2"])


func test_entry_scenes_list_each_start_scene_once() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["starts"] = [{"id": "st_a", "if": "f_a", "scene": "s2"}, {"id": "st_b", "if": "f_a", "scene": "s2"}, {"id": "st_main", "scene": "s1"}]
	var graph: StoryGraph = _graph(data, [StoryFixtures.flag("f_a")])
	# Act
	var entries: PackedStringArray = graph.entry_scenes()
	# Assert
	assert_array(Array(entries)).is_equal(["s2", "s1"])


func test_reachable_from_the_start_leaves_out_a_scene_without_incoming_transition() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["scenes"].append(GraphFixtures.scene("s_orphan", [GraphFixtures.normal("orph_go", "o_orph")]))
	data["outcomes"].append(GraphFixtures.outcome("o_orph", ["t_s2"]))
	var graph: StoryGraph = _graph(data)
	# Act
	var seen: PackedStringArray = graph.reachable(graph.entry_scenes())
	# Assert
	assert_array(Array(seen)).contains_exactly(["s1", "s2"])


func test_reachable_with_a_banned_scene_does_not_pass_through_it() -> void:
	# Arrange
	var graph: StoryGraph = _graph(GraphFixtures.chain(["s1", "s2", "s3"]))
	# Act
	var seen: PackedStringArray = graph.reachable(PackedStringArray(["s1"]), "s2")
	# Assert
	assert_array(Array(seen)).is_equal(["s1"])


func test_back_edges_of_a_chain_are_empty() -> void:
	# Arrange
	var graph: StoryGraph = _graph(GraphFixtures.chain(["s1", "s2", "s3"]))
	# Act
	var edges: Array[PackedStringArray] = graph.back_edges()
	# Assert
	assert_array(edges).is_empty()


func test_back_edges_of_a_very_long_chain_are_found_without_recursion_limits() -> void:
	# Arrange
	var ids: Array = []
	for i: int in 2000:
		ids.append("s%d" % i)
	var data: Dictionary = GraphFixtures.chain(ids)
	data["transitions"][1999] = GraphFixtures.to_scene("t_s1999", "s0")
	var graph: StoryGraph = _graph(data)
	# Act
	var edges: Array[PackedStringArray] = graph.back_edges()
	# Assert
	assert_int(edges.size()).is_equal(1)
	assert_array(Array(edges[0])).is_equal(["s1999", "s0"])


func test_back_edges_find_a_two_scene_loop_once() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	data["transitions"][1] = GraphFixtures.to_scene("t_s2", "s1")
	var graph: StoryGraph = _graph(data)
	# Act
	var edges: Array[PackedStringArray] = graph.back_edges()
	# Assert
	assert_int(edges.size()).is_equal(1)
	assert_array(Array(edges[0])).is_equal(["s2", "s1"])


func test_back_edges_find_a_scene_that_leads_into_itself() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1"])
	data["transitions"][0] = GraphFixtures.to_scene("t_s1", "s1")
	var graph: StoryGraph = _graph(data)
	# Act
	var edges: Array[PackedStringArray] = graph.back_edges()
	# Assert
	assert_array(Array(edges[0])).is_equal(["s1", "s1"])
