class_name HeroData
extends RefCounted
## Hero passport from hero.json (ADR-0001 §1; heroes.md, rule 1). `stat_bonuses[i]` belongs to `stat_ids[i]`.

var id: String
var stat_ids: PackedStringArray
var stat_bonuses: PackedInt32Array
var chapter_ids: PackedStringArray
var chapters: Array[ChapterData] = []
var endings: PackedStringArray
var portrait: String
var accent: String
var sum_exception: String
