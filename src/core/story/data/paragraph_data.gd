class_name ParagraphData
extends RefCounted
## Paragraph of a scene, outcome or coda, and an insert of a bridge (ADR-0001 §1).
## `condition` is the raw `if` text; empty means unconditional.

var text: String
var condition: String
var speaks: String
var damage: String
