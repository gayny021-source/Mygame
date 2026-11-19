extends GdUnitTestSuite
## ThreadSaveIo watchdog (TD C3): a task that never completes is abandoned after watchdog_ms,
## the result is a failure of the right shape and the next start is accepted.

const PATH := "user://rt1_watchdog.tmp"


## A task that reports completion only after `hung` is cleared (the real thread ends at once).
class HungIo extends ThreadSaveIo:
	var hung: bool = true

	func _is_done(task: int) -> bool:
		return not hung and super._is_done(task)


var _now: int = 0


func before_test() -> void:
	_now = 0


func after_test() -> void:
	var path: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _io() -> HungIo:
	var io: HungIo = HungIo.new()
	io.watchdog_ms = 3000
	io.clock = func() -> int: return _now
	return io


func test_hung_write_is_abandoned_after_the_watchdog_and_the_next_start_is_refused() -> void:
	# Arrange
	var io: HungIo = _io()
	io.start_write(PATH, PackedByteArray([1]))
	# Act / Assert
	_now = 2999
	assert_object(io.poll()).is_null()
	_now = 3000
	var done: SaveIo.IoDone = io.poll()
	assert_object(done).is_not_null()
	assert_bool(done.ok).is_false()
	assert_int(io.abandoned).is_equal(1)
	assert_bool(io.start_write(PATH, PackedByteArray([2]))).is_false()


func test_late_result_of_an_abandoned_task_is_discarded_and_then_starts_are_accepted() -> void:
	# Arrange
	var io: HungIo = _io()
	io.start_write(PATH, PackedByteArray([1]))
	_now = 3000
	io.poll()
	io.hung = false
	OS.delay_msec(50)
	# Act
	var late: SaveIo.IoDone = io.poll()
	# Assert
	assert_object(late).is_null()
	assert_bool(io.start_write(PATH, PackedByteArray([2]))).is_true()


func test_starts_are_refused_after_max_abandoned_tasks_in_a_row() -> void:
	# Arrange
	var io: HungIo = _io()
	io.max_abandoned = 2
	for round: int in 2:
		io.hung = true
		_now += 10000
		io.start_write(PATH, PackedByteArray([1]))
		_now += 3000
		io.poll()
		io.hung = false
		OS.delay_msec(50)
		io.poll()
	# Act / Assert
	assert_bool(io.start_write(PATH, PackedByteArray([2]))).is_false()


func test_hung_read_is_abandoned_with_a_read_error_per_slot() -> void:
	# Arrange
	var io: HungIo = _io()
	io.start_read(PackedStringArray([PATH, PATH]))
	_now = 5000
	# Act
	var done: SaveIo.IoDone = io.poll()
	# Assert
	assert_bool(done.ok).is_false()
	assert_array(done.failed).contains_exactly([0, 1])
	assert_int(done.statuses.size()).is_equal(2)
	assert_object(done.reads[0]).is_null()


func test_a_running_task_before_the_watchdog_still_refuses_a_second_start() -> void:
	# Arrange
	var io: HungIo = _io()
	io.start_write(PATH, PackedByteArray([1]))
	_now = 100
	# Act / Assert
	assert_bool(io.start_write(PATH, PackedByteArray([2]))).is_false()
