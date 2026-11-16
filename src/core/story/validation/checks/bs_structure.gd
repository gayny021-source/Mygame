class_name BsStructure
extends RefCounted
## Structural checks of one chapter graph (branching-story.md, Core Rules 3–6, 9, 12; AC-02…AC-06, AC-09):
## BS-02 option form and single use, BS-03 dead ends, BS-04 reachability, BS-05 loops and last
## entries, BS-06 paragraph structure, BS-09 the safe option with a price. Conditions are never evaluated.
## Not here: word and paragraph limits of F4 (warnings, story S5) and the proposed bridge punctuation check.

const INSERT_MARK := "{insert}"
const PRICE := "price"


## Appends the findings for `graph.chapter` to `issues`.
static func check(hero: HeroData, graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var flags: Dictionary[String, FlagDecl] = {}
	for decl: FlagDecl in hero.flags:
		flags[decl.id] = decl
	_option_form(graph, issues)
	_single_use(graph, issues)
	_dead_ends(graph, issues)
	_reachability(graph, issues)
	_loops_and_last_entries(graph, flags, issues)
	_paragraphs(graph, options, issues)
	_bridges_and_codas(graph, issues)
	_safe_price(graph, flags, issues)


static func _scene_path(graph: StoryGraph, scene: SceneData) -> String:
	return "%s/scenes/%s" % [graph.chapter.id, scene.id]


static func _option_path(graph: StoryGraph, scene: SceneData, option: OptionData) -> String:
	return "%s/options/%s" % [_scene_path(graph, scene), option.id]


static func _outcome_path(graph: StoryGraph, outcome: OutcomeData) -> String:
	return "%s/outcomes/%s" % [graph.chapter.id, outcome.id]


static func _transition_path(graph: StoryGraph, transition: TransitionData) -> String:
	return "%s/transitions/%s" % [graph.chapter.id, transition.id]


static func _has_unconditional(paragraphs: Array[ParagraphData]) -> bool:
	for paragraph: ParagraphData in paragraphs:
		if paragraph.condition.is_empty():
			return true
	return false


# BS-02: a risky option has a check and no outcome; any other has an outcome and no check.
static func _option_form(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	for scene: SceneData in graph.chapter.scenes:
		for option: OptionData in scene.options:
			var problem: String = _option_problem(option)
			if not problem.is_empty():
				GraphValidator.report(issues, "BS-02", _option_path(graph, scene, option), option.id, problem)


static func _option_problem(option: OptionData) -> String:
	if option.kind == OptionData.KIND_RISKY:
		if option.check == null:
			return "рискованный вариант без проверки"
		if not option.outcome.is_empty():
			return "рискованный вариант с исходом"
		if option.check.success == option.check.failure:
			return "успех и провал проверки — один исход"
		return ""
	if option.check != null:
		return "вариант без риска с проверкой"
	if option.outcome.is_empty():
		return "вариант без исхода"
	return ""


# BS-02: an outcome belongs to one option, a transition to the outcomes of one scene.
static func _single_use(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	var outcome_owner: Dictionary[String, String] = {}
	var transition_owner: Dictionary[String, String] = {}
	var reported: Dictionary[String, bool] = {}
	for scene: SceneData in graph.chapter.scenes:
		for option: OptionData in scene.options:
			var option_key: String = "%s/%s" % [scene.id, option.id]
			for outcome_id: String in graph.option_outcomes(option):
				var owner: String = outcome_owner.get(outcome_id, option_key)
				outcome_owner[outcome_id] = owner
				if owner != option_key and not reported.has("o:" + outcome_id):
					reported["o:" + outcome_id] = true
					GraphValidator.report(issues, "BS-02", "%s/outcomes/%s" % [graph.chapter.id, outcome_id], outcome_id, "исход назван вариантами «%s» и «%s»" % [owner, option_key])
				_claim_transitions(graph, scene, outcome_id, transition_owner, reported, issues)


static func _claim_transitions(graph: StoryGraph, scene: SceneData, outcome_id: String, owner: Dictionary[String, String], reported: Dictionary[String, bool], issues: Array[DataIssue]) -> void:
	var outcome: OutcomeData = graph.outcome_by_id.get(outcome_id)
	if outcome == null:
		return
	for route: RouteData in outcome.routes:
		var first: String = owner.get(route.transition, scene.id)
		owner[route.transition] = first
		if first != scene.id and not reported.has("t:" + route.transition):
			reported["t:" + route.transition] = true
			GraphValidator.report(issues, "BS-02", "%s/transitions/%s" % [graph.chapter.id, route.transition], route.transition, "переход назван исходами сцен «%s» и «%s»" % [first, scene.id])


# BS-03: every scene has an option open at any flags; every outcome has routes; a failure does not lead back into its scene.
static func _dead_ends(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	for scene: SceneData in graph.chapter.scenes:
		if not _has_open_option(scene):
			GraphValidator.report(issues, "BS-03", _scene_path(graph, scene), scene.id, "нет варианта без проверки и без условия")
		for option: OptionData in scene.options:
			if option.check != null and graph.outcome_leads_into(option.check.failure, scene.id):
				GraphValidator.report(issues, "BS-03", _option_path(graph, scene, option), option.id, "провал проверки ведёт в сцену этой же проверки")
	for outcome: OutcomeData in graph.chapter.outcomes:
		if outcome.routes.is_empty():
			GraphValidator.report(issues, "BS-03", _outcome_path(graph, outcome), outcome.id, "у исхода нет переходов")


static func _has_open_option(scene: SceneData) -> bool:
	for option: OptionData in scene.options:
		if option.kind != OptionData.KIND_RISKY and option.check == null and option.condition.is_empty():
			return true
	return false


# BS-04: scenes reachable from the starts; outcomes named by an option; transitions named by such an outcome.
static func _reachability(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	var seen: Dictionary[String, bool] = StoryGraph.as_set(graph.reachable(graph.entry_scenes()))
	var named_outcomes: Dictionary[String, bool] = {}
	var named_transitions: Dictionary[String, bool] = {}
	for scene: SceneData in graph.chapter.scenes:
		if not seen.has(scene.id) and not scene.deprecated:
			GraphValidator.report(issues, "BS-04", _scene_path(graph, scene), scene.id, "в сцену не ведёт ни одна запись starts и ни один переход")
		for outcome_id: String in graph.scene_outcomes(scene):
			named_outcomes[outcome_id] = true
	for outcome: OutcomeData in graph.chapter.outcomes:
		if not named_outcomes.has(outcome.id):
			if not outcome.deprecated:
				GraphValidator.report(issues, "BS-04", _outcome_path(graph, outcome), outcome.id, "исход не назван ни одним вариантом")
			continue
		for route: RouteData in outcome.routes:
			named_transitions[route.transition] = true
	for transition: TransitionData in graph.chapter.transitions:
		if not named_transitions.has(transition.id) and not transition.deprecated:
			GraphValidator.report(issues, "BS-04", _transition_path(graph, transition), transition.id, "на переход не ссылается ни один исход")


# BS-05: no loops; the last start and the last route have no `if`; starts read only `run` flags.
static func _loops_and_last_entries(graph: StoryGraph, flags: Dictionary[String, FlagDecl], issues: Array[DataIssue]) -> void:
	for edge: PackedStringArray in graph.back_edges():
		GraphValidator.report(issues, "BS-05", "%s/scenes/%s" % [graph.chapter.id, edge[0]], edge[0], "сцена ведёт назад в «%s»: цикл" % edge[1])
	var starts: Array[StartData] = graph.chapter.starts
	if not starts.is_empty() and not starts[-1].condition.is_empty():
		GraphValidator.report(issues, "BS-05", "%s/starts/%s" % [graph.chapter.id, starts[-1].id], starts[-1].id, "у последней записи starts есть if")
	for outcome: OutcomeData in graph.chapter.outcomes:
		if not outcome.routes.is_empty() and not outcome.routes[-1].condition.is_empty():
			GraphValidator.report(issues, "BS-05", _outcome_path(graph, outcome), outcome.id, "у последней записи routes есть if")
	var known: ConditionVocabulary = _vocabulary(flags)
	for start: StartData in starts:
		var chapter_flag: String = _chapter_flag_read(start.condition, known, flags)
		if not chapter_flag.is_empty():
			GraphValidator.report(issues, "BS-05", "%s/starts/%s" % [graph.chapter.id, start.id], start.id, "условие старта читает флаг области chapter «%s»" % chapter_flag)


static func _vocabulary(flags: Dictionary[String, FlagDecl]) -> ConditionVocabulary:
	var declared: Array[FlagDecl] = []
	declared.assign(flags.values())
	return FlagLoader.vocabulary(declared)


# The first flag of scope `chapter` that the condition reads, or "". A condition that does not parse is DT-08 of the loader.
static func _chapter_flag_read(text: String, known: ConditionVocabulary, flags: Dictionary[String, FlagDecl]) -> String:
	if text.is_empty():
		return ""
	var parsed: ConditionParser.ParseResult = ConditionParser.parse(text, known)
	if parsed.condition == null:
		return ""
	for id: String in FlagUsage.flags_in(parsed.condition, flags):
		if flags[id].scope == FlagDecl.SCOPE_CHAPTER:
			return id
	return ""


# BS-06: an unconditional paragraph in scenes and outcomes; a choice scene ends on one; at most OPTIONS_MAX options.
static func _paragraphs(graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var linear_outcomes: PackedStringArray = []
	for scene: SceneData in graph.chapter.scenes:
		if scene.options.size() == 1 and scene.options[0].check == null:
			linear_outcomes.append(scene.options[0].outcome)
		var last_is_open: bool = not scene.paragraphs.is_empty() and scene.paragraphs[-1].condition.is_empty()
		if not _has_unconditional(scene.paragraphs):
			GraphValidator.report(issues, "BS-06", _scene_path(graph, scene), scene.id, "в сцене нет безусловного абзаца")
		elif scene.options.size() >= 2 and not last_is_open:
			GraphValidator.report(issues, "BS-06", _scene_path(graph, scene), scene.id, "последний абзац сцены выбора с условием")
		if scene.options.size() > options.options_max:
			GraphValidator.report(issues, "BS-06", _scene_path(graph, scene), scene.id, "вариантов %d, не больше %d" % [scene.options.size(), options.options_max])
	for outcome: OutcomeData in graph.chapter.outcomes:
		if not linear_outcomes.has(outcome.id) and not _has_unconditional(outcome.paragraphs):
			GraphValidator.report(issues, "BS-06", _outcome_path(graph, outcome), outcome.id, "в исходе нет безусловного абзаца")


# BS-06: a bridge is one paragraph with the insert mark exactly when it has inserts; the end of a chapter has a coda.
static func _bridges_and_codas(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	for transition: TransitionData in graph.chapter.transitions:
		var path: String = _transition_path(graph, transition)
		if transition.to_kind == TransitionData.TO_SCENE:
			_check_bridge(transition, path, issues)
		elif transition.to_kind == TransitionData.TO_CHAPTER_END:
			if transition.coda.is_empty():
				GraphValidator.report(issues, "BS-06", path, transition.id, "у конца главы нет коды")
			elif not transition.coda[-1].condition.is_empty():
				GraphValidator.report(issues, "BS-06", path, transition.id, "последний абзац коды с условием")


static func _check_bridge(transition: TransitionData, path: String, issues: Array[DataIssue]) -> void:
	if transition.bridge == null:
		GraphValidator.report(issues, "BS-06", path, transition.id, "у перехода в сцену нет моста")
		return
	var base: String = transition.bridge.base
	if base.strip_edges().contains("\n"):
		GraphValidator.report(issues, "BS-06", path, transition.id, "мост — больше одного абзаца")
	var marks: int = base.count(INSERT_MARK)
	var wanted: int = 1 if not transition.bridge.inserts.is_empty() else 0
	if marks != wanted:
		GraphValidator.report(issues, "BS-06", path, transition.id, "отметок %s: %d, нужно %d" % [INSERT_MARK, marks, wanted])


# BS-09: a scene with a risky option has an unconditional safe option that sets exactly one `price` flag.
static func _safe_price(graph: StoryGraph, flags: Dictionary[String, FlagDecl], issues: Array[DataIssue]) -> void:
	for scene: SceneData in graph.chapter.scenes:
		if not _has_risky(scene) or _has_priced_safe_option(graph, scene, flags):
			continue
		GraphValidator.report(issues, "BS-09", _scene_path(graph, scene), scene.id, "при рискованном варианте нет безопасного без условия, ставящего ровно один флаг price")


static func _has_risky(scene: SceneData) -> bool:
	for option: OptionData in scene.options:
		if option.kind == OptionData.KIND_RISKY:
			return true
	return false


static func _has_priced_safe_option(graph: StoryGraph, scene: SceneData, flags: Dictionary[String, FlagDecl]) -> bool:
	for option: OptionData in scene.options:
		if option.kind != OptionData.KIND_SAFE or not option.condition.is_empty():
			continue
		var outcome: OutcomeData = graph.outcome_by_id.get(option.outcome)
		if outcome != null and _price_count(outcome, flags) == 1:
			return true
	return false


static func _price_count(outcome: OutcomeData, flags: Dictionary[String, FlagDecl]) -> int:
	var total: int = 0
	for id: String in outcome.sets:
		var decl: FlagDecl = flags.get(id)
		if decl != null and decl.category == PRICE:
			total += 1
	return total
