class_name StoryPosition
extends RefCounted
## Resume point of the story {chapter, scene, entry transition, pending outcome} (branching-story.md,
## rule 8; ADR-0001 §6; story S6). Edges, text and the chosen route are not stored: they are
## recomputed from the data and the flags. The navigator owns its position and hands out copies.
##
## Usage: [code]var raw := navigator.position().to_dict()[/code]

const KEYS: PackedStringArray = ["chapter", "scene", "transition", "pending_outcome"]

var chapter: String
var scene: String
## Id of the entry transition; empty when the scene was entered by a start.
var transition: String
## Id of the outcome shown but not left yet; empty when none.
var pending_outcome: String


func _init(chapter_id: String = "", scene_id: String = "", entry: String = "", pending: String = "") -> void:
	chapter = chapter_id
	scene = scene_id
	transition = entry
	pending_outcome = pending


## The four keys, always strings (never null).
func to_dict() -> Dictionary:
	return {"chapter": chapter, "scene": scene, "transition": transition, "pending_outcome": pending_outcome}


## Position read from a save; null when findings were appended to `issues` (DT-02, DT-03, DT-04, DT-06).
static func from_dict(raw: Dictionary, path: String, issues: Array[DataIssue]) -> StoryPosition:
	var before: int = issues.size()
	var reader: DictReader = DictReader.new(raw, path, issues)
	for key: Variant in raw:
		if not KEYS.has(key):
			reader.issue("DT-04", str(key), "неизвестный ключ")
	var result: StoryPosition = StoryPosition.new(_id(reader, "chapter"), _id(reader, "scene"), reader.text("transition", false), reader.text("pending_outcome", false))
	if issues.size() > before:
		return null
	return result


static func _id(reader: DictReader, key: String) -> String:
	var value: String = reader.text(key)
	if reader.has_text(key) and not value.is_empty() and not DictReader.is_id(value):
		reader.issue("DT-06", key, "id «%s» не подходит под ^[a-z][a-z0-9_]*$" % value)
	return value
