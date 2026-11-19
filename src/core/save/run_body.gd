class_name RunBody
extends RefCounted
## Body v1 of a run slot (save-system.md, rule 2; ADR-0002 §3, §5, §6; story SV1), the only owner of
## the raw run body. No `gen` (it lives in the header, AC-61), no generator `state` in the roll record
## (B1), no status yet (B4); `start`, `milestone_max` ride inside each RunState.to_dict. `chapter_map` waits for the GDD «Схема главы».
##
## Usage: [code]var raw: Variant = body.to_dict(issues)[/code] — null with findings means no write.

const KEYS: PackedStringArray = ["run_id", "hero", "resume", "schema", "roll"]
const SNAPSHOT_KEYS: PackedStringArray = ["state", "position"]


## A flag state and the point to resume from.
class Snapshot extends RefCounted:
	var state: RunState
	var position: StoryPosition


	func _init(snapshot_state: RunState, snapshot_position: StoryPosition) -> void:
		state = snapshot_state
		position = snapshot_position


	## {state, position}, a copy taken now.
	func to_dict() -> Dictionary:
		return {"state": state.to_dict(), "position": position.to_dict()}


var run_id: String
var hero: String
var resume: Snapshot
## Snapshots of the chapter map, oldest first.
var schema: Array[Snapshot] = []
## The roll record; null when there is none.
var roll: RollRecord


## The raw body (a Dictionary); `roll` only when there is a record. Null, with a finding in `issues`,
## when the body has no resume (DT-03) or a null schema snapshot (DT-02): such a body is not written.
func to_dict(issues: Array[DataIssue]) -> Variant:
	if resume == null:
		issues.append(DataIssue.new("DT-03", "body/resume", "", "нет снимка возобновления"))
		return null
	var snapshots: Array[Dictionary] = []
	for i: int in schema.size():
		if schema[i] == null:
			issues.append(DataIssue.new("DT-02", "body/schema/%d" % i, "", "снимок схемы пуст"))
			return null
		snapshots.append(schema[i].to_dict())
	var raw: Dictionary = {"run_id": run_id, "hero": hero, "resume": resume.to_dict(), "schema": snapshots}
	if roll != null:
		raw["roll"] = roll.to_dict()
	return raw


## Body read from a slot; null when findings were appended to `issues` (DT-02, DT-03, DT-04, DT-06,
## DT-05 a hero other than `hero_id` of the file name, Э-14). `log_error` goes to the restored
## states; a dropped undeclared flag is logged once per load.
static func from_dict(raw: Dictionary, path: String, issues: Array[DataIssue], declarations: Array[FlagDecl], hero_id: String, log_error: Callable = Callable()) -> RunBody:
	var before: int = issues.size()
	var reader: DictReader = DictReader.new(raw, path, issues)
	_check_keys(reader, raw, KEYS)
	var body: RunBody = RunBody.new()
	body.run_id = reader.text("run_id")
	body.hero = StoryPosition.read_id(reader, "hero")
	if DictReader.is_id(body.hero) and body.hero != hero_id:
		reader.issue("DT-05", "hero", "герой «%s», а файл героя «%s»" % [body.hero, hero_id])
	var reported: Dictionary[String, bool] = {}
	var resume: Variant = reader.typed("resume", TYPE_DICTIONARY, true)
	if resume != null:
		body.resume = _snapshot(resume, path + "/resume", issues, declarations, log_error, reported)
	var snapshots: Variant = reader.typed("schema", TYPE_ARRAY, true)
	if snapshots != null:
		body.schema = _snapshots(reader, snapshots, issues, declarations, log_error, reported)
	var record: Variant = reader.typed("roll", TYPE_DICTIONARY, false)
	if record != null:
		body.roll = RollRecord.from_dict(record, path + "/roll", issues)
	if issues.size() > before:
		return null
	return body


static func _snapshots(reader: DictReader, items: Array, issues: Array[DataIssue], declarations: Array[FlagDecl], log_error: Callable, reported: Dictionary[String, bool]) -> Array[Snapshot]:
	var result: Array[Snapshot] = []
	for i: int in items.size():
		if not items[i] is Dictionary:
			reader.issue("DT-02", "schema/%d" % i, "ожидался объект")
			continue
		result.append(_snapshot(items[i], "%s/schema/%d" % [reader.path, i], issues, declarations, log_error, reported))
	return result


static func _snapshot(raw: Dictionary, path: String, issues: Array[DataIssue], declarations: Array[FlagDecl], log_error: Callable, reported: Dictionary[String, bool]) -> Snapshot:
	var reader: DictReader = DictReader.new(raw, path, issues)
	_check_keys(reader, raw, SNAPSHOT_KEYS)
	var state: Variant = reader.typed("state", TYPE_DICTIONARY, true)
	var position: Variant = reader.typed("position", TYPE_DICTIONARY, true)
	if state == null or position == null:
		return null
	var restored: RunState = RunState.from_dict(state, path + "/state", issues, declarations, log_error, reported)
	return Snapshot.new(restored, StoryPosition.from_dict(position, path + "/position", issues))


static func _check_keys(reader: DictReader, raw: Dictionary, known: PackedStringArray) -> void:
	for key: Variant in raw:
		if not known.has(key):
			reader.issue("DT-04", str(key), "неизвестный ключ")
