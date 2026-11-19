class_name OutcomeData
extends RefCounted
## Outcome of an option (branching-story.md, Core Rules 5). `sets` and `clears` are flag ids.

const CARTOUCHES: PackedStringArray = ["bonk", "censor"]

var id: String
var paragraphs: Array[ParagraphData] = []
var sets: PackedStringArray
var clears: PackedStringArray
var routes: Array[RouteData] = []
## Closed set id of the cartouche over the outcome frame (НП-60), or empty: none.
var cartouche: String
var deprecated: bool
