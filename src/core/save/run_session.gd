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
## The write behind `show_released` ended with this outcome, sent just before it. Only for the log and
## guards: a failed roll write is not shown to the player (CEO 2026-11-18, «Экран броска»).
signal write_ended(outcome: SaveWriter.Outcome)
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
var _captions: CaptionTexts
## Options of the scene on show with their captions; the states are worked out by `_state_of`.
var _views: Array[OptionView] = []
## The stake of the scene was seen (reading-screen.md, «защёлка»): reset by a new scene or a load.
var _stake_read: bool


## `captions` null reads assets/data/config/captions.json.
func _init(hero: HeroData, writer: SaveWriter, d20: D20Check, make_run_id: Callable, log_error: Callable, captions: CaptionTexts = null) -> void:
	_captions = captions
	if _captions == null:
		var issues: Array[DataIssue] = []
		_captions = CaptionTexts.load_file(CaptionTexts.PATH, issues)
		for issue: DataIssue in issues:
			log_error.call("%s %s: %s" % [issue.code, issue.path, issue.message])
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


## Standing flags the hero card shows, in the hero's declaration order; empty before a run.
func visible_flags() -> Array[FlagDecl]:
	if _state == null:
		return []
	return _state.visible_flags()


func journal_size() -> int:
	return _state.journal().size() if _state != null else 0


## The screen on show; null before a run.
func screen() -> StoryScreen:
	return _nav.screen() if _nav != null else null


## Transition 6: a new run from the start of chapter 1, written as a pair; one ticket. Null while the
## ticket of an earlier start still waits (a double tap): the UI keeps the screen it has.
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
	_enter_views(page)
	_waiting = _commit(TRANSITION_NEW, _nav.position(), null)
	return page


## Queues the load of this hero; the token, 0 when the writer refused or a write still waits (the load
## would read the disk before the write lands). Ends with `loaded`. A refused load changes nothing, so
## a flow error stays and «В меню» (start_new) is its way out.
func load_saved() -> int:
	if _waiting != 0:
		return 0
	_load_token = _writer.load_run(_hero.id)
	return _load_token


## A plain option (transition 2): applies its outcome, then the outcome screen waits for the write.
func apply_plain(option: OptionData) -> StoryScreen:
	if _state == null or _waiting != 0 or option == null or option.check != null:
		return null
	var page: StoryScreen = _nav.screen()
	if page == null or page.kind != StoryScreen.Kind.SCENE or not page.scene.options.has(option):
		return null
	if not _is_open(option) or not _can_apply(option.outcome):
		return null
	_turn = null
	return _apply(option.outcome)


## «Дальше»: commit 1 when it enters a scene.
func advance() -> StoryScreen:
	if _state == null or _waiting != 0:
		return null
	return _after(_nav.advance())


## A risky option of the scene on show; false when there is no such check.
func choose_check(option: OptionData) -> bool:
	if _state == null or _waiting != 0:
		return false
	if _turn != null and _turn.phase != CheckTurn.Phase.CANCELLED:
		return false
	if not _is_open(option):
		return false
	_turn = CheckTurn.choose(_nav.screen(), option, _hero, _d20, _commit_roll, _log)
	return _turn != null


## «Передумать»: only before the roll; nothing is written. False when there is no such turn.
func cancel_check() -> bool:
	return _turn != null and _turn.cancel()


## «Бросить»: commit 3 inside.
func roll() -> D20Result:
	return _turn.roll() if _turn != null else null


## «Продолжить»: commit 7 inside (state before the outcome), then the outcome is applied once.
func continue_check() -> StoryScreen:
	if _waiting != 0 or _turn == null or _turn.phase != CheckTurn.Phase.ROLLED:
		return null
	if not _can_apply(_turn.result.outcome_id):
		return null
	var result: D20Result = _turn.proceed()
	if result == null:
		return null
	return _apply(result.outcome_id)


## The numbers of the turn before the roll, with the texts; null without a turn or without a DC.
func check_brief() -> CheckBrief:
	if _turn == null:
		return null
	var data: CheckBrief = _turn.brief()
	if data == null:
		return null
	data.stat_name = _stat_name(data.stat_id)
	data.level_word = _captions.level_word(data.level)
	data.caption = _captions.risky(data.stat_name, data.bonus, data.level, data.dc, data.chance)
	return data


## True while a turn made by a load waits for «Продолжить»: the Roll screen shows the roll at once.
## A record already applied belongs to the outcome page, not to the Roll screen.
func has_restored_turn() -> bool:
	return _turn != null and _turn.restored and _turn.phase == CheckTurn.Phase.ROLLED and not _turn.record.applied


## The roll of the restored turn; null when there is none.
func restored_result() -> D20Result:
	return _turn.result if has_restored_turn() else null


## Closes the Roll screen without an outcome after a flow error (СВ Э-23): only from ROLLED while no write
## waits. Nothing is written or applied and the choice stays blocked (DD-011).
func close_check() -> bool:
	if _waiting != 0 or _turn == null or not _turn.close():
		return false
	_log.call("ошибка потока: Экран броска «%s» закрыт без исхода" % _turn.check.id)
	return true


## True when the scene on show has no option that a hindrance has not closed (the fallback screen).
func no_open_options() -> bool:
	var page: StoryScreen = screen()
	if page == null or page.kind != StoryScreen.Kind.SCENE:
		return false
	for view: OptionView in _views:
		if view.reason.is_empty():
			return false
	return true


## The stake of the scene was seen at least once (a latch, not a timer).
func stake_read() -> bool:
	return _stake_read


## UI to core: the last line of the stake of scene `scene_id` is in the visible area. Ignored off a
## scene and for another scene (a late call from the one just left).
func report_stake_visible(scene_id: String) -> void:
	var page: StoryScreen = screen()
	if page != null and page.kind == StoryScreen.Kind.SCENE and page.scene.id == scene_id:
		_stake_read = true


## True after a flow error closed the Roll screen (СВ Э-23): every option stays blocked, and the way out
## is «В меню» (start_new) or a load, which both end the turn.
func flow_error() -> bool:
	return _turn != null and _turn.phase == CheckTurn.Phase.CLOSED


## The cards of the scene on show (or of the option just taken on its outcome) with their states; copies,
## so the UI cannot change what the session keeps.
func option_views() -> Array[OptionView]:
	var taken: OptionData = _taken(screen())
	var result: Array[OptionView] = []
	for view: OptionView in _views:
		var copy: OptionView = OptionView.new()
		copy.option = view.option
		copy.caption = view.caption
		copy.reason = view.reason
		copy.state = _state_of(view, taken)
		result.append(copy)
	return result


# Rules 1, 7, 8: taken or blocked after a choice, closed by a hindrance, inactive until the stake is read.
func _state_of(view: OptionView, taken: OptionData) -> OptionView.State:
	if taken != null:
		return OptionView.State.CHOSEN if view.option == taken else OptionView.State.BLOCKED
	if not view.reason.is_empty():
		return OptionView.State.CLOSED
	if not _stake_read:
		return OptionView.State.INACTIVE
	return OptionView.State.OPEN


# The core gate of a touch (rules 7-9): the option must be in the choice and OPEN now.
func _is_open(option: OptionData) -> bool:
	var taken: OptionData = _taken(screen())
	for view: OptionView in _views:
		if view.option == option:
			return _state_of(view, taken) == OptionView.State.OPEN
	return false


# The option taken: the one of the outcome on show or of a live turn; null before a choice.
func _taken(page: StoryScreen) -> OptionData:
	if page != null and page.kind == StoryScreen.Kind.OUTCOME:
		return page.option
	if _turn != null and _turn.phase != CheckTurn.Phase.CANCELLED:
		return _turn.option
	return null


func _enter_views(page: StoryScreen) -> void:
	_stake_read = false
	_views = []
	if page.kind == StoryScreen.Kind.OUTCOME:
		_add_view(page.option)
		return
	if page.kind != StoryScreen.Kind.SCENE:
		return
	for option: OptionData in page.scene.options:
		if not _nav.holds(option.condition):
			continue
		if option.check != null and not _has_stat(option.check.stat):
			_log.call("у героя нет характеристики или её названия «%s»: вариант «%s» скрыт" % [option.check.stat, option.id])
			continue
		_add_view(option)


func _add_view(option: OptionData) -> void:
	var view: OptionView = _view_of(option)
	if view != null:
		_views.append(view)


# Null when a risky option cannot be thrown (invalid d20 config, no DC for the level): hidden, logged
# (d20-checks.md, «конфиг уровней»).
func _view_of(option: OptionData) -> OptionView:
	var view: OptionView = OptionView.new()
	view.option = option
	if option.check == null:
		view.caption = _captions.plain(_price_of(option) if option.kind == OptionData.KIND_SAFE else "")
		return view
	var issues: Array[DataIssue] = []
	var dc: int = _d20.config.dc(option.check.level, issues)
	for issue: DataIssue in issues:
		_log.call("%s %s (%s): %s" % [issue.code, issue.path, option.check.id, issue.message])
	if not _d20.config.valid or dc < 0:
		_log.call("%s рискованный вариант «%s» скрыт: бросок невозможен" % [_d20.config.issue_code, option.id])
		return null
	var hindrance: FlagDecl = _hindrance(option.check.stat)
	if hindrance != null:
		view.reason = hindrance.title
		view.caption = _captions.closed(_stat_name(option.check.stat), hindrance.title)
		return view
	var bonus: int = D20Check.bonus_of(_hero, option.check.stat)
	view.caption = _captions.risky(_stat_name(option.check.stat), bonus, option.check.level, dc, D20Check.chance(dc, bonus))
	return view


# A stat the player can read: it exists and has a name (hero.json requires one).
func _has_stat(stat_id: String) -> bool:
	return not _stat_name(stat_id).is_empty()


func _stat_name(stat_id: String) -> String:
	for stat: StatData in _hero.stats:
		if stat.id == stat_id:
			return stat.name
	return ""


# The flag that closes `stat_id`, the one set first (heroes.md, «Помехи во время игры»).
func _hindrance(stat_id: String) -> FlagDecl:
	if _state == null:
		return null
	for entry: RunState.Entry in _state.journal():
		if entry.action != RunState.Entry.Action.SET or not _state.has_flag(entry.flag):
			continue
		var decl: FlagDecl = _decl(entry.flag)
		if decl != null and decl.blocks.has(stat_id):
			return decl
	return null


func _decl(flag_id: String) -> FlagDecl:
	for decl: FlagDecl in _hero.flags:
		if decl.id == flag_id:
			return decl
	return null


# Title of the one price flag the safe option's outcome sets; empty when none.
func _price_of(option: OptionData) -> String:
	var outcome: OutcomeData = _find_outcome(option.outcome)
	if outcome == null:
		return ""
	for flag_id: String in outcome.sets:
		var decl: FlagDecl = _decl(flag_id)
		if decl != null and decl.category == "price":
			return decl.title
	return ""


func _begin(state: RunState) -> void:
	_state = state
	_turn = null
	_waiting = 0
	_nav = StoryNavigator.new(_hero, _on_chapter_finished, _log)


# StoryNavigator refuses to run without a valid chapter-finished Callable (story_navigator.gd:236).
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
		var plain: bool = option.outcome == outcome_id
		var risky: bool = option.check != null and (option.check.success == outcome_id or option.check.failure == outcome_id)
		if plain or risky:
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
		_enter_views(page)
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


func _on_write_finished(ticket: int, outcome: SaveWriter.Outcome) -> void:
	if ticket != _waiting:
		return
	_waiting = 0
	if outcome != SaveWriter.Outcome.OK:
		_log.call("запись %d закончилась кодом %d" % [ticket, outcome])
	write_ended.emit(outcome)
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
	_enter_views(page)
	if body.roll != null:
		_turn = CheckTurn.restore(page, body.roll, _commit_roll, _log)
	loaded.emit(SaveWriter.LoadCode.OK, page)
