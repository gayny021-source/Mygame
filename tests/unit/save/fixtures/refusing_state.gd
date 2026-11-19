class_name RefusingState
extends RunState
## Test double: a RunState that refuses every outcome («не применено») and counts the calls.

var asked: int = 0
var applied: int = 0


func can_apply() -> bool:
	asked += 1
	return false


func apply_outcome(_scene_id: String, _outcome_id: String, _sets: PackedStringArray, _clears: PackedStringArray) -> bool:
	applied += 1
	return false
