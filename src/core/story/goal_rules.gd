class_name GoalRules
extends RefCounted
## Pure rules of the chapter goal (chapter-goal.md: rules 1, 3, 5, 6, 7, 12; F2; States; Э-21).
## No state, no log: the story core (RunSession) calls them, writes the result into RunState and logs.
##
## Usage: [code]var max: int = GoalRules.next_milestone_max(chapter, scene, false, 2, false)[/code]


## Normalized attempt context; `issue` is a finding for one log line, empty when none.
class Context extends RefCounted:
	var start: String
	var milestone_max: int
	var issue: String
	## True for «ошибка данных» (start lost among several), false for a warning.
	var is_error: bool


## Number k (from 1) of the scene's milestone in the chapter list; 0 when the scene has none or the id is broken.
static func milestone_number(chapter: ChapterData, scene: SceneData) -> int:
	if scene == null or scene.milestone.is_empty():
		return 0
	for index: int in chapter.milestones.size():
		if chapter.milestones[index].id == scene.milestone:
			return index + 1
	return 0


## F2: the new `milestone_max` on entering `scene`. A start scene assigns, whatever was before; other scenes
## raise it unless the fail flag stands. The old value is first brought to 1..V; V = 0 gives 0.
static func next_milestone_max(chapter: ChapterData, scene: SceneData, start_scene: bool, current_max: int, fail_flag_set: bool) -> int:
	var total: int = chapter.milestones.size()
	if total == 0:
		return 0
	var number: int = milestone_number(chapter, scene)
	if start_scene:
		return maxi(number, 1)
	var kept: int = clampi(current_max, 1, total)
	if fail_flag_set:
		return kept
	return maxi(kept, number)


## Э-21: brings a loaded context to a valid one before the first view and the first F2.
## (б) no `milestone_max`: the scene's milestone without a fail flag, else 1; (в) clamped to 1..V;
## (г) a lost `start`: the only entry of `starts`, else empty and an error.
static func normalize_context(chapter: ChapterData, scene: SceneData, start_id: String, milestone_max: int, fail_flag_set: bool) -> Context:
	var context: Context = Context.new()
	var notes: PackedStringArray = []
	context.start = start_id
	var total: int = chapter.milestones.size()
	if total == 0:
		context.milestone_max = 0
	elif milestone_max <= 0 and not fail_flag_set:
		context.milestone_max = maxi(milestone_number(chapter, scene), 1)
		notes.append("нет веха_макс")
	elif milestone_max <= 0:
		context.milestone_max = 1
		notes.append("нет веха_макс")
	else:
		context.milestone_max = clampi(milestone_max, 1, total)
		if context.milestone_max != milestone_max:
			notes.append("веха_макс %d вне 1..%d" % [milestone_max, total])
	if not chapter.starts.is_empty() and _start_of(chapter, start_id) == null:
		notes.append("старт «%s» не найден" % start_id)
		if chapter.starts.size() == 1:
			context.start = chapter.starts[0].id
		else:
			context.start = ""
			context.is_error = true
	if not notes.is_empty():
		context.issue = "цель главы «%s»: %s" % [chapter.id, "; ".join(notes)]
	return context


## The six-row table of States. `in_chapter` false is «не начат». Impossible rows are made harmless:
## (flag, any, final) is DONE_FAILED; `pending` without the flag is ignored (see `is_impossible`).
static func mode(in_chapter: bool, fail_flag_set: bool, pending: bool, final_shown: bool) -> GoalView.Mode:
	if not in_chapter:
		return GoalView.Mode.NOT_STARTED
	if final_shown:
		return GoalView.Mode.DONE_FAILED if fail_flag_set else GoalView.Mode.DONE_OK
	if fail_flag_set and not pending:
		return GoalView.Mode.FROZEN
	return GoalView.Mode.RUNNING


## True for the input combinations that never happen (States): `pending` without the flag, or with `final_shown`.
static func is_impossible(fail_flag_set: bool, pending: bool, final_shown: bool) -> bool:
	return pending and (not fail_flag_set or final_shown)


## The goal in force: the goal of the attempt's start, else the chapter goal; empty when the start is lost
## among several entries (Э-18, Э-21 г: the chapter goal is not substituted silently).
static func goal_of(chapter: ChapterData, start_id: String) -> String:
	if chapter.starts.is_empty():
		return chapter.goal
	var entry: StartData = _start_of(chapter, start_id)
	if entry == null:
		return ""
	return entry.goal if not entry.goal.is_empty() else chapter.goal


## The view for a normalized context. `chapter` null is «не начат».
static func view(chapter: ChapterData, scene: SceneData, start_id: String, milestone_max: int, fail_flag_set: bool, pending: bool, final_shown: bool) -> GoalView:
	var result: GoalView = GoalView.new()
	if chapter == null:
		return result
	result.mode = mode(true, fail_flag_set, pending, final_shown)
	result.milestones_total = chapter.milestones.size()
	result.goal = goal_of(chapter, start_id)
	if result.milestones_total > 0:
		result.position = result.milestones_total if result.mode == GoalView.Mode.DONE_OK else clampi(milestone_max, 1, result.milestones_total)
	match result.mode:
		GoalView.Mode.DONE_OK:
			_caption(result, GoalView.Caption.FULFILLED, result.goal)
		GoalView.Mode.FROZEN, GoalView.Mode.DONE_FAILED:
			_caption(result, GoalView.Caption.FAILED, result.goal)
		_:
			_running_caption(result, chapter, scene, start_id)
	return result


# Rule 6: the start scene of the attempt's start says the goal, later scenes say the step of milestone P.
static func _running_caption(result: GoalView, chapter: ChapterData, scene: SceneData, start_id: String) -> void:
	var entry: StartData = _start_of(chapter, start_id)
	var on_start: bool = entry != null and scene != null and entry.scene == scene.id
	if result.milestones_total == 0 or on_start:
		_caption(result, GoalView.Caption.GOAL, result.goal)
		return
	_caption(result, GoalView.Caption.STEP, chapter.milestones[result.position - 1].step)


static func _caption(result: GoalView, kind: GoalView.Caption, text: String) -> void:
	if text.is_empty():
		return
	result.caption = kind
	result.caption_text = text


static func _start_of(chapter: ChapterData, start_id: String) -> StartData:
	for entry: StartData in chapter.starts:
		if entry.id == start_id:
			return entry
	return null
