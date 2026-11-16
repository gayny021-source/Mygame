class_name StoryNavigator
extends RefCounted
## Story navigator (branching-story.md, rules 2-8; ADR-0001 §6; story S6): picks the start, the
## bridge, the paragraphs and the route by the flags, and keeps the position. It never applies an
## outcome and never writes a file: the Choice system applies, the Save system writes.
## A returned null means the call was refused and nothing changed; Kind.ERROR means the error is
## already logged, the position is untouched, and every call is refused until start_run or resume.
##
## Usage: [code]var nav := StoryNavigator.new(hero, on_chapter_finished); var screen := nav.start_run(state)[/code]

const KIND := StoryScreen.Kind

var _hero: HeroData
var _vocab: ConditionVocabulary
var _chapter_finished: Callable
var _log_error: Callable
## Parsed conditions by text; null when the text does not parse (logged once, reads as false).
var _conditions: Dictionary[String, Condition] = {}
var _scenes: Dictionary[String, SceneData] = {}
var _outcomes: Dictionary[String, OutcomeData] = {}
var _transitions: Dictionary[String, TransitionData] = {}
var _chapter_index: int = -1
var _state: RunState
var _position: StoryPosition
var _screen: StoryScreen


## `chapter_finished` takes the id of the chapter left; `log_error` takes one String
## (push_error when none is given).
func _init(hero: HeroData, chapter_finished: Callable, log_error: Callable = Callable()) -> void:
	_hero = hero
	_vocab = FlagLoader.vocabulary(hero.flags)
	_chapter_finished = chapter_finished
	_log_error = log_error


## New run: the start of the first chapter over `state`.
func start_run(state: RunState) -> StoryScreen:
	_state = state
	return _enter_chapter(0)


## Load and «Начать отсюда»: the scene of `saved` without an edge of the graph, then its pending
## outcome when there is one. The outcome is not applied again: its flags are already in `state`.
func resume(saved: StoryPosition, state: RunState) -> StoryScreen:
	_state = state
	_position = null
	var index: int = _chapter_at(saved.chapter)
	if index < 0:
		return _fail("загрузка: главы «%s» нет у героя" % saved.chapter)
	_index_chapter(index)
	if not _scenes.has(saved.scene):
		return _fail("загрузка: сцены «%s» нет в главе «%s»" % [saved.scene, saved.chapter])
	var option: OptionData = null
	if not saved.pending_outcome.is_empty():
		option = _option_of(_scenes[saved.scene], saved.pending_outcome)
		if option == null:
			return _fail("загрузка: исход «%s» не из вариантов сцены «%s»" % [saved.pending_outcome, saved.scene])
	var entry: TransitionData = _transitions.get(saved.transition)
	if not saved.transition.is_empty() and entry == null:
		_log("загрузка: перехода входа «%s» нет, сцена без моста" % saved.transition)
	var page: StoryScreen = _enter_scene(saved.scene, saved.transition, entry)
	if option == null:
		return page
	return _show_outcome(_outcomes[saved.pending_outcome], option)


## The Choice system applied the outcome `outcome_id` of an option of the current scene.
## Null when the scene is not on screen or the outcome is not one of its options.
func outcome_applied(outcome_id: String) -> StoryScreen:
	if _screen == null or _screen.kind != KIND.SCENE:
		return null
	var option: OptionData = _option_of(_screen.scene, outcome_id)
	if option == null:
		_log("исход «%s» не из вариантов сцены «%s»" % [outcome_id, _screen.scene.id])
		return null
	return _show_outcome(_outcomes[outcome_id], option)


## «Дальше» on an outcome or a coda; null in any other phase.
func advance() -> StoryScreen:
	if _screen == null:
		return null
	if _screen.kind == KIND.OUTCOME:
		return _follow(_screen.transition)
	if _screen.kind == KIND.CODA:
		return _next_chapter()
	return null


## A copy of the position; null before the first scene.
func position() -> StoryPosition:
	if _position == null:
		return null
	return StoryPosition.new(_position.chapter, _position.scene, _position.transition, _position.pending_outcome)


## The last screen, not recomputed.
func screen() -> StoryScreen:
	return _screen


## True when `condition` holds over the run state; empty is true. For the `if` of options.
## False before start_run or resume: there is no run state yet.
func holds(condition: String) -> bool:
	if _state == null:
		return false
	if condition.is_empty():
		return true
	if not _conditions.has(condition):
		_conditions[condition] = _parse(condition)
	var parsed: Condition = _conditions[condition]
	return parsed != null and parsed.evaluate(_state)


func _enter_chapter(index: int) -> StoryScreen:
	if index >= _hero.chapters.size():
		return _fail("у героя нет главы номер %d" % (index + 1))
	_index_chapter(index)
	var chapter: ChapterData = _hero.chapters[index]
	var start: StartData = null
	for entry: StartData in chapter.starts:
		if holds(entry.condition):
			start = entry
			break
	if start == null:
		return _fail("в главе «%s» нет годной записи starts" % chapter.id)
	_check_goal_failure(index, start)
	return _enter_scene(start.scene, "", null)


# BS-19 during play (hypothesis of the detector): only logged, play goes on.
func _check_goal_failure(index: int, start: StartData) -> void:
	if index == 0 or not start.goal.is_empty():
		return
	var flag: String = _hero.chapters[index - 1].goal_fail_flag
	if not flag.is_empty() and _state.has_flag(flag):
		_log("BS-19: флаг провала «%s» стоит, а запись starts «%s» без goal" % [flag, start.id])


# `entry` is the id of the entry transition ("" for a start); `transition` is null when it is missing.
func _enter_scene(scene_id: String, entry: String, transition: TransitionData) -> StoryScreen:
	var scene: SceneData = _scenes.get(scene_id)
	if scene == null:
		return _fail("сцены «%s» нет в главе «%s»" % [scene_id, _chapter().id])
	var page: StoryScreen = StoryScreen.new(KIND.SCENE)
	page.scene = scene
	if entry.is_empty():
		page.chapter_title = _chapter().title
	elif transition != null:
		page.bridge = _bridge(transition)
	page.paragraphs = _visible(scene.paragraphs)
	if page.paragraphs.is_empty():
		_log("у сцены «%s» нет абзацев при текущих флагах" % scene_id)
	_position = StoryPosition.new(_chapter().id, scene_id, entry)
	_screen = page
	return page


func _bridge(transition: TransitionData) -> String:
	if transition.bridge == null:
		_log("у перехода «%s» нет моста" % transition.id)
		return ""
	for insert: ParagraphData in transition.bridge.inserts:
		if holds(insert.condition):
			return transition.bridge.joined(insert.text)
	return transition.bridge.joined("")


func _show_outcome(outcome: OutcomeData, option: OptionData) -> StoryScreen:
	var page: StoryScreen = StoryScreen.new(KIND.OUTCOME)
	page.scene = _screen.scene
	page.outcome = outcome
	page.option = option
	page.paragraphs = _visible(outcome.paragraphs)
	page.transition = _route(outcome)
	_position.pending_outcome = outcome.id if option.check == null else ""
	_screen = page
	if page.paragraphs.is_empty():
		return advance()
	return page


func _route(outcome: OutcomeData) -> TransitionData:
	for route: RouteData in outcome.routes:
		if not holds(route.condition):
			continue
		var transition: TransitionData = _transitions.get(route.transition)
		if transition != null and _leads(transition):
			return transition
		_log("исход «%s»: переход «%s» не найден или ведёт мимо главы" % [outcome.id, route.transition])
	return null


func _leads(transition: TransitionData) -> bool:
	if transition.to_kind == TransitionData.TO_SCENE:
		return _scenes.has(transition.to_id)
	if transition.to_kind == TransitionData.TO_ENDING:
		return _hero.endings.has(transition.to_id)
	return transition.to_kind == TransitionData.TO_CHAPTER_END


func _follow(transition: TransitionData) -> StoryScreen:
	if transition == null:
		return _fail("у исхода «%s» нет годного перехода" % _screen.outcome.id)
	if transition.to_kind == TransitionData.TO_SCENE:
		return _enter_scene(transition.to_id, transition.id, transition)
	var page: StoryScreen = StoryScreen.new(KIND.ENDING)
	page.scene = _screen.scene
	page.transition = transition
	if transition.to_kind == TransitionData.TO_ENDING:
		_screen = page
		return page
	page.kind = KIND.CODA
	page.paragraphs = _visible(transition.coda)
	_screen = page
	if not page.paragraphs.is_empty():
		return page
	_log("кода перехода «%s» пуста при текущих флагах" % transition.id)
	return _next_chapter()


func _next_chapter() -> StoryScreen:
	var finished: String = _chapter().id
	var next: int = _chapter_index + 1
	if next >= _hero.chapters.size():
		return _fail("после главы «%s» нет следующей главы" % finished)
	if not _chapter_finished.is_valid():
		return _fail("нет обработчика конца главы «%s»" % finished)
	# advance() from inside the callback is refused: no screen until the next chapter starts.
	_screen = null
	_chapter_finished.call(finished)
	_state.end_chapter()
	return _enter_chapter(next)


func _option_of(scene: SceneData, outcome_id: String) -> OptionData:
	if not _outcomes.has(outcome_id):
		return null
	for option: OptionData in scene.options:
		if option.outcome == outcome_id:
			return option
		if option.check != null and (option.check.success == outcome_id or option.check.failure == outcome_id):
			return option
	return null


func _visible(paragraphs: Array[ParagraphData]) -> Array[ParagraphData]:
	var result: Array[ParagraphData] = []
	for paragraph: ParagraphData in paragraphs:
		if holds(paragraph.condition):
			result.append(paragraph)
	return result


func _parse(text: String) -> Condition:
	var parsed: ConditionParser.ParseResult = ConditionParser.parse(text, _vocab)
	if parsed.condition == null and parsed.issues.is_empty():
		_log("условие «%s» не разобрано" % text)
	elif parsed.condition == null:
		_log("условие «%s» не разобрано: %s" % [text, parsed.issues[0].message])
	return parsed.condition


func _chapter_at(chapter_id: String) -> int:
	for i: int in _hero.chapters.size():
		if _hero.chapters[i].id == chapter_id:
			return i
	return -1


func _index_chapter(index: int) -> void:
	_chapter_index = index
	var chapter: ChapterData = _hero.chapters[index]
	_scenes.clear()
	_outcomes.clear()
	_transitions.clear()
	for scene: SceneData in chapter.scenes:
		_scenes[scene.id] = scene
	for outcome: OutcomeData in chapter.outcomes:
		_outcomes[outcome.id] = outcome
	for transition: TransitionData in chapter.transitions:
		_transitions[transition.id] = transition


func _chapter() -> ChapterData:
	return _hero.chapters[_chapter_index]


func _fail(message: String) -> StoryScreen:
	_log(message)
	_screen = StoryScreen.new(KIND.ERROR)
	return _screen


func _log(message: String) -> void:
	if _log_error.is_valid():
		_log_error.call(message)
	else:
		push_error(message)
