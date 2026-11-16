class_name RunState
extends ConditionContext
## Flag state of one run (run-state.md, Core Rules 1-4, 10; ADR-0001 §6, story S3).
## Only apply_outcome and end_chapter change it. Errors during play go to the injected
## `log_error` (push_error when none is given), never a crash; an undeclared id is
## logged once. The status "finished", snapshot and restore are later stories
## (ending, save), not here.
##
## Usage: [code]var state := RunState.new(hero.flags); state.apply_outcome("s1", "o1", sets, clears)[/code]

## Journal outcome id for flags cleared at the end of a chapter.
const CHAPTER_END_OUTCOME := "chapter_end"


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


## True when the flag stands. An undeclared id is logged and answers false.
func has_flag(id: String) -> bool:
	if not _declared(id):
		return false
	return _active.has(id)


func any_in_category(category: String) -> bool:
	return not active_in_category(category).is_empty()


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
