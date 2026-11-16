class_name ChapterLoader
extends RefCounted
## Loads one chapter JSON into typed structures (ADR-0001 §4, story S1). Reports
## DT-01…DT-07 and the chapter part of BS-01 as DataIssue. `if` is parsed
## (DT-08, story S2); with a vocabulary of the hero's flags `if`, sets, clears and
## goal_fail_flag are checked against it (BS-01, story S3), without one only the syntax.

const CHAPTER_KEYS: PackedStringArray = ["schema_version", "id", "title", "goal", "starts", "goal_fail_flag", "milestones", "scenes", "outcomes", "transitions"]
const START_KEYS: PackedStringArray = ["id", "if", "scene", "goal"]
const MILESTONE_KEYS: PackedStringArray = ["id", "step"]
const SCENE_KEYS: PackedStringArray = ["id", "title", "paragraphs", "illustration", "options", "milestone", "node", "final", "deprecated"]
const PARAGRAPH_KEYS: PackedStringArray = ["text", "if", "speaks", "damage"]
const OPTION_KEYS: PackedStringArray = ["id", "text", "kind", "if", "reason", "check", "outcome", "exception"]
const CHECK_KEYS: PackedStringArray = ["id", "stat", "level", "success", "failure", "crit_success_line", "crit_failure_line"]
const OUTCOME_KEYS: PackedStringArray = ["id", "paragraphs", "sets", "clears", "routes", "deprecated"]
const ROUTE_KEYS: PackedStringArray = ["if", "transition"]
const TRANSITION_KEYS: PackedStringArray = ["id", "to", "bridge", "coda", "early", "deprecated"]
const BRIDGE_KEYS: PackedStringArray = ["base", "inserts"]
const INSERT_KEYS: PackedStringArray = ["if", "text"]
const REQUIRED_LISTS: PackedStringArray = ["starts", "scenes", "outcomes", "transitions"]


## Reads and loads the chapter file at `path`. The chapter is in `data` only when there are no issues.
## A lone chapter has no hero, so conditions get the syntax check only.
static func load_file(path: String) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var data: Dictionary = read_object(path, result.issues)
	if not result.issues.is_empty():
		return result
	return load_from_dict(data, path)


## Loads a chapter from parsed JSON; `source` starts every finding's path.
## The chapter is in `data` only when there are no issues. `known` is the hero's flag
## vocabulary; with null only the syntax of conditions is checked.
static func load_from_dict(data: Dictionary, source: String, known: ConditionVocabulary = null) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var chapter: ChapterData = parse(data, source, result.issues, known)
	if result.issues.is_empty():
		result.data = chapter
	return result


## Reads a JSON file whose root is an object. On failure adds DT-01 (no file,
## bad syntax; the path ends with `:<line>`) or DT-02 (root is not an object).
## A contract between the loaders (ChapterLoader, HeroLoader, FlagLoader), not for other code.
static func read_object(path: String, issues: Array[DataIssue]) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		issues.append(DataIssue.new("DT-01", path, "", "файл не открывается: %s" % error_string(FileAccess.get_open_error())))
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		# get_error_line() считает строки с нуля
		issues.append(DataIssue.new("DT-01", "%s:%d" % [path, json.get_error_line() + 1], "", json.get_error_message()))
		return {}
	if not json.data is Dictionary:
		issues.append(DataIssue.new("DT-02", path, "", "корень файла — не объект"))
		return {}
	return json.data


## Builds the chapter and appends its findings to `issues`. Returns null when the
## schema version is not readable; otherwise the chapter, possibly incomplete —
## HeroLoader needs it to check hero-wide references even in a broken chapter.
## `known` is the hero's flag vocabulary (null: syntax of conditions only).
## A contract between the loaders (ChapterLoader, HeroLoader), not for other code.
static func parse(data: Dictionary, source: String, issues: Array[DataIssue], known: ConditionVocabulary = null) -> ChapterData:
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(CHAPTER_KEYS):
		return null
	var chapter: ChapterData = ChapterData.new()
	chapter.id = reader.id()
	chapter.title = reader.text("title")
	chapter.goal = reader.text("goal")
	chapter.goal_fail_flag = reader.text("goal_fail_flag", false)
	for item: DictReader in reader.children("starts", START_KEYS):
		chapter.starts.append(_start(item))
	for item: DictReader in reader.children("milestones", MILESTONE_KEYS, false):
		chapter.milestones.append(_milestone(item))
	for item: DictReader in reader.children("scenes", SCENE_KEYS):
		chapter.scenes.append(_scene(item))
	for item: DictReader in reader.children("outcomes", OUTCOME_KEYS):
		chapter.outcomes.append(_outcome(item))
	for item: DictReader in reader.children("transitions", TRANSITION_KEYS):
		chapter.transitions.append(_transition(item))
	# условия и флаги не зависят от ссылок между списками: проверка идёт и в неполной главе
	_check_conditions(chapter, source, known, issues)
	for key: String in REQUIRED_LISTS:
		# без списка (о нём уже есть DT-03 или DT-02) проверка ссылок дала бы только вторичные BS-01
		if not reader.has_list(key):
			return chapter
	# milestones необязателен: мешает только ключ неверного типа
	if reader.has("milestones") and not reader.has_list("milestones"):
		return chapter
	_check_references(chapter, source, issues)
	return chapter


## Ids that must be unique in the hero's data: scenes, options, checks, outcomes
## and transitions of the chapter (branching-story.md, Core Rules 2–6).
## A contract between the loaders (ChapterLoader, HeroLoader), not for other code.
static func owned_ids(chapter: ChapterData) -> PackedStringArray:
	var ids: PackedStringArray = []
	for scene: SceneData in chapter.scenes:
		ids.append(scene.id)
		for option: OptionData in scene.options:
			ids.append(option.id)
			if option.check != null:
				ids.append(option.check.id)
	for outcome: OutcomeData in chapter.outcomes:
		ids.append(outcome.id)
	for transition: TransitionData in chapter.transitions:
		ids.append(transition.id)
	return ids


static func _start(reader: DictReader) -> StartData:
	var start: StartData = StartData.new()
	start.id = reader.id()
	start.condition = reader.condition()
	start.scene = reader.text("scene")
	start.goal = reader.text("goal", false)
	return start


static func _milestone(reader: DictReader) -> MilestoneData:
	var milestone: MilestoneData = MilestoneData.new()
	milestone.id = reader.id()
	milestone.step = reader.text("step")
	return milestone


static func _scene(reader: DictReader) -> SceneData:
	var scene: SceneData = SceneData.new()
	scene.id = reader.id()
	scene.title = reader.text("title", false)
	_append_paragraphs(scene.paragraphs, reader.children("paragraphs", PARAGRAPH_KEYS, true, true))
	scene.illustration = reader.text("illustration")
	for item: DictReader in reader.children("options", OPTION_KEYS):
		scene.options.append(_option(item))
	scene.milestone = reader.text("milestone", false)
	scene.node = reader.flag("node")
	scene.final = reader.flag("final")
	scene.deprecated = reader.flag("deprecated")
	return scene


static func _append_paragraphs(target: Array[ParagraphData], readers: Array[DictReader]) -> void:
	for reader: DictReader in readers:
		var paragraph: ParagraphData = ParagraphData.new()
		paragraph.text = reader.text("text")
		paragraph.condition = reader.condition()
		paragraph.speaks = reader.text("speaks", false)
		paragraph.damage = reader.text("damage", false)
		target.append(paragraph)


static func _option(reader: DictReader) -> OptionData:
	var option: OptionData = OptionData.new()
	option.id = reader.id()
	option.text = reader.text("text")
	option.kind = reader.one_of("kind", OptionData.KINDS)
	option.condition = reader.condition()
	option.reason = reader.text("reason", false)
	var check_reader: DictReader = reader.child("check", CHECK_KEYS)
	if check_reader != null:
		option.check = _check(check_reader)
	option.outcome = reader.text("outcome", false)
	option.exception = reader.text("exception", false)
	# только форма; согласованность kind и check — BS-02, история S4
	if reader.has_text("outcome") and option.outcome.is_empty():
		reader.issue("DT-02", "outcome", "строка outcome пуста")
	elif reader.has("outcome") and reader.has("check"):
		reader.issue("BS-01", "outcome", "у варианта заданы и outcome, и check — нужен ровно один")
	elif not reader.has("outcome") and not reader.has("check"):
		reader.issue("BS-01", "outcome", "у варианта нет ни outcome, ни check — нужен ровно один")
	return option


static func _check(reader: DictReader) -> CheckData:
	var check: CheckData = CheckData.new()
	check.id = reader.id()
	check.stat = reader.text("stat")
	check.level = reader.one_of("level", CheckData.LEVELS)
	check.success = reader.text("success")
	check.failure = reader.text("failure")
	check.crit_success_line = reader.text("crit_success_line", false)
	check.crit_failure_line = reader.text("crit_failure_line", false)
	return check


static func _outcome(reader: DictReader) -> OutcomeData:
	var outcome: OutcomeData = OutcomeData.new()
	outcome.id = reader.id()
	_append_paragraphs(outcome.paragraphs, reader.children("paragraphs", PARAGRAPH_KEYS, false, true))
	outcome.sets = _flag_ids(reader, "sets")
	outcome.clears = _flag_ids(reader, "clears")
	for item: DictReader in reader.children("routes", ROUTE_KEYS):
		var route: RouteData = RouteData.new()
		route.condition = item.condition()
		route.transition = item.text("transition")
		outcome.routes.append(route)
	outcome.deprecated = reader.flag("deprecated")
	return outcome


# Список id флагов; пустая строка в нём — DT-02, а не молчаливый пропуск.
static func _flag_ids(reader: DictReader, key: String) -> PackedStringArray:
	var by_index: Dictionary = reader.strings_by_index(key, false)
	for i: int in by_index:
		var id: String = by_index[i]
		if id.is_empty():
			reader.issue("DT-02", "%s/%d" % [key, i], "пустой id флага")
	return PackedStringArray(by_index.values())


static func _transition(reader: DictReader) -> TransitionData:
	var transition: TransitionData = TransitionData.new()
	transition.id = reader.id()
	_read_target(transition, reader)
	var bridge_reader: DictReader = reader.child("bridge", BRIDGE_KEYS)
	if bridge_reader != null:
		transition.bridge = BridgeData.new()
		transition.bridge.base = bridge_reader.text("base")
		_append_paragraphs(transition.bridge.inserts, bridge_reader.children("inserts", INSERT_KEYS, false))
	_append_paragraphs(transition.coda, reader.children("coda", PARAGRAPH_KEYS, false, true))
	transition.early = reader.flag("early")
	transition.deprecated = reader.flag("deprecated")
	return transition


static func _read_target(transition: TransitionData, reader: DictReader) -> void:
	var to: String = reader.text("to")
	var parts: PackedStringArray = to.split(":")
	var with_id: bool = parts.size() == 2 and not parts[1].is_empty()
	if to == TransitionData.TO_CHAPTER_END:
		transition.to_kind = to
	elif with_id and (parts[0] == TransitionData.TO_SCENE or parts[0] == TransitionData.TO_ENDING):
		transition.to_kind = parts[0]
		transition.to_id = parts[1]
	elif not to.is_empty():
		reader.issue("DT-05", "to", "значение «%s» — не scene:<id>, chapter_end или ending:<id>" % to)


# BS-01 внутри главы: граф не пуст, id уникальны, ссылки на сцены, исходы и переходы существуют.
static func _check_references(chapter: ChapterData, source: String, issues: Array[DataIssue]) -> void:
	if chapter.starts.is_empty():
		issues.append(DataIssue.new("BS-01", source + "/starts", chapter.id, "в главе нет ни одной записи starts"))
	if chapter.scenes.is_empty():
		issues.append(DataIssue.new("BS-01", source + "/scenes", chapter.id, "в главе нет ни одной сцены"))
	var milestone_ids: PackedStringArray = _ids(chapter.milestones)
	var scene_ids: PackedStringArray = _ids(chapter.scenes)
	var outcome_ids: PackedStringArray = _ids(chapter.outcomes)
	var transition_ids: PackedStringArray = _ids(chapter.transitions)
	_report_repeats(_ids(chapter.starts), source + "/starts", issues)
	_report_repeats(milestone_ids, source + "/milestones", issues)
	_report_repeats(owned_ids(chapter), source, issues)
	for i: int in chapter.starts.size():
		var start: StartData = chapter.starts[i]
		var start_path: String = "%s/starts/%s" % [source, DictReader.label(start.id, i)]
		_require(start.scene, scene_ids, start_path + "/scene", start.id, issues)
	for i: int in chapter.scenes.size():
		var scene: SceneData = chapter.scenes[i]
		var scene_path: String = "%s/scenes/%s" % [source, DictReader.label(scene.id, i)]
		_require(scene.milestone, milestone_ids, scene_path + "/milestone", scene.id, issues)
		for j: int in scene.options.size():
			var option: OptionData = scene.options[j]
			var option_path: String = "%s/options/%s" % [scene_path, DictReader.label(option.id, j)]
			if not option.outcome.is_empty():
				_require(option.outcome, outcome_ids, option_path + "/outcome", option.id, issues)
			if option.check != null:
				_require(option.check.success, outcome_ids, option_path + "/check/success", option.check.id, issues)
				_require(option.check.failure, outcome_ids, option_path + "/check/failure", option.check.id, issues)
	for i: int in chapter.outcomes.size():
		var outcome: OutcomeData = chapter.outcomes[i]
		var outcome_path: String = "%s/outcomes/%s" % [source, DictReader.label(outcome.id, i)]
		for j: int in outcome.routes.size():
			_require(outcome.routes[j].transition, transition_ids, "%s/routes/%d/transition" % [outcome_path, j], outcome.id, issues)
	for i: int in chapter.transitions.size():
		var transition: TransitionData = chapter.transitions[i]
		if transition.to_kind == TransitionData.TO_SCENE:
			var transition_path: String = "%s/transitions/%s" % [source, DictReader.label(transition.id, i)]
			_require(transition.to_id, scene_ids, transition_path + "/to", transition.id, issues)


# Разбор `if` везде, где условие может стоять; с `known` ещё и флаги sets, clears, goal_fail_flag.
static func _check_conditions(chapter: ChapterData, source: String, known: ConditionVocabulary, issues: Array[DataIssue]) -> void:
	for i: int in chapter.starts.size():
		var start: StartData = chapter.starts[i]
		_check_condition(start.condition, "%s/starts/%s" % [source, DictReader.label(start.id, i)], start.id, known, issues)
	for i: int in chapter.scenes.size():
		var scene: SceneData = chapter.scenes[i]
		var scene_path: String = "%s/scenes/%s" % [source, DictReader.label(scene.id, i)]
		_check_paragraphs(scene.paragraphs, scene_path + "/paragraphs", scene.id, known, issues)
		for j: int in scene.options.size():
			var option: OptionData = scene.options[j]
			_check_condition(option.condition, "%s/options/%s" % [scene_path, DictReader.label(option.id, j)], option.id, known, issues)
	for i: int in chapter.outcomes.size():
		var outcome: OutcomeData = chapter.outcomes[i]
		var outcome_path: String = "%s/outcomes/%s" % [source, DictReader.label(outcome.id, i)]
		_check_paragraphs(outcome.paragraphs, outcome_path + "/paragraphs", outcome.id, known, issues)
		for j: int in outcome.routes.size():
			_check_condition(outcome.routes[j].condition, "%s/routes/%d" % [outcome_path, j], outcome.id, known, issues)
		_check_declared(outcome.sets, outcome_path + "/sets", true, outcome.id, known, issues)
		_check_declared(outcome.clears, outcome_path + "/clears", true, outcome.id, known, issues)
	for i: int in chapter.transitions.size():
		var transition: TransitionData = chapter.transitions[i]
		var transition_path: String = "%s/transitions/%s" % [source, DictReader.label(transition.id, i)]
		if transition.bridge != null:
			_check_paragraphs(transition.bridge.inserts, transition_path + "/bridge/inserts", transition.id, known, issues)
		_check_paragraphs(transition.coda, transition_path + "/coda", transition.id, known, issues)
	_check_declared(PackedStringArray([chapter.goal_fail_flag]), source + "/goal_fail_flag", false, chapter.id, known, issues)


static func _check_paragraphs(paragraphs: Array[ParagraphData], path: String, owner_id: String, known: ConditionVocabulary, issues: Array[DataIssue]) -> void:
	for i: int in paragraphs.size():
		_check_condition(paragraphs[i].condition, "%s/%d" % [path, i], owner_id, known, issues)


# Пустой `if` (ключа нет) пропущен; пустую строку DictReader уже назвал DT-08.
static func _check_condition(text: String, path: String, owner_id: String, known: ConditionVocabulary, issues: Array[DataIssue]) -> void:
	if text.is_empty():
		return
	for issue: DataIssue in ConditionParser.parse(text, known).issues:
		issue.path = path + "/if"
		issue.object_id = owner_id
		issues.append(issue)


# Список id флагов (sets, clears, goal_fail_flag) против объявлений героя; без `known` не проверяется.
# Пустой id: ключа нет (goal_fail_flag) или о нём уже есть DT-02 (sets, clears).
static func _check_declared(ids: PackedStringArray, path: String, indexed: bool, owner_id: String, known: ConditionVocabulary, issues: Array[DataIssue]) -> void:
	if known == null:
		return
	for i: int in ids.size():
		if ids[i].is_empty() or known.flags.has(ids[i]):
			continue
		var id_path: String = "%s/%d" % [path, i] if indexed else path
		issues.append(DataIssue.new("BS-01", id_path, owner_id, "флаг «%s» не объявлен у героя" % ids[i]))


static func _ids(items: Array) -> PackedStringArray:
	var ids: PackedStringArray = []
	for item: RefCounted in items:
		var id: String = item.get("id")
		ids.append(id)
	return ids


static func _report_repeats(ids: PackedStringArray, prefix: String, issues: Array[DataIssue]) -> void:
	var seen: PackedStringArray = []
	for id: String in ids:
		if id.is_empty():
			continue
		if seen.has(id):
			issues.append(DataIssue.new("BS-01", "%s/%s" % [prefix, id], id, "id «%s» повторяется" % id))
		seen.append(id)


static func _require(target: String, known: PackedStringArray, path: String, owner_id: String, issues: Array[DataIssue]) -> void:
	# пустая ссылка: ключа нет (необязательный) или о нём уже есть DT-находка
	if target.is_empty() or known.has(target):
		return
	issues.append(DataIssue.new("BS-01", path, owner_id, "ссылка на несуществующий id «%s»" % target))
