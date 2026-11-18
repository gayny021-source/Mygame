extends GdUnitTestSuite
## Unit tests for the transition-6 pair (save-system.md, rule 11, rule 5; ADR-0002 §4; story SV2):
## AC-39, AC-40, AC-41, AC-43 (writer level), AC-62, AC-66 (a, c).

const OK_OUT: int = SaveWriter.Outcome.OK
const ERROR_OUT: int = SaveWriter.Outcome.ERROR
const PAIR: int = 6

var _rig: WriterRig


func before_test() -> void:
	_rig = WriterRig.new()


## R1 at gen 14 in `_a`, as AC-40 and AC-62 start.
func _old_run() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r1"))


func _others() -> Dictionary[String, PackedByteArray]:
	_rig.put(WriterRig.RUN_OTHER, 4, WriterRig.run("rb", WriterRig.OTHER))
	_rig.put("gallery", 3, {"seen": ["e_1"]})
	_rig.put("settings", 5, {"volume": 2})
	return _rig.files.duplicate()


func _assert_untouched(kept: Dictionary[String, PackedByteArray]) -> void:
	for path: String in kept:
		if not path.begins_with("user://run_rovend"):
			assert_array(_rig.files[path]).is_equal(kept[path])


func test_pair_new_hero_writes_only_own_files() -> void:
	_old_run()
	var kept: Dictionary[String, PackedByteArray] = _rig.files.duplicate()
	_rig.commit("rb", PAIR, WriterRig.OTHER)
	_rig.pump()
	assert_array(_rig.io.written).is_equal(["user://run_mirel_b.sav", "user://run_mirel_a.sav"])
	assert_array(_rig.bytes(WriterRig.RUN, WriterRig.A)).is_equal(kept["user://run_rovend_a.sav"])
	assert_str(_rig.loaded_run()).is_equal("r1")


func test_pair_restart_fills_both_slots_with_new_run() -> void:
	_old_run()
	var kept: Dictionary[String, PackedByteArray] = _others()
	var ticket: int = _rig.commit("r2", PAIR)
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2@15")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r2@16")
	assert_array(_rig.finished).is_equal([Vector2i(ticket, OK_OUT)])
	assert_int(_rig.files.size()).is_equal(kept.size() + 1)
	_assert_untouched(kept)


func test_pair_killed_first_write_of_new_hero_is_empty() -> void:
	_rig.io.kill_write = 1
	_rig.io.kill_at = 30
	_rig.commit("r_new", PAIR)
	_rig.pump()
	assert_bool(_rig.files.has(SaveWriter.path_of(WriterRig.RUN, WriterRig.A))).is_false()
	assert_int(_rig.loaded(WriterRig.RUN).code).is_equal(SaveCodec.Pick.Code.EMPTY)


func test_pair_restart_during_write_displaces_waiting_one() -> void:
	_old_run()
	_rig.io.hold_write = true
	_rig.commit("r1_cur")
	_rig.pump(3)
	var waiting: int = _rig.commit("r1_wait")
	var pair: int = _rig.commit("r2", PAIR)
	_rig.io.release()
	_rig.pump()
	var order: Array[String] = ["user://run_rovend_b.sav", "user://run_rovend_a.sav", "user://run_rovend_b.sav"]
	assert_array(_rig.io.written).is_equal(order)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r2@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2@17")
	assert_array(_rig.finished.slice(1)).is_equal([Vector2i(waiting, OK_OUT), Vector2i(pair, OK_OUT)])


func test_pair_over_corrupt_starts_at_gen_1() -> void:
	_rig.garbage(WriterRig.RUN, WriterRig.A)
	_rig.garbage(WriterRig.RUN, WriterRig.B)
	var kept: Dictionary[String, PackedByteArray] = _others()
	_rig.commit("r_new", PAIR)
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_new@1")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r_new@2")
	_assert_untouched(kept)


func test_pair_over_too_new_goes_above_its_gen() -> void:
	_rig.put(WriterRig.RUN, 15, WriterRig.run("r_future"), 2)
	var kept: Dictionary[String, PackedByteArray] = _others()
	_rig.commit("r_new", PAIR)
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r_new@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_new@17")
	_assert_untouched(kept)


func test_pair_kill_points_load_old_then_new() -> void:
	var points: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 100), Vector2i(2, -1), Vector2i(2, 100), Vector2i(0, -1)]
	var expected: Array[String] = ["r1", "r1", "r2", "r2", "r2"]
	for i: int in points.size():
		_rig = WriterRig.new()
		_old_run()
		_rig.io.kill_write = points[i].x
		_rig.io.kill_at = points[i].y
		_rig.commit("r2", PAIR)
		_rig.pump()
		_rig.restart()
		assert_str(_rig.loaded_run()).is_equal(expected[i])


func test_pair_after_pair_any_one_broken_slot_loads_new() -> void:
	for slot: int in 2:
		_rig = WriterRig.new()
		_old_run()
		_rig.commit("r2", PAIR)
		_rig.pump()
		assert_int(_rig.finished.size()).is_equal(1)
		_rig.garbage(WriterRig.RUN, slot)
		assert_str(_rig.loaded_run()).is_equal("r2")


func test_pair_first_write_error_skips_second() -> void:
	_old_run()
	_rig.io.fail_writes = 1
	var ticket: int = _rig.commit("r2", PAIR)
	_rig.pump()
	assert_int(_rig.io.written.size()).is_equal(1)
	assert_array(_rig.finished).is_equal([Vector2i(ticket, ERROR_OUT)])
	assert_str(_rig.loaded_run()).is_equal("r1")


func test_pair_second_write_error_keeps_new_run() -> void:
	_old_run()
	_rig.io.hold_write = true
	var ticket: int = _rig.commit("r2", PAIR)
	_rig.pump(3)
	_rig.io.fail_writes = 1
	_rig.io.release()
	_rig.pump()
	assert_array(_rig.finished).is_equal([Vector2i(ticket, ERROR_OUT)])
	assert_str(_rig.loaded_run()).is_equal("r2")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2@15")
	_rig.commit("r2_next")
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r2_next@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2@15")


func test_pair_other_hero_waits_for_second_write() -> void:
	_old_run()
	_rig.put(WriterRig.RUN_OTHER, 4, WriterRig.run("rb", WriterRig.OTHER))
	var kept_b: PackedByteArray = _rig.bytes(WriterRig.RUN_OTHER, WriterRig.A)
	_rig.io.hold_write = true
	_rig.commit("r2", PAIR)
	_rig.pump(3)
	_rig.commit("rb_1", 1, WriterRig.OTHER)
	_rig.commit("rb_new", PAIR, WriterRig.OTHER)
	assert_array(_rig.bytes(WriterRig.RUN_OTHER, WriterRig.A)).is_equal(kept_b)
	_rig.io.release()
	_rig.pump()
	var order: Array[String] = ["user://run_rovend_b.sav", "user://run_rovend_a.sav", "user://run_mirel_b.sav", "user://run_mirel_a.sav"]
	assert_array(_rig.io.written).is_equal(order)
	assert_str(_rig.slot_run(WriterRig.RUN_OTHER, WriterRig.B, WriterRig.OTHER)).is_equal("rb_new@5")
	assert_str(_rig.slot_run(WriterRig.RUN_OTHER, WriterRig.A, WriterRig.OTHER)).is_equal("rb_new@6")


func test_pair_waiting_pair_displaced_by_commit_stays_a_pair() -> void:
	_old_run()
	_rig.io.hold_write = true
	_rig.commit("r1_cur")
	_rig.pump(3)
	_rig.commit("r2", PAIR)
	_rig.commit("r2_next")
	_rig.io.release()
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r2_next@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2_next@17")
