class_name D20Result
extends RefCounted
## Result of one d20 check (d20-checks.md, rule 9 and formulas 1, 5, 6; story S7). A value built
## by D20Check.resolve: the UI draws it, nothing reads the run state to make it. Text, gender and
## the U+2212 minus of the labels belong to the UI (AC-07).

enum Crit { NONE, SUCCESS, FAILURE }

var check_id: String
var stat_id: String
## `check.success` on a success, `check.failure` otherwise; a crit leads to the same outcome.
var outcome_id: String
## Natural face 1…20.
var roll: int
var bonus: int
## roll + bonus, not clamped: 0 is a legal total.
var total: int
var dc: int
var success: bool
## By the face only: SUCCESS on 20, FAILURE on 1.
var crit: Crit
## The crit line of the check after strip_edges(); empty off a crit and for a blank line.
## The UI puts it before the outcome paragraphs.
var crit_line: String
## The bonus changed the result (formula 5): «решила» when `success`, «подвела» otherwise.
var bonus_decided: bool
var rerolled: bool
