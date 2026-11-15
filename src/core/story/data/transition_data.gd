class_name TransitionData
extends RefCounted
## Edge of the chapter graph (branching-story.md, Core Rules 6). The file value
## `scene:<id>` / `chapter_end` / `ending:<id>` is split into `to_kind` and `to_id`.

const TO_SCENE := "scene"
const TO_CHAPTER_END := "chapter_end"
const TO_ENDING := "ending"

var id: String
var to_kind: String
var to_id: String
var bridge: BridgeData
var coda: Array[ParagraphData] = []
var early: bool
var deprecated: bool
