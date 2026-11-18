class_name RunSession
extends RefCounted
## Story side of the Save layer: owner of the navigator, the RunState, the schema snapshots and the roll
## record of one run, and of the commits of transitions 1, 2, 3, 6, 7 (save-system.md, rules 4, 7, 8, 10;
## ADR-0002 §1, §5 B2; DD-021, DD-022; story SV4). Transitions 4, 5 wait for the GDD «Схема главы».
## Commit 1 only after advance()/outcome_applied() returned a SCENE; resume, an ERROR screen and null
## write nothing. A commit that returns 0 leaves no ticket, so the screen shows at once (DD-022).
## Choosing a plain option drops a restored roll record: the player left the check.
##
## Usage: [code]var screen: StoryScreen = session.start_new()[/code]; show it when `waiting()` is false,
## or on `show_released`.

## The ticket of a waiting transition finished (OK, ERROR or TIMEOUT), rule 7.
signal show_released()
## A load ended: the load code and the resumed screen. CORRUPT with an ERROR screen is a refusal by id
## (rule 8, item 6): no run exists then and nothing was written.
signal loaded(code: SaveWriter.LoadCode, screen: StoryScreen)

const TRANSITION_SCENE: int = 1
const TRANSITION_PLAIN: int = 2
const TRANSITION_NEW: int = 6

var _hero: HeroData
var _writer: SaveWriter
var _d20: D20Check
var _make_run_id: Callable
var _log: Callable
var _nav: StoryNavigator
var _state: RunState
var _run_id: String
var _schema: Array[RunBody.Snapshot] = []
var _schema_chapter: String
var _turn: CheckTurn
var _waiting: int
var _load_token: int


func _init(hero: HeroData, writer: SaveWriter, d20: D20Check, make_run_id: Callable, log_error: Callable) -> void:
	_hero = hero
	_writer = writer
	_d20 = d20
	_make_run_id = make_run_id
	_log = log_error
	_writer.write_finished.connect(_on_write_finished)
	_writer.load_finished.connect(_on_load_finished)


## True while a run exists (not after a refused load).
func active() -> bool:
	return _state != null


## True from a transition 2, 3, 6, 7 commit until its ticket ends (rule 7).
func waiting() -> bool:
	return _waiting != 0


func has_flag(id: String) -> bool:
	return _state != null and _state.has_flag(id)


func journal_size() -> int:
	return _state.journal().size() if _state != null else 0


## The screen on show; null before a run.
func screen() -> StoryScreen:
	return _nav.screen() if _nav != null else null


## Transition 6: a new run from the start of chapter 1, written as a pair; one ticket.
func start_new() -> StoryScreen:
	if _waiting != 0:
		return null
	_begin(RunState.new(_hero.flags, _log))
	_run_id = _make_run_id.call()
	_schema = []
	var page: StoryScreen = _nav.start_run(_state)
	if page.kind != StoryScreen.Kind.SCENE:
		_state = null
		return page
	_schema_chapter = _nav.position().chapter
	_waiting = _commit(TRANSITION_NEW, _nav.position(), null)
	return page


## Queues the load of this hero; the token, 0 when the writer refused. Ends with `loaded`.
func load_saved() -> int:
	_load_token = _writer.load_run(_hero.id)
	return _load_token


## A plain option (transition 2): applies its outcome, then the outcome screen waits for the write.
func apply_plain(option: OptionData) -> StoryScreen:
	if _state == null or option == null or option.check != null:
		return null
	var page: StoryScreen = _nav.screen()
	if page == null or page.kind != StoryScreen.Kind.SCENE or not page.scene.options.has(option):
		return null
	if not _can_apply(option.outcome):
		return null
	_turn = null
	return _apply(option.outcome)


## «Дальше»: commit 1 when it enters a scene.
func advance() -> StoryScreen:
	if _state == null:
		return null
	return _after(_nav.advance())


## A risky option of the scene on show; false when there is no such check.
func choose_check(option: OptionData) -> bool:
	if _state == null:
		return false
	if _turn != null and (_turn.phase == CheckTurn.Phase.CHOSEN or _turn.phase == CheckTurn.Phase.ROLLED):
		return false
	_turn = CheckTurn.choose(_nav.screen(), option, _hero, _d20, _commit_roll, _log)
	return _turn != null


## «Бросить»: commit 3 inside.
func roll() -> D20Result:
	return _turn.roll() if _turn != null else null


## «Продолжить»: commit 7 inside (state before the outcome), then the outcome is applied once.
func continue_check() -> StoryScreen:
	if _turn == null or _turn.phase != CheckTurn.Phase.ROLLED:
		return null
	if not _can_apply(_turn.result.outcome_id):
		return null
	var result: D20Result = _turn.proceed()
	if result == null:
		return null
	return _apply(result.outcome_id)


func _begin(state: RunState) -> void:
	_state = state
	_turn = null
	_waiting = 0
	_nav = StoryNavigator.new(_hero, _on_chapter_finished, _log)


func _on_chapter_finished(_chapter_id: String) -> void:
	pass


# Everything outcome_applied() checks, asked first: the state must change before the navigator routes
# (conditions read it), so the navigator cannot be the judge. Logs why when refused.
func _can_apply(outcome_id: String) -> bool:
	var page: StoryScreen = _nav.screen()
	if page == null or page.kind != StoryScreen.Kind.SCENE or _find_outcome(outcome_id) == null:
		_log.call("исход «%s» не применён: нет сцены на экране или исхода у героя" % outcome_id)
		return false
	for option: OptionData in page.scene.options:
		if option.outcome == outcome_id or (option.check != null and (option.check.success == outcome_id or option.check.failure == outcome_id)):
			return true
	_log.call("исход «%s» не применён: он не из вариантов сцены «%s»" % [outcome_id, page.scene.id])
	return false


func _apply(outcome_id: String) -> StoryScreen:
	var scene_id: String = _nav.position().scene
	var outcome: OutcomeData = _find_outcome(outcome_id)
	_state.apply_outcome(scene_id, outcome_id, outcome.sets, outcome.clears)
	return _after(_nav.outcome_applied(outcome_id))


func _find_outcome(outcome_id: String) -> OutcomeData:
	var chapter_id: String = _nav.position().chapter
	for chapter: ChapterData in _hero.chapters:
		if chapter.id != chapter_id:
			continue
		for outcome: OutcomeData in chapter.outcomes:
			if outcome.id == outcome_id:
				return outcome
	return null


# Transition by the kind of the returned screen: SCENE is 1, an outcome with text and no check is 2.
func _after(page: StoryScreen) -> StoryScreen:
	if page == null:
		return null
	var position: StoryPosition = _nav.position()
	if page.kind == StoryScreen.Kind.SCENE:
		_turn = null
		_snapshot_schema(page, position)
		_commit(TRANSITION_SCENE, position, null)
	elif page.kind == StoryScreen.Kind.OUTCOME and not position.pending_outcome.is_empty():
		_waiting = _commit(TRANSITION_PLAIN, position, null)
	return page


func _snapshot_schema(page: StoryScreen, position: StoryPosition) -> void:
	if position.chapter != _schema_chapter:
		_schema = []
		_schema_chapter = position.chapter
	if page.scene.node or position.transition.is_empty():
		_schema.append(RunBody.Snapshot.new(_frozen(_state), position))


# A schema snapshot keeps its own state: the live one keeps changing.
func _frozen(state: RunState) -> RunState:
	var issues: Array[DataIssue] = []
	return RunState.from_dict(state.to_dict(), "session", issues, _hero.flags, _log)


func _commit_roll(transition: int, record: RollRecord) -> void:
	_waiting = _commit(transition, _nav.position(), record)


# The one ticket of a commit, 0 when refused: the writer logged why and nothing waits.
func _commit(transition: int, position: StoryPosition, record: RollRecord) -> int:
	var body: RunBody = RunBody.new()
	body.run_id = _run_id
	body.hero = _hero.id
	body.resume = RunBody.Snapshot.new(_state, position)
	body.schema = _schema
	body.roll = record
	var issues: Array[DataIssue] = []
	var raw: Variant = body.to_dict(issues)
	return _writer.commit(transition, _hero.id, raw, issues)


func _on_write_finished(ticket: int, _outcome: SaveWriter.Outcome) -> void:
	if ticket != _waiting:
		return
	_waiting = 0
	show_released.emit()


func _on_load_finished(token: int, code: SaveWriter.LoadCode, raw: Dictionary) -> void:
	if token != _load_token:
		return
	_load_token = 0
	if code != SaveWriter.LoadCode.OK:
		loaded.emit(code, null)
		return
	var issues: Array[DataIssue] = []
	var body: RunBody = RunBody.from_dict(raw, "save", issues, _hero.flags, _hero.id, _log)
	if body == null:
		for issue: DataIssue in issues:
			_log.call("загрузка: %s %s: %s" % [issue.code, issue.path, issue.message])
		loaded.emit(SaveWriter.LoadCode.CORRUPT, null)
		return
	_begin(body.resume.state)
	_run_id = body.run_id
	_schema = body.schema
	_schema_chapter = body.resume.position.chapter
	var page: StoryScreen = _nav.resume(body.resume.position, _state)
	if page.kind == StoryScreen.Kind.ERROR:
		_state = null
		loaded.emit(SaveWriter.LoadCode.CORRUPT, page)
		return
	if body.roll != null:
		_turn = CheckTurn.restore(page, body.roll, _commit_roll, _log)
	loaded.emit(SaveWriter.LoadCode.OK, page)
