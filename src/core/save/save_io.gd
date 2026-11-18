class_name SaveIo
extends RefCounted
## Save file I/O executor (save-system.md, rules 5, 6; ADR-0002 §1, §4; story SV2). Gets ready bytes
## from SaveWriter and only moves them: no parsing, no hashing, no queue. There is no rename and no
## delete (rule 5, AC-12). This base runs synchronously; ThreadSaveIo (later) moves the same calls to
## one WorkerThreadPool task at a time. FakeSaveIo replaces it in tests.
##
## Usage: [code]io.start_write("user://gallery_b.sav", bytes)[/code], then [code]io.poll()[/code]
## each frame until it returns an IoDone.


## Result of one started operation.
class IoDone extends RefCounted:
	## Read status of one path.
	enum FileStatus { ABSENT, READ, READ_ERROR }
	## Write: the file opened, every byte stored and closed. Read: every existing file opened; false is
	## a read error, not a missing file.
	var ok: bool
	## Read: per path the bytes, or null when the file does not exist or failed to open.
	var reads: Array[Variant] = []
	## Read: per path its status.
	var statuses: Array[FileStatus] = []
	## Read: indexes of the paths with READ_ERROR; empty when `ok`.
	var failed: Array[int] = []


var _done: IoDone


## Overwrites `path` with `bytes` (open, store, close). One operation at a time.
func start_write(path: String, bytes: PackedByteArray) -> void:
	_done = IoDone.new()
	_done.ok = _write(path, bytes)


## Reads every path whole. One operation at a time.
func start_read(paths: PackedStringArray) -> void:
	_done = IoDone.new()
	for slot: int in paths.size():
		var bytes: PackedByteArray = _read(paths[slot], _done)
		var status: IoDone.FileStatus = _done.statuses[slot]
		if status == IoDone.FileStatus.READ_ERROR:
			_done.failed.append(slot)
		_done.reads.append(bytes if status == IoDone.FileStatus.READ else null)
	_done.ok = _done.failed.is_empty()


## The finished operation once, then null until the next start.
func poll() -> IoDone:
	var done: IoDone = _done
	_done = null
	return done


static func _write(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_buffer(bytes)
	file.close()
	return stored


## The bytes of `path`, empty unless READ; appends its status to `done.statuses`.
static func _read(path: String, done: IoDone) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		done.statuses.append(IoDone.FileStatus.ABSENT)
		return PackedByteArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		done.statuses.append(IoDone.FileStatus.READ_ERROR)
		return PackedByteArray()
	done.statuses.append(IoDone.FileStatus.READ)
	return file.get_buffer(file.get_length())
