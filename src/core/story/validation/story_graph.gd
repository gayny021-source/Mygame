class_name StoryGraph
extends RefCounted
## Indexes and scene-to-scene edges of one chapter (ADR-0001 §6, story S4; branching-story.md,
## Core Rules 6 and 9). An edge runs scene -> outcome of its option -> transition of a route ->
## target scene. Conditions are not evaluated: every route counts. Built once, read by the checks.
## Ids are unique: the loader reports repeats as BS-01 and gives no data, so the indexes trust them.

var chapter: ChapterData
var scene_by_id: Dictionary[String, SceneData] = {}
var outcome_by_id: Dictionary[String, OutcomeData] = {}
var transition_by_id: Dictionary[String, TransitionData] = {}
var _next: Dictionary[String, PackedStringArray] = {}


func _init(source: ChapterData) -> void:
	chapter = source
	for scene: SceneData in chapter.scenes:
		scene_by_id[scene.id] = scene
	for outcome: OutcomeData in chapter.outcomes:
		outcome_by_id[outcome.id] = outcome
	for transition: TransitionData in chapter.transitions:
		transition_by_id[transition.id] = transition
	for scene: SceneData in chapter.scenes:
		_next[scene.id] = _targets(scene)


## The ids as a set, for membership tests inside loops.
static func as_set(ids: PackedStringArray) -> Dictionary[String, bool]:
	var set: Dictionary[String, bool] = {}
	for id: String in ids:
		set[id] = true
	return set


## Distinct outcome ids named by one option: both of a risky option, or its own.
func option_outcomes(option: OptionData) -> PackedStringArray:
	var ids: PackedStringArray = []
	if option.check != null:
		ids.append(option.check.success)
		if option.check.failure != option.check.success:
			ids.append(option.check.failure)
	if not option.outcome.is_empty() and not ids.has(option.outcome):
		ids.append(option.outcome)
	return ids


## Ids of the outcomes named by the options of `scene`, repeats kept.
func scene_outcomes(scene: SceneData) -> PackedStringArray:
	var ids: PackedStringArray = []
	for option: OptionData in scene.options:
		ids.append_array(option_outcomes(option))
	return ids


## True when a route of the outcome leads into the scene `scene_id`.
func outcome_leads_into(outcome_id: String, scene_id: String) -> bool:
	return _outcome_scenes(outcome_id).has(scene_id)


## Distinct scenes that `scene_id` leads into, in the order the file lists them.
func successors(scene_id: String) -> PackedStringArray:
	return _next.get(scene_id, PackedStringArray())


## Distinct start scenes of the chapter, in the order of `starts`.
func entry_scenes() -> PackedStringArray:
	var ids: PackedStringArray = []
	for start: StartData in chapter.starts:
		if not ids.has(start.scene):
			ids.append(start.scene)
	return ids


## Scenes reachable from `roots` (roots included), never entering `banned`.
func reachable(roots: PackedStringArray, banned: String = "") -> PackedStringArray:
	var seen: Dictionary[String, bool] = {}
	var order: PackedStringArray = []
	for root: String in roots:
		if root != banned and scene_by_id.has(root) and not seen.has(root):
			seen[root] = true
			order.append(root)
	var head: int = 0
	while head < order.size():
		var current: String = order[head]
		head += 1
		for target: String in successors(current):
			if target != banned and not seen.has(target):
				seen[target] = true
				order.append(target)
	return order


## Edges [from, to] that close a loop (depth-first search from every scene, without recursion).
func back_edges() -> Array[PackedStringArray]:
	var edges: Array[PackedStringArray] = []
	# 1 — on the current path, 2 — finished
	var state: Dictionary[String, int] = {}
	for scene: SceneData in chapter.scenes:
		if state.has(scene.id):
			continue
		state[scene.id] = 1
		var path: PackedStringArray = [scene.id]
		var cursor: PackedInt32Array = [0]
		while not path.is_empty():
			var id: String = path[-1]
			var targets: PackedStringArray = successors(id)
			var index: int = cursor[-1]
			if index >= targets.size():
				state[id] = 2
				path.remove_at(path.size() - 1)
				cursor.remove_at(cursor.size() - 1)
				continue
			cursor[-1] = index + 1
			var target: String = targets[index]
			var mark: int = state.get(target, 0)
			if mark == 1:
				edges.append(PackedStringArray([id, target]))
			elif mark == 0:
				state[target] = 1
				path.append(target)
				cursor.append(0)
	return edges


func _targets(scene: SceneData) -> PackedStringArray:
	var ids: PackedStringArray = []
	for outcome_id: String in scene_outcomes(scene):
		for target: String in _outcome_scenes(outcome_id):
			if not ids.has(target):
				ids.append(target)
	return ids


# Existing scenes that the routes of the outcome lead into.
func _outcome_scenes(outcome_id: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	var outcome: OutcomeData = outcome_by_id.get(outcome_id)
	if outcome == null:
		return ids
	for route: RouteData in outcome.routes:
		var transition: TransitionData = transition_by_id.get(route.transition)
		var is_scene: bool = transition != null and transition.to_kind == TransitionData.TO_SCENE
		if is_scene and scene_by_id.has(transition.to_id):
			ids.append(transition.to_id)
	return ids
