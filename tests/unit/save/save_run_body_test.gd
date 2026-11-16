extends GdUnitTestSuite
## Unit tests for RunBody through slot bytes (save-system.md, rule 2; ADR-0002 §3, §5 B1, B4;
## story SV1): AC-04 and AC-05 without the writer, AC-61 on the body.

const PATH := "save/run_rovend_a"


func _decoded(body: Dictionary) -> Dictionary:
	var read: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 14, body), 0, SaveFixtures.APP_VERSION, SaveFixtures.HERO)
	assert_int(read.status).is_equal(SaveCodec.SlotRead.Status.VALID)
	return read.body


func _load(raw: Dictionary, issues: Array[DataIssue], decls: Array[FlagDecl] = SaveFixtures.decls()) -> RunBody:
	return RunBody.from_dict(raw, PATH, issues, decls)


func _codes(issues: Array[DataIssue]) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in issues:
		codes.append(issue.code)
	return codes


func test_ac05_body_with_every_field_through_a_slot_is_equal() -> void:
	# Arrange
	var written: Dictionary = SaveFixtures.body().to_dict()
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(_decoded(written), issues)
	# Assert
	assert_array(issues).is_empty()
	assert_dict(loaded.to_dict()).is_equal(written)
	assert_int(loaded.schema.size()).is_equal(3)
	assert_str(loaded.resume.position.transition).is_equal("t_cross")
	assert_bool(loaded.resume.state.has_flag("leg_wound")).is_true()


func test_ac04_roll_has_no_state_and_reads_back_equal() -> void:
	# Arrange
	var raw: Dictionary = _decoded(SaveFixtures.body().to_dict())
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(raw, issues)
	# Assert
	assert_bool(raw["roll"].has("state")).is_false()
	assert_array(raw["roll"].keys()).contains_exactly_in_any_order(Array(RollRecord.KEYS))
	assert_dict(loaded.roll.to_dict()).is_equal(SaveFixtures.roll().to_dict())


func test_ac61_body_has_no_gen_and_v1_keys_only() -> void:
	# Act
	var raw: Dictionary = SaveFixtures.body().to_dict()
	# Assert: no gen (AC-61), no status/start/milestone_max (B4)
	assert_array(raw.keys()).contains_exactly_in_any_order(Array(RunBody.KEYS))


func test_body_without_roll_has_no_roll_key() -> void:
	# Arrange
	var body: RunBody = SaveFixtures.body()
	body.roll = null
	var issues: Array[DataIssue] = []
	# Act
	var loaded: RunBody = _load(_decoded(body.to_dict()), issues)
	# Assert
	assert_bool(body.to_dict().has("roll")).is_false()
	assert_array(issues).is_empty()
	assert_object(loaded.roll).is_null()


func test_snapshot_in_the_body_is_a_copy() -> void:
	# Arrange
	var body: RunBody = SaveFixtures.body()
	var raw: Dictionary = body.to_dict()
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
	var loaded: RunBody = RunBody.from_dict(_decoded(SaveFixtures.body().to_dict()), PATH, issues, decls, sink)
	# Assert: one line per restored state that held it
	assert_array(issues).is_empty()
	assert_bool(loaded.resume.state.has_flag("leg_wound")).is_true()
	for snapshot: RunBody.Snapshot in loaded.schema:
		assert_array(snapshot.state.to_dict()["flags"]).not_contains(["torch"])
	assert_int(logs.size()).is_equal(3)


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
		var raw: Dictionary = _decoded(SaveFixtures.body().to_dict())
		cases[name].call(raw)
		var issues: Array[DataIssue] = []
		# Act
		var loaded: RunBody = _load(raw, issues)
		# Assert
		assert_object(loaded).override_failure_message(name).is_null()
		assert_array(_codes(issues)).override_failure_message(name).contains_exactly([expected[name]])
