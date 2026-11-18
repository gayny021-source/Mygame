class_name FakeSaveIo
extends SaveIo
## In-memory SaveIo for the writer tests (save-system.md, rules 5, 6, 11; ADR-0002 §1; stories SV2, SV3).
## Files live in a dictionary that a second instance may share: a new writer over the same `files` is
## a restarted process. No threads, no disk.

## Path -> bytes on "disk".
var files: Dictionary[String, PackedByteArray]
var opens: int
var closes: int
var reads: int
## Paths in the order their writes started.
var written: PackedStringArray = []
## So many next writes store half of the bytes and return false (store_* failed, Э-17).
var fail_writes: int
## While true, a started write keeps its result until release().
var hold_write: bool
## While true, a started read keeps its result until release() (a hung load, rule 8).
var hold_read: bool
## So many next reads fail as a whole: ok false, no bytes (a read error, not a missing file).
var fail_reads: int
## When ≥ 0, a read returns only so many slots (a short answer of the executor).
var read_slots: int = -1
## Slot whose file fails to open at the next read, then -1 (a read error of one slot).
var fail_read_slot: int = -1
## 1-based number of the write at which the process is killed; 0 — never.
var kill_write: int
## Bytes the killed write leaves in the file; -1 — killed before open, the file is untouched.
var kill_at: int = -1
var dead: bool
var _result: SaveIo.IoDone
var _held: SaveIo.IoDone


func _init(shared: Dictionary[String, PackedByteArray] = {}) -> void:
	files = shared


func start_write(path: String, bytes: PackedByteArray) -> void:
	if dead:
		return
	if written.size() + 1 == kill_write:
		_kill(path, bytes)
		return
	written.append(path)
	opens += 1
	var done: SaveIo.IoDone = SaveIo.IoDone.new()
	done.ok = fail_writes == 0
	if done.ok:
		files[path] = bytes
	else:
		fail_writes -= 1
		files[path] = bytes.slice(0, bytes.size() / 2)
	closes += 1
	if hold_write:
		_held = done
	else:
		_result = done


func start_read(paths: PackedStringArray) -> void:
	if dead:
		return
	reads += 1
	var done: SaveIo.IoDone = SaveIo.IoDone.new()
	var whole: bool = fail_reads > 0
	if whole:
		fail_reads -= 1
	for slot: int in paths.size():
		if whole or slot == fail_read_slot:
			done.failed.append(slot)
			done.statuses.append(SaveIo.IoDone.FileStatus.READ_ERROR)
			done.reads.append(null)
		elif files.has(paths[slot]):
			done.statuses.append(SaveIo.IoDone.FileStatus.READ)
			done.reads.append(files[paths[slot]])
		else:
			done.statuses.append(SaveIo.IoDone.FileStatus.ABSENT)
			done.reads.append(null)
	fail_read_slot = -1
	done.ok = done.failed.is_empty()
	if read_slots >= 0:
		done.reads.resize(read_slots)
	if hold_read:
		_held = done
	else:
		_result = done


func poll() -> SaveIo.IoDone:
	var done: SaveIo.IoDone = _result
	_result = null
	return done


## Lets a held write or read finish at the next poll.
func release() -> void:
	hold_write = false
	hold_read = false
	_result = _held
	_held = null


func _kill(path: String, bytes: PackedByteArray) -> void:
	dead = true
	if kill_at < 0:
		return
	written.append(path)
	opens += 1
	files[path] = bytes.slice(0, kill_at)
