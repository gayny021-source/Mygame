class_name BsBudget
extends RefCounted
## Path checks (branching-story.md, Core Rules 11 and 12; F2, F3, F5, F7; AC-13…AC-16, AC-18; story S5):
## BS-13 rhythm, BS-14 ceiling, spine limit and floor of risky choices, BS-15 a short path without an early
## ending, BS-16 the structure of early endings, BS-18 words on a path. Every limit comes from ValidatorOptions.
## Not here: the frequency of F5 (needs the d20 config; AC-32) and the MVP ban on early endings (AC-63).

## Checks that need the paths: with a loop or a stopped walk each of them reports that it did not run.
const PATH_CODES: PackedStringArray = ["BS-13", "BS-14", "BS-15", "BS-18"]


## Appends the findings of one chapter to `issues`.
static func check(hero: HeroData, graph: StoryGraph, paths: ChapterPaths, usage: FlagUsage, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	_early_endings(hero, graph, usage, options, issues)
	if paths.has_loop or paths.truncated:
		var reason: String = "в графе цикл (BS-05)" if paths.has_loop else "путей больше path_enum_max = %d, обход остановлен" % options.path_enum_max
		for code: String in PATH_CODES:
			GraphValidator.report(issues, code, graph.chapter.id, graph.chapter.id, "не проверено: %s" % reason, DataIssue.WARNING)
		return
	var side: Dictionary[String, bool] = _side_scenes(graph, paths)
	var reported: Dictionary[String, bool] = {}
	for path: ChapterPaths.PathInfo in paths.paths:
		_rhythm(graph, path, options, reported, issues)
		_budget(graph, path, side, options, issues)
		_length_and_words(graph, path, options, issues)


static func _warn(issues: Array[DataIssue], code: String, graph: StoryGraph, path: ChapterPaths.PathInfo, message: String) -> void:
	var where: String = "%s/paths/%s" % [graph.chapter.id, "-".join(path.scenes)]
	GraphValidator.report(issues, code, where, path.scenes[-1], message, DataIssue.WARNING)


# Scenes off the spine: not a start scene and not on every path that does not end early.
static func _side_scenes(graph: StoryGraph, paths: ChapterPaths) -> Dictionary[String, bool]:
	var visits: Dictionary[String, int] = {}
	var total: int = 0
	for path: ChapterPaths.PathInfo in paths.paths:
		if path.early:
			continue
		total += 1
		for id: String in path.scenes:
			visits[id] = visits.get(id, 0) + 1
	var entries: PackedStringArray = graph.entry_scenes()
	var side: Dictionary[String, bool] = {}
	for id: String in visits:
		if visits[id] < total and not entries.has(id):
			side[id] = true
	return side


# BS-13 (F7): at least `pause_scenes_min` scenes without a risky option between two with one; at most
# `linear_run_max` linear scenes in a row. A finding is made once per scene, whatever paths lead through it.
static func _rhythm(graph: StoryGraph, path: ChapterPaths.PathInfo, options: ValidatorOptions, reported: Dictionary[String, bool], issues: Array[DataIssue]) -> void:
	var pause: int = -1
	var linear_run: int = 0
	for id: String in path.scenes:
		var scene: SceneData = graph.scene_by_id[id]
		var linear: bool = scene.options.size() == 1 and scene.options[0].check == null
		if linear:
			linear_run += 1
		else:
			linear_run = 0
		if linear_run == options.linear_run_max + 1:
			_rhythm_once(graph, id, "линейных сцен подряд больше %d" % options.linear_run_max, reported, issues)
		if not ChapterPaths.is_risky(scene):
			if pause >= 0:
				pause += 1
			continue
		if pause >= 0 and pause < options.pause_scenes_min:
			_rhythm_once(graph, id, "между сценами с рискованным вариантом меньше %d сцен без него" % options.pause_scenes_min, reported, issues)
		pause = 0


static func _rhythm_once(graph: StoryGraph, scene_id: String, message: String, reported: Dictionary[String, bool], issues: Array[DataIssue]) -> void:
	var key: String = scene_id + message
	if reported.has(key):
		return
	reported[key] = true
	GraphValidator.report(issues, "BS-13", "%s/scenes/%s" % [graph.chapter.id, scene_id], scene_id, message, DataIssue.WARNING)


# BS-14 (F2): R(p) <= k_budget and at most `spine_risky_max` of them off the side branch; the floor
# R(p) >= k_min holds on paths of `s_path_min` scenes or more that do not end early. One finding per path.
static func _budget(graph: StoryGraph, path: ChapterPaths.PathInfo, side: Dictionary[String, bool], options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var on_spine: int = 0
	for id: String in path.scenes:
		if ChapterPaths.is_risky(graph.scene_by_id[id]) and not side.has(id):
			on_spine += 1
	if path.risky > options.k_budget or on_spine > options.spine_risky_max:
		_warn(issues, "BS-14", graph, path, "рискованных выборов на пути %d (вне ответвления %d): потолок %d, вне ответвления не больше %d" % [path.risky, on_spine, options.k_budget, options.spine_risky_max])
	elif not path.early and path.scenes.size() >= options.s_path_min and path.risky < options.k_min:
		_warn(issues, "BS-14", graph, path, "рискованных выборов на пути %d из %d сцен: пол %d" % [path.risky, path.scenes.size(), options.k_min])


# BS-15 and BS-18 (F3) on paths that do not end early.
static func _length_and_words(graph: StoryGraph, path: ChapterPaths.PathInfo, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	if path.early:
		return
	if path.scenes.size() < options.s_path_min:
		_warn(issues, "BS-15", graph, path, "путь из %d сцен короче %d и кончается не ранней концовкой" % [path.scenes.size(), options.s_path_min])
	if path.words_min < options.path_words_min:
		_warn(issues, "BS-18", graph, path, "слов на пути %d (без условных абзацев), меньше %d" % [path.words_min, options.path_words_min])
	if path.words_max > options.path_words_max:
		_warn(issues, "BS-18", graph, path, "слов на пути %d (все условия истинны), больше %d" % [path.words_max, options.path_words_max])


# BS-16: an early ending comes only from the failure of a check, in a scene that is not a start scene, not
# the first check of the hero and not the final node; the fatal option has an `if` that reads no flag set in
# its own scene; a chapter has at most `n_early_max` early endings.
static func _early_endings(hero: HeroData, graph: StoryGraph, usage: FlagUsage, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var early: PackedStringArray = []
	for transition: TransitionData in graph.chapter.transitions:
		if transition.early and not transition.deprecated:
			early.append(transition.id)
	if early.is_empty():
		return
	if early.size() > options.n_early_max:
		GraphValidator.report(issues, "BS-16", graph.chapter.id, graph.chapter.id, "ранних концовок в главе %d, не больше %d" % [early.size(), options.n_early_max])
	var first_checks: Dictionary[String, bool] = _first_checks(hero, graph)
	var entries: PackedStringArray = graph.entry_scenes()
	for scene: SceneData in graph.chapter.scenes:
		for option: OptionData in scene.options:
			for outcome_id: String in graph.option_outcomes(option):
				if not _leads_into(graph, outcome_id, early):
					continue
				var path: String = "%s/scenes/%s/options/%s" % [graph.chapter.id, scene.id, option.id]
				if option.check == null or outcome_id != option.check.failure:
					GraphValidator.report(issues, "BS-16", path, option.id, "в раннюю концовку ведёт исход «%s», а не провал проверки" % outcome_id)
					continue
				var problem: String = _fatal_problem(graph, usage, scene, option, entries, first_checks)
				if not problem.is_empty():
					GraphValidator.report(issues, "BS-16", path, option.id, problem)


static func _leads_into(graph: StoryGraph, outcome_id: String, transitions: PackedStringArray) -> bool:
	var outcome: OutcomeData = graph.outcome_by_id.get(outcome_id)
	if outcome == null:
		return false
	for route: RouteData in outcome.routes:
		if transitions.has(route.transition):
			return true
	return false


static func _fatal_problem(graph: StoryGraph, usage: FlagUsage, scene: SceneData, option: OptionData, entries: PackedStringArray, first_checks: Dictionary[String, bool]) -> String:
	if entries.has(scene.id):
		return "роковой вариант в сцене варианта входа"
	if first_checks.has(scene.id):
		return "роковой вариант на первой проверке героя"
	if scene.final:
		return "роковой вариант в финальном узле"
	if option.condition.is_empty():
		return "роковой вариант без условия: он должен открываться флагом прошлой сцены"
	var own: Dictionary[String, bool] = {}
	for outcome_id: String in graph.scene_outcomes(scene):
		var outcome: OutcomeData = graph.outcome_by_id.get(outcome_id)
		if outcome != null:
			own.merge(StoryGraph.as_set(outcome.sets))
	for id: String in usage.flags_of(option.condition):
		if own.has(id):
			return "условие рокового варианта читает флаг «%s», который ставит эта же сцена" % id
	return ""


# Scenes of the hero's first chapter where a path from a start meets its first risky option.
static func _first_checks(hero: HeroData, graph: StoryGraph) -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	if hero.chapter_ids.is_empty() or hero.chapter_ids[0] != graph.chapter.id:
		return found
	var seen: Dictionary[String, bool] = {}
	var queue: PackedStringArray = graph.entry_scenes()
	var head: int = 0
	while head < queue.size():
		var id: String = queue[head]
		head += 1
		if seen.has(id) or not graph.scene_by_id.has(id):
			continue
		seen[id] = true
		if ChapterPaths.is_risky(graph.scene_by_id[id]):
			found[id] = true
			continue
		queue.append_array(graph.successors(id))
	return found
