class_name CheckData
extends RefCounted
## d20 check of a risky option (d20-checks.md, rule 1). `success` and `failure` are outcome ids.

const LEVELS: PackedStringArray = ["easy", "medium", "hard"]

var id: String
var stat: String
var level: String
var success: String
var failure: String
var crit_success_line: String
var crit_failure_line: String
