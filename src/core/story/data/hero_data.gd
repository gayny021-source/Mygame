class_name HeroData
extends RefCounted
## Hero passport from hero.json (ADR-0001 §1; heroes.md, rule 1).

var id: String
var stats: Array[StatData] = []
var chapter_ids: PackedStringArray
var chapters: Array[ChapterData] = []
var endings: PackedStringArray
var portrait: String
var accent: String
var sum_exception: String
## Declarations from flags.json; empty when the hero has no such file.
var flags: Array[FlagDecl] = []
