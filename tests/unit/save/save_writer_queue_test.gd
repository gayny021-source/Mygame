extends GdUnitTestSuite
## Unit tests for the SaveWriter queue (save-system.md, rules 4, 6, F6; ADR-0002 §4; DD-022, DD-023;
## story SV2): AC-06 (write level), AC-13, AC-14, AC-15, AC-22.

const OK_OUT: int = SaveWriter.Outcome.OK
const ERROR_OUT: int = SaveWriter.Outcome.ERROR

var _rig: WriterRig


func before_test() -> void:
	_rig = WriterRig.new()


func _tickets() -> Array[int]:
	var tickets: Array[int] = []
	for done: Vector2i in _rig.finished:
		tickets.append(done.x)
	return tickets


func test_queue_three_commits_during_held_write_put_two_on_disk() -> void:
	_rig.put(WriterRig.RUN, 19, WriterRig.run("r0"))
	_rig.io.hold_write = true
	var first: int = _rig.commit("t0")
	_rig.pump(3)
	var later: Array[int] = [_rig.commit("t1"), _rig.commit("t2"), _rig.commit("t3")]
	_rig.io.release()
	_rig.pump()
	assert_array(_rig.io.written).is_equal(["user://run_rovend_a.sav", "user://run_rovend_b.sav"])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("t0@20")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t3@21")
	assert_array(_tickets()).is_equal([first] + later)
	for done: Vector2i in _rig.finished:
		assert_int(done.y).is_equal(OK_OUT)


func test_queue_other_files_do_not_displace_waiting_run_write() -> void:
	_rig.io.hold_write = true
	_rig.commit("a0")
	_rig.pump(3)
	_rig.commit("a1")
	_rig.commit("b0", 1, WriterRig.OTHER)
	_rig.writer.write_gallery({"seen": ["e_1"]})
	_rig.writer.write_settings({"volume": 3})
	_rig.io.release()
	_rig.pump()
	var order: Array[String] = ["user://run_rovend_b.sav", "user://run_rovend_a.sav", "user://run_mirel_b.sav", "user://gallery_b.sav", "user://settings_b.sav"]
	assert_array(_rig.io.written).is_equal(order)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("a1@2")


func test_queue_displacing_write_keeps_place_before_gallery() -> void:
	_rig.io.hold_write = true
	_rig.commit("a0")
	_rig.pump(3)
	var displaced: int = _rig.commit("a1")
	var gallery: int = _rig.writer.write_gallery({"seen": ["e_1"]})
	var winner: int = _rig.commit("a2")
	_rig.io.release()
	_rig.pump()
	assert_array(_rig.io.written).is_equal(["user://run_rovend_b.sav", "user://run_rovend_a.sav", "user://gallery_b.sav"])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("a2@2")
	assert_array(_tickets().slice(1)).is_equal([displaced, winner, gallery])


func test_queue_ticket_without_subscriber_writes_and_logs() -> void:
	_rig.restart(false)
	var ticket: int = _rig.commit("a0")
	_rig.pump()
	assert_int(ticket).is_greater(0)
	assert_int(_rig.io.written.size()).is_equal(1)
	assert_int(_rig.lines.size()).is_equal(1)


func test_commit_serializes_body_at_call() -> void:
	var raw: Dictionary = WriterRig.run("r_call")
	var issues: Array[DataIssue] = []
	_rig.writer.commit(1, WriterRig.HERO, raw, issues)
	raw["run_id"] = "r_changed"
	raw["schema"].clear()
	_rig.pump()
	var stored: Dictionary = _rig.read(WriterRig.RUN, WriterRig.B).body
	assert_str(stored["run_id"]).is_equal("r_call")
	assert_int(stored["schema"].size()).is_equal(3)


func test_commit_each_single_transition_writes_one_file_once() -> void:
	for transition: int in [1, 2, 3, 4, 5, 7]:
		var opens: int = _rig.io.opens
		var closes: int = _rig.io.closes
		var writes: int = _rig.io.written.size()
		var signals: int = _rig.finished.size()
		var ticket: int = _rig.commit("r_%d" % transition, transition)
		_rig.pump()
		assert_int(_rig.io.opens - opens).is_equal(1)
		assert_int(_rig.io.closes - closes).is_equal(1)
		assert_int(_rig.io.written.size() - writes).is_equal(1)
		assert_int(_rig.finished.size() - signals).is_equal(1)
		assert_int(_rig.finished.back().x).is_equal(ticket)


func test_commit_pair_writes_twice_and_signals_after_second() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r1"))
	_rig.io.hold_write = true
	var ticket: int = _rig.commit("r2", 6)
	_rig.pump(3)
	_rig.io.release()
	_rig.pump(1)
	assert_int(_rig.io.written.size()).is_equal(2)
	assert_int(_rig.finished.size()).is_equal(0)
	_rig.pump()
	assert_array(_rig.finished).is_equal([Vector2i(ticket, OK_OUT)])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r2@15")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("r2@16")


func test_commit_with_findings_or_null_body_writes_nothing_and_keeps_gen() -> void:
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r1"))
	var none: Array[DataIssue] = []
	var found: Array[DataIssue] = [DataIssue.new("DT-03", "body/resume", "", "нет снимка возобновления")]
	assert_int(_rig.writer.commit(1, WriterRig.HERO, null, none)).is_equal(0)
	assert_int(_rig.writer.commit(1, WriterRig.HERO, WriterRig.run("r_bad"), found)).is_equal(0)
	assert_int(_rig.writer.commit(1, "../x", WriterRig.run("r_bad"), none)).is_equal(0)
	assert_int(_rig.writer.commit(8, WriterRig.HERO, WriterRig.run("r_bad"), none)).is_equal(0)
	_rig.pump()
	assert_int(_rig.lines.size()).is_equal(4)
	assert_int(_rig.io.written.size()).is_equal(0)
	assert_int(_rig.finished.size()).is_equal(0)
	_rig.commit("r_good")
	_rig.pump()
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r_good@15")


func test_gallery_and_settings_write_both_slots_and_fall_back() -> void:
	for i: int in 2:
		_rig.writer.write_gallery({"seen": ["e_%d" % i]})
		_rig.writer.write_settings({"volume": i})
	_rig.pump()
	for key: String in ["gallery", "settings"]:
		for slot: int in 2:
			var head: String = _rig.bytes(key, slot).slice(0, 4).get_string_from_ascii()
			assert_str(head).is_equal("KPSV")
	_rig.garbage("gallery", WriterRig.A)
	var pick: SaveCodec.Pick = _rig.loaded("gallery", "")
	assert_int(pick.code).is_equal(SaveCodec.Pick.Code.OK)
	assert_int(pick.slot).is_equal(WriterRig.B)
	assert_dict(_rig.read("gallery", WriterRig.B, "").body).is_equal({"seen": ["e_0"]})
