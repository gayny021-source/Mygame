class_name SaveWriter
extends RefCounted
## Save writer: one ordered queue, generations, the transition-6 pair (save-system.md, rules 4, 5, 6,
## 11, F1, F2, F6; ADR-0002 §1, §4; DD-022, DD-023; story SV2). Runs on the main thread: the body is
## serialized at commit (AC-15), the header with gen and sum is framed when the write starts, and
## SaveIo only moves bytes. Timeouts and load_run come in SV3.
##
## Usage: [code]var ticket := writer.commit(1, "rovend", body, issues)[/code]; 0 means refused
## (the caller shows the screen at once, DD-022). Call [code]pump()[/code] every frame.

## Outcome of a ticket. TIMEOUT arrives with SV3.
enum Outcome { OK, ERROR }

## Once per ticket; displaced tickets get the outcome of the write that displaced them (rule 6).
signal write_finished(ticket: int, outcome: Outcome)

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
var _queue: Array[Job] = []
var _job: Job
## Key -> last gen closed with OK; a missing key is read from its slots first (rule 5).
var _gen_ok: Dictionary[String, int] = {}
var _next_ticket: int = 1


## `log_line` takes one String per finished write or refused commit.
func _init(io: SaveIo, app_version: int, log_line: Callable) -> void:
	_io = io
	_app_version = app_version
	_log_line = log_line


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


## Polls SaveIo, advances the running job and starts the next one when idle.
func pump() -> void:
	if _job != null:
		var done: SaveIo.IoDone = _io.poll()
		if done == null:
			return
		_advance(done)
	if _job == null and not _queue.is_empty():
		_job = _queue.pop_front()
		_start()


func _enqueue(key: String, hero: String, body: Dictionary, pair: bool) -> int:
	var ticket: int = _next_ticket
	_next_ticket += 1
	var payload: PackedByteArray = SaveCodec.serialize(body)
	for waiting: Job in _queue:
		if waiting.key != key:
			continue
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
	var slots: Array[SaveCodec.SlotRead] = []
	for slot: int in reads.size():
		var bytes: Variant = reads[slot]
		var slot_read: SaveCodec.SlotRead = null
		if bytes != null:
			slot_read = SaveCodec.decode(bytes, slot, _app_version, _job.hero)
		slots.append(slot_read)
	var pick: SaveCodec.Pick = SaveCodec.pick(slots[0], slots[1])
	if pick.code == SaveCodec.Pick.Code.TOO_NEW and not _job.pair:
		_finish(Outcome.ERROR, "save: %s новее приложения, не пишется" % _job.key)
		return
	_gen_ok[_job.key] = pick.gen_max
	_write_next()


## Starts the next write; refuses the whole job when its writes would pass MAX_GEN (F1).
func _write_next() -> void:
	if _gen_ok[_job.key] + _job.writes_left > SaveCodec.MAX_GEN:
		_finish(Outcome.ERROR, "save: %s gen за пределом %d, не пишется" % [_job.key, SaveCodec.MAX_GEN])
		return
	_job.gen = _gen_ok[_job.key] + 1
	var bytes: PackedByteArray = SaveCodec.frame(_app_version, _job.gen, _job.payload)
	_io.start_write(path_of(_job.key, SaveCodec.slot_of(_job.gen)), bytes)


## Ends the job before the signals, so a handler may commit again.
func _finish(outcome: Outcome, line: String = "") -> void:
	var job: Job = _job
	_job = null
	if line.is_empty():
		line = "save: %s gen %d %s" % [job.key, job.gen, Outcome.keys()[outcome]]
	_log_line.call(line)
	for ticket: int in job.tickets:
		write_finished.emit(ticket, outcome)


func _refuse(reason: String) -> int:
	_log_line.call("save: commit отклонён: " + reason)
	return 0
