class_name RollRecord
extends RefCounted
## The roll record S7 hands to the Save system (d20-checks.md, rule 9; States «Итог показан
## (восстановлен)»; DD-020, DD-021; story S7): only the inputs of the roll. Everything derived is
## recomputed by D20Check.restore, so a record cannot disagree with its result. The generator state
## is not stored: rule 10 wants a new sequence on every start.
##
## Usage: [code]var raw: Dictionary = turn.record.to_dict()[/code]

const KEYS: PackedStringArray = ["scene_id", "check_id", "stat_id", "roll", "bonus", "dc", "rerolled", "applied"]

var scene_id: String
var check_id: String
var stat_id: String
## Natural face 1…20.
var roll: int
var bonus: int
var dc: int
var rerolled: bool
## «Продолжить» was accepted: the outcome goes to the Choice system, then the record is dropped.
var applied: bool


## A record of `result` rolled in the scene `scene`, not applied yet.
static func of(scene: String, result: D20Result) -> RollRecord:
	var record: RollRecord = RollRecord.new()
	record.scene_id = scene
	record.check_id = result.check_id
	record.stat_id = result.stat_id
	record.roll = result.roll
	record.bonus = result.bonus
	record.dc = result.dc
	record.rerolled = result.rerolled
	return record


## The eight keys; the only way out to the save layer.
func to_dict() -> Dictionary:
	return {
		"scene_id": scene_id, "check_id": check_id, "stat_id": stat_id, "roll": roll, "bonus": bonus,
		"dc": dc, "rerolled": rerolled, "applied": applied,
	}


## Record read from a save; null when findings were appended to `issues` (DT-02 a face outside
## 1…20 or not whole, DT-03, DT-04, DT-06).
static func from_dict(raw: Dictionary, path: String, issues: Array[DataIssue]) -> RollRecord:
	var before: int = issues.size()
	var reader: DictReader = DictReader.new(raw, path, issues)
	for key: Variant in raw:
		if not str(key).begins_with("_") and not KEYS.has(key):
			reader.issue("DT-04", str(key), "неизвестный ключ")
	var record: RollRecord = RollRecord.new()
	record.scene_id = StoryPosition._id(reader, "scene_id")
	record.check_id = StoryPosition._id(reader, "check_id")
	record.stat_id = StoryPosition._id(reader, "stat_id")
	var face_before: int = issues.size()
	record.roll = reader.integer("roll")
	if issues.size() == face_before and (record.roll < 1 or record.roll > 20):
		reader.issue("DT-02", "roll", "грань %d вне 1…20" % record.roll)
	record.bonus = reader.integer("bonus")
	record.dc = reader.integer("dc")
	record.rerolled = reader.flag("rerolled", true)
	record.applied = reader.flag("applied", true)
	if issues.size() > before:
		return null
	return record
