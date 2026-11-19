extends GdUnitTestSuite
## Attempt context in RunState (chapter-goal.md, rules 5, 12; ADR-0002 §3, B4): `start`, `milestone_max`.

var _decls: Array[FlagDecl] = []


func _from(raw: Dictionary, issues: Array[DataIssue]) -> RunState:
	return RunState.from_dict(raw, "t", issues, _decls)


func test_a_new_state_has_no_context() -> void:
	var state: RunState = RunState.new(_decls)
	assert_str(state.attempt_start()).is_empty()
	assert_int(state.milestone_max()).is_equal(0)


func test_to_dict_carries_both_fields() -> void:
	var state: RunState = RunState.new(_decls)
	state.set_attempt("st_main", 2)
	var raw: Dictionary = state.to_dict()
	assert_str(raw["start"]).is_equal("st_main")
	assert_int(raw["milestone_max"]).is_equal(2)


func test_round_trip_through_json_keeps_the_context() -> void:
	var state: RunState = RunState.new(_decls)
	state.set_attempt("st_fail", 3)
	var parsed: Variant = JSON.parse_string(JSON.stringify(state.to_dict()))
	var issues: Array[DataIssue] = []
	var back: RunState = _from(parsed, issues)
	assert_array(issues).is_empty()
	assert_str(back.attempt_start()).is_equal("st_fail")
	assert_int(back.milestone_max()).is_equal(3)


func test_an_old_slot_without_the_keys_loads_with_an_empty_context() -> void:
	var issues: Array[DataIssue] = []
	var back: RunState = _from({"flags": [], "journal": []}, issues)
	assert_array(issues).is_empty()
	assert_object(back).is_not_null()
	assert_str(back.attempt_start()).is_empty()
	assert_int(back.milestone_max()).is_equal(0)


func test_an_unknown_extra_key_is_refused_dt04() -> void:
	var issues: Array[DataIssue] = []
	var back: RunState = _from({"flags": [], "journal": [], "start": "a", "milestone_max": 1, "status": "x"}, issues)
	assert_object(back).is_null()
	assert_str(issues[0].code).is_equal("DT-04")


func test_a_wrong_type_of_a_field_is_refused() -> void:
	var issues: Array[DataIssue] = []
	var back: RunState = _from({"flags": [], "journal": [], "start": 5, "milestone_max": "2"}, issues)
	assert_object(back).is_null()
	assert_bool(issues.is_empty()).is_false()
