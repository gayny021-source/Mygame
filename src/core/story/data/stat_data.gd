class_name StatData
extends RefCounted
## One hero stat from hero.json `stats` (ADR-0001 §4; heroes.md, rule 1).

var id: String
## Name the player reads («Сила»); required in hero.json.
var name: String
var bonus: int
