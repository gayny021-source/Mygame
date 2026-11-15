class_name SceneData
extends RefCounted
## Scene: text and one choice (branching-story.md, Core Rules 3).

var id: String
var title: String
var paragraphs: Array[ParagraphData] = []
var illustration: String
var options: Array[OptionData] = []
var milestone: String
var node: bool
var final: bool
var deprecated: bool
