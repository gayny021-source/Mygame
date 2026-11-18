class_name SaveWriter
extends RefCounted
## Save writer: one ordered queue, generations, the transition-6 pair, timeouts and loads
## (save-system.md, rules 4-8, 11, 15, F1-F3, F6; ADR-0002 §1, §4; DD-022, DD-023; stories SV2, SV3).
## Runs on the main thread: the body is serialized at commit (AC-15), the header with gen and sum is
## framed when the write starts, and SaveIo only moves bytes. The clock is the `now_ms` of pump():
## a commit or load_run is stamped with the time of the last pump (at most one frame early).
##
## Usage: [code]var ticket := writer.commit(1, "rovend", body, issues)[/code]; 0 means refused
## (the caller shows the screen at once, DD-022). Call [code]pump(now_ms)[/code] every frame with
## monotonic milliseconds.

## Outcome of a ticket; TIMEOUT only releases the screen, the write goes on (rule 7).
enum Outcome { OK, ERROR, TIMEOUT }
## Code of a load; the first four follow SaveCodec.Pick.Code (rule 8).
enum LoadCode { OK, EMPTY, CORRUPT, TOO_NEW, LOAD_TIMEOUT }

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
var _migrations: Dictionary[int, Callable]
var _queue: Array[Job] = []
var _job: Job
## Key -> last gen closed with OK; a missing key is read from its slots first (rule 5).
var _gen_ok: Dictionary[String, int] = {}
var _next_ticket: int = 1
## Ticket -> time of its commit, until its one signal (F3).
var _waiting: Dictionary[int, int] = {}
## Hero -> its pending load job; a second load_run gets the same token.
var _loads: Dictionary[String, Job] = {}
var _now: int
## Time the last job of any file ended with any outcome (rule 8, the token clock).
var _last_done: int
var _expired: Array[int] = []


## `log_line` takes one String per finished job, timeout or refusal. `wait_ms` is T_ожид (F3);
## `migrations` is empty in the game until format_version 2 (rule 15).
func _init(io: SaveIo, app_version: int, log_line: Callable, wait_ms: int, migrations: Dictionary[int, Callable] = {}) -> void:
	_io = io
	_app_version = app_version
	_log_line = log_line
	_wait_ms = wait_ms
	_migrations = migrations


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


## Queues the load of `hero_id` after every write queued before it (rule 8). Returns the token, the
## pending one when this hero already waits, or 0 with a log line when the id is unfit for a path.
## The token ends with load_finished: the pick code, or LOAD_TIMEOUT after `wait_ms` with no job ended.
func load_run(hero_id: String) -> int:
	if not DictReader.is_id(hero_id):
		return _refuse("id героя «%s» не годится для пути" % hero_id)
	if _loads.has(hero_id):
		return _loads[hero_id].tickets[0]
	var job: Job = Job.new(RUN_PREFIX + hero_id, hero_id, PackedByteArray(), false)
	job.is_load = true
	job.queued_ms = _now
	job.tickets.append(_next_ticket)
	_next_ticket += 1
	_queue.append(job)
	_loads[hero_id] = job
	return job.tickets[0]


## One frame at monotonic `now_ms`: polls SaveIo, advances the running job, starts the next one when
## idle, then times out tickets and loads (F3, rule 8).
func pump(now_ms: int) -> void:
	_now = now_ms
	if _job != null:
		var done: SaveIo.IoDone = _io.poll()
		if done != null:
			_advance(done)
	if _job == null and not _queue.is_empty():
		_job = _queue.pop_front()
		_start()
	_time_out_tickets()
	_time_out_loads()


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
	if _job.is_load:
		_io.start_read(PackedStringArray([path_of(_job.key, 0), path_of(_job.key, 1)]))
		return
	_job.writes_left = 2 if _job.pair else 1
	if _gen_ok.has(_job.key):
		_write_next()
		return
	var paths: PackedStringArray = [path_of(_job.key, 0), path_of(_job.key, 1)]
	_io.start_read(paths)


## A failed write ends the job ERROR and leaves gen_ok as is: the retry of the next commit goes to the
## same slot (rule 5). A failed second pair write keeps the first one, so the new run survives in
## the first slot and the ticket still gets ERROR (rule 11, AC-66 a).
func _advance(done: SaveIo.IoDone) -> void:
	if _job.is_load:
		_loaded(done.reads)
		return
	if _job.gen == 0:
		_primed(done.reads)
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
func _primed(reads: Array[Variant]) -> void:
	var slots: Array[SaveCodec.SlotRead] = _decoded(reads)
	var pick: SaveCodec.Pick = SaveCodec.pick(slots[0], slots[1])
	if pick.code == SaveCodec.Pick.Code.TOO_NEW and not _job.pair:
		_finish(Outcome.ERROR, "save: %s новее приложения, не пишется" % _job.key)
		return
	_gen_ok[_job.key] = pick.gen_max
	_write_next()


## Both slots of the running job checked by rule 2; null for a missing file.
func _decoded(reads: Array[Variant]) -> Array[SaveCodec.SlotRead]:
	var slots: Array[SaveCodec.SlotRead] = []
	for slot: int in reads.size():
		var bytes: Variant = reads[slot]
		var slot_read: SaveCodec.SlotRead = null
		if bytes != null:
			slot_read = SaveCodec.decode(bytes, slot, _app_version, _job.hero)
		slots.append(slot_read)
	return slots


## Ends a load job (rule 8, items 1-5). An expired one ends silently: its token already got
## LOAD_TIMEOUT. Nothing is written, the slots stay as read (invariant 5).
func _loaded(reads: Array[Variant]) -> void:
	var job: Job = _job
	var slots: Array[SaveCodec.SlotRead] = _decoded(reads)
	_job = null
	_last_done = _now
	if job.expired:
		return
	_loads.erase(job.hero)
	var pick: SaveCodec.Pick = SaveCodec.pick(slots[0], slots[1])
	var code: LoadCode = (pick.code as int) as LoadCode
	var body: Dictionary = {}
	if code == LoadCode.OK:
		var slot_read: SaveCodec.SlotRead = slots[pick.slot]
		var migrated: Variant = _migrated(slot_read.body, slot_read.version)
		if migrated is Dictionary:
			body = migrated
		else:
			code = LoadCode.CORRUPT
	_log_line.call("save: load %s %s" % [job.key, LoadCode.keys()[code]])
	load_finished.emit(job.tickets[0], code, body)


## The body brought from `version` to the app version in memory; null when a step is missing or
## fails (rule 15: a migration error is CORRUPT).
func _migrated(body: Dictionary, version: int) -> Variant:
	var result: Variant = body
	for step: int in range(version, _app_version):
		if not _migrations.has(step) or not (result is Dictionary):
			return null
		result = _migrations[step].call(result)
	return result


## Starts the next write; refuses the whole job when its writes would pass MAX_GEN (F1).
func _write_next() -> void:
	if _gen_ok[_job.key] + _job.writes_left > SaveCodec.MAX_GEN:
		_finish(Outcome.ERROR, "save: %s gen за пределом %d, не пишется" % [_job.key, SaveCodec.MAX_GEN])
		return
	_job.gen = _gen_ok[_job.key] + 1
	var bytes: PackedByteArray = SaveCodec.frame(_app_version, _job.gen, _job.payload)
	_io.start_write(path_of(_job.key, SaveCodec.slot_of(_job.gen)), bytes)


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
	for job: Job in _loads.values():
		if _now - maxi(job.queued_ms, _last_done) < _wait_ms:
			continue
		_loads.erase(job.hero)
		_queue.erase(job)
		job.expired = true
		_log_line.call("save: load %s LOAD_TIMEOUT" % job.key)
		load_finished.emit(job.tickets[0], LoadCode.LOAD_TIMEOUT, {})


func _refuse(reason: String) -> int:
	_log_line.call("save: commit отклонён: " + reason)
	return 0
