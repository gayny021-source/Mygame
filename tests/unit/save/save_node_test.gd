extends GdUnitTestSuite
## Unit tests for SaveNode, the only Node of the save layer (ADR-0002 §1; AC-22 pause and return write
## nothing; story SV4). The writer is injected over a FakeSaveIo.


func test_process_pumps_the_writer_so_a_queued_write_finishes() -> void:
	# Arrange
	var rig: WriterRig = WriterRig.new()
	var node: SaveNode = auto_free(SaveNode.new())
	node.writer = rig.writer
	var ticket: int = rig.commit("R1")
	# Act
	for frame: int in 30:
		node._process(0.016)
	# Assert
	assert_array(rig.finished).contains_exactly([Vector2i(ticket, SaveWriter.Outcome.OK)])


func test_pause_and_return_notifications_write_nothing() -> void:
	# Arrange
	var rig: WriterRig = WriterRig.new()
	var node: SaveNode = auto_free(SaveNode.new())
	node.writer = rig.writer
	# Act
	node.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	node.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	node._process(0.016)
	# Assert
	assert_int(rig.io.written.size()).is_equal(0)
	assert_int(rig.io.opens).is_equal(0)


func test_ready_without_an_injected_writer_builds_one_from_the_project_config() -> void:
	# Arrange
	var node: SaveNode = auto_free(SaveNode.new())
	# Act
	add_child(node)
	# Assert
	assert_object(node.writer).is_not_null()


func test_flush_waits_for_a_queued_write_and_returns_true() -> void:
	# Arrange
	var rig: WriterRig = WriterRig.new()
	var node: SaveNode = auto_free(SaveNode.new())
	node.writer = rig.writer
	rig.commit("R1")
	# Act
	var done: bool = node.flush()
	# Assert
	assert_bool(done).is_true()
	assert_bool(rig.writer.idle()).is_true()


func test_flush_gives_up_after_the_timeout_when_the_write_hangs() -> void:
	# Arrange
	var rig: WriterRig = WriterRig.new()
	rig.io.hold_write = true
	var node: SaveNode = auto_free(SaveNode.new())
	node.writer = rig.writer
	node.flush_ms = 30
	rig.commit("R1")
	var started: int = Time.get_ticks_msec()
	# Act
	var done: bool = node.flush()
	# Assert
	assert_bool(done).is_false()
	assert_int(Time.get_ticks_msec() - started).is_less(1000)


func test_pause_notification_flushes_the_pending_write_without_new_ones() -> void:
	# Arrange
	var rig: WriterRig = WriterRig.new()
	var node: SaveNode = auto_free(SaveNode.new())
	node.writer = rig.writer
	rig.commit("R1")
	# Act
	node.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	# Assert
	assert_bool(rig.writer.idle()).is_true()
	assert_int(rig.io.written.size()).is_equal(1)
