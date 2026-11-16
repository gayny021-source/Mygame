class_name BridgeData
extends RefCounted
## Bridge of a transition into a scene: `base` with the `{insert}` mark and conditional inserts.

## Place of the insert in `base`; no spaces sit next to it (UR-1, CEO decision).
const INSERT_MARK := "{insert}"
## Signs that take no space before them (typography, not balance).
const CLOSING := ",.;:!?…)»”"
## Signs that take no space after them.
const OPENING := "(«„“"

var base: String
var inserts: Array[ParagraphData] = []


## `base` with `insert` in place of the mark; an empty `insert` is a hidden one and leaves no trace.
## A shown insert is parted from its neighbours by one space, none before a closing sign
## (branching-story.md, AC-52; UR-1). Without a mark returns `base`.
##
## Usage: [code]bridge.joined("и ветер")[/code] on "Мост{insert}." gives "Мост и ветер."
func joined(insert: String) -> String:
	var at: int = base.find(INSERT_MARK)
	if at < 0:
		return base
	var left: String = base.left(at)
	var right: String = base.substr(at + INSERT_MARK.length())
	if insert.is_empty():
		return left + _gap(left, right) + right
	return left + _gap(left, insert) + insert + _gap(insert, right) + right


static func _gap(before: String, after: String) -> String:
	if before.is_empty() or after.is_empty():
		return ""
	if CLOSING.contains(after[0]) or OPENING.contains(before[-1]):
		return ""
	return " "
