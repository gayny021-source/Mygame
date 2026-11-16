class_name FlagUsage
extends RefCounted
## Which flags the data of one hero reads and sets (branching-story.md, Core Rules 7 and 12; story S5):
## the base of traces (BS-07, BS-08), dead conditions (BS-11, BS-12) and the prose limits of F4.
## Built once per hero; conditions are parsed once and kept. A condition that does not parse is DT-08
## of the loader and reads nothing here.

## Declarations of the hero by id.
var decls: Dictionary[String, FlagDecl] = {}
## Readable flags: those in at least one condition of the hero; `cat(x)` reads every flag of the category.
var read: Dictionary[String, bool] = {}
## Flags a condition names itself (a flag, `any(...)`, `group(g) == f`): what BS-11 looks at.
var named: Dictionary[String, bool] = {}
## Flags that at least one outcome of the hero sets.
var set_by_outcome: Dictionary[String, bool] = {}
var _known: ConditionVocabulary
var _parsed: Dictionary[String, Condition] = {}


func _init(hero: HeroData) -> void:
	for decl: FlagDecl in hero.flags:
		decls[decl.id] = decl
	_known = FlagLoader.vocabulary(hero.flags)
	for chapter: ChapterData in hero.chapters:
		for text: String in condition_sites(chapter).values():
			for id: String in flags_of(text):
				read[id] = true
			var node: Condition = parse(text)
			if node != null:
				for id: String in flags_in(node, decls, false):
					named[id] = true
		for outcome: OutcomeData in chapter.outcomes:
			for id: String in outcome.sets:
				set_by_outcome[id] = true


## The parsed condition, or null when `text` is empty or does not parse.
func parse(text: String) -> Condition:
	if text.is_empty():
		return null
	if not _parsed.has(text):
		_parsed[text] = ConditionParser.parse(text, _known).condition
	return _parsed[text]


## Distinct declared flags that the condition `text` reads.
func flags_of(text: String) -> PackedStringArray:
	var node: Condition = parse(text)
	if node == null:
		return PackedStringArray()
	var ids: PackedStringArray = []
	for id: String in flags_in(node, decls):
		if not ids.has(id):
			ids.append(id)
	return ids


## Flags the condition tree reads, repeats kept; with `categories` a `cat(x)` stands for every flag of x.
static func flags_in(node: Condition, flags: Dictionary[String, FlagDecl], categories: bool = true) -> PackedStringArray:
	var ids: PackedStringArray = []
	match node.kind:
		Condition.Kind.FLAG, Condition.Kind.ANY, Condition.Kind.GROUP:
			ids.append_array(node.flags)
		Condition.Kind.CATEGORY:
			for decl: FlagDecl in flags.values():
				if categories and decl.category == node.name:
					ids.append(decl.id)
	for child: Condition in node.children:
		ids.append_array(flags_in(child, flags, categories))
	return ids


## Every non-empty condition of the chapter by its place `<chapter>/<kind>/<id>/<field>[/<index>]`:
## starts, scene paragraphs and options, outcome paragraphs and routes, bridge inserts and codas.
static func condition_sites(chapter: ChapterData) -> Dictionary[String, String]:
	var sites: Dictionary[String, String] = {}
	for start: StartData in chapter.starts:
		_add(sites, "%s/starts/%s/if" % [chapter.id, start.id], start.condition)
	for scene: SceneData in chapter.scenes:
		_add_paragraphs(sites, "%s/scenes/%s/paragraphs" % [chapter.id, scene.id], scene.paragraphs)
		for option: OptionData in scene.options:
			_add(sites, "%s/scenes/%s/options/%s" % [chapter.id, scene.id, option.id], option.condition)
	for outcome: OutcomeData in chapter.outcomes:
		_add_paragraphs(sites, "%s/outcomes/%s/paragraphs" % [chapter.id, outcome.id], outcome.paragraphs)
		for i: int in outcome.routes.size():
			_add(sites, "%s/outcomes/%s/routes/%d" % [chapter.id, outcome.id, i], outcome.routes[i].condition)
	for transition: TransitionData in chapter.transitions:
		if transition.bridge != null:
			_add_paragraphs(sites, "%s/transitions/%s/inserts" % [chapter.id, transition.id], transition.bridge.inserts)
		_add_paragraphs(sites, "%s/transitions/%s/coda" % [chapter.id, transition.id], transition.coda)
	return sites


static func _add(sites: Dictionary[String, String], path: String, text: String) -> void:
	if not text.is_empty():
		sites[path] = text


static func _add_paragraphs(sites: Dictionary[String, String], path: String, paragraphs: Array[ParagraphData]) -> void:
	for i: int in paragraphs.size():
		_add(sites, "%s/%d" % [path, i], paragraphs[i].condition)
