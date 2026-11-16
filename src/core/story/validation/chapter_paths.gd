class_name ChapterPaths
extends RefCounted
## Paths of one chapter graph (branching-story.md, F2, F3; story S5): every scene sequence from a start
## scene to a scene whose outcome leads into a terminal. A sequence that can end both in an early ending
## and in another terminal is two paths. Words are counted for both ends of the flag range: `words_min`
## shows only unconditional paragraphs and the shortest step, `words_max` every paragraph, the longest
## insert and the longest step ("all conditions true"). With a loop (BS-05) there are no paths.
##
## Usage: [code]for path: ChapterPaths.PathInfo in ChapterPaths.new(graph).paths: ...[/code]

## One path p of F2.
class PathInfo extends RefCounted:
	## Scene ids in the order of the path: scenes(p) is their count.
	var scenes: PackedStringArray = []
	## R(p): scenes of the path with a risky option.
	var risky: int = 0
	## True when the path ends in an early ending.
	var early: bool = false
	## W(p) of F3 at the two ends of the flag range.
	var words_min: int = 0
	var words_max: int = 0


## True when the graph has a loop: then `paths` is empty and the path checks say so.
var has_loop: bool = false
## True when the walk stopped at `limit` paths or at `limit` × scenes walk steps: `paths` is incomplete and
## the path checks say so.
var truncated: bool = false
var paths: Array[PathInfo] = []
var _graph: StoryGraph
var _limit: int
var _walked: int = 0


## `limit` is ValidatorOptions.path_enum_max; 0 walks every path.
func _init(graph: StoryGraph, limit: int = 0) -> void:
	_graph = graph
	_limit = limit
	has_loop = not graph.back_edges().is_empty()
	if has_loop:
		return
	for entry: String in graph.entry_scenes():
		if graph.scene_by_id.has(entry):
			_walk(PackedStringArray([entry]))


## Words of a text counted by spaces (F3, O-6).
static func words(text: String) -> int:
	return text.split(" ", false).size()


## Words of the paragraphs: `all` counts conditional ones too.
static func paragraph_words(paragraphs: Array[ParagraphData], all: bool) -> int:
	var total: int = 0
	for paragraph: ParagraphData in paragraphs:
		if all or paragraph.condition.is_empty():
			total += words(paragraph.text)
	return total


## True when a scene has a risky option (F2, R(p)).
static func is_risky(scene: SceneData) -> bool:
	for option: OptionData in scene.options:
		if option.kind == OptionData.KIND_RISKY:
			return true
	return false


# Depth-first over successors; the graph has no loop, so the depth is at most the scene count.
func _walk(prefix: PackedStringArray) -> void:
	if truncated:
		return
	_walked += 1
	# `limit` complete paths have at most limit × scenes prefixes; more steps mean dead-end prefixes (BS-03)
	if _limit > 0 and _walked > _limit * _graph.chapter.scenes.size():
		truncated = true
		return
	var last: String = prefix[-1]
	for next: String in _graph.successors(last):
		var longer: PackedStringArray = prefix.duplicate()
		longer.append(next)
		_walk(longer)
	var ends: Dictionary[bool, bool] = {}
	for pair: Array in _steps(last, ""):
		var transition: TransitionData = pair[1]
		ends[transition.early] = true
	for early: bool in ends:
		_add(prefix, early)


func _add(scenes: PackedStringArray, early: bool) -> void:
	if _limit > 0 and paths.size() >= _limit:
		truncated = true
		return
	var path: PathInfo = PathInfo.new()
	path.scenes = scenes
	path.early = early
	var low: int = 0
	var high: int = 0
	for i: int in scenes.size():
		var scene: SceneData = _graph.scene_by_id[scenes[i]]
		if is_risky(scene):
			path.risky += 1
		low += paragraph_words(scene.paragraphs, false)
		high += paragraph_words(scene.paragraphs, true)
		var next: String = scenes[i + 1] if i + 1 < scenes.size() else ""
		var step: Vector2i = _step_words(scenes[i], next, early)
		low += step.x
		high += step.y
	path.words_min = low
	path.words_max = high
	paths.append(path)


# Shortest and longest words of the step out of `from`: outcome plus the bridge into `to`,
# or, with `to` empty, outcome plus the coda of a terminal of this `early` kind.
func _step_words(from: String, to: String, early: bool) -> Vector2i:
	var low: int = -1
	var high: int = 0
	for pair: Array in _steps(from, to):
		var outcome: OutcomeData = pair[0]
		var transition: TransitionData = pair[1]
		if to.is_empty() and transition.early != early:
			continue
		var step_low: int = paragraph_words(outcome.paragraphs, false) + _transition_words(transition, false)
		var step_high: int = paragraph_words(outcome.paragraphs, true) + _transition_words(transition, true)
		if low < 0:
			low = step_low
		else:
			low = mini(low, step_low)
		high = maxi(high, step_high)
	return Vector2i(maxi(low, 0), high)


# [outcome, transition] pairs out of the scene `from`: into the scene `to`, or into a terminal when `to` is empty.
func _steps(from: String, to: String) -> Array[Array]:
	var pairs: Array[Array] = []
	for outcome_id: String in _graph.scene_outcomes(_graph.scene_by_id[from]):
		var outcome: OutcomeData = _graph.outcome_by_id.get(outcome_id)
		if outcome == null:
			continue
		for route: RouteData in outcome.routes:
			var transition: TransitionData = _graph.transition_by_id.get(route.transition)
			if transition == null:
				continue
			var into_scene: bool = transition.to_kind == TransitionData.TO_SCENE
			var wanted: bool = transition.to_id == to if into_scene else to.is_empty()
			if wanted:
				pairs.append([outcome, transition])
	return pairs


static func _transition_words(transition: TransitionData, all: bool) -> int:
	var total: int = paragraph_words(transition.coda, all)
	if transition.bridge == null:
		return total
	total += words(transition.bridge.base.replace(BridgeData.INSERT_MARK, " "))
	var longest: int = 0
	for insert: ParagraphData in transition.bridge.inserts:
		longest = maxi(longest, words(insert.text))
	return total + (longest if all else 0)
