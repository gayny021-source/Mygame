class_name ReleasedIds
extends RefCounted
## The list of released ids of a hero (BS-26; ADR-0001 §3; branching-story.md, Edge Cases "Обновление",
## AC-26; story S5): `freeze` builds it from the current data, `diff` reports every listed id that the data
## lost. A `deprecated` object is still in the data, so it passes. Pure: the CLI reads and writes the file.
##
## Usage: [code]var issues: Array[DataIssue] = ReleasedIds.diff(hero, ChapterLoader.read_object(path, issues))[/code]

const KINDS: PackedStringArray = ["chapters", "scenes", "outcomes", "transitions", "endings", "flags", "starts"]
const FILE_KEYS: PackedStringArray = ["schema_version", "released_at", "ids"]


## The file content `{schema_version, released_at, ids: {<kind>: [sorted ids]}}`; starts are `<chapter>/<start>`.
static func freeze(hero: HeroData, released_at: String) -> Dictionary:
	var current: Dictionary[String, PackedStringArray] = _current(hero)
	var ids: Dictionary = {}
	for kind: String in KINDS:
		var sorted: PackedStringArray = current[kind]
		sorted.sort()
		ids[kind] = Array(sorted)
	return {"schema_version": DictReader.SCHEMA_VERSION, "released_at": released_at, "ids": ids}


## BS-26 (error) for every id of `released` missing from `hero`; DT-NN when the file has a wrong form.
static func diff(hero: HeroData, released: Dictionary) -> Array[DataIssue]:
	var issues: Array[DataIssue] = []
	var reader: DictReader = DictReader.new(released, "%s/released_ids.json" % hero.id, issues)
	if not reader.schema_ok(FILE_KEYS):
		return issues
	reader.text("released_at")
	if not reader.has("ids"):
		reader.issue("DT-03", "ids", "нет обязательного ключа")
		return issues
	var listed: DictReader = reader.child("ids", KINDS)
	if listed == null:
		return issues
	var current: Dictionary[String, PackedStringArray] = _current(hero)
	for kind: String in KINDS:
		var present: Dictionary[String, bool] = StoryGraph.as_set(current[kind])
		for id: String in listed.strings(kind):
			if not present.has(id):
				listed.issue("BS-26", kind, "выпущенный id «%s» пропал из данных: удалять и переименовывать нельзя, только deprecated" % id)
	return issues


static func _current(hero: HeroData) -> Dictionary[String, PackedStringArray]:
	var chapters: PackedStringArray = []
	var starts: PackedStringArray = []
	var scenes: PackedStringArray = []
	var outcomes: PackedStringArray = []
	var transitions: PackedStringArray = []
	var flags: PackedStringArray = []
	for decl: FlagDecl in hero.flags:
		flags.append(decl.id)
	for chapter: ChapterData in hero.chapters:
		chapters.append(chapter.id)
		for start: StartData in chapter.starts:
			starts.append("%s/%s" % [chapter.id, start.id])
		for scene: SceneData in chapter.scenes:
			scenes.append(scene.id)
		for outcome: OutcomeData in chapter.outcomes:
			outcomes.append(outcome.id)
		for transition: TransitionData in chapter.transitions:
			transitions.append(transition.id)
	return {"chapters": chapters, "scenes": scenes, "outcomes": outcomes, "transitions": transitions, "endings": hero.endings.duplicate(), "flags": flags, "starts": starts}
