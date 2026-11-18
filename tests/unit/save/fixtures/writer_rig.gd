class_name WriterRig
extends RefCounted
## A SaveWriter over a FakeSaveIo with its log and finished tickets collected (story SV2). restart()
## keeps `files`: a new writer over the same slots is a restarted process.

const HERO := SaveFixtures.HERO
const OTHER := "mirel"
const RUN := "run_rovend"
const RUN_OTHER := "run_mirel"
const A: int = 0
const B: int = 1

var files: Dictionary[String, PackedByteArray] = {}
var io: FakeSaveIo
var writer: SaveWriter
var lines: PackedStringArray = []
## Vector2i(ticket, outcome) per write_finished, in order.
var finished: Array[Vector2i] = []


func _init() -> void:
	restart()


func restart(subscribe: bool = true) -> void:
	io = FakeSaveIo.new(files)
	writer = SaveWriter.new(io, SaveFixtures.APP_VERSION, _log_line)
	if subscribe:
		writer.write_finished.connect(_on_finished)


func pump(times: int = 30) -> void:
	for i: int in times:
		writer.pump()


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
