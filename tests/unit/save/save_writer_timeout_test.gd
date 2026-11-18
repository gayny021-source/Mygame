extends GdUnitTestSuite
## Unit tests for the SaveWriter timeouts (save-system.md, rules 5, 6, 7, 8, 11, F3; ADR-0002 §4;
## story SV3): AC-16, AC-17, AC-18, AC-20, AC-65, AC-66 (b), AC-67. The clock is the rig's `now_ms`.

const OK_OUT: int = SaveWriter.Outcome.OK
const TIMEOUT_OUT: int = SaveWriter.Outcome.TIMEOUT
const LOAD_OK: int = SaveWriter.LoadCode.OK
const LOAD_TIMEOUT: int = SaveWriter.LoadCode.LOAD_TIMEOUT
const WAIT: int = WriterRig.WAIT_MS

var _rig: WriterRig


func before_test() -> void:
	_rig = WriterRig.new()


func _outcomes(ticket: int) -> Array[int]:
	var outcomes: Array[int] = []
	for done: Vector2i in _rig.finished:
		if done.x == ticket:
			outcomes.append(done.y)
	return outcomes


func _lines_with(text: String) -> int:
	var count: int = 0
	for line: String in _rig.lines:
		if line.contains(text):
			count += 1
	return count


## A held write of `run_id` committed at `ms`; its ticket.
func _held_commit(ms: int, run_id: String) -> int:
	_rig.io.hold_write = true
	_rig.at(ms)
	var ticket: int = _rig.commit(run_id)
	_rig.pump(3)
	return ticket


func test_ac16_timeout_comes_once_at_wait_after_commit() -> void:
	# Arrange
	var ticket: int = _held_commit(10500, "t1")
	# Act
	_rig.at(12499)
	var before: Array[int] = _outcomes(ticket)
	_rig.at(12500)
	for frame: int in 10:
		_rig.at(12516 + 16 * frame)
	# Assert
	assert_array(before).is_empty()
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])


func test_ac16_wait_from_config_500_times_out_at_11000() -> void:
	# Arrange
	_rig.restart(true, 500)
	var ticket: int = _held_commit(10500, "t1")
	# Act
	_rig.at(10999)
	var before: Array[int] = _outcomes(ticket)
	_rig.at(11000)
	# Assert
	assert_array(before).is_empty()
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])


func test_ac16_slot_body_has_no_write_time() -> void:
	# Arrange
	_held_commit(10500, "t1")
	_rig.at(12500)
	_rig.io.release()
	_rig.pump()
	var expected: Array = WriterRig.run("t1").keys()
	# Act
	var keys: Array = _rig.read(WriterRig.RUN, WriterRig.B).body.keys()
	# Assert
	keys.sort()
	expected.sort()
	assert_array(keys).is_equal(expected)


func test_ac17_late_write_lands_with_one_signal_and_one_log_line() -> void:
	# Arrange
	var ticket: int = _held_commit(0, "t1")
	_rig.at(WAIT)
	# Act
	_rig.io.release()
	_rig.pump()
	# Assert
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t1@1")
	assert_int(_lines_with("запоздало")).is_equal(1)


func test_ac18_next_commit_after_timeout_lands_after_the_late_write() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_held_commit(0, "t15")
	_rig.at(WAIT)
	var next: int = _rig.commit("t16")
	# Act
	_rig.io.release()
	_rig.pump()
	var token: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_array(_rig.io.written).is_equal(["user://run_rovend_b.sav", "user://run_rovend_a.sav"])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t15@15")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("t16@16")
	assert_array(_outcomes(next)).is_equal([OK_OUT])
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_OK)])
	assert_str(_rig.load_bodies[0]["run_id"]).is_equal("t16")


func test_ac20_hung_writer_times_out_each_ticket_from_its_own_commit() -> void:
	# Arrange
	_held_commit(0, "t0")
	var tickets: Array[int] = []
	for i: int in 5:
		_rig.at(100 * (i + 1))
		tickets.append(_rig.commit("t%d" % (i + 1)))
	# Act / Assert: each ticket waits WAIT from its own commit
	for i: int in 5:
		_rig.at(100 * (i + 1) + WAIT - 1)
		assert_array(_outcomes(tickets[i])).is_empty()
		_rig.at(100 * (i + 1) + WAIT)
		assert_array(_outcomes(tickets[i])).is_equal([TIMEOUT_OUT])
	assert_int(_rig.io.written.size()).is_equal(1)


func test_ac20_load_on_hung_writer_times_out_and_gives_nothing_later() -> void:
	# Arrange
	_held_commit(0, "t0")
	_rig.at(1000)
	_rig.commit("t1")
	_rig.at(3000)
	var token: int = _rig.load_run()
	var repeats: Array[int] = [_rig.load_run(), _rig.load_run(), _rig.load_run()]
	# Act
	_rig.at(3000 + WAIT - 1)
	var before: int = _rig.load_results.size()
	_rig.at(3000 + WAIT)
	var reads: int = _rig.io.reads
	_rig.io.release()
	_rig.pump()
	var after_release: Array[Vector2i] = _rig.load_results.duplicate()
	var again: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_array(repeats).is_equal([token, token, token])
	assert_int(before).is_equal(0)
	assert_array(after_release).is_equal([Vector2i(token, LOAD_TIMEOUT)])
	assert_int(reads).is_equal(1)
	assert_int(again).is_not_equal(token)
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT), Vector2i(again, LOAD_OK)])
	assert_str(_rig.load_bodies[1]["run_id"]).is_equal("t1")
	assert_int(_rig.io.reads).is_equal(reads + 1)
	assert_int(_lines_with("LOAD_TIMEOUT")).is_equal(1)
	for path: String in _rig.files:
		assert_str(path).not_contains(SaveWriter.GALLERY)


func test_ac20_started_load_that_timed_out_gives_its_result_to_nobody() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.io.hold_read = true
	var token: int = _rig.load_run()
	_rig.pump(3)
	# Act
	_rig.at(WAIT)
	_rig.io.release()
	_rig.pump()
	var again: int = _rig.load_run()
	_rig.pump()
	# Assert
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT), Vector2i(again, LOAD_OK)])
	assert_int(_rig.io.reads).is_equal(2)


func test_ac65_late_ok_after_timeout_counts_its_gen() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	var ticket: int = _held_commit(0, "t15")
	_rig.at(WAIT)
	var lines: int = _rig.lines.size()
	# Act
	_rig.io.release()
	_rig.pump()
	var late_lines: int = _rig.lines.size() - lines
	var b_bytes: PackedByteArray = _rig.bytes(WriterRig.RUN, WriterRig.B)
	_rig.commit("t16")
	_rig.pump()
	# Assert
	assert_int(late_lines).is_equal(1)
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t15@15")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("t16@16")
	assert_bool(_rig.bytes(WriterRig.RUN, WriterRig.B) == b_bytes).is_true()


func test_ac65_late_error_after_timeout_retries_the_same_gen() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.io.fail_writes = 1
	_held_commit(0, "t15")
	_rig.at(WAIT)
	_rig.io.release()
	_rig.pump()
	var a_bytes: PackedByteArray = _rig.bytes(WriterRig.RUN, WriterRig.A)
	# Act
	_rig.commit("t15b")
	_rig.pump()
	# Assert
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t15b@15")
	assert_bool(_rig.bytes(WriterRig.RUN, WriterRig.A) == a_bytes).is_true()


func test_ac66b_commits_after_pair_timeout_wait_for_its_second_write() -> void:
	# Arrange: R1 in _a; the pair wrote 15 to _b and holds 16
	_rig.put(WriterRig.RUN, 14, WriterRig.run("R1"))
	var pair: int = _rig.commit("R2", SaveWriter.PAIR_TRANSITION)
	_rig.pump(2)
	_rig.io.hold_write = true
	_rig.pump()
	_rig.at(WAIT)
	var pair_outcomes: Array[int] = _outcomes(pair)
	var first: int = _rig.commit("P1")
	var second: int = _rig.commit("P2")
	# Act
	_rig.io.release()
	_rig.pump()
	# Assert
	assert_array(pair_outcomes).is_equal([TIMEOUT_OUT])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("R2@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("P2@17")
	assert_array(_outcomes(first)).is_equal([OK_OUT])
	assert_array(_outcomes(second)).is_equal([OK_OUT])
	assert_array(_outcomes(pair)).is_equal([TIMEOUT_OUT])


func test_ac67_moving_queue_longer_than_wait_gives_no_load_timeout() -> void:
	# Arrange: five writes of 500 ms each, the load after them
	_rig.io.hold_write = true
	_rig.commit("t1")
	_rig.commit("m1", 1, WriterRig.OTHER)
	_rig.writer.write_gallery({"endings": []})
	_rig.writer.write_settings({"volume": 1})
	_rig.pump(3)
	_rig.commit("t2")
	var token: int = _rig.load_run()
	# Act
	for i: int in 5:
		_rig.io.release()
		_rig.io.hold_write = true
		_rig.at(500 * (i + 1))
		_rig.pump(3)
	# Assert
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_OK)])
	assert_str(_rig.load_bodies[0]["run_id"]).is_equal("t2")


func test_ac67_hung_after_progress_times_out_wait_after_last_done() -> void:
	# Arrange: the first job closes at 700, the next one hangs
	_rig.io.hold_write = true
	_rig.commit("m1", 1, WriterRig.OTHER)
	_rig.commit("t1")
	_rig.pump(3)
	_rig.at(100)
	var token: int = _rig.load_run()
	_rig.io.release()
	_rig.io.hold_write = true
	_rig.at(700)
	_rig.pump(3)
	# Act
	_rig.at(700 + WAIT - 1)
	var before: int = _rig.load_results.size()
	_rig.at(700 + WAIT)
	# Assert
	assert_int(before).is_equal(0)
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT)])


func test_ac67_idle_writer_counts_from_the_load_not_instantly() -> void:
	# Arrange: the last job closed at 0, the writer idles 5 s, then hangs
	_rig.commit("t1")
	_rig.pump()
	_held_commit(5000, "t2")
	var token: int = _rig.load_run()
	# Act
	_rig.at(5000 + WAIT - 1)
	var before: int = _rig.load_results.size()
	_rig.at(5000 + WAIT)
	# Assert
	assert_int(before).is_equal(0)
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT)])


func test_read_error_before_a_write_ends_error_without_writing() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.io.fail_reads = 1
	var ticket: int = _rig.commit("t15")
	# Act
	_rig.pump()
	var written: int = _rig.io.written.size()
	_rig.commit("t15b")
	_rig.pump()
	# Assert
	assert_array(_outcomes(ticket)).is_equal([SaveWriter.Outcome.ERROR])
	assert_int(written).is_equal(0)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t15b@15")
	assert_int(_rig.io.reads).is_equal(2)


func test_clock_going_back_does_not_move_the_writer_time_back() -> void:
	# Arrange
	_rig.io.hold_write = true
	_rig.at(1000)
	_rig.at(500)
	var ticket: int = _rig.commit("t1")
	_rig.pump(3)
	# Act
	_rig.at(1000 + WAIT - 1)
	var before: Array[int] = _outcomes(ticket)
	_rig.at(1000 + WAIT)
	# Assert
	assert_array(before).is_empty()
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])


func test_same_time_frames_never_time_out() -> void:
	# Arrange
	var ticket: int = _held_commit(1000, "t1")
	# Act
	for frame: int in 50:
		_rig.at(1000)
	var before: Array[int] = _outcomes(ticket)
	_rig.at(1000 + WAIT)
	# Assert
	assert_array(before).is_empty()
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])


func test_jump_after_background_times_out_once_by_real_time() -> void:
	# Arrange
	var ticket: int = _held_commit(0, "t1")
	var token: int = _rig.load_run()
	# Act
	_rig.at(3600000)
	_rig.at(3600016)
	# Assert
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT)])


func test_handlers_that_pump_get_each_signal_once() -> void:
	# Arrange: two loads and three tickets expire in one frame; every handler pumps again
	_rig.io.hold_write = true
	var tickets: Array[int] = [_rig.commit("t1"), _rig.commit("m1", 1, WriterRig.OTHER), _rig.writer.write_gallery({"endings": []})]
	_rig.pump(3)
	var loads: Array[int] = [_rig.load_run(), _rig.load_run(WriterRig.OTHER)]
	var again: Callable = func(_id: int, _code: int, _body: Dictionary = {}) -> void: _rig.writer.pump(_rig.now_ms + WAIT)
	_rig.writer.write_finished.connect(again)
	_rig.writer.load_finished.connect(again)
	# Act
	_rig.at(WAIT)
	# Assert
	for ticket: int in tickets:
		assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_array(_rig.load_results).is_equal([Vector2i(loads[0], LOAD_TIMEOUT), Vector2i(loads[1], LOAD_TIMEOUT)])


func test_pump_from_a_signal_handler_returns_at_once() -> void:
	# Arrange: the TIMEOUT handler releases the held write and pumps again
	var ticket: int = _held_commit(0, "t1")
	var lines_in_handler: Array[int] = []
	var again: Callable = func(_id: int, _outcome: int) -> void:
		_rig.io.release()
		var before: int = _rig.lines.size()
		_rig.writer.pump(_rig.now_ms)
		lines_in_handler.append(_rig.lines.size() - before)
	_rig.writer.write_finished.connect(again)
	# Act
	_rig.at(WAIT)
	_rig.pump()
	# Assert: the inner pump did nothing; the next outer pump ended the write
	assert_array(lines_in_handler).is_equal([0])
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("t1@1")


func test_commit_before_the_first_pump_is_stamped_by_that_pump() -> void:
	# Arrange: the commit and the load come before any pump; the first frame is at 10000
	_rig.io.hold_write = true
	var ticket: int = _rig.commit("t1")
	var token: int = _rig.load_run()
	# Act
	_rig.at(10000)
	_rig.pump(3)
	_rig.at(10000 + WAIT - 1)
	var before: Array[int] = _outcomes(ticket)
	var loads_before: int = _rig.load_results.size()
	_rig.at(10000 + WAIT)
	# Assert
	assert_array(before).is_empty()
	assert_int(loads_before).is_equal(0)
	assert_array(_outcomes(ticket)).is_equal([TIMEOUT_OUT])
	assert_array(_rig.load_results).is_equal([Vector2i(token, LOAD_TIMEOUT)])


func test_unreadable_slot_pauses_writes_until_it_reads_again() -> void:
	# Arrange: _a gen 14 reads, _b gen 15 does not; the load takes _a
	_rig.put(WriterRig.RUN, 14, WriterRig.run("r14"))
	_rig.put(WriterRig.RUN, 15, WriterRig.run("r15"))
	_rig.io.fail_read_slot = WriterRig.B
	_rig.load_run()
	_rig.pump()
	_rig.io.fail_read_slot = WriterRig.B
	_rig.lines.clear()
	# Act
	var paused: int = _rig.commit("t1")
	_rig.pump()
	var written: int = _rig.io.written.size()
	var lines: PackedStringArray = _rig.lines.duplicate()
	var resumed: int = _rig.commit("t2")
	_rig.pump()
	# Assert: the write after the unreadable slot knows gen 15 and does not touch it
	assert_str(_rig.load_bodies[0]["run_id"]).is_equal("r14")
	assert_array(_outcomes(paused)).is_equal([SaveWriter.Outcome.ERROR])
	assert_int(written).is_equal(0)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0]).contains("не прочитаны")
	assert_array(_outcomes(resumed)).is_equal([OK_OUT])
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("t2@16")
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.B)).is_equal("r15@15")


func test_pair_with_an_unreadable_slot_refuses_entirely() -> void:
	# Arrange
	_rig.put(WriterRig.RUN, 14, WriterRig.run("R1"))
	_rig.io.fail_read_slot = WriterRig.B
	# Act
	var pair: int = _rig.commit("R2", SaveWriter.PAIR_TRANSITION)
	_rig.pump()
	# Assert
	assert_array(_outcomes(pair)).is_equal([SaveWriter.Outcome.ERROR])
	assert_int(_rig.io.written.size()).is_equal(0)
	assert_str(_rig.slot_run(WriterRig.RUN, WriterRig.A)).is_equal("R1@14")
