class_name BsTraces
extends RefCounted
## Meaning checks on flags and traces (branching-story.md, Core Rules 7 and 12; AC-07, AC-08, AC-11, AC-12,
## AC-17, AC-24; story S5): BS-07 fake choice, BS-08 equal success and failure, BS-11 a condition no outcome
## can make true, BS-12 dead places (a route below an always-true one, two flags of one group at once, a goal
## fail flag nothing sets), BS-17 a node that reads nothing, BS-24 a wound without damage.
## Not here (no input in the data yet): `price` read only by an epilogue line, the dead branch of F6 and the
## "true on no path" algorithm of O-5; the CLI lists them as not assessed.

const WOUND := "wound"


## Appends the findings of one chapter to `issues`.
static func check(hero: HeroData, graph: StoryGraph, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	_fake_choices(graph, usage, issues)
	_dead_routes(graph, issues)
	_group_clashes(graph, usage, issues)
	_silent_nodes(hero, graph, issues)
	_wounds(graph, usage, issues)


## Appends the hero-wide findings: BS-11 and the BS-12 of goal fail flags.
static func check_hero(hero: HeroData, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	var unset: Dictionary[String, bool] = {}
	for id: String in usage.named:
		if not usage.set_by_outcome.has(id):
			unset[id] = true
	for chapter: ChapterData in hero.chapters:
		var flag: String = chapter.goal_fail_flag
		if flag.is_empty() or usage.set_by_outcome.has(flag):
			continue
		unset[flag] = true
		GraphValidator.report(issues, "BS-12", "%s/goal_fail_flag" % chapter.id, flag, "флаг провала цели «%s» не ставит ни один исход: вход под провал мёртв" % flag, DataIssue.WARNING)
	for id: String in unset:
		GraphValidator.report(issues, "BS-11", "%s/flags/%s" % [hero.id, id], id, "флаг «%s» читается, но его не ставит ни один исход героя" % id, DataIssue.WARNING)


# Trace of an outcome: readable flags it sets (+) or clears (-) and the targets of its routes, sorted.
static func _outcome_trace(graph: StoryGraph, usage: FlagUsage, outcome_id: String) -> String:
	var outcome: OutcomeData = graph.outcome_by_id.get(outcome_id)
	if outcome == null:
		return ""
	var parts: PackedStringArray = []
	for id: String in outcome.sets:
		if usage.read.has(id):
			parts.append("+" + id)
	for id: String in outcome.clears:
		if usage.read.has(id):
			parts.append("-" + id)
	for route: RouteData in outcome.routes:
		var transition: TransitionData = graph.transition_by_id.get(route.transition)
		if transition == null:
			continue
		var target: String = "%s:%s" % [transition.to_kind, transition.to_id]
		if not parts.has(target):
			parts.append(target)
	parts.sort()
	return ",".join(parts)


# Trace of an option: its outcome's, or the pair success | failure of a risky one; empty when a part is empty.
static func _option_trace(graph: StoryGraph, usage: FlagUsage, option: OptionData) -> String:
	if option.check == null:
		return _outcome_trace(graph, usage, option.outcome)
	var success: String = _outcome_trace(graph, usage, option.check.success)
	var failure: String = _outcome_trace(graph, usage, option.check.failure)
	if success.is_empty() or failure.is_empty():
		return ""
	return "%s | %s" % [success, failure]


# BS-07 (error) in scenes of two or more options, BS-08 (warning) for every check; `exception` lifts both.
static func _fake_choices(graph: StoryGraph, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	for scene: SceneData in graph.chapter.scenes:
		var path: String = "%s/scenes/%s" % [graph.chapter.id, scene.id]
		var traces: PackedStringArray = []
		for option: OptionData in scene.options:
			traces.append(_option_trace(graph, usage, option))
			_equal_ends(graph, usage, option, path, issues)
		if scene.options.size() < 2:
			continue
		for i: int in scene.options.size():
			var first: OptionData = scene.options[i]
			if not first.exception.is_empty():
				continue
			if traces[i].is_empty():
				GraphValidator.report(issues, "BS-07", "%s/options/%s" % [path, first.id], first.id, "след варианта пуст: он не ставит читаемых флагов и никуда не ведёт")
				continue
			for j: int in range(i + 1, scene.options.size()):
				var second: OptionData = scene.options[j]
				if second.exception.is_empty() and traces[j] == traces[i]:
					GraphValidator.report(issues, "BS-07", "%s/options/%s" % [path, second.id], second.id, "след варианта равен следу «%s» (%s): фальшивый выбор" % [first.id, traces[i]])


static func _equal_ends(graph: StoryGraph, usage: FlagUsage, option: OptionData, path: String, issues: Array[DataIssue]) -> void:
	if option.check == null or not option.exception.is_empty():
		return
	var success: String = _outcome_trace(graph, usage, option.check.success)
	if success.is_empty() or success != _outcome_trace(graph, usage, option.check.failure):
		return
	GraphValidator.report(issues, "BS-08", "%s/options/%s" % [path, option.id], option.id, "у успеха и провала один след (%s)" % success, DataIssue.WARNING)


# BS-12: a route below an unconditional route or below a route with the same condition is never taken.
static func _dead_routes(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	for outcome: OutcomeData in graph.chapter.outcomes:
		var above: PackedStringArray = []
		for i: int in outcome.routes.size():
			var condition: String = outcome.routes[i].condition
			if above.has("") or above.has(condition):
				GraphValidator.report(issues, "BS-12", "%s/outcomes/%s/routes/%d" % [graph.chapter.id, outcome.id, i], outcome.id, "запись routes не выбирается никогда: выше запись, истинная при тех же флагах", DataIssue.WARNING)
			above.append(condition)


# BS-12: a condition that needs two flags of one displacement group standing at once is never true.
static func _group_clashes(graph: StoryGraph, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	var sites: Dictionary[String, String] = FlagUsage.condition_sites(graph.chapter)
	for path: String in sites:
		var node: Condition = usage.parse(sites[path])
		var group: String = "" if node == null else _clash(node, usage.decls)
		if not group.is_empty():
			GraphValidator.report(issues, "BS-12", path, path.get_slice("/", 2), "условие «%s» требует сразу двух флагов группы «%s»: оно ложно всегда" % [sites[path], group], DataIssue.WARNING)


# The group of which an `and` needs two flags at once, or "".
static func _clash(node: Condition, decls: Dictionary[String, FlagDecl]) -> String:
	if node.kind == Condition.Kind.AND:
		var groups: Dictionary[String, String] = {}
		for id: String in _required(node):
			var decl: FlagDecl = decls.get(id)
			if decl == null or decl.group.is_empty():
				continue
			if groups.has(decl.group) and groups[decl.group] != id:
				return decl.group
			groups[decl.group] = id
	for child: Condition in node.children:
		var inner: String = _clash(child, decls)
		if not inner.is_empty():
			return inner
	return ""


# Flags an `and` chain needs standing: plain flags and `group(g) == f`, through nested `and`.
static func _required(node: Condition) -> PackedStringArray:
	var ids: PackedStringArray = []
	for child: Condition in node.children:
		match child.kind:
			Condition.Kind.FLAG, Condition.Kind.GROUP:
				ids.append(child.flags[0])
			Condition.Kind.AND:
				ids.append_array(_required(child))
	return ids


# BS-17: a node reads a flag in a bridge into it, a paragraph or an option. The start scene of the hero's first chapter is exempt.
static func _silent_nodes(hero: HeroData, graph: StoryGraph, issues: Array[DataIssue]) -> void:
	var first_chapter: bool = not hero.chapter_ids.is_empty() and hero.chapter_ids[0] == graph.chapter.id
	var entries: PackedStringArray = graph.entry_scenes()
	for scene: SceneData in graph.chapter.scenes:
		if not scene.node or (first_chapter and entries.has(scene.id)):
			continue
		if not _reads(graph, scene):
			GraphValidator.report(issues, "BS-17", "%s/scenes/%s" % [graph.chapter.id, scene.id], scene.id, "узловая сцена не читает ни одного флага в мосте, абзаце или варианте", DataIssue.WARNING)


static func _reads(graph: StoryGraph, scene: SceneData) -> bool:
	for paragraph: ParagraphData in scene.paragraphs:
		if not paragraph.condition.is_empty():
			return true
	for option: OptionData in scene.options:
		if not option.condition.is_empty():
			return true
	for transition: TransitionData in graph.chapter.transitions:
		if transition.to_kind != TransitionData.TO_SCENE or transition.to_id != scene.id or transition.bridge == null:
			continue
		for insert: ParagraphData in transition.bridge.inserts:
			if not insert.condition.is_empty():
				return true
	return false


# BS-24: an outcome that sets a `wound` flag has `damage` in one of its own paragraphs.
static func _wounds(graph: StoryGraph, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	for outcome: OutcomeData in graph.chapter.outcomes:
		var wound: String = ""
		for id: String in outcome.sets:
			var decl: FlagDecl = usage.decls.get(id)
			if decl != null and decl.category == WOUND:
				wound = id
		if wound.is_empty() or _has_damage(outcome):
			continue
		GraphValidator.report(issues, "BS-24", "%s/outcomes/%s" % [graph.chapter.id, outcome.id], outcome.id, "исход ставит рану «%s», но ни в одном его абзаце нет damage" % wound, DataIssue.WARNING)


static func _has_damage(outcome: OutcomeData) -> bool:
	for paragraph: ParagraphData in outcome.paragraphs:
		if not paragraph.damage.is_empty():
			return true
	return false
