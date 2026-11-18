class_name SaveWriter
extends RefCounted
## Save writer: one ordered queue, generations, the transition-6 pair, timeouts and loads
## (save-system.md, rules 4-8, 11, 15, F1-F3, F6; ADR-0002 §1, §4; DD-022, DD-023; stories SV2, SV3).
## Runs on the main thread: the body is serialized at commit (AC-15), the header with gen and sum is
## framed when the write starts, and SaveIo only moves bytes. The clock is the `now_ms` of pump():
## a commit or load_run is stamped with the time of the last pump (at most one frame early); one made
## before the first pump is stamped by that pump. The time never moves back: a smaller `now_ms` keeps
## the last one.
##
## Usage: [code]var ticket := writer.commit(1, "rovend", body, issues)[/code]; 0 means refused
## (the caller shows the screen at once, DD-022). Call [code]pump(now_ms)[/code] every frame with
## monotonic milliseconds.

## Outcome of a ticket; TIMEOUT only releases the screen, the write goes on (rule 7).
enum Outcome { OK, ERROR, TIMEOUT }
## Code of a load: the first four from SaveCodec.Pick.Code (rule 8); READ_ERROR — no slot loads
## and a file failed to read, the player may retry (rule 12, CEO decision «Сбой чтения сохранения»).
enum LoadCode { OK, EMPTY, CORRUPT, TOO_NEW, LOAD_TIMEOUT, READ_ERROR }

## Once per ticket; displaced tickets get the outcome of the write that displaced them (rule 6).
signal write_finished(ticket: int, outcome: Outcome)
## Once per token; `body` is the migrated run body for OK, else empty (rule 8).
signal load_finished(token: int, code: LoadCode, body: Dictionary)

const PATH := "user://%s_%s.sav"
const SLOT_NAMES: PackedStringArray = ["a", "b"]
const RUN_PREFIX := "run_"
const GALLERY := "gallery"
const SETTINGS := "settings"
## Transition 6 (new run, «Пройти заново»): the body is written twice, an indivisible pair (rule 11).
const PAIR_TRANSITION: int = 6
const LAST_TRANSITION: int = 7


## One queued write of one file; `tickets` grows as newer commits of the file displace it.
class Job extends RefCounted:
	var key: String
	## Expected body.hero; "" for Gallery and Settings.
	var hero: String
	var payload: PackedByteArray
	var pair: bool
	## A load_run job: reads both slots, writes nothing (rule 8).
	var is_load: bool
	## A load whose token got LOAD_TIMEOUT while it ran: its result goes nowhere.
	var expired: bool
	## Time the load token was queued.
	var queued_ms: int
	var tickets: Array[int] = []
	## Gen of the write in progress; 0 while the slots are being read.
	var gen: int
	var writes_left: int

	func _init(job_key: String, job_hero: String, job_payload: PackedByteArray, job_pair: bool) -> void:
		key = job_key
		hero = job_hero
		payload = job_payload
		pair = job_pair


var _io: SaveIo
var _app_version: int
var _log_line: Callable
var _wait_ms: int
## Format version N -> migrate_vN→vN+1, a Callable(body: Dictionary) -> Dictionary or null on error.
var _migrations: Dictionary[int, Callable] = {}
var _queue: Array[Job] = []
var _job: Job
## Key -> last gen closed with OK; a missing key is read from its slots first (rule 5).
var _gen_ok: Dictionary[String, int] = {}
var _next_ticket: int = 1
## Ticket -> time of its commit, until its one signal (F3).
var _waiting: Dictionary[int, int] = {}
## Pending load jobs, oldest first; a hero may have two when a write was queued between them.
var _loads: Array[Job] = []
var _now: int
## Time the last job of any file ended with any outcome (rule 8, the token clock).
var _last_done: int
## Reused every frame: no allocation in pump.
var _expired: Array[int] = []
var _expired_loads: Array[Job] = []
var _pumping: bool
var _pumped: bool


## `log_line` takes one String per finished job, timeout or refusal. `wait_ms` is T_ожид (F3);
## `migrations` is empty in the game until format_version 2 (rule 15); a step with a version below 1
## or an invalid Callable is refused here with a log line, so its chain loads CORRUPT.
func _init(io: SaveIo, app_version: int, log_line: Callable, wait_ms: int, migrations: Dictionary[int, Callable] = {}) -> void:
	_io = io
	_app_version = app_version
	_log_line = log_line
	_wait_ms = wait_ms
	for version: int in migrations:
		if version >= 1 and migrations[version].is_valid():
			_migrations[version] = migrations[version]
		else:
			_log_line.call("save: миграция v%d отклонена: Callable не годен" % version)


## Slot file of a key: slot 0 is `_a`, 1 is `_b` (F1).
static func path_of(key: String, slot: int) -> String:
	return PATH % [key, SLOT_NAMES[slot]]


## Queues the run body of `hero_id` for transition 1…7; 6 is the pair. Returns the ticket, or 0 with
## a log line and nothing queued when the transition is unknown, the id unfit for a path, the body
## null, `issues` not empty or body.hero not `hero_id` (DD-023: no write, no gen spent).
func commit(transition: int, hero_id: String, body: Variant, issues: Array[DataIssue]) -> int:
	if transition < 1 or transition > LAST_TRANSITION:
		return _refuse("переход %d вне 1…%d" % [transition, LAST_TRANSITION])
	if not DictReader.is_id(hero_id):
		return _refuse("id героя «%s» не годится для пути" % hero_id)
	if not issues.is_empty() or not (body is Dictionary):
		return _refuse("тело %s не собрано, находок %d" % [hero_id, issues.size()])
	if body.get("hero") != hero_id:
		return _refuse("тело героя «%s» в файл %s" % [body.get("hero"), hero_id])
	return _enqueue(RUN_PREFIX + hero_id, hero_id, body, transition == PAIR_TRANSITION)


## Queues the Gallery body (rule 1); its slots follow the same generations.
func write_gallery(body: Dictionary) -> int:
	return _enqueue(GALLERY, "", body, false)


## Queues the Settings body (rule 1).
func write_settings(body: Dictionary) -> int:
	return _enqueue(SETTINGS, "", body, false)


## Queues the load of `hero_id` after every write queued before it (rule 8). Returns the token: the
## pending one of this hero when no write of the hero was queued after it, else a new one; 0 with a
## log line when the id is unfit for a path.
## The token ends with load_finished: the pick code, or LOAD_TIMEOUT after `wait_ms` with no job ended.
func load_run(hero_id: String) -> int:
	if not DictReader.is_id(hero_id):
		return _refuse("id героя «%s» не годится для пути" % hero_id)
	var pending: Job = _pending_load(hero_id)
	if pending != null and not _write_after(pending):
		return pending.tickets[0]
	var job: Job = Job.new(RUN_PREFIX + hero_id, hero_id, PackedByteArray(), false)
	job.is_load = true
	job.queued_ms = _now
	job.tickets.append(_next_ticket)
	_next_ticket += 1
	_queue.append(job)
	_loads.append(job)
	return job.tickets[0]


## One frame at monotonic `now_ms`: polls SaveIo, advances the running job, starts the next one when
## idle, then times out tickets and loads (F3, rule 8). A pump from a signal handler returns at once:
## the outer pump is still walking its lists.
func pump(now_ms: int) -> void:
	if _pumping:
		return
	_pumping = true
	if not _pumped:
		_stamp_early(now_ms)
	_now = maxi(_now, now_ms)
	if _job != null:
		var done: SaveIo.IoDone = _io.poll()
		if done != null:
			_advance(done)
	if _job == null and not _queue.is_empty():
		_job = _queue.pop_front()
		_start()
	_time_out_tickets()
	_time_out_loads()
	_pumping = false


## The first pump stamps what came before it: the clock is unknown until then, not 0.
func _stamp_early(now_ms: int) -> void:
	_pumped = true
	for ticket: int in _waiting:
		_waiting[ticket] = now_ms
	for job: Job in _loads:
		job.queued_ms = now_ms


## The newest pending load of `hero_id`, or null.
func _pending_load(hero_id: String) -> Job:
	for i: int in range(_loads.size() - 1, -1, -1):
		if _loads[i].hero == hero_id:
			return _loads[i]
	return null


## True when a write of the load's file waits after it; a running load counts every queued one.
func _write_after(load_job: Job) -> bool:
	for i: int in range(_queue.find(load_job) + 1, _queue.size()):
		if _queue[i].key == load_job.key and not _queue[i].is_load:
			return true
	return false


func _enqueue(key: String, hero: String, body: Dictionary, pair: bool) -> int:
	var ticket: int = _next_ticket
	_next_ticket += 1
	_waiting[ticket] = _now
	var payload: PackedByteArray = SaveCodec.serialize(body)
	# The newest job of the key only: a write after a load of it must not reach that load (rule 8).
	for i: int in range(_queue.size() - 1, -1, -1):
		var waiting: Job = _queue[i]
		if waiting.key != key:
			continue
		if waiting.is_load:
			break
		waiting.payload = payload
		# A displaced pair stays a pair: one write would leave the old run in the other slot.
		waiting.pair = waiting.pair or pair
		waiting.tickets.append(ticket)
		return ticket
	var job: Job = Job.new(key, hero, payload, pair)
	job.tickets.append(ticket)
	_queue.append(job)
	return ticket


func _start() -> void:
	var paths: PackedStringArray = [path_of(_job.key, 0), path_of(_job.key, 1)]
	if _job.is_load:
		if not _io.start_read(paths):
			_advance(_refused_read())
		return
	_job.writes_left = 2 if _job.pair else 1
	if _gen_ok.has(_job.key):
		_write_next()
		return
	if not _io.start_read(paths):
		_advance(_refused_read())


## A failed write ends the job ERROR and leaves gen_ok as is: the retry of the next commit goes to the
## same slot (rule 5). A failed second pair write keeps the first one, so the new run survives in
## the first slot and the ticket still gets ERROR (rule 11, AC-66 a).
func _advance(done: SaveIo.IoDone) -> void:
	if _job.is_load:
		_loaded(done)
		return
	if _job.gen == 0:
		_primed(done)
		return
	if not done.ok:
		_finish(Outcome.ERROR)
		return
	_gen_ok[_job.key] = _job.gen
	_job.writes_left -= 1
	if _job.writes_left > 0:
		_write_next()
		return
	_finish(Outcome.OK)


## The slots read by the first step of a job with an unknown gen (F2; AC-09, AC-43, AC-64).
## A read error ends the job ERROR without a write and leaves gen_ok unknown: the unreadable slot's
## gen is unknown, so the next gen could land on the newest valid one. A pair refuses too (Э-32).
func _primed(done: SaveIo.IoDone) -> void:
	if not done.ok:
		_finish(Outcome.ERROR, "save: %s слоты не прочитаны, не пишется" % _job.key)
		return
	var slots: Array[SaveCodec.SlotRead] = _decoded(done.reads)
	var pick: SaveCodec.Pick = SaveCodec.pick(slots[0], slots[1])
	if pick.code == SaveCodec.Pick.Code.TOO_NEW and not _job.pair:
		_finish(Outcome.ERROR, "save: %s новее приложения, не пишется" % _job.key)
		return
	_gen_ok[_job.key] = pick.gen_max
	_write_next()


## Both slots of the running job checked by rule 2; null for a missing file or a slot the executor
## did not return.
func _decoded(reads: Array[Variant]) -> Array[SaveCodec.SlotRead]:
	var slots: Array[SaveCodec.SlotRead] = []
	for slot: int in SLOT_NAMES.size():
		var bytes: Variant = reads[slot] if slot < reads.size() else null
		var slot_read: SaveCodec.SlotRead = null
		if bytes != null:
			slot_read = SaveCodec.decode(bytes, slot, _app_version, _job.hero)
		slots.append(slot_read)
	return slots


## Ends a load job (rule 8, items 1-5). An expired one ends silently: its token already got
## LOAD_TIMEOUT. A slot that failed to read counts as no file for the pick: a readable valid slot
## still loads (rule 8 item 2, with a log line); otherwise the code is READ_ERROR, never EMPTY or
## CORRUPT — the files may be fine, the player retries (rule 12). Nothing is written, the slots stay
## as read (invariant 5).
func _loaded(done: SaveIo.IoDone) -> void:
	var job: Job = _job
	var slots: Array[SaveCodec.SlotRead] = _decoded(done.reads)
	_job = null
	_last_done = _now
	if job.expired:
		return
	_loads.erase(job)
	var pick: SaveCodec.Pick = SaveCodec.pick(slots[0], slots[1])
	var code: LoadCode = _code_of(pick.code)
	var body: Dictionary = {}
	var note: String = ""
	if code == LoadCode.OK:
		body = _migrated(slots[pick.slot], job.hero)
	if code == LoadCode.OK and body.is_empty():
		code = LoadCode.CORRUPT
		note = ", миграция не удалась"
	if not done.failed.is_empty():
		note += ", слоты %s не прочитаны" % [done.failed]
	# READ_ERROR outranks EMPTY, CORRUPT and TOO_NEW on purpose: the unread file may be fine and the
	# player retries (CEO decision «Сбой чтения сохранения», rule 12).
	if not done.failed.is_empty() and code != LoadCode.OK:
		code = LoadCode.READ_ERROR
	_log_line.call("save: load %s %s%s" % [job.key, LoadCode.keys()[code], note])
	load_finished.emit(job.tickets[0], code, body)


static func _code_of(code: SaveCodec.Pick.Code) -> LoadCode:
	match code:
		SaveCodec.Pick.Code.OK:
			return LoadCode.OK
		SaveCodec.Pick.Code.EMPTY:
			return LoadCode.EMPTY
		SaveCodec.Pick.Code.CORRUPT:
			return LoadCode.CORRUPT
		SaveCodec.Pick.Code.TOO_NEW:
			return LoadCode.TOO_NEW
	push_error("save: неизвестный код pick %d" % code)
	return LoadCode.CORRUPT


## The slot body brought to the app version in memory; empty when a step is missing, fails or
## changes the hero of the file (rule 15: a migration error is CORRUPT).
func _migrated(slot_read: SaveCodec.SlotRead, hero: String) -> Dictionary:
	var result: Variant = slot_read.body
	for step: int in range(slot_read.version, _app_version):
		if not _migrations.has(step) or not (result is Dictionary):
			return {}
		result = _migrations[step].call(result)
	if not (result is Dictionary) or result.get("hero") != hero:
		return {}
	return result


## Starts the next write; refuses the whole job when its writes would pass MAX_GEN (F1).
func _write_next() -> void:
	if _gen_ok[_job.key] + _job.writes_left > SaveCodec.MAX_GEN:
		_finish(Outcome.ERROR, "save: %s gen за пределом %d, не пишется" % [_job.key, SaveCodec.MAX_GEN])
		return
	_job.gen = _gen_ok[_job.key] + 1
	var bytes: PackedByteArray = SaveCodec.frame(_app_version, _job.gen, _job.payload)
	if not _io.start_write(path_of(_job.key, SaveCodec.slot_of(_job.gen)), bytes):
		_finish(Outcome.ERROR, "save: %s ввод-вывод занят, запись не начата" % _job.key)


# A start SaveIo refused is a read error of both slots: nothing was read, nothing is left to poll.
func _refused_read() -> SaveIo.IoDone:
	var done: SaveIo.IoDone = SaveIo.IoDone.new()
	for slot: int in SLOT_NAMES.size():
		done.statuses.append(SaveIo.IoDone.FileStatus.READ_ERROR)
		done.reads.append(null)
		done.failed.append(slot)
	return done


## Ends the job before the signals, so a handler may commit again. Tickets that already got TIMEOUT
## get no signal; the job's one log line counts them (rule 7, AC-17, AC-65).
func _finish(outcome: Outcome, line: String = "") -> void:
	var job: Job = _job
	_job = null
	_last_done = _now
	if line.is_empty():
		line = "save: %s gen %d %s" % [job.key, job.gen, Outcome.keys()[outcome]]
	var signalled: Array[int] = []
	for ticket: int in job.tickets:
		if _waiting.erase(ticket):
			signalled.append(ticket)
	var late: int = job.tickets.size() - signalled.size()
	if late > 0:
		line += ", запоздало после TIMEOUT, билетов %d" % late
	_log_line.call(line)
	for ticket: int in signalled:
		write_finished.emit(ticket, outcome)


## TIMEOUT once per ticket waiting `wait_ms` since its commit (F3).
func _time_out_tickets() -> void:
	if _waiting.is_empty():
		return
	_expired.clear()
	for ticket: int in _waiting:
		if _now - _waiting[ticket] >= _wait_ms:
			_expired.append(ticket)
	for ticket: int in _expired:
		_waiting.erase(ticket)
		_log_line.call("save: билет %d TIMEOUT" % ticket)
		write_finished.emit(ticket, Outcome.TIMEOUT)


## LOAD_TIMEOUT once `wait_ms` passed since the later of the token and the last ended job (rule 8):
## a queued job leaves the queue, a running one ends silently.
func _time_out_loads() -> void:
	if _loads.is_empty():
		return
	_expired_loads.clear()
	for job: Job in _loads:
		if _now - maxi(job.queued_ms, _last_done) >= _wait_ms:
			_expired_loads.append(job)
	for job: Job in _expired_loads:
		_loads.erase(job)
		_queue.erase(job)
		job.expired = true
		_log_line.call("save: load %s LOAD_TIMEOUT" % job.key)
		load_finished.emit(job.tickets[0], LoadCode.LOAD_TIMEOUT, {})


func _refuse(reason: String) -> int:
	_log_line.call("save: commit отклонён: " + reason)
	return 0
