extends GdUnitTestSuite
## Unit tests for SaveWriter generations and slots (save-system.md, rule 5, F1, F2; ADR-0002 §2, §4;
## story SV2): AC-09, AC-10, AC-11, AC-12, AC-35, AC-36, AC-64.

const OK_OUT: int = SaveWriter.Outcome.OK
const ERROR_OUT: int = SaveWriter.Outcome.ERROR

var _rig: WriterRig


func before_test() -> void:
	_rig = WriterRig.new()


func _corrupt(key: String, slot: int) -> void:
	var path: String = SaveWriter.path_of(key, slot)
	var bytes: PackedByteArray = _rig.files[path]
	bytes[bytes.size() - 2] ^= 0xFF
	_rig.files[path] = bytes


func test_gen_valid_a_and_broken_b_next_write_is_15_in_b() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.put(WriterRig.RUN, 15, WriterRig.run("r15"))
	_corrupt(WriterRig.RUN, WriterRig.B)
	assert_str(_rig.loaded_run()).is_equal("r14")
	_rig.commit("r_next")
	_rig.pump()
	assert_array(_rig.io.written).is_equal(["user://run_rovend_b.sav"])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_next@15")


func test_gen_no_valid_slot_next_write_is_1() -> void:
	_rig.garbage(WriterRig.RUN, WriterRig.A)
	_rig.garbage(WriterRig.RUN, WriterRig.B)
	_rig.commit("r_new")
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_new@1")


func test_gen_new_process_over_14_and_15_writes_16_in_a() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.put(WriterRig.RUN, 15, WriterRig.run("r15"))
	_rig.restart()
	_rig.commit("r16")
	_rig.pump()
	assert_int(_rig.io.reads).is_equal(1)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r16@16")


func test_gen_twenty_writes_never_touch_newest_slot() -> void:
	var previous: String = ""
	for i: int in 20:
		var newest: int = _rig.loaded(WriterRig.RUN).slot
		var kept: PackedByteArray = _rig.bytes(WriterRig.RUN, newest)
		_rig.commit("r_%d" % i)
		_rig.pump()
		if newest >= 0:
			assert_array(_rig.bytes(WriterRig.RUN, newest)).is_equal(kept)
		assert_str(_rig.io.written[i]).is_not_equal(previous)
		previous = _rig.io.written[i]
	assert_int(_rig.loaded(WriterRig.RUN).gen_max).is_equal(20)


func test_gen_error_keeps_gen_and_slot() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.io.fail_writes = 1
	var failed: int = _rig.commit("r_fail")
	_rig.pump()
	_rig.commit("r_ok")
	_rig.pump()
	assert_int(_rig.finished[0].x).is_equal(failed)
	assert_int(_rig.finished[0].y).is_equal(ERROR_OUT)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_ok@15")


func test_gen_two_errors_keep_last_valid_slot() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	var kept: PackedByteArray = _rig.bytes(WriterRig.RUN, WriterRig.A)
	_rig.io.fail_writes = 2
	_rig.commit("r_fail_1")
	_rig.pump()
	_rig.commit("r_fail_2")
	_rig.pump()
	assert_array(_rig.io.written).is_equal(["user://run_rovend_b.sav", "user://run_rovend_b.sav"])
	assert_array(_rig.bytes(WriterRig.RUN, WriterRig.A)).is_equal(kept)
	assert_str(_rig.loaded_run()).is_equal("r14")


func test_gen_scenario_never_removes_or_adds_files() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r1"))
	for transition: int in [1, 2, 3, 4, 5, 7, 1]:
		_rig.commit("r1", transition)
		_rig.pump()
		assert_int(_rig.files.size()).is_equal(2)
	_rig.commit("r2", 6)
	_rig.commit("r3", 6)
	_rig.pump()
	assert_int(_rig.files.size()).is_equal(2)
	assert_bool(_rig.io.has_method("rename")).is_false()
	assert_bool(_rig.io.has_method("remove")).is_false()


func test_gen_killed_write_loads_previous_body_whole() -> void:
	for transition: int in [3, 4]:
		var raw: Dictionary = WriterRig.run("r_new")
		var size: int = SaveCodec.encode(SaveFixtures.APP_VERSION, 15, raw).size()
		for cut: int in [0, 24, 48 + (size - 48) / 2, size - 1, -2]:
			_rig = WriterRig.new()
			_rig.put(WriterRig.RUN, 14, WriterRig.run("r_old"))
			if cut != -2:
				_rig.io.kill_write = 1
				_rig.io.kill_at = cut
			_rig.commit("r_new", transition)
			_rig.pump()
			var expected: String = "r_new" if cut == -2 else "r_old"
			assert_str(_rig.loaded_run()).is_equal(expected)
			var pick: SaveCodec.Pick = _rig.loaded(WriterRig.RUN)
			var body: Dictionary = _rig.read(WriterRig.RUN, pick.slot).body
			assert_int(body["schema"].size()).is_equal(3)
			assert_bool(body.has("roll")).is_true()


func test_gallery_too_new_slot_is_not_overwritten() -> void:
	_rig.put("gallery", 14, {"seen": ["e_9"]}, 2)
	_rig.garbage("gallery", WriterRig.B)
	var kept_a: PackedByteArray = _rig.bytes("gallery", WriterRig.A)
	var kept_b: PackedByteArray = _rig.bytes("gallery", WriterRig.B)
	var ticket: int = _rig.writer.write_gallery({"seen": ["e_1"]})
	_rig.pump()
	assert_int(_rig.io.written.size()).is_equal(0)
	assert_array(_rig.bytes("gallery", WriterRig.A)).is_equal(kept_a)
	assert_array(_rig.bytes("gallery", WriterRig.B)).is_equal(kept_b)
	assert_int(_rig.lines.size()).is_equal(1)
	assert_array(_rig.finished).is_equal([Vector2i(ticket, ERROR_OUT)])


func test_gallery_both_corrupt_writes_gen_1_in_b() -> void:
	_rig.garbage("gallery", WriterRig.A)
	_rig.garbage("gallery", WriterRig.B)
	var kept_a: PackedByteArray = _rig.bytes("gallery", WriterRig.A)
	_rig.writer.write_gallery({"seen": ["e_1"]})
	_rig.pump()
	assert_int(_rig.read("gallery", WriterRig.B, "").gen).is_equal(1)
	assert_array(_rig.bytes("gallery", WriterRig.A)).is_equal(kept_a)
