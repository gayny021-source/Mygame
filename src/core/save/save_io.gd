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
	## Write: the file opened, every byte stored and closed. Read: always true.
	var ok: bool
	## Read: per path the bytes, or null when the file does not exist.
	var reads: Array[Variant] = []


var _done: IoDone


## Overwrites `path` with `bytes` (open, store, close). One operation at a time.
func start_write(path: String, bytes: PackedByteArray) -> void:
	_done = IoDone.new()
	_done.ok = _write(path, bytes)


## Reads every path whole. One operation at a time.
func start_read(paths: PackedStringArray) -> void:
	_done = IoDone.new()
	_done.ok = true
	for path: String in paths:
		_done.reads.append(_read(path))


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


## Null for a missing file; an unreadable one gives empty bytes, which the codec finds invalid.
static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_bytes(path)
