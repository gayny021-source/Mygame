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
## The goal view may differ: a scene entered, the outcome text shown, the chapter signal, a load
## (chapter-goal.md, rule 1). One signal per event; the screen asks `goal_view()` after it.
signal goal_changed()

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
## «провал_ждёт» (chapter-goal.md, rule 1): the outcome that set the goal-fail flag is applied, its text not shown.
var _goal_pending: bool
## «финал_показан»: the text of the final outcome was shown; never stored, false after a load.
var _final_shown: bool
## The chapter signal came after the coda: the goal is «не начат» until the next start scene.
var _chapter_done: bool
## A refusal of the outcome («не применено», СВ Э-23): choices stay blocked until a load or a new run.
var _flow_error: bool


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


## The goal view of the scene on show: a pure function of the chapter data, the state and the two
## flags; «не начат» outside a chapter and after the chapter signal (chapter-goal.md, rule 1).
func goal_view() -> GoalView:
	if _state == null or _nav == null or _chapter_done or _nav.position() == null:
		return GoalView.new()
	var position: StoryPosition = _nav.position()
	var chapter: ChapterData = _chapter_of(position.chapter)
	if chapter == null:
		return GoalView.new()
	return GoalRules.view(chapter, _scene_of(chapter, position.scene), _state.attempt_start(), _state.milestone_max(), _fail_flag_set(chapter), _goal_pending, _final_shown)


## The Reading screen shows the text of an outcome: one step lifts «провал_ждёт» and, on a final scene,
## raises «финал_показан»; one `goal_changed` per event, none when nothing changed (chapter-goal.md, rule 1).
func report_outcome_text_shown() -> void:
	var page: StoryScreen = screen()
	if _state == null or page == null or page.scene == null or page.kind != StoryScreen.Kind.OUTCOME:
		return
	_mark_text_shown(page.scene)


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
	_enter_goal(page)
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
	if _state == null or _waiting != 0 or _flow_error or option == null or option.check != null:
		return null
	var page: StoryScreen = _nav.screen()
	if page == null or page.kind != StoryScreen.Kind.SCENE or not page.scene.options.has(option):
		return null
	if not _is_open(option):
		return null
	if not _can_apply(option.outcome):
		_flow_error = true
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
	if _state == null or _waiting != 0 or _flow_error:
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
	if _waiting != 0 or _flow_error or _turn == null or _turn.phase != CheckTurn.Phase.ROLLED:
		return null
	if not _can_apply(_turn.result.outcome_id):
		_flow_error = true
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


## Closes the Roll screen without an outcome (СВ Э-23): only after «Продолжить» was refused in this check
## and while no write waits. Nothing is written or applied and the choice stays blocked (DD-011). The
## refusal logged the error already.
func close_check() -> bool:
	if _waiting != 0 or not _flow_error or _turn == null:
		return false
	return _turn.close()


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


## True after State refused an outcome, with or without a check (СВ Э-23): every option stays blocked, and
## the way out is «В меню» (start_new) or a load, which both end the turn.
func flow_error() -> bool:
	return _flow_error


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
	_goal_pending = false
	_final_shown = false
	_chapter_done = false
	_flow_error = false
	_nav = StoryNavigator.new(_hero, _on_chapter_finished, _log)


# The chapter signal (chapter-goal.md, rule 11, «Сигнал и лог»): only a finished goal of this chapter goes
# to «не начат»; every other case changes nothing and writes one line.
func _on_chapter_finished(chapter_id: String) -> void:
	var position: StoryPosition = _nav.position()
	if position == null or position.chapter != chapter_id:
		_log.call("цель главы: сигнал конца главы «%s» не своей главы" % chapter_id)
		return
	if _chapter_done:
		_log.call("цель главы: повторный сигнал конца главы «%s»" % chapter_id)
		return
	var mode: GoalView.Mode = goal_view().mode
	if mode != GoalView.Mode.DONE_OK and mode != GoalView.Mode.DONE_FAILED:
		_log.call("цель главы: ошибка потока, сигнал конца главы «%s» до показа финала" % chapter_id)
		return
	_chapter_done = true
	goal_changed.emit()


# F2 on entering a scene, before the snapshot of the entry and commit 1 (chapter-goal.md, rule 5): the
# context lands in the snapshot. A start scene writes `start` and resets both flags (rule 1, AC-77).
func _enter_goal(page: StoryScreen) -> void:
	var chapter: ChapterData = _chapter_of(_nav.position().chapter)
	if chapter == null:
		return
	var start_id: String = _nav.start_id()
	var on_start: bool = not start_id.is_empty()
	if not page.scene.milestone.is_empty() and GoalRules.milestone_number(chapter, page.scene) == 0:
		_log.call("цель главы: веха «%s» сцены «%s» не описана" % [page.scene.milestone, page.scene.id])
	var reached: int = GoalRules.next_milestone_max(chapter, page.scene, on_start, _state.milestone_max(), _fail_flag_set(chapter))
	_state.set_attempt(start_id if on_start else _state.attempt_start(), reached)
	_goal_pending = false
	_chapter_done = false
	if on_start:
		_final_shown = false
	goal_changed.emit()


func _mark_text_shown(scene: SceneData) -> void:
	var chapter: ChapterData = _chapter_of(_nav.position().chapter)
	var failed: bool = chapter != null and _fail_flag_set(chapter)
	if GoalRules.is_impossible(failed, _goal_pending, _final_shown):
		_log.call("цель главы: ошибка потока, признаки провал_ждёт и финал_показан несовместимы с флагом")
	var shown: bool = _final_shown or scene.final
	if not _goal_pending and shown == _final_shown:
		return
	_goal_pending = false
	_final_shown = shown
	goal_changed.emit()


# Э-21 and Э-24 on a load: the context is made valid before the first view and F2, the corrected value
# goes into the state; «провал_ждёт» is derived from the pending outcome, «финал_показан» is false.
func _restore_goal(position: StoryPosition) -> void:
	_final_shown = false
	_goal_pending = false
	var chapter: ChapterData = _chapter_of(position.chapter)
	if chapter == null:
		return
	var failed: bool = _fail_flag_set(chapter)
	var context: GoalRules.Context = GoalRules.normalize_context(chapter, _scene_of(chapter, position.scene), _state.attempt_start(), _state.milestone_max(), failed)
	_state.set_attempt(context.start, context.milestone_max)
	if not context.issue.is_empty():
		_log.call(context.issue)
	var pending: OutcomeData = _find_outcome(position.pending_outcome)
	_goal_pending = failed and pending != null and pending.sets.has(chapter.goal_fail_flag) and _set_by(chapter.goal_fail_flag, pending.id, position)


# Э-24, AC-72: the flag was not standing when this scene was entered. A node scene has its entry snapshot
# as the last schema snapshot: exact, also after a loop of the graph. Otherwise the last journal record
# must be the SET of this very outcome on this scene (a flag that already stood journals nothing).
# shortcut: a plain (non-node) scene revisited by a loop with no other journal record in between reads as pending
# after a load; close it when the entry snapshot of every scene is kept.
func _set_by(flag_id: String, outcome_id: String, position: StoryPosition) -> bool:
	if not _schema.is_empty():
		var entry_snapshot: RunBody.Snapshot = _schema.back()
		if entry_snapshot.position.scene == position.scene and entry_snapshot.position.transition == position.transition:
			return not entry_snapshot.state.has_flag(flag_id)
	var records: Array[RunState.Entry] = _state.journal()
	if records.is_empty():
		return false
	var last: RunState.Entry = records.back()
	return last.action == RunState.Entry.Action.SET and last.flag == flag_id and last.outcome == outcome_id and last.scene == position.scene


func _chapter_of(chapter_id: String) -> ChapterData:
	for chapter: ChapterData in _hero.chapters:
		if chapter.id == chapter_id:
			return chapter
	return null


func _scene_of(chapter: ChapterData, scene_id: String) -> SceneData:
	for scene: SceneData in chapter.scenes:
		if scene.id == scene_id:
			return scene
	return null


func _fail_flag_set(chapter: ChapterData) -> bool:
	return not chapter.goal_fail_flag.is_empty() and _state.has_flag(chapter.goal_fail_flag)


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
			return _state_accepts(outcome_id)
	_log.call("исход «%s» не применён: он не из вариантов сцены «%s»" % [outcome_id, page.scene.id])
	return false


# State is asked before a result is taken: its refusal logs once and nothing else happens.
func _state_accepts(outcome_id: String) -> bool:
	if _state.can_apply():
		return true
	_log.call("исход «%s» не применён: Состояние ответило «не применено»" % outcome_id)
	return false


func _apply(outcome_id: String) -> StoryScreen:
	var scene_id: String = _nav.position().scene
	var outcome: OutcomeData = _find_outcome(outcome_id)
	var chapter: ChapterData = _chapter_of(_nav.position().chapter)
	var failed_before: bool = chapter != null and _fail_flag_set(chapter)
	if not _state.apply_outcome(scene_id, outcome_id, outcome.sets, outcome.clears):
		_log.call("исход «%s» не применён: Состояние ответило «не применено»" % outcome_id)
		_flow_error = true
		return null
	_goal_pending = chapter != null and not failed_before and _fail_flag_set(chapter)
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
	if page.kind == StoryScreen.Kind.CODA:
		_mark_text_shown(page.scene)
	if page.kind == StoryScreen.Kind.SCENE:
		_turn = null
		_enter_goal(page)
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
		var frozen: RunState = _frozen(_state)
		if frozen != null:
			_schema.append(RunBody.Snapshot.new(frozen, position))


# A schema snapshot keeps its own state: the live one keeps changing. Null, with the findings logged,
# when the copy does not read back: that snapshot is left out, nothing crashes.
func _frozen(state: RunState) -> RunState:
	var issues: Array[DataIssue] = []
	var copy: RunState = RunState.from_dict(state.to_dict(), "session", issues, _hero.flags, _log)
	for issue: DataIssue in issues:
		_log.call("снимок схемы: %s %s: %s" % [issue.code, issue.path, issue.message])
	return copy


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
	_restore_goal(body.resume.position)
	_enter_views(page)
	if body.roll != null:
		_turn = CheckTurn.restore(page, body.roll, _commit_roll, _log)
	loaded.emit(SaveWriter.LoadCode.OK, page)
