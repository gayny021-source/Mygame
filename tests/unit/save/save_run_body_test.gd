extends GdUnitTestSuite
## Unit tests for RunBody through slot bytes (save-system.md, rule 2; ADR-0002 §3, §5 B1, B4;
## story SV1): AC-04 and AC-05 without the writer, AC-61 on the body.

const PATH := "save/run_rovend_a"


func _decoded(body: Dictionary) -> Dictionary:
	var read: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 14, body), 0, SaveFixtures.APP_VERSION, SaveFixtures.HERO)
	assert_int(read.status).is_equal(SaveCodec.SlotRead.Status.VALID)
	return read.body


func _load(raw: Dictionary, issues: Array[DataIssue], decls: Array[FlagDecl] = SaveFixtures.decls()) -> RunBody:
	return RunBody.from_dict(raw, PATH, issues, decls, SaveFixtures.HERO)


func _codes(issues: Array[DataIssue]) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in issues:
		codes.append(issue.code)
	return codes


func test_ac05_body_with_every_field_through_a_slot_is_equal() -> void:
	# Arrange
	var written: Dictionary = SaveFixtures.raw_body()
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(_decoded(written), issues)
	# Assert
	assert_array(issues).is_empty()
	assert_dict(SaveFixtures.raw_of(loaded)).is_equal(written)
	assert_int(loaded.schema.size()).is_equal(3)
	assert_str(loaded.resume.position.transition).is_equal("t_cross")
	assert_bool(loaded.resume.state.has_flag("leg_wound")).is_true()


func test_ac04_roll_has_no_state_and_reads_back_equal() -> void:
	# Arrange
	var raw: Dictionary = _decoded(SaveFixtures.raw_body())
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(raw, issues)
	# Assert
	assert_bool(raw["roll"].has("state")).is_false()
	assert_array(raw["roll"].keys()).contains_exactly_in_any_order(Array(RollRecord.KEYS))
	assert_dict(loaded.roll.to_dict()).is_equal(SaveFixtures.roll().to_dict())


func test_ac61_body_has_no_gen_and_v1_keys_only() -> void:
	# Act
	var raw: Dictionary = SaveFixtures.raw_body()
	# Assert: no gen (AC-61), no status/start/milestone_max (B4)
	assert_array(raw.keys()).contains_exactly_in_any_order(Array(RunBody.KEYS))


func test_body_without_roll_has_no_roll_key() -> void:
	# Arrange
	var body: RunBody = SaveFixtures.body()
	body.roll = null
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(_decoded(SaveFixtures.raw_of(body)), issues)
	# Assert
	assert_bool(SaveFixtures.raw_of(body).has("roll")).is_false()
	assert_array(issues).is_empty()
	assert_object(loaded.roll).is_null()


func test_snapshot_in_the_body_is_a_copy() -> void:
	# Arrange
	var body: RunBody = SaveFixtures.body()
	var raw: Dictionary = SaveFixtures.raw_of(body)
	var before: Dictionary = raw.duplicate(true)
	# Act
	body.resume.state.end_chapter()
	# Assert
	assert_dict(raw).is_equal(before)


func test_undeclared_flag_is_dropped_from_every_snapshot() -> void:
	# Arrange: torch stands in the resume and in two schema snapshots (run-state.md, AC-24)
	var decls: Array[FlagDecl] = SaveFixtures.decls()
	decls.remove_at(1)
	var logs: Array[String] = []
	var sink: Callable = func(message: String) -> void: logs.append(message)
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = RunBody.from_dict(_decoded(SaveFixtures.raw_body()), PATH, issues, decls, SaveFixtures.HERO, sink)
	# Assert: «once» is once per load, not per snapshot (TD C2)
	assert_array(issues).is_empty()
	assert_bool(loaded.resume.state.has_flag("leg_wound")).is_true()
	for snapshot: RunBody.Snapshot in loaded.schema:
		assert_array(snapshot.state.to_dict()["flags"]).not_contains(["torch"])
	assert_int(logs.size()).is_equal(1)


func test_broken_body_is_a_finding_and_null() -> void:
	var cases: Dictionary[String, Callable] = {
		"roll state (B1)": func(raw: Dictionary) -> void: raw["roll"]["state"] = "1234",
		"gen (AC-61)": func(raw: Dictionary) -> void: raw["gen"] = 14,
		"chapter_map": func(raw: Dictionary) -> void: raw["chapter_map"] = {},
		"no resume": func(raw: Dictionary) -> void: raw.erase("resume"),
		"schema not a list": func(raw: Dictionary) -> void: raw["schema"] = {},
		"schema element not an object": func(raw: Dictionary) -> void: raw["schema"][1] = "s_bridge",
		"snapshot without position": func(raw: Dictionary) -> void: raw["schema"][0].erase("position"),
		"bad scene id": func(raw: Dictionary) -> void: raw["resume"]["position"]["scene"] = "Bridge",
		"bad hero id": func(raw: Dictionary) -> void: raw["hero"] = "Rovend",
		"empty run_id": func(raw: Dictionary) -> void: raw["run_id"] = "",
	}
	var expected: Dictionary[String, String] = {
		"roll state (B1)": "DT-04", "gen (AC-61)": "DT-04", "chapter_map": "DT-04", "no resume": "DT-03",
		"schema not a list": "DT-02", "schema element not an object": "DT-02",
		"snapshot without position": "DT-03", "bad scene id": "DT-06", "bad hero id": "DT-06",
		"empty run_id": "DT-02",
	}
	for name: String in cases:
		# Arrange
		var raw: Dictionary = _decoded(SaveFixtures.raw_body())
		cases[name].call(raw)
		var issues: Array[DataIssue] = []
		# Act
		var loaded: RunBody = _load(raw, issues)
		# Assert
		assert_object(loaded).override_failure_message(name).is_null()
		assert_array(_codes(issues)).override_failure_message(name).contains_exactly([expected[name]])


func test_hero_other_than_the_file_name_is_a_refusal() -> void:
	# Arrange: the slot was decoded for another hero (TD C4; Э-14)
	var raw: Dictionary = _decoded(SaveFixtures.raw_body())
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = RunBody.from_dict(raw, PATH, issues, SaveFixtures.decls(), "other")
	# Assert
	assert_object(loaded).is_null()
	assert_array(_codes(issues)).contains_exactly(["DT-05"])


func test_unknown_key_in_a_valid_slot_is_a_refusal_without_fallback() -> void:
	# Arrange: same format_version, the sum is right, an unknown key (TD C5; rule 8, item 6)
	var raw: Dictionary = SaveFixtures.raw_body()
	raw["mood"] = "calm"
	var older: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 14, SaveFixtures.raw_body()), 0, SaveFixtures.APP_VERSION, SaveFixtures.HERO)
	var newer: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 15, raw), 1, SaveFixtures.APP_VERSION, SaveFixtures.HERO)
	var issues: Array[DataIssue] = []
	# Act
	var pick: SaveCodec.Pick = SaveCodec.pick(older, newer)
	var loaded: RunBody = _load(newer.body, issues)
	# Assert: the slot is chosen, its body is refused; the older generation is not offered
	assert_int(pick.code).is_equal(SaveCodec.Pick.Code.OK)
	assert_int(pick.slot).is_equal(1)
	assert_object(loaded).is_null()
	assert_array(_codes(issues)).contains_exactly(["DT-04"])


func test_null_parts_from_json_are_findings_not_crashes() -> void:
	var cases: Dictionary[String, Callable] = {
		"resume null": func(raw: Dictionary) -> void: raw["resume"] = null,
		"schema null": func(raw: Dictionary) -> void: raw["schema"] = null,
		"schema element null": func(raw: Dictionary) -> void: raw["schema"][0] = null,
		"state null": func(raw: Dictionary) -> void: raw["resume"]["state"] = null,
		"roll null": func(raw: Dictionary) -> void: raw["roll"] = null,
	}
	for name: String in cases:
		# Arrange
		var raw: Dictionary = _decoded(SaveFixtures.raw_body())
		cases[name].call(raw)
		var issues: Array[DataIssue] = []
		# Act
		var loaded: RunBody = _load(raw, issues)
		# Assert
		assert_object(loaded).override_failure_message(name).is_null()
		assert_array(_codes(issues)).override_failure_message(name).contains_exactly(["DT-02"])


func test_body_without_resume_or_with_a_null_snapshot_gives_a_finding_and_null() -> void:
	# Arrange (TD G3): a body built in code with a hole
	var no_resume: RunBody = SaveFixtures.body()
	no_resume.resume = null
	var null_snapshot: RunBody = SaveFixtures.body()
	null_snapshot.schema[1] = null
	var cases: Dictionary[String, RunBody] = {"DT-03": no_resume, "DT-02": null_snapshot}
	for code: String in cases:
		var issues: Array[DataIssue] = []
		# Act
		var raw: Variant = cases[code].to_dict(issues)
		# Assert
		assert_object(raw).override_failure_message(code).is_null()
		assert_array(_codes(issues)).override_failure_message(code).contains_exactly([code])


func test_group_conflict_in_two_snapshots_is_logged_once_per_load() -> void:
	# Arrange (TD round 2): bold and calm stand together in the resume and in the last schema snapshot
	var raw: Dictionary = _decoded(SaveFixtures.raw_body())
	raw["resume"]["state"]["flags"].append("stance_bold")
	raw["schema"][2]["state"]["flags"].append("stance_calm")
	var logs: Array[String] = []
	var sink: Callable = func(message: String) -> void: logs.append(message)
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = RunBody.from_dict(raw, PATH, issues, SaveFixtures.decls(), SaveFixtures.HERO, sink)
	# Assert: each state keeps one flag of the group, one log line for the load
	assert_array(issues).is_empty()
	assert_str(loaded.resume.state.flag_in_group("stance")).is_equal("stance_calm")
	assert_str(loaded.schema[2].state.flag_in_group("stance")).is_equal("stance_bold")
	assert_int(logs.size()).is_equal(1)
