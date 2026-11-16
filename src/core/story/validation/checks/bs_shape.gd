class_name BsShape
extends RefCounted
## BS-10, the shape of a chapter (branching-story.md, Core Rules 2 and 10; F1, F8; AC-10): entry
## scenes of one scene each lead into the first common scene; the spine runs from it to the one
## final node; exactly one side branch leaves one spine scene and rejoins; nodes sit on the spine;
## the finales are FINALES_BASE open and FINALES_PAST past-dependent; terminals fit the place of the
## chapter in the hero. Sizes outside F1 are warnings. Without one final or a common scene the
## rest of the shape cannot be told, so only that finding is made.


## Appends the BS-10 findings for `graph.chapter` to `issues`.
static func check(hero: HeroData, graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var chapter: ChapterData = graph.chapter
	_sizes(graph, options, issues)
	var finals: PackedStringArray = []
	for scene: SceneData in chapter.scenes:
		if scene.final:
			finals.append(scene.id)
	if finals.size() != 1:
		_error(issues, chapter, "в главе финалов: %d, нужен ровно один" % finals.size())
		return
	var common: String = _common_scene(graph, issues)
	if common.is_empty():
		return
	var final_id: String = finals[0]
	var body: PackedStringArray = graph.reachable(PackedStringArray([common]))
	if not body.has(final_id):
		_error(issues, chapter, "финал «%s» недостижим из первой общей сцены «%s»" % [final_id, common])
		return
	var spine: PackedStringArray = _spine(graph, body, common, final_id)
	_branches(graph, body, spine, final_id, options, issues)
	_nodes(graph, body, spine, issues)
	_finales(hero, graph, final_id, options, issues)


static func _error(issues: Array[DataIssue], chapter: ChapterData, message: String, object_id: String = "") -> void:
	var path: String = chapter.id if object_id.is_empty() else "%s/scenes/%s" % [chapter.id, object_id]
	GraphValidator.report(issues, "BS-10", path, object_id if not object_id.is_empty() else chapter.id, message)


static func _sizes(graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var scenes: int = 0
	var nodes: int = 0
	for scene: SceneData in graph.chapter.scenes:
		scenes += 0 if scene.deprecated else 1
		nodes += 1 if scene.node else 0
	_warn_range(graph.chapter, issues, "сцен в главе", scenes, options.s_chapter_min, options.s_chapter_max)
	_warn_range(graph.chapter, issues, "узловых сцен", nodes, options.n_node_min, options.n_node_max)


static func _warn_range(chapter: ChapterData, issues: Array[DataIssue], what: String, value: int, low: int, high: int) -> void:
	if value < low or value > high:
		GraphValidator.report(issues, "BS-10", chapter.id, chapter.id, "%s: %d, безопасно %d…%d" % [what, value, low, high], DataIssue.WARNING)


# Every entry scene leads into exactly one scene, the same for all entries. "" when it does not.
static func _common_scene(graph: StoryGraph, issues: Array[DataIssue]) -> String:
	var common: String = ""
	for entry: String in graph.entry_scenes():
		var next: PackedStringArray = graph.successors(entry)
		if next.size() != 1 or (not common.is_empty() and next[0] != common):
			_error(issues, graph.chapter, "вариант входа «%s» не ведёт в одну общую сцену с остальными" % entry, entry)
			return ""
		common = next[0]
	return common


# Scenes that every way from the common scene to the final passes through.
static func _spine(graph: StoryGraph, body: PackedStringArray, common: String, final_id: String) -> PackedStringArray:
	var spine: PackedStringArray = []
	for id: String in body:
		var on_every_way: bool = id == common or id == final_id
		if not on_every_way:
			on_every_way = not graph.reachable(PackedStringArray([common]), id).has(final_id)
		if on_every_way:
			spine.append(id)
	return spine


static func _branches(graph: StoryGraph, body: PackedStringArray, spine: PackedStringArray, final_id: String, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var side: PackedStringArray = []
	for id: String in body:
		if not spine.has(id):
			side.append(id)
	var parts: Array[PackedStringArray] = _components(graph, side)
	if parts.size() != 1:
		_error(issues, graph.chapter, "ответвлений: %d, нужно одно" % parts.size())
	for part: PackedStringArray in parts:
		_check_branch(graph, part, spine, final_id, issues)
	if side.size() > options.branch_max:
		GraphValidator.report(issues, "BS-10", graph.chapter.id, graph.chapter.id, "в ответвлении сцен: %d, безопасно не больше %d" % [side.size(), options.branch_max], DataIssue.WARNING)


# Groups of side scenes that touch each other by an edge in either direction.
static func _components(graph: StoryGraph, side: PackedStringArray) -> Array[PackedStringArray]:
	var parts: Array[PackedStringArray] = []
	var placed: PackedStringArray = []
	for start: String in side:
		if placed.has(start):
			continue
		var part: PackedStringArray = [start]
		var head: int = 0
		while head < part.size():
			var current: String = part[head]
			head += 1
			for other: String in side:
				var linked: bool = graph.successors(current).has(other) or graph.successors(other).has(current)
				if linked and not part.has(other):
					part.append(other)
		placed.append_array(part)
		parts.append(part)
	return parts


static func _check_branch(graph: StoryGraph, part: PackedStringArray, spine: PackedStringArray, final_id: String, issues: Array[DataIssue]) -> void:
	var leaves_from: PackedStringArray = []
	for id: String in spine:
		for target: String in graph.successors(id):
			if part.has(target) and not leaves_from.has(id):
				leaves_from.append(id)
	if leaves_from.size() != 1:
		_error(issues, graph.chapter, "ответвление «%s» выходит из сцен хребта: %d, нужна одна" % [part[0], leaves_from.size()], part[0])
	for id: String in part:
		if not graph.reachable(PackedStringArray([id])).has(final_id):
			_error(issues, graph.chapter, "ответвление «%s» не возвращается на хребет" % part[0], part[0])
			return


static func _nodes(graph: StoryGraph, body: PackedStringArray, spine: PackedStringArray, issues: Array[DataIssue]) -> void:
	for scene: SceneData in graph.chapter.scenes:
		if scene.node and body.has(scene.id) and not spine.has(scene.id):
			_error(issues, graph.chapter, "узловая сцена вне хребта", scene.id)
		if scene.final and not scene.node:
			_error(issues, graph.chapter, "финал не узловая сцена", scene.id)


# Terminals of the final scene: base ones are open at any flags, the rest need a past flag.
static func _finales(hero: HeroData, graph: StoryGraph, final_id: String, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var base: PackedStringArray = []
	var past: PackedStringArray = []
	var terminals: Array[TransitionData] = []
	for option: OptionData in graph.scene_by_id[final_id].options:
		for outcome_id: String in _used_outcomes(option):
			var outcome: OutcomeData = graph.outcome_by_id.get(outcome_id)
			if outcome == null:
				continue
			for route: RouteData in outcome.routes:
				var transition: TransitionData = graph.transition_by_id.get(route.transition)
				if transition == null or transition.to_kind == TransitionData.TO_SCENE:
					continue
				terminals.append(transition)
				var open: bool = option.condition.is_empty() and route.condition.is_empty()
				if open and not base.has(transition.id):
					base.append(transition.id)
				elif not open and not past.has(transition.id):
					past.append(transition.id)
	var past_only: int = 0
	for id: String in past:
		past_only += 0 if base.has(id) else 1
	if base.size() != options.finales_base or past_only != options.finales_past:
		_error(issues, graph.chapter, "финалы %d + %d, нужно %d + %d" % [base.size(), past_only, options.finales_base, options.finales_past], final_id)
	_check_terminals(hero, graph.chapter, terminals, final_id, issues)


static func _used_outcomes(option: OptionData) -> PackedStringArray:
	var ids: PackedStringArray = []
	if option.check != null:
		ids.append(option.check.success)
		ids.append(option.check.failure)
	if not option.outcome.is_empty():
		ids.append(option.outcome)
	return ids


# A chapter that is not the last one of the hero ends in chapter_end, the last one in an ending.
static func _check_terminals(hero: HeroData, chapter: ChapterData, terminals: Array[TransitionData], final_id: String, issues: Array[DataIssue]) -> void:
	var place: int = hero.chapter_ids.find(chapter.id)
	if place < 0:
		return
	var is_last: bool = place == hero.chapter_ids.size() - 1
	var wrong: String = TransitionData.TO_CHAPTER_END if is_last else TransitionData.TO_ENDING
	var mismatched: int = 0
	for transition: TransitionData in terminals:
		mismatched += 1 if transition.to_kind == wrong else 0
	if mismatched > 0:
		_error(issues, chapter, "переходов финала не по месту главы: %d (%s)" % [mismatched, "последняя глава: нужна концовка" if is_last else "не последняя глава: нужен конец главы"], final_id)
