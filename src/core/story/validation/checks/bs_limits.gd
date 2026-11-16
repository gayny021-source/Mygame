class_name BsLimits
extends RefCounted
## Screen limits of F4 (branching-story.md, F4; AC-31) as BS-06 warnings, and the bridge punctuation of
## UR-1 (proposal for BS-06, AC-06, O-16) as BS-06 errors; story S5. A warning message starts with its tag
## `F4/<limit>`, an error with `UR-1`. The worst flag set counts: every condition true, the longest insert.
## The option count limit (an error) is BS-06 of BsStructure.

const SIGNS := ",.;:!?…"
const DANGLING := ",;:-–—"


## Appends the findings of one chapter to `issues`.
static func check(graph: StoryGraph, usage: FlagUsage, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var chapter: ChapterData = graph.chapter
	for scene: SceneData in chapter.scenes:
		var path: String = "%s/scenes/%s" % [chapter.id, scene.id]
		_paragraph_words(scene.paragraphs, path, scene.id, options, issues)
		_scene_screen(graph, scene, path, usage, options, issues)
		var past: int = 0
		for option: OptionData in scene.options:
			if not option.condition.is_empty() and option.exception.is_empty():
				past += 1
		if past > options.past_options_max:
			_warn(issues, "F4/past", path, scene.id, "вариантов от прошлого %d, не больше %d" % [past, options.past_options_max])
	for outcome: OutcomeData in chapter.outcomes:
		var path: String = "%s/outcomes/%s" % [chapter.id, outcome.id]
		_paragraph_words(outcome.paragraphs, path, outcome.id, options, issues)
		if outcome.paragraphs.size() > options.outcome_paragraphs_max:
			_warn(issues, "F4/outcome", path, outcome.id, "абзацев в исходе %d, не больше %d" % [outcome.paragraphs.size(), options.outcome_paragraphs_max])
	for transition: TransitionData in chapter.transitions:
		var path: String = "%s/transitions/%s" % [chapter.id, transition.id]
		_paragraph_words(transition.coda, path, transition.id, options, issues)
		if transition.coda.size() > options.coda_paragraphs_max:
			_warn(issues, "F4/coda", path, transition.id, "абзацев в коде %d, не больше %d" % [transition.coda.size(), options.coda_paragraphs_max])
		if transition.bridge != null:
			_bridge(transition, path, options, issues)


static func _warn(issues: Array[DataIssue], tag: String, path: String, object_id: String, message: String) -> void:
	GraphValidator.report(issues, "BS-06", path, object_id, "%s: %s" % [tag, message], DataIssue.WARNING)


static func _paragraph_words(paragraphs: Array[ParagraphData], path: String, object_id: String, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	for i: int in paragraphs.size():
		var count: int = ChapterPaths.words(paragraphs[i].text)
		if count > options.paragraph_words_max:
			_warn(issues, "F4/words", "%s/paragraphs/%d" % [path, i], object_id, "в абзаце %d слов, не больше %d" % [count, options.paragraph_words_max])


# The screen of a scene: the bridge into it plus its paragraphs; conditional paragraphs; flags read by the prose.
static func _scene_screen(graph: StoryGraph, scene: SceneData, path: String, usage: FlagUsage, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var with_bridge: int = 0
	var prose: PackedStringArray = []
	for transition: TransitionData in graph.chapter.transitions:
		if transition.to_kind != TransitionData.TO_SCENE or transition.to_id != scene.id or transition.bridge == null:
			continue
		with_bridge = 1
		for insert: ParagraphData in transition.bridge.inserts:
			prose.append(insert.condition)
	var conditional: int = 0
	for paragraph: ParagraphData in scene.paragraphs:
		if not paragraph.condition.is_empty():
			conditional += 1
		prose.append(paragraph.condition)
	var screen: int = with_bridge + scene.paragraphs.size()
	if screen > options.screen_paragraphs_max:
		_warn(issues, "F4/screen", path, scene.id, "абзацев на экране сцены (с мостом) %d, не больше %d" % [screen, options.screen_paragraphs_max])
	if conditional > options.conditional_paragraphs_max:
		_warn(issues, "F4/conditional", path, scene.id, "условных абзацев %d, не больше %d" % [conditional, options.conditional_paragraphs_max])
	var flags: Dictionary[String, bool] = {}
	for text: String in prose:
		flags.merge(StoryGraph.as_set(usage.flags_of(text)))
	if flags.size() > options.prose_flags_max:
		_warn(issues, "F4/flags", path, scene.id, "проза сцены читает флагов %d, не больше %d" % [flags.size(), options.prose_flags_max])


# F4 words of the bridge with its longest insert, and UR-1 on the base without the insert.
static func _bridge(transition: TransitionData, path: String, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var base: String = transition.bridge.base.replace(BsStructure.INSERT_MARK, "")
	var longest: int = 0
	for insert: ParagraphData in transition.bridge.inserts:
		longest = maxi(longest, ChapterPaths.words(insert.text))
	var count: int = ChapterPaths.words(base) + longest
	if count > options.paragraph_words_max:
		_warn(issues, "F4/bridge", path, transition.id, "в мосте %d слов, не больше %d" % [count, options.paragraph_words_max])
	for problem: String in _punctuation(base):
		GraphValidator.report(issues, "BS-06", path, transition.id, "UR-1: мост «%s»: %s" % [base, problem])


static func _punctuation(text: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	if text.strip_edges().is_empty():
		problems.append("пустой абзац")
		return problems
	if text.contains("  "):
		problems.append("двойной пробел")
	for sign: String in SIGNS:
		if text.contains(" " + sign):
			problems.append("пробел перед «%s»" % sign)
	if SIGNS.contains(text[0]):
		problems.append("знак препинания в начале")
	if DANGLING.contains(text[-1]):
		problems.append("висячий знак в конце")
	return problems
