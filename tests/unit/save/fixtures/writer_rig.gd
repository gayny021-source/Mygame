class_name WriterRig
extends RefCounted
## A SaveWriter over a FakeSaveIo with its log, finished tickets and loads collected (stories SV2,
## SV3). restart() keeps `files`: a new writer over the same slots is a restarted process. The clock
## is `now_ms`, moved only by the test (rule 7: monotonic, no real timers).

const HERO := SaveFixtures.HERO
const OTHER := "mirel"
const RUN := "run_rovend"
const RUN_OTHER := "run_mirel"
const A: int = 0
const B: int = 1
## T_ожид of ADR-0002 §4 (candidate 2000 ms).
const WAIT_MS: int = 2000

var files: Dictionary[String, PackedByteArray] = {}
var io: FakeSaveIo
var writer: SaveWriter
var lines: PackedStringArray = []
## Vector2i(ticket, outcome) per write_finished, in order.
var finished: Array[Vector2i] = []
## Vector2i(token, code) per load_finished, in order; `load_bodies` holds their bodies.
var load_results: Array[Vector2i] = []
var load_bodies: Array[Dictionary] = []
var now_ms: int


func _init() -> void:
	restart()


func restart(subscribe: bool = true, wait_ms: int = WAIT_MS, app_version: int = SaveFixtures.APP_VERSION, migrations: Dictionary[int, Callable] = {}) -> void:
	io = FakeSaveIo.new(files)
	writer = SaveWriter.new(io, app_version, _log_line, wait_ms, migrations)
	writer.load_finished.connect(_on_loaded)
	if subscribe:
		writer.write_finished.connect(_on_finished)


## So many frames at the current `now_ms`.
func pump(times: int = 30) -> void:
	for i: int in times:
		writer.pump(now_ms)


## One frame at `ms`.
func at(ms: int) -> void:
	now_ms = ms
	writer.pump(now_ms)


func load_run(hero: String = HERO) -> int:
	return writer.load_run(hero)


## Fixture body of `hero` with its run_id replaced.
static func run(run_id: String, hero: String = HERO) -> Dictionary:
	var raw: Dictionary = SaveFixtures.raw_body()
	raw["run_id"] = run_id
	raw["hero"] = hero
	return raw


func commit(run_id: String, transition: int = 1, hero: String = HERO) -> int:
	var issues: Array[DataIssue] = []
	return writer.commit(transition, hero, run(run_id, hero), issues)


func put(key: String, gen: int, body: Dictionary, version: int = 1) -> void:
	files[SaveWriter.path_of(key, SaveCodec.slot_of(gen))] = SaveCodec.encode(version, gen, body)


func garbage(key: String, slot: int) -> void:
	files[SaveWriter.path_of(key, slot)] = "junk".to_ascii_buffer()


func bytes(key: String, slot: int) -> PackedByteArray:
	return files.get(SaveWriter.path_of(key, slot), PackedByteArray())


func read(key: String, slot: int, hero: String = HERO) -> SaveCodec.SlotRead:
	return SaveCodec.decode(bytes(key, slot), slot, SaveFixtures.APP_VERSION, hero)


## Both slots of `key` picked as a fresh process loads them (F2).
func loaded(key: String, hero: String = HERO) -> SaveCodec.Pick:
	var a: SaveCodec.SlotRead = read(key, A, hero) if files.has(SaveWriter.path_of(key, A)) else null
	var b: SaveCodec.SlotRead = read(key, B, hero) if files.has(SaveWriter.path_of(key, B)) else null
	return SaveCodec.pick(a, b)


## run_id of the body a fresh process loads, "" when nothing loads.
func loaded_run(key: String = RUN, hero: String = HERO) -> String:
	var pick: SaveCodec.Pick = loaded(key, hero)
	if pick.code != SaveCodec.Pick.Code.OK:
		return ""
	return read(key, pick.slot, hero).body["run_id"]


## run_id and gen of a slot, as "R2@15"; "" when the slot is not valid.
func slot_run(key: String, slot: int, hero: String = HERO) -> String:
	var slot_read: SaveCodec.SlotRead = read(key, slot, hero)
	if slot_read.status != SaveCodec.SlotRead.Status.VALID:
		return ""
	return "%s@%d" % [slot_read.body["run_id"], slot_read.gen]


func _log_line(line: String) -> void:
	lines.append(line)


func _on_finished(ticket: int, outcome: SaveWriter.Outcome) -> void:
	finished.append(Vector2i(ticket, outcome))


func _on_loaded(token: int, code: SaveWriter.LoadCode, body: Dictionary) -> void:
	load_results.append(Vector2i(token, code))
	load_bodies.append(body)
