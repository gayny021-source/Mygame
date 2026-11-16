class_name StoryGraph
extends RefCounted
## Indexes and scene-to-scene edges of one chapter (ADR-0001 §6, story S4; branching-story.md,
## Core Rules 6 and 9). An edge runs scene -> outcome of its option -> transition of a route ->
## target scene. Conditions are not evaluated: every route counts. Built once, read by the checks.

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


## Ids of the outcomes named by the options of `scene` (a risky option names two).
func scene_outcomes(scene: SceneData) -> PackedStringArray:
	var ids: PackedStringArray = []
	for option: OptionData in scene.options:
		if option.check != null:
			ids.append(option.check.success)
			ids.append(option.check.failure)
		if not option.outcome.is_empty():
			ids.append(option.outcome)
	return ids


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
	var seen: PackedStringArray = []
	var queue: PackedStringArray = []
	for root: String in roots:
		if root != banned and scene_by_id.has(root) and not seen.has(root):
			seen.append(root)
			queue.append(root)
	var head: int = 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		for target: String in successors(current):
			if target != banned and not seen.has(target):
				seen.append(target)
				queue.append(target)
	return seen


## Edges [from, to] that close a loop (found by depth-first search from every scene).
func back_edges() -> Array[PackedStringArray]:
	var edges: Array[PackedStringArray] = []
	var state: Dictionary[String, int] = {}
	for scene: SceneData in chapter.scenes:
		_walk(scene.id, state, edges)
	return edges


# 1 — on the current path, 2 — finished. Depth is bounded by the scene count of a chapter.
func _walk(id: String, state: Dictionary[String, int], edges: Array[PackedStringArray]) -> void:
	if state.has(id):
		return
	state[id] = 1
	for target: String in successors(id):
		if state.get(target, 0) == 1:
			edges.append(PackedStringArray([id, target]))
		else:
			_walk(target, state, edges)
	state[id] = 2


func _targets(scene: SceneData) -> PackedStringArray:
	var ids: PackedStringArray = []
	for outcome_id: String in scene_outcomes(scene):
		var outcome: OutcomeData = outcome_by_id.get(outcome_id)
		if outcome == null:
			continue
		for route: RouteData in outcome.routes:
			var transition: TransitionData = transition_by_id.get(route.transition)
			var is_scene: bool = transition != null and transition.to_kind == TransitionData.TO_SCENE
			if is_scene and scene_by_id.has(transition.to_id) and not ids.has(transition.to_id):
				ids.append(transition.to_id)
	return ids
