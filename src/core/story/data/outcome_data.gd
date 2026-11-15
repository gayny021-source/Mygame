class_name OutcomeData
extends RefCounted
## Outcome of an option (branching-story.md, Core Rules 5). `sets` and `clears` are flag ids.

var id: String
var paragraphs: Array[ParagraphData] = []
var sets: PackedStringArray
var clears: PackedStringArray
var routes: Array[RouteData] = []
var deprecated: bool
