class_name ThreadSaveIo
extends SaveIo
## SaveIo on one WorkerThreadPool task at a time (ADR-0002 §1, §4; story SV4). The task only moves
## bytes into its own IoDone; the main thread reads it after `is_task_completed` and
## `wait_for_task_completion`. WorkerThreadPool is NOT SOURCEABLE in docs/engine-reference: save_disk_test
## is its probe.

var _task: int = -1
var _running: IoDone


## False, with a warning, while a task runs: one task at a time, the running one is not lost.
func start_write(path: String, bytes: PackedByteArray) -> bool:
	if _busy():
		return false
	_running = IoDone.new()
	_task = WorkerThreadPool.add_task(_write_task.bind(path, bytes, _running))
	return true


func start_read(paths: PackedStringArray) -> bool:
	if _busy():
		return false
	_running = IoDone.new()
	_task = WorkerThreadPool.add_task(_read_task.bind(paths, _running))
	return true


## The finished operation once; null while the task runs or when none was started.
func poll() -> IoDone:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	var done: IoDone = _running
	_task = -1
	_running = null
	return done


func _busy() -> bool:
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
