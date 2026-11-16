@abstract
class_name D20Source
extends RefCounted
## Source of the natural d20 face (d20-checks.md, rule 10; ADR-0001 §6; story S7). The game uses
## EngineD20Source; tests use the doubles in tests/fixtures/checks/.
##
## Usage: [code]var face: int = source.roll()[/code]

## One face 1…20; every call is one roll.
@abstract func roll() -> int
