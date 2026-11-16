class_name CheckTurn
extends RefCounted
## Life of one d20 check, from the tap on a risky option to «Продолжить» (d20-checks.md, States and
## the event rule; DD-020, DD-021; story S7). The only caller of the Save `commit` in transitions 3
## (rolled) and 7 (applied); it never reads or writes RunState. The first accepted event changes the
## phase in the same call, so a double tap is refused; a refused event returns null or false and
## calls nothing. «Брошена» and «Итог показан» differ only by the animation: both are ROLLED here.
##
## Usage: [code]var r: D20Result = turn.proceed()[/code], then the Choice system applies
## `r.outcome_id` to the state and calls `navigator.outcome_applied(r.outcome_id)`.

enum Phase { CHOSEN, ROLLED, APPLIED, CANCELLED }

## Save transitions this class commits (save-system.md).
const COMMIT_ROLLED := 3
const COMMIT_APPLIED := 7

var phase: Phase
var check: CheckData
var scene_id: String
## Null before the roll.
var result: D20Result
## Null before the roll; `applied` is set by `proceed`.
var record: RollRecord
var _d20: D20Check
var _hero: HeroData
var _commit: Callable
var _log: Callable


## A check chosen on `screen`; null when the screen is not a scene, `option` is not a risky option of
## it (an error screen writes nothing), or the d20 config is not valid (risky options are hidden then,
## and that one is logged).
## `commit` takes (transition: int, record: RollRecord) and serializes the record at once; `log_error`
## takes one String.
static func choose(screen: StoryScreen, option: OptionData, hero: HeroData, d20: D20Check, commit: Callable, log_error: Callable) -> CheckTurn:
	if screen == null or screen.kind != StoryScreen.Kind.SCENE:
		return null
	if option == null or option.check == null or not screen.scene.options.has(option):
		return null
	if not d20.config.valid:
		log_error.call("%s конфиг d20 недействителен: рискованный вариант «%s» скрыт" % [d20.config.issue_code, option.id])
		return null
	var turn: CheckTurn = CheckTurn.new()
	turn.phase = Phase.CHOSEN
	turn.check = option.check
	turn.scene_id = screen.scene.id
	turn._d20 = d20
	turn._hero = hero
	turn._commit = commit
	turn._log = log_error
	return turn


## The check of `record` after a load, shown again by the record's numbers (AC-21, AC-24): ROLLED,
## the source and `commit` not called. Null and one line to `log_error` when the screen is not the
## record's scene, the scene has no such check any more, or the record does not fit it (another stat, a
## bonus outside STAT_BONUS_MIN…MAX; the DC is not compared, AC-21): the record is dropped, the player
## chooses again.
static func restore(screen: StoryScreen, record: RollRecord, commit: Callable, log_error: Callable) -> CheckTurn:
	if record == null:
		log_error.call("DT-02 запись о броске отброшена: записи нет")
		return null
	if screen == null or screen.kind != StoryScreen.Kind.SCENE or screen.scene.id != record.scene_id:
		log_error.call("запись о броске отброшена: сцены «%s» нет на экране" % record.scene_id)
		return null
	var found: CheckData = null
	for option: OptionData in screen.scene.options:
		if option.check != null and option.check.id == record.check_id:
			found = option.check
	if found == null:
		log_error.call("запись о броске отброшена: в сцене «%s» нет проверки «%s»" % [record.scene_id, record.check_id])
		return null
	if record.stat_id != found.stat or record.bonus < D20Config.STAT_BONUS_MIN or record.bonus > D20Config.STAT_BONUS_MAX:
		log_error.call("DT-02 запись о броске отброшена: «%s» %+d не подходит к проверке «%s» (%s, бонус %d…%d)" % [record.stat_id, record.bonus, found.id, found.stat, D20Config.STAT_BONUS_MIN, D20Config.STAT_BONUS_MAX])
		return null
	var turn: CheckTurn = CheckTurn.new()
	turn.phase = Phase.ROLLED
	turn.check = found
	turn.scene_id = record.scene_id
	turn.record = record
	turn.result = D20Check.restore(record, found)
	turn._commit = commit
	turn._log = log_error
	return turn


## «Бросить»: only from CHOSEN. One call of the source, then commit 3 with an unapplied record. The
## phase changes only once the record exists; a level without a DC is logged and leaves CHOSEN.
func roll() -> D20Result:
	if phase != Phase.CHOSEN:
		return null
	var issues: Array[DataIssue] = []
	var rolled: D20Result = _d20.roll(check, _hero, issues)
	for issue: DataIssue in issues:
		_log.call("%s %s (%s): %s" % [issue.code, issue.path, check.id, issue.message])
	if rolled == null:
		return null
	result = rolled
	record = RollRecord.of(scene_id, result)
	phase = Phase.ROLLED
	_commit.call(COMMIT_ROLLED, record)
	return result


## «Передумать» or «Назад»: only from CHOSEN; the source is not touched.
func cancel() -> bool:
	if phase != Phase.CHOSEN:
		return false
	phase = Phase.CANCELLED
	return true


## «Продолжить»: only from ROLLED, so the result goes to the Choice system exactly once. Commits 7
## unless a restored record was already applied.
func proceed() -> D20Result:
	if phase != Phase.ROLLED:
		return null
	if record == null:
		_log.call("DT-02 «Продолжить» отклонено: у проверки «%s» нет записи о броске" % check.id)
		return null
	phase = Phase.APPLIED
	if not record.applied:
		record.applied = true
		_commit.call(COMMIT_APPLIED, record)
	return result
