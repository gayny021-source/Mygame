extends GdUnitTestSuite
## Unit tests for RunState.to_dict and from_dict (run-state.md, rule 11, AC-23, AC-30; save-system.md,
## rule 2; ADR-0002 §3, §5 B3; story SV1): a snapshot is a copy, restore assigns the flags and the
## journal without replaying outcomes, an undeclared flag is a finding.

const PATH := "save/resume/state"

var _logs: Array[String] = []


func _sink() -> Callable:
	_logs.clear()
	return func(message: String) -> void: _logs.append(message)


func _through_json(raw: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(raw))


func _restore(raw: Dictionary, issues: Array[DataIssue], decls: Array[FlagDecl] = SaveFixtures.decls()) -> RunState:
	return RunState.from_dict(raw, PATH, issues, decls, _sink())


func _codes(issues: Array[DataIssue]) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in issues:
		codes.append(issue.code)
	return codes


func _ids(flags: Array[FlagDecl]) -> Array[String]:
	var ids: Array[String] = []
	for decl: FlagDecl in flags:
		ids.append(decl.id)
	return ids


func test_round_trip_through_json_is_equal_and_journal_not_doubled() -> void:
	# Arrange: the chapter end adds a journal record without a scene
	var state: RunState = SaveFixtures.state()
	state.end_chapter()
	var raw: Dictionary = state.to_dict()
	var issues: Array[DataIssue] = []
	# Act
	var restored: RunState = _restore(_through_json(raw), issues)
	# Assert
	assert_array(issues).is_empty()
	assert_dict(restored.to_dict()).is_equal(raw)
	assert_array(_ids(restored.active_flags())).contains_exactly(["leg_wound", "stance_calm"])
	assert_int(restored.journal().size()).is_equal(state.journal().size())
	assert_array(_logs).is_empty()


func test_snapshot_has_flags_and_journal_only() -> void:
	# Act
	var raw: Dictionary = SaveFixtures.state().to_dict()
	# Assert
	assert_array(raw.keys()).contains_exactly_in_any_order(Array(RunState.KEYS))
	assert_array(raw["flags"]).contains_exactly(["leg_wound", "torch", "stance_calm"])
	assert_dict(raw["journal"][3]).is_equal({"flag": "stance_bold", "action": "cleared", "scene": "s_bridge", "outcome": "o_breathe"})


func test_snapshot_is_a_copy() -> void:
	# Arrange
	var state: RunState = SaveFixtures.state(1)
	var raw: Dictionary = state.to_dict()
	var before: Dictionary = raw.duplicate(true)
	# Act: changes after the snapshot, of the state and of a state restored from it
	state.apply_outcome("s_ford", "o_slip", PackedStringArray(["stance_bold"]), PackedStringArray(["leg_wound"]))
	state.end_chapter()
	var issues: Array[DataIssue] = []
	_restore(raw, issues).apply_outcome("s_ford", "o_slip", PackedStringArray(["stance_calm"]), PackedStringArray())
	# Assert
	assert_dict(raw).is_equal(before)


func test_restored_state_keeps_chapter_scope_and_groups() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var restored: RunState = _restore(_through_json(SaveFixtures.state().to_dict()), issues)
	# Act
	restored.end_chapter()
	restored.apply_outcome("s_ford", "o_shout", PackedStringArray(["stance_bold"]), PackedStringArray())
	# Assert
	assert_bool(restored.has_flag("torch")).is_false()
	assert_bool(restored.has_flag("leg_wound")).is_true()
	assert_str(restored.flag_in_group("stance")).is_equal("stance_bold")
	assert_int(restored.journal().size()).is_equal(SaveFixtures.state().journal().size() + 3)


func test_same_outcome_after_restore_equals_run_without_snapshot() -> void:
	# Arrange (run-state.md, AC-30)
	var issues: Array[DataIssue] = []
	var restored: RunState = _restore(_through_json(SaveFixtures.state(2).to_dict()), issues)
	var straight: RunState = SaveFixtures.state(2)
	# Act
	restored.apply_outcome("s_bridge", "o_breathe", PackedStringArray(["stance_calm"]), PackedStringArray(["leg_wound"]))
	straight.apply_outcome("s_bridge", "o_breathe", PackedStringArray(["stance_calm"]), PackedStringArray(["leg_wound"]))
	# Assert
	assert_dict(restored.to_dict()).is_equal(straight.to_dict())


func test_undeclared_flag_is_bs01_and_null() -> void:
	# Arrange: torch stands and is in the journal, the hero's data no longer declare it (ADR-0002 B3)
	var decls: Array[FlagDecl] = SaveFixtures.decls()
	decls.remove_at(1)
	var issues: Array[DataIssue] = []
	# Act
	var restored: RunState = _restore(SaveFixtures.state().to_dict(), issues, decls)
	# Assert
	assert_object(restored).is_null()
	assert_array(_codes(issues)).contains_exactly(["BS-01", "BS-01"])
	assert_str(issues[0].path).is_equal(PATH + "/flags/1")
	assert_str(issues[0].message).contains("torch")


func test_deprecated_flag_is_restored() -> void:
	# Arrange (run-state.md, AC-24, K3)
	var decls: Array[FlagDecl] = SaveFixtures.decls()
	decls[0].deprecated = true
	var issues: Array[DataIssue] = []
	# Act
	var restored: RunState = _restore(SaveFixtures.state().to_dict(), issues, decls)
	# Assert
	assert_array(issues).is_empty()
	assert_bool(restored.has_flag("leg_wound")).is_true()


func test_broken_snapshot_is_a_finding_and_null() -> void:
	var cases: Dictionary[String, Callable] = {
		"DT-04": func(raw: Dictionary) -> void: raw["status"] = "running",
		"DT-03": func(raw: Dictionary) -> void: raw.erase("journal"),
		"DT-02": func(raw: Dictionary) -> void: raw["flags"] = ["torch", 7],
		"DT-05": func(raw: Dictionary) -> void: raw["journal"][0]["action"] = "toggled",
		"DT-04 ": func(raw: Dictionary) -> void: raw["journal"][0]["gen"] = 14,
	}
	for code: String in cases:
		# Arrange
		var raw: Dictionary = _through_json(SaveFixtures.state().to_dict())
		cases[code].call(raw)
		var issues: Array[DataIssue] = []
		# Act
		var restored: RunState = _restore(raw, issues)
		# Assert
		assert_object(restored).override_failure_message(code).is_null()
		assert_array(_codes(issues)).override_failure_message(code).contains_exactly([code.strip_edges()])
