class_name CountingD20Source
extends D20Source
## Test double of the d20 source (d20-checks.md, rule 10; story S7): always the same face, counts its calls.

var calls: int = 0
var _face: int


func _init(face: int = 7) -> void:
	_face = face


func roll() -> int:
	calls += 1
	return _face
