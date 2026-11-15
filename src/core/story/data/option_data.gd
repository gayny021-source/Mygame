class_name OptionData
extends RefCounted
## Option of a scene (branching-story.md, Core Rules 4). `check` is null when the file has none.

const KINDS: PackedStringArray = ["normal", "risky", "safe"]

var id: String
var text: String
var kind: String
var condition: String
var reason: String
var check: CheckData
var outcome: String
var exception: String
