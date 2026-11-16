class_name RunState
extends ConditionContext
## Flag state of one run (run-state.md, Core Rules 1-4, 10; ADR-0001 §6, story S3).
## Only apply_outcome, end_chapter and finish change it. Errors during play go to the
## injected `log_error` (push_error when none is given), never a crash.
## Snapshot and restore are the save story, not here.
##
## Usage: [code]var state := RunState.new(hero.flags); state.apply_outcome("s1", "o1", sets, clears)[/code]

## Journal outcome id for flags cleared at the end of a chapter.
const CHAPTER_END_OUTCOME := "chapter_end"

enum Status { RUNNING, FINISHED }


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


var _status: Status = Status.RUNNING
var _decls: Dictionary[String, FlagDecl] = {}
var _active: Dictionary[String, bool] = {}
var _journal: Array[Entry] = []
var _log_error: Callable


## `declarations` are all flags of the hero; `log_error` takes one String.
func _init(declarations: Array[FlagDecl], log_error: Callable = Callable()) -> void:
	for decl: FlagDecl in declarations:
		_decls[decl.id] = decl
	_log_error = log_error


## Applies the `sets` then the `clears` of an outcome. False (nothing changed) once the run is finished.
## An undeclared id is logged and skipped; an id both set and cleared ends cleared.
func apply_outcome(scene_id: String, outcome_id: String, sets: PackedStringArray, clears: PackedStringArray) -> bool:
	if _status == Status.FINISHED:
		_report("прохождение завершено: исход «%s» не применён" % outcome_id)
		return false
	for id: String in sets:
		if _declared(id):
			_stand(id, scene_id, outcome_id)
	for id: String in clears:
		if _declared(id):
			_drop(id, scene_id, outcome_id)
	return true


## Clears every standing flag with scope `chapter`. False once the run is finished.
func end_chapter() -> bool:
	if _status == Status.FINISHED:
		_report("прохождение завершено: конец главы не применён")
		return false
	for decl: FlagDecl in _decls.values():
		if decl.scope == FlagDecl.SCOPE_CHAPTER:
			_drop(decl.id, "", CHAPTER_END_OUTCOME)
	return true


## Freezes the run (an ending was reached); queries keep working. False when already finished.
func finish() -> bool:
	if _status == Status.FINISHED:
		_report("прохождение уже завершено")
		return false
	_status = Status.FINISHED
	return true


## True after finish().
func is_finished() -> bool:
	return _status == Status.FINISHED


## True when the flag stands. An undeclared id is logged and answers false.
func has_flag(id: String) -> bool:
	if not _declared(id):
		return false
	return _active.has(id)


func any_in_category(category: String) -> bool:
	return not active_in_category(category).is_empty()


func flag_in_group(group: String) -> String:
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


## Ids of the stats closed by standing flags, each once.
func blocked_stats() -> PackedStringArray:
	var result: PackedStringArray = []
	for decl: FlagDecl in active_flags():
		for stat: String in decl.blocks:
			if not result.has(stat):
				result.append(stat)
	return result


## Journal in the order of events (a new list; the entries are shared, do not edit them).
func journal() -> Array[Entry]:
	return _journal.duplicate()


# Группа вытесняет: прежний флаг снимается и пишется раньше нового (run-state.md, правило 10).
func _stand(id: String, scene_id: String, outcome_id: String) -> void:
	if _active.has(id):
		return
	var group: String = _decls[id].group
	if not group.is_empty():
		var standing: String = flag_in_group(group)
		if not standing.is_empty():
			_drop(standing, scene_id, outcome_id)
	_active[id] = true
	_journal.append(Entry.new(id, Entry.Action.SET, scene_id, outcome_id))


func _drop(id: String, scene_id: String, outcome_id: String) -> void:
	if not _active.has(id):
		return
	_active.erase(id)
	_journal.append(Entry.new(id, Entry.Action.CLEARED, scene_id, outcome_id))


func _declared(id: String) -> bool:
	if _decls.has(id):
		return true
	_report("флаг «%s» не объявлен у героя" % id)
	return false


func _report(message: String) -> void:
	if _log_error.is_valid():
		_log_error.call(message)
	else:
		push_error(message)
