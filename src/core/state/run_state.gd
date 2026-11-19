class_name RunState
extends ConditionContext
## Flag state of one run (run-state.md, Core Rules 1-4, 10; ADR-0001 §6, story S3).
## Only apply_outcome and end_chapter change it. Errors during play go to the injected
## `log_error` (push_error when none is given), never a crash; an undeclared id is
## logged once. Snapshot and restore: to_dict and from_dict (save-system.md, rule 2;
## ADR-0002 §3; story SV1). The status "finished" is the ending story, not here.
##
## Usage: [code]var state := RunState.new(hero.flags); state.apply_outcome("s1", "o1", sets, clears)[/code]

## Journal outcome id for flags cleared at the end of a chapter.
const CHAPTER_END_OUTCOME := "chapter_end"
## Keys of a snapshot (ADR-0002 §3, B4; status comes with the endings story). `start` and `milestone_max`
## are the attempt context of the chapter goal (chapter-goal.md, rules 5, 12); a slot without them loads.
const KEYS: PackedStringArray = ["flags", "journal", "start", "milestone_max"]
const ENTRY_KEYS: PackedStringArray = ["flag", "action", "scene", "outcome"]
## Journal `action` in a snapshot, indexed by Entry.Action.
const ACTIONS: PackedStringArray = ["set", "cleared"]


## One journal record: which flag, set or cleared, in which scene, by which outcome.
class Entry extends RefCounted:
	enum Action { SET, CLEARED }

	var flag: String
	var action: Action
	var scene: String
	var outcome: String


	func _init(flag_id: String, flag_action: Action, scene_id: String, outcome_id: String) -> void:
		flag = flag_id
		action = flag_action
		scene = scene_id
		outcome = outcome_id


var _decls: Dictionary[String, FlagDecl] = {}
var _active: Dictionary[String, bool] = {}
var _journal: Array[Entry] = []
var _reported: Dictionary[String, bool] = {}
var _log_error: Callable
var _attempt_start: String
var _milestone_max: int


## `declarations` are all flags of the hero; `log_error` takes one String.
func _init(declarations: Array[FlagDecl], log_error: Callable = Callable()) -> void:
	for decl: FlagDecl in declarations:
		_decls[decl.id] = decl
	_log_error = log_error


## Applies the `sets` then the `clears` of an outcome. An undeclared id is logged and
## skipped; an id both set and cleared ends cleared.
func apply_outcome(scene_id: String, outcome_id: String, sets: PackedStringArray, clears: PackedStringArray) -> void:
	for id: String in sets:
		if _declared(id):
			_stand(id, scene_id, outcome_id)
	for id: String in clears:
		if _declared(id):
			_drop(id, scene_id, outcome_id)


## Clears every standing flag with scope `chapter`.
func end_chapter() -> void:
	for decl: FlagDecl in _decls.values():
		if decl.scope == FlagDecl.SCOPE_CHAPTER:
			_drop(decl.id, "", CHAPTER_END_OUTCOME)


## Attempt context of the chapter goal: the id of the `starts` entry the attempt began with and the
## highest milestone number reached (0 = not written). Only the story core writes it (chapter-goal.md, rule 12).
func set_attempt(start_id: String, milestone_max: int) -> void:
	_attempt_start = start_id
	_milestone_max = milestone_max


## Id of the `starts` entry of the attempt; empty when not written.
func attempt_start() -> String:
	return _attempt_start


## Highest milestone number of the attempt; 0 when not written.
func milestone_max() -> int:
	return _milestone_max


## True when the flag stands. An undeclared id is logged and answers false.
func has_flag(id: String) -> bool:
	if not _declared(id):
		return false
	return _active.has(id)


## True when at least one active flag belongs to the category.
func any_in_category(category: String) -> bool:
	return not active_in_category(category).is_empty()


## Id of the active flag standing in the group, or "" when none.
func flag_in_group(group: String) -> String:
	if group.is_empty():
		return ""
	for decl: FlagDecl in active_flags():
		if decl.group == group:
			return decl.id
	return ""


## Standing flags in declaration order (a new list, titles included).
func active_flags() -> Array[FlagDecl]:
	var result: Array[FlagDecl] = []
	for decl: FlagDecl in _decls.values():
		if _active.has(decl.id):
			result.append(decl)
	return result


## Standing flags of `category`.
func active_in_category(category: String) -> Array[FlagDecl]:
	var result: Array[FlagDecl] = []
	for decl: FlagDecl in active_flags():
		if decl.category == category:
			result.append(decl)
	return result


## Standing flags shown as chips on the hero card.
func visible_flags() -> Array[FlagDecl]:
	var result: Array[FlagDecl] = []
	for decl: FlagDecl in active_flags():
		if decl.visible:
			result.append(decl)
	return result


## Journal in the order of events (a new list; the entries are shared, do not edit them).
func journal() -> Array[Entry]:
	return _journal.duplicate()


## Snapshot for the save layer, a copy: ids of the standing flags in declaration order and the journal.
func to_dict() -> Dictionary:
	var flags: Array[String] = []
	for decl: FlagDecl in active_flags():
		flags.append(decl.id)
	var records: Array[Dictionary] = []
	for entry: Entry in _journal:
		records.append({"flag": entry.flag, "action": ACTIONS[entry.action], "scene": entry.scene, "outcome": entry.outcome})
	return {"flags": flags, "journal": records, "start": _attempt_start, "milestone_max": _milestone_max}


## State restored from a snapshot (run-state.md, rule 11): flags and journal are assigned as they
## are, outcomes are not replayed. A flag no longer declared for the hero is dropped with its journal
## records and logged once (run-state.md, AC-24; `deprecated` flags stay). Null when findings were
## appended to `issues`: DT-02, DT-03, DT-04, DT-05 a wrong action. Two flags of one group: the one
## set last in the journal stays (rule 10). `reported` shares «logged once» across one load.
static func from_dict(raw: Dictionary, path: String, issues: Array[DataIssue], declarations: Array[FlagDecl], log_error: Callable = Callable(), reported: Dictionary[String, bool] = {}) -> RunState:
	var before: int = issues.size()
	var state: RunState = RunState.new(declarations, log_error)
	state._reported = reported
	var reader: DictReader = DictReader.new(raw, path, issues)
	for key: Variant in raw:
		if not KEYS.has(key):
			reader.issue("DT-04", str(key), "неизвестный ключ")
	state._read_context(raw)
	for id: String in reader.strings("flags"):
		if state._declared(id):
			state._active[id] = true
	for item: DictReader in reader.children("journal", ENTRY_KEYS):
		var flag: String = item.text("flag")
		var action: int = ACTIONS.find(item.one_of("action", ACTIONS))
		var scene_id: String = item.text("scene", false)
		var outcome_id: String = item.text("outcome")
		if not flag.is_empty() and state._declared(flag):
			state._journal.append(Entry.new(flag, action as Entry.Action, scene_id, outcome_id))
	if issues.size() > before:
		return null
	state._one_per_group()
	return state


# Контекст попытки читается мягко (Э-21): неверный тип — как будто ключа нет, одно предупреждение;
# значения чинит История (GoalRules.normalize_context).
func _read_context(raw: Dictionary) -> void:
	if raw.has("start"):
		if raw["start"] is String:
			_attempt_start = raw["start"]
		else:
			_report("контекст попытки: «start» не строка, поле сброшено")
	if raw.has("milestone_max"):
		var value: Variant = raw["milestone_max"]
		var whole: bool = value is int or (value is float and value == floorf(value) and absf(value) < 1.0e9)
		if whole:
			_milestone_max = int(value)
		else:
			_report("контекст попытки: «milestone_max» не целое число, поле сброшено")


# Группа вытесняет: прежний флаг снимается и пишется раньше нового (run-state.md, правило 10).
func _stand(id: String, scene_id: String, outcome_id: String) -> void:
	if _active.has(id):
		return
	var standing: String = flag_in_group(_decls[id].group)
	if not standing.is_empty():
		_drop(standing, scene_id, outcome_id)
	_active[id] = true
	_journal.append(Entry.new(id, Entry.Action.SET, scene_id, outcome_id))


func _drop(id: String, scene_id: String, outcome_id: String) -> void:
	if not _active.has(id):
		return
	_active.erase(id)
	_journal.append(Entry.new(id, Entry.Action.CLEARED, scene_id, outcome_id))


# Правленые данные героя или подложный снимок дают два флага группы (правило 10): остаётся
# поставленный журналом последним, без записи в журнале — последний в списке; журнал не трогается.
func _one_per_group() -> void:
	var keep: Dictionary[String, String] = {}
	for id: String in _active:
		keep[_decls[id].group] = id
	for entry: Entry in _journal:
		if entry.action == Entry.Action.SET and _active.has(entry.flag):
			keep[_decls[entry.flag].group] = entry.flag
	var dropped: PackedStringArray = []
	var fresh: bool = false
	for id: String in _active.keys():
		var group: String = _decls[id].group
		if group.is_empty() or keep[group] == id:
			continue
		_active.erase(id)
		dropped.append(id)
		# Ключ с «:» не совпадёт с id флага: один лог на группу за загрузку (общий _reported).
		fresh = fresh or not _reported.has("group:" + group)
		_reported["group:" + group] = true
	if fresh:
		_report("в группе стоят несколько флагов, сняты: %s" % ", ".join(dropped))


# Условие читают часто: одна запись в лог на id, а не на каждый вызов.
func _declared(id: String) -> bool:
	if _decls.has(id):
		return true
	if not _reported.has(id):
		_reported[id] = true
		_report("флаг «%s» не объявлен у героя" % id)
	return false


func _report(message: String) -> void:
	if _log_error.is_valid():
		_log_error.call(message)
	else:
		push_error(message)
