class_name ThreadSaveIo
extends SaveIo
## SaveIo on one WorkerThreadPool task at a time (ADR-0002 §1, §4; story SV4). The task only moves
## bytes into its own IoDone; the main thread reads it after `is_task_completed` and
## `wait_for_task_completion`. WorkerThreadPool is NOT SOURCEABLE in docs/engine-reference: save_disk_test
## is its probe.

## A task running longer than this is abandoned (TD C3): its thread cannot be stopped, so the IO
## reports a failed result but keeps the task id and stays busy until the thread ends. Two threads
## never write one slot; a late result is discarded.
var watchdog_ms: int = 3000
## After this many abandoned tasks in a row (none finished normally between) every start is refused.
var max_abandoned: int = 3
## Test seam only: tests replace the clock to move time without sleeping.
var clock: Callable = Time.get_ticks_msec
## Tasks abandoned so far.
var abandoned: int = 0

var _task: int = -1
var _running: IoDone
var _started_ms: int
var _read_slots: int
var _is_abandoned: bool = false
var _strikes: int = 0


## False, with a warning, while a task runs: one task at a time, the running one is not lost.
func start_write(path: String, bytes: PackedByteArray) -> bool:
	if _busy():
		return false
	_running = IoDone.new()
	_read_slots = 0
	_started_ms = clock.call()
	_task = WorkerThreadPool.add_task(_write_task.bind(path, bytes, _running))
	return true


func start_read(paths: PackedStringArray) -> bool:
	if _busy():
		return false
	_running = IoDone.new()
	_read_slots = paths.size()
	_started_ms = clock.call()
	_task = WorkerThreadPool.add_task(_read_task.bind(paths, _running))
	return true


## The finished operation once; null while the task runs or when none was started. The result of
## an abandoned task is dropped; its thread is joined here, which cannot block (it is complete).
func poll() -> IoDone:
	if _task < 0:
		return null
	if not _is_done(_task):
		return _abandon() if not _is_abandoned and clock.call() - _started_ms >= watchdog_ms else null
	WorkerThreadPool.wait_for_task_completion(_task)
	var done: IoDone = _running
	var late: bool = _is_abandoned
	_task = -1
	_running = null
	_is_abandoned = false
	if late:
		return null
	_strikes = 0
	return done


## Test seam: HungIo in the watchdog test never reports completion without a real stuck thread.
func _is_done(task: int) -> bool:
	return WorkerThreadPool.is_task_completed(task)


## Returns a failed result of the stuck task's shape; the task itself stays, so `_busy` refuses starts.
func _abandon() -> IoDone:
	push_warning("ThreadSaveIo: задача висит больше %d мс, брошена" % watchdog_ms)
	abandoned += 1
	_strikes += 1
	_is_abandoned = true
	var done: IoDone = IoDone.new()
	for slot: int in _read_slots:
		done.statuses.append(IoDone.FileStatus.READ_ERROR)
		done.reads.append(null)
		done.failed.append(slot)
	return done


func _busy() -> bool:
	if _strikes >= max_abandoned:
		push_warning("ThreadSaveIo: %d задач подряд зависли, запись отключена" % _strikes)
		return true
	if _task >= 0:
		push_warning("ThreadSaveIo: задача уже идёт, новый запуск отклонён")
	return _task >= 0


static func _write_task(path: String, bytes: PackedByteArray, done: IoDone) -> void:
	done.ok = _write(path, bytes)


static func _read_task(paths: PackedStringArray, done: IoDone) -> void:
	for slot: int in paths.size():
		var bytes: PackedByteArray = _read(paths[slot], done)
		if done.statuses[slot] == IoDone.FileStatus.READ_ERROR:
			done.failed.append(slot)
		done.reads.append(bytes if done.statuses[slot] == IoDone.FileStatus.READ else null)
	done.ok = done.failed.is_empty()
