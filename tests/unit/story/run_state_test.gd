extends GdUnitTestSuite
## Unit tests for RunState (ADR-0001 §6, story S3; run-state.md, Core Rules 1-4, 10,
## AC-06..AC-09, AC-11, AC-13..AC-19, AC-22 status part). Errors during play go to an
## injected logger. Snapshot and restore (AC-23, AC-24, AC-30, AC-31) belong to the save story.

var _logs: Array[String] = []


func _decl(id: String, category: String = "story", scope: String = "run", group: String = "") -> FlagDecl:
	var decl: FlagDecl = FlagDecl.new()
	decl.id = id
	decl.category = category
	decl.title = "Название " + id
	decl.scope = scope
	decl.group = group
	return decl


func _state(decls: Array[FlagDecl]) -> RunState:
	_logs.clear()
	var sink: Callable = func(message: String) -> void: _logs.append(message)
	return RunState.new(decls, sink)


func _apply_set(state: RunState, ids: Array[String], outcome: String = "o1", scene: String = "s1") -> bool:
	return state.apply_outcome(scene, outcome, PackedStringArray(ids), PackedStringArray())


func _apply_clear(state: RunState, ids: Array[String], outcome: String = "o1", scene: String = "s1") -> bool:
	return state.apply_outcome(scene, outcome, PackedStringArray(), PackedStringArray(ids))


func _ids(flags: Array[FlagDecl]) -> Array[String]:
	var ids: Array[String] = []
	for decl: FlagDecl in flags:
		ids.append(decl.id)
	return ids


func _journal_lines(state: RunState) -> Array[String]:
	var lines: Array[String] = []
	for entry: RunState.Entry in state.journal():
		lines.append("%s %s" % [entry.flag, "set" if entry.action == RunState.Entry.Action.SET else "cleared"])
	return lines


func _groups() -> Array[FlagDecl]:
	return [_decl("a", "story", "run", "g"), _decl("b", "story", "run", "g"), _decl("c", "story", "run", "g"), _decl("d")]


func test_new_state_has_no_flags_and_no_journal() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Assert
	assert_bool(state.has_flag("a")).is_false()
	assert_array(state.active_flags()).is_empty()
	assert_array(state.journal()).is_empty()
	assert_bool(state.is_finished()).is_false()


func test_apply_outcome_sets_flags_and_lists_them_with_titles() -> void:
	# Arrange
	var state: RunState = _state([_decl("wound_a", "wound"), _decl("wound_b", "wound"), _decl("item_x", "item")])
	# Act
	_apply_set(state, ["wound_a", "wound_b"])
	# Assert
	assert_bool(state.has_flag("wound_a")).is_true()
	assert_bool(state.has_flag("wound_b")).is_true()
	assert_bool(state.has_flag("item_x")).is_false()
	assert_array(_ids(state.active_flags())).is_equal(["wound_a", "wound_b"] as Array[String])
	assert_array(_ids(state.active_in_category("wound"))).is_equal(["wound_a", "wound_b"] as Array[String])
	assert_str(state.active_flags()[0].title).is_equal("Название wound_a")


func test_condition_truth_table_matches_run_state_ac07() -> void:
	# Arrange
	var cases: Array[Array] = [[false, false], [false, true], [true, false], [true, true]]
	var expected: Array[Array] = [[false, false, false, false], [false, false, true, true], [true, false, true, true], [false, true, true, true]]
	for i: int in cases.size():
		var state: RunState = _state([_decl("f_a"), _decl("f_b")])
		var ids: Array[String] = []
		if cases[i][0]:
			ids.append("f_a")
		if cases[i][1]:
			ids.append("f_b")
		_apply_set(state, ids)
		# Act
		var got: Array[bool] = []
		for text: String in ["f_a and not f_b", "f_a and f_b", "f_b or f_a", "any(f_a, f_b)"]:
			got.append(ConditionParser.parse(text, null).condition.evaluate(state))
		# Assert
		assert_array(got).is_equal(expected[i])


func test_flag_in_group_answers_none_then_standing_flag() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Assert
	assert_str(state.flag_in_group("g")).is_empty()
	_apply_set(state, ["a"])
	assert_str(state.flag_in_group("g")).is_equal("a")


func test_any_in_category_follows_active_flags() -> void:
	# Arrange
	var state: RunState = _state([_decl("w", "wound"), _decl("i", "item")])
	# Act
	_apply_set(state, ["w"])
	# Assert
	assert_bool(state.any_in_category("wound")).is_true()
	assert_bool(state.any_in_category("item")).is_false()


func test_visible_flags_return_only_active_visible_ones() -> void:
	# Arrange
	var shown: FlagDecl = _decl("v")
	shown.visible = true
	var state: RunState = _state([shown, _decl("h")])
	# Act
	_apply_set(state, ["v", "h"])
	# Assert
	assert_array(_ids(state.visible_flags())).is_equal(["v"] as Array[String])


func test_setting_a_standing_flag_again_changes_nothing_and_logs_nothing() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	_apply_set(state, ["d"])
	# Act
	var applied: bool = _apply_set(state, ["d"], "o2")
	# Assert
	assert_bool(applied).is_true()
	assert_array(_journal_lines(state)).is_equal(["d set"] as Array[String])
	assert_array(_logs).is_empty()


func test_clearing_a_flag_that_is_not_set_changes_nothing_and_logs_nothing() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Act
	var applied: bool = _apply_clear(state, ["d"])
	# Assert
	assert_bool(applied).is_true()
	assert_array(state.journal()).is_empty()
	assert_array(_logs).is_empty()


func test_set_clear_set_writes_three_journal_entries() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Act
	_apply_set(state, ["d"], "o1")
	_apply_clear(state, ["d"], "o2")
	_apply_set(state, ["d"], "o3")
	# Assert
	assert_bool(state.has_flag("d")).is_true()
	assert_array(_journal_lines(state)).is_equal(["d set", "d cleared", "d set"] as Array[String])


func test_setting_a_group_flag_clears_the_standing_one_first() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	_apply_set(state, ["a", "d"])
	# Act
	_apply_set(state, ["b"])
	# Assert
	assert_bool(state.has_flag("a")).is_false()
	assert_bool(state.has_flag("b")).is_true()
	assert_bool(state.has_flag("d")).is_true()
	var lines: Array[String] = _journal_lines(state)
	assert_array(lines.slice(-2)).is_equal(["a cleared", "b set"] as Array[String])


func test_two_flags_of_one_group_in_one_outcome_leave_the_last() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Act
	_apply_set(state, ["a", "b"])
	# Assert
	assert_bool(state.has_flag("a")).is_false()
	assert_bool(state.has_flag("b")).is_true()
	assert_array(_journal_lines(state)).is_equal(["a set", "a cleared", "b set"] as Array[String])


func test_one_outcome_that_sets_and_clears_a_flag_leaves_it_cleared() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	# Act
	state.apply_outcome("s1", "o1", PackedStringArray(["d"]), PackedStringArray(["d"]))
	# Assert
	assert_bool(state.has_flag("d")).is_false()


func test_end_chapter_clears_only_chapter_scope_flags() -> void:
	# Arrange
	var state: RunState = _state([_decl("r"), _decl("c", "story", "chapter"), _decl("n")])
	_apply_set(state, ["r", "c", "n"])
	# Act
	var applied: bool = state.end_chapter()
	# Assert
	assert_bool(applied).is_true()
	assert_bool(state.has_flag("c")).is_false()
	assert_bool(state.has_flag("r")).is_true()
	assert_bool(state.has_flag("n")).is_true()
	var last: RunState.Entry = state.journal()[-1]
	assert_str(last.flag).is_equal("c")
	assert_str(last.outcome).is_equal(RunState.CHAPTER_END_OUTCOME)


func test_end_chapter_twice_writes_one_clear_per_flag() -> void:
	# Arrange
	var state: RunState = _state([_decl("c", "story", "chapter")])
	_apply_set(state, ["c"])
	# Act
	state.end_chapter()
	state.end_chapter()
	# Assert
	assert_array(_journal_lines(state)).is_equal(["c set", "c cleared"] as Array[String])


func test_journal_entry_names_flag_action_scene_and_outcome() -> void:
	# Arrange
	var state: RunState = _state([_decl("a"), _decl("b")])
	# Act
	_apply_set(state, ["a"], "o1", "s1")
	_apply_set(state, ["b"], "o2", "s2")
	_apply_clear(state, ["a"], "o3", "s3")
	# Assert
	var entries: Array[RunState.Entry] = state.journal()
	assert_int(entries.size()).is_equal(3)
	assert_str(entries[1].flag).is_equal("b")
	assert_str(entries[1].scene).is_equal("s2")
	assert_str(entries[1].outcome).is_equal("o2")
	assert_int(entries[2].action).is_equal(RunState.Entry.Action.CLEARED)
	assert_str(entries[2].outcome).is_equal("o3")


func test_changing_a_returned_list_does_not_change_the_state() -> void:
	# Arrange
	var state: RunState = _state([_decl("a")])
	_apply_set(state, ["a"])
	# Act
	state.active_flags().clear()
	state.journal().clear()
	# Assert
	assert_bool(state.has_flag("a")).is_true()
	assert_int(state.journal().size()).is_equal(1)


func test_queries_do_not_change_flags_or_journal() -> void:
	# Arrange
	var state: RunState = _state(_groups())
	_apply_set(state, ["a"])
	# Act
	state.has_flag("a")
	state.any_in_category("story")
	state.flag_in_group("g")
	state.active_flags()
	state.visible_flags()
	state.blocked_stats()
	# Assert
	assert_array(_journal_lines(state)).is_equal(["a set"] as Array[String])
	assert_array(_ids(state.active_flags())).is_equal(["a"] as Array[String])


func test_outcome_with_an_undeclared_flag_skips_it_and_logs_its_id() -> void:
	# Arrange
	var state: RunState = _state([_decl("y")])
	# Act
	var applied: bool = _apply_set(state, ["x", "y"])
	# Assert
	assert_bool(applied).is_true()
	assert_bool(state.has_flag("y")).is_true()
	assert_int(_logs.size()).is_equal(1)
	assert_str(_logs[0]).contains("x")


func test_condition_over_an_undeclared_flag_is_false_and_logs_its_id() -> void:
	# Arrange
	var state: RunState = _state([_decl("y")])
	# Act
	var holds: bool = ConditionParser.parse("x", null).condition.evaluate(state)
	# Assert
	assert_bool(holds).is_false()
	assert_int(_logs.size()).is_equal(1)
	assert_str(_logs[0]).contains("x")


func test_blocked_stats_list_stats_closed_by_active_flags() -> void:
	# Arrange
	var hinder: FlagDecl = _decl("hinder", "wound", "run")
	hinder.visible = true
	hinder.blocks = PackedStringArray(["strength", "faith"])
	var other: FlagDecl = _decl("other", "wound", "run")
	other.blocks = PackedStringArray(["strength"])
	var state: RunState = _state([hinder, other])
	# Assert
	assert_array(Array(state.blocked_stats())).is_empty()
	_apply_set(state, ["hinder", "other"])
	assert_array(Array(state.blocked_stats())).is_equal(["strength", "faith"])
	_apply_clear(state, ["hinder", "other"])
	assert_array(Array(state.blocked_stats())).is_empty()


func test_finish_freezes_the_state_but_keeps_queries() -> void:
	# Arrange
	var state: RunState = _state([_decl("r"), _decl("c", "story", "chapter"), _decl("n")])
	_apply_set(state, ["r", "c"])
	# Act
	var finished: bool = state.finish()
	var applied: bool = _apply_set(state, ["n"])
	var ended: bool = state.end_chapter()
	# Assert
	assert_bool(finished).is_true()
	assert_bool(state.is_finished()).is_true()
	assert_bool(applied).is_false()
	assert_bool(ended).is_false()
	assert_bool(state.has_flag("c")).is_true()
	assert_bool(state.has_flag("n")).is_false()
	assert_array(_journal_lines(state)).is_equal(["r set", "c set"] as Array[String])
	assert_int(_logs.size()).is_equal(2)


func test_finish_twice_is_refused_and_logged() -> void:
	# Arrange
	var state: RunState = _state([])
	state.finish()
	# Act
	var again: bool = state.finish()
	# Assert
	assert_bool(again).is_false()
	assert_int(_logs.size()).is_equal(1)
