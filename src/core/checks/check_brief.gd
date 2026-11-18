class_name CheckBrief
extends RefCounted
## What the Roll screen reads before the roll (roll-screen.md, Dependencies Д-3): the numbers of the
## check, from the same functions as the caption. A restored turn is briefed by its record.

var check_id: String
var stat_id: String
var level: String
var bonus: int
var dc: int
## Smallest face that succeeds (D20Check.need) and the chance in percent (D20Check.chance).
var need: int
var chance: int
## The option the check belongs to: its text and the reason of the past («[Гарзуг рядом]»).
var option_text: String
var option_reason: String
## Filled by RunSession from CaptionTexts.
var stat_name: String
var level_word: String
var caption: String
