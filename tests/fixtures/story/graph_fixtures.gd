class_name GraphFixtures
extends RefCounted
## Factory of small chapters for the graph checks BS-02…BS-10 (ADR-0001, story S4).
## Every call returns a fresh Dictionary in the file format; `hero` turns it into HeroData
## the way the loaders do. `m_*` of the GDD are built in the tests from `chain` and `f1_chapter`.

const F1_FLAGS := StoryFixtures.DIR + "/hero_stub/flags.json"

## Loader findings of the last `hero` call: a fixture that must be valid is checked on them.
static var last_issues: Array[DataIssue] = []


static func scene(id: String, options: Array, node: bool = false) -> Dictionary:
	return {"id": id, "paragraphs": ["Абзац " + id + "."], "illustration": "ill_" + id, "options": options, "node": node}


static func normal(id: String, outcome_id: String) -> Dictionary:
	return {"id": id, "text": "Вариант", "kind": "normal", "outcome": outcome_id}


static func safe(id: String, outcome_id: String) -> Dictionary:
	return {"id": id, "text": "Осторожно", "kind": "safe", "outcome": outcome_id}


static func risky(id: String, success: String, failure: String) -> Dictionary:
	var check: Dictionary = {"id": id + "_check", "stat": "strength", "level": "medium", "success": success, "failure": failure}
	return {"id": id, "text": "Рискнуть", "kind": "risky", "check": check}


## `routes` items are a transition id or a ready {if, transition} entry.
static func outcome(id: String, routes: Array, sets: Array = [], paragraphs: Array = ["Исход."]) -> Dictionary:
	var entries: Array = []
	for route: Variant in routes:
		entries.append(route if route is Dictionary else {"transition": route})
	return {"id": id, "paragraphs": paragraphs, "sets": sets, "routes": entries}


static func to_scene(id: String, scene_id: String) -> Dictionary:
	return {"id": id, "to": "scene:" + scene_id, "bridge": {"base": "Мост."}}


static func to_end(id: String) -> Dictionary:
	return {"id": id, "to": "chapter_end", "coda": ["Кода."]}


static func to_ending(id: String, ending: String) -> Dictionary:
	return {"id": id, "to": "ending:" + ending}


## `starts` empty: one start without `if` on the first scene.
static func chapter(scenes: Array, outcomes: Array, transitions: Array, starts: Array = []) -> Dictionary:
	var entries: Array = starts
	if entries.is_empty():
		entries = [{"id": "st_main", "scene": scenes[0]["id"]}]
	return {"schema_version": 1, "id": "m_g", "title": "Мини-глава", "goal": "Цель", "starts": entries, "scenes": scenes, "outcomes": outcomes, "transitions": transitions}


## Linear chain of scenes: one normal option each, the last one ends the chapter.
static func chain(ids: Array) -> Dictionary:
	var scenes: Array = []
	var outcomes: Array = []
	var transitions: Array = []
	for i: int in ids.size():
		var id: String = ids[i]
		scenes.append(scene(id, [normal(id + "_go", "o_" + id)]))
		outcomes.append(outcome("o_" + id, ["t_" + id]))
		transitions.append(to_scene("t_" + id, ids[i + 1]) if i + 1 < ids.size() else to_end("t_" + id))
	return chapter(scenes, outcomes, transitions)


## The element of `items` with this id, or an empty Dictionary.
static func find(items: Array, id: String) -> Dictionary:
	for item: Dictionary in items:
		if item["id"] == id:
			return item
	return {}


## A side scene `branch_id`: the outcome `from_outcome` now leads into it, it leads on to `to_scene_id`.
static func add_branch(data: Dictionary, from_outcome: String, branch_id: String, to_scene_id: String) -> void:
	var into: String = "t_%s_%s" % [from_outcome, branch_id]
	var out: String = "t_%s_out" % branch_id
	find(data["outcomes"], from_outcome)["routes"] = [{"transition": into}]
	data["transitions"].append(to_scene(into, branch_id))
	data["transitions"].append(to_scene(out, to_scene_id))
	data["outcomes"].append(outcome("o_" + branch_id, [out]))
	data["scenes"].append(scene(branch_id, [normal(branch_id + "_go", "o_" + branch_id)]))


## ch_f1 of the hero_stub fixture as a fresh Dictionary.
static func f1_chapter() -> Dictionary:
	var issues: Array[DataIssue] = []
	return ChapterLoader.read_object(StoryFixtures.CH_F1, issues)


## Flag declarations of the hero_stub fixture as Dictionaries.
static func f1_flags() -> Array:
	var issues: Array[DataIssue] = []
	return ChapterLoader.read_object(F1_FLAGS, issues)["flags"]


## HeroData with the one chapter `data`; `chapter_ids` default to that chapter alone.
static func hero(data: Dictionary, flag_dicts: Array = [], chapter_ids: Array = []) -> HeroData:
	last_issues = []
	var result: HeroData = HeroData.new()
	result.id = "hero_g"
	var stat_ids: PackedStringArray = ["strength"]
	result.flags = FlagLoader.parse(StoryFixtures.flags_file(flag_dicts), "test", stat_ids, last_issues)
	var known: ConditionVocabulary = FlagLoader.vocabulary(result.flags)
	var loaded: ChapterData = ChapterLoader.parse(data, "test", last_issues, known)
	result.chapters.append(loaded)
	result.chapter_ids = PackedStringArray(chapter_ids) if not chapter_ids.is_empty() else PackedStringArray([loaded.id])
	return result


static func chapter_data(data: Dictionary, flag_dicts: Array = []) -> ChapterData:
	return hero(data, flag_dicts).chapters[0]


## Findings with this code; `severity` empty counts both kinds.
static func count(issues: Array[DataIssue], code: String, severity: String = "") -> int:
	var total: int = 0
	for issue: DataIssue in issues:
		if issue.code == code and (severity.is_empty() or issue.severity == severity):
			total += 1
	return total
