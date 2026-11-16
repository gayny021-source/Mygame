class_name EngineD20Source
extends D20Source
## The game's d20 (d20-checks.md, rule 10): its own RandomNumberGenerator, randomly seeded at
## creation, so every process start gives a new sequence. The generator state is not saved.
##
## Usage: [code]var source: D20Source = EngineD20Source.new()[/code]

var _rng: RandomNumberGenerator


## `rng` is injected only by the χ² test, with a fixed seed (AC-10).
func _init(rng: RandomNumberGenerator = RandomNumberGenerator.new()) -> void:
	_rng = rng


func roll() -> int:
	return _rng.randi_range(1, 20)
