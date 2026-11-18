extends GdUnitTestSuite
## Unit tests for SaveWriter.load_run (save-system.md, rules 8, 12, 15, F2, Э-31; ADR-0002 §4; story
## SV3): AC-19, AC-26…AC-30, AC-32, AC-38, AC-42, AC-68 (writer level). The slots live in the rig.

const LOAD_OK: int = SaveWriter.LoadCode.OK
const LOAD_EMPTY: int = SaveWriter.LoadCode.EMPTY
const LOAD_CORRUPT: int = SaveWriter.LoadCode.CORRUPT
const LOAD_TOO_NEW: int = SaveWriter.LoadCode.TOO_NEW
const LOAD_READ_ERROR: int = SaveWriter.LoadCode.READ_ERROR
const RUN := WriterRig.RUN
const A: int = WriterRig.A
const B: int = WriterRig.B

var _rig: WriterRig


func before_test() -> void:
	_rig = WriterRig.new()


## Runs one load_run to its end; its code.
func _load() -> int:
	var token: int = _rig.load_run()
	_rig.pump()
	assert_int(_rig.load_results.back().x).is_equal(token)
	return _rig.load_results.back().y


func _body() -> Dictionary:
	return _rig.load_bodies.back()


func _slots() -> Array[PackedByteArray]:
	return [_rig.bytes(RUN, A), _rig.bytes(RUN, B)]


## Cuts slot `slot` in the middle of its body (Э-02).
func _cut(slot: int) -> void:
	var path: String = SaveWriter.path_of(RUN, slot)
	var bytes: PackedByteArray = _rig.files[path]
	var middle: int = SaveFixtures.HEADER_SIZE + (bytes.size() - SaveFixtures.HEADER_SIZE) / 2
	_rig.files[path] = bytes.slice(0, middle)


static func _migrate_v1(body: Dictionary) -> Variant:
	body["v2"] = true
	return body


static func _migrate_fails(_raw: Dictionary) -> Variant:
	return null


func test_ac19_load_waits_for_the_write_in_progress() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.io.hold_write = true
	_rig.commit("t15")
	_rig.pump(3)
	var reads: int = _rig.io.reads
	# Act
	var token: int = _rig.load_run()
	_rig.pump(5)
	var reads_while_held: int = _rig.io.reads - reads
	_rig.io.release()
	_rig.pump()
	# Assert
	assert_int(reads_while_held).is_equal(0)
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_OK)])
	assert_str(_body()["run_id"]).is_equal("t15")


func test_ac26_two_valid_slots_load_the_newest() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.put(RUN, 15, WriterRig.run("r15"))
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r15")
	assert_int(_rig.io.reads).is_equal(1)


func test_ac27_cut_b_loads_a_and_next_write_goes_over_the_cut() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.put(RUN, 15, WriterRig.run("r15"))
	_cut(B)
	# Act
	var code: int = _load()
	_rig.commit("t15")
	_rig.pump()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r14")
	assert_str(_rig.slot_run(RUN, B)).is_equal("t15@15")


func test_ac27_bad_older_a_loads_b_and_next_write_goes_to_a() -> void:
	# Arrange
	_rig.garbage(RUN, A)
	_rig.put(RUN, 15, WriterRig.run("r15"))
	# Act
	var code: int = _load()
	_rig.commit("t16")
	_rig.pump()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r15")
	assert_str(_rig.slot_run(RUN, A)).is_equal("t16@16")


func test_ac28_both_slots_bad_is_corrupt_and_files_stay() -> void:
	# Arrange
	_rig.garbage(RUN, A)
	_rig.put(RUN, 15, WriterRig.run("r15"))
	_cut(B)
	var before: Array[PackedByteArray] = _slots()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_CORRUPT)
	assert_dict(_body()).is_empty()
	assert_bool(_slots() == before).is_true()


func test_ac28_lone_empty_a_is_corrupt() -> void:
	# Arrange
	_rig.files[SaveWriter.path_of(RUN, A)] = PackedByteArray()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_CORRUPT)


func test_ac28_lone_bad_b_is_empty_with_a_log_line() -> void:
	# Arrange
	_rig.put(RUN, 1, WriterRig.run("r1"))
	_cut(B)
	var before: PackedByteArray = _rig.bytes(RUN, B)
	_rig.lines.clear()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_EMPTY)
	assert_int(_rig.lines.size()).is_equal(1)
	assert_str(_rig.lines[0]).contains("EMPTY")
	assert_bool(_rig.bytes(RUN, B) == before).is_true()


func test_ac29_no_files_is_empty() -> void:
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_EMPTY)
	assert_dict(_body()).is_empty()


func test_ac29_one_valid_file_loads_it() -> void:
	# Arrange
	_rig.put(RUN, 1, WriterRig.run("r1"))
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r1")


func test_ac30_newer_version_is_too_new_without_fallback() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.put(RUN, 15, WriterRig.run("r15"), 2)
	var before: Array[PackedByteArray] = _slots()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_TOO_NEW)
	assert_dict(_body()).is_empty()
	assert_bool(_slots() == before).is_true()


func test_ac32_old_version_migrates_in_memory_only() -> void:
	# Arrange
	var migrations: Dictionary[int, Callable] = {1: _migrate_v1}
	_rig.restart(true, WriterRig.WAIT_MS, 2, migrations)
	_rig.put(RUN, 14, WriterRig.run("r14"))
	var a_before: PackedByteArray = _rig.bytes(RUN, A)
	# Act
	var first: int = _load()
	var first_body: Dictionary = _body()
	var second: int = _load()
	_rig.commit("t15")
	_rig.pump()
	# Assert
	assert_array([first, second]).is_equal([LOAD_OK, LOAD_OK])
	assert_bool(first_body["v2"]).is_true()
	assert_dict(_body()).is_equal(first_body)
	assert_int(_rig.bytes(RUN, B).decode_u32(4)).is_equal(2)
	assert_bool(_rig.bytes(RUN, A) == a_before).is_true()


func test_ac32_failed_migration_is_corrupt() -> void:
	# Arrange
	var migrations: Dictionary[int, Callable] = {1: _migrate_fails}
	_rig.restart(true, WriterRig.WAIT_MS, 2, migrations)
	_rig.put(RUN, 14, WriterRig.run("r14"))
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_CORRUPT)
	assert_dict(_body()).is_empty()


func test_ac32_gap_in_the_migration_chain_is_corrupt() -> void:
	# Arrange: v1 → v2 exists, v2 → v3 does not
	var migrations: Dictionary[int, Callable] = {1: _migrate_v1}
	_rig.restart(true, WriterRig.WAIT_MS, 3, migrations)
	_rig.put(RUN, 14, WriterRig.run("r14"))
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_CORRUPT)


## The slots of one AC-38 case; its expected code.
func _arrange_case(index: int) -> int:
	match index:
		0:
			_rig.put(RUN, 14, WriterRig.run("r14"))
			_rig.put(RUN, 15, WriterRig.run("r15"))
			return LOAD_OK
		1:
			_rig.put(RUN, 14, WriterRig.run("r14"))
			_rig.put(RUN, 15, WriterRig.run("r15"))
			_cut(B)
			return LOAD_OK
		2:
			var migrations: Dictionary[int, Callable] = {1: _migrate_v1}
			_rig.restart(true, WriterRig.WAIT_MS, 2, migrations)
			_rig.put(RUN, 14, WriterRig.run("r14"))
			return LOAD_OK
		3:
			return LOAD_EMPTY
		4:
			_rig.garbage(RUN, A)
			_rig.garbage(RUN, B)
			return LOAD_CORRUPT
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.put(RUN, 15, WriterRig.run("r15"), 2)
	return LOAD_TOO_NEW


func test_ac38_ac42_load_writes_nothing_and_repeats_the_same_code() -> void:
	for index: int in 6:
		# Arrange
		_rig = WriterRig.new()
		var expected: int = _arrange_case(index)
		var before: Array[PackedByteArray] = _slots()
		# Act
		var codes: Array[int] = [_load(), _load()]
		# Assert
		assert_array(codes).is_equal([expected, expected])
		assert_int(_rig.io.written.size()).is_equal(0)
		assert_bool(_slots() == before).is_true()


func test_ac68_dropped_flag_loads_ok_and_writes_nothing() -> void:
	# Arrange: torch is no longer declared for rovend
	_rig.put(RUN, 14, SaveFixtures.raw_body())
	var before: Array[PackedByteArray] = _slots()
	var decls: Array[FlagDecl] = SaveFixtures.decls()
	decls.remove_at(1)
	var logs: Array[String] = []
	var sink: Callable = func(message: String) -> void: logs.append(message)
	var issues: Array[DataIssue] = []
	# Act
	var code: int = _load()
	var loaded: RunBody = RunBody.from_dict(_body(), RUN, issues, decls, SaveFixtures.HERO, sink)
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_array(issues).is_empty()
	assert_bool(loaded.resume.state.has_flag("leg_wound")).is_true()
	assert_bool(loaded.resume.state.has_flag("torch")).is_false()
	assert_int(logs.size()).is_equal(1)
	assert_int(_rig.io.written.size()).is_equal(0)
	assert_bool(_slots() == before).is_true()


func test_load_of_an_id_unfit_for_a_path_is_refused() -> void:
	# Act
	var token: int = _rig.load_run("../x")
	_rig.pump()
	# Assert
	assert_int(token).is_equal(0)
	assert_int(_rig.io.reads).is_equal(0)
	assert_array(_rig.load_results).is_empty()
	assert_int(_rig.lines.size()).is_equal(1)


func test_load_after_a_finished_one_gets_a_new_token() -> void:
	# Arrange
	var first: int = _rig.load_run()
	_rig.pump()
	# Act
	var second: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_int(second).is_not_equal(first)
	assert_int(_rig.load_results.size()).is_equal(2)


func test_write_after_a_queued_load_does_not_reach_that_load() -> void:
	# Arrange: t15 runs, t16 waits, the load is queued after t16
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.io.hold_write = true
	_rig.commit("t15")
	_rig.pump(3)
	_rig.commit("t16")
	var token: int = _rig.load_run()
	# Act
	_rig.commit("t17")
	_rig.io.release()
	_rig.pump()
	# Assert
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_OK)])
	assert_str(_body()["run_id"]).is_equal("t16")
	assert_str(_rig.slot_run(RUN, B)).is_equal("t17@17")


func test_load_commit_load_gives_a_second_token_that_sees_the_commit() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	var first: int = _rig.load_run()
	_rig.commit("t15")
	# Act
	var second: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_int(second).is_not_equal(first)
	assert_array(_rig.load_results).is_equal([Vector2i(first, LOAD_OK), Vector2i(second, LOAD_OK)])
	assert_str(_rig.load_bodies[0]["run_id"]).is_equal("r14")
	assert_str(_rig.load_bodies[1]["run_id"]).is_equal("t15")


func test_two_loads_without_a_write_between_share_one_token() -> void:
	# Act
	var first: int = _rig.load_run()
	var second: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_int(second).is_equal(first)
	assert_array(_rig.load_results).is_equal([Vector2i(first, LOAD_EMPTY)])
	assert_int(_rig.io.reads).is_equal(1)


func test_read_error_is_read_error_with_one_line_and_writes_nothing() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.io.fail_reads = 1
	var before: Array[PackedByteArray] = _slots()
	_rig.lines.clear()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_READ_ERROR)
	assert_dict(_body()).is_empty()
	assert_int(_rig.lines.size()).is_equal(1)
	assert_int(_rig.io.written.size()).is_equal(0)
	assert_bool(_slots() == before).is_true()


func test_retry_after_read_error_loads_normally() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.io.fail_reads = 1
	var first: int = _load()
	# Act
	var retry: int = _load()
	# Assert
	assert_array([first, retry]).is_equal([LOAD_READ_ERROR, LOAD_OK])
	assert_str(_body()["run_id"]).is_equal("r14")


func test_unreadable_newer_slot_loads_the_valid_one_with_a_log_line() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.put(RUN, 15, WriterRig.run("r15"))
	_rig.io.fail_read_slot = B
	_rig.lines.clear()
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r14")
	assert_int(_rig.lines.size()).is_equal(1)
	assert_str(_rig.lines[0]).contains("не прочитан")


func test_unreadable_slot_beside_a_bad_one_is_read_error() -> void:
	# Arrange
	_rig.garbage(RUN, A)
	_rig.put(RUN, 15, WriterRig.run("r15"))
	_rig.io.fail_read_slot = B
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_READ_ERROR)
	assert_dict(_body()).is_empty()


func test_unreadable_slot_beside_no_file_is_read_error_not_empty() -> void:
	# Arrange
	_rig.put(RUN, 15, WriterRig.run("r15"))
	_rig.io.fail_read_slot = B
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_READ_ERROR)


func test_short_read_counts_the_missing_slot_as_no_file() -> void:
	# Arrange
	_rig.put(RUN, 14, WriterRig.run("r14"))
	_rig.io.read_slots = 1
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_OK)
	assert_str(_body()["run_id"]).is_equal("r14")


static func _migrate_to_other_hero(body: Dictionary) -> Variant:
	body["hero"] = WriterRig.OTHER
	return body


func test_migration_that_changes_the_hero_is_corrupt() -> void:
	# Arrange
	var migrations: Dictionary[int, Callable] = {1: _migrate_to_other_hero}
	_rig.restart(true, WriterRig.WAIT_MS, 2, migrations)
	_rig.put(RUN, 14, WriterRig.run("r14"))
	# Act
	var code: int = _load()
	# Assert
	assert_int(code).is_equal(LOAD_CORRUPT)
	assert_dict(_body()).is_empty()


func test_invalid_migration_is_refused_at_registration() -> void:
	# Arrange
	var migrations: Dictionary[int, Callable] = {1: Callable()}
	_rig.lines.clear()
	# Act
	_rig.restart(true, WriterRig.WAIT_MS, 2, migrations)
	var refused: int = _rig.lines.size()
	_rig.put(RUN, 14, WriterRig.run("r14"))
	var code: int = _load()
	# Assert
	assert_int(refused).is_equal(1)
	assert_int(code).is_equal(LOAD_CORRUPT)
