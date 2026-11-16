class_name ScriptedD20Source
extends D20Source
## Test-only d20, kept out of src/ so a release build cannot ship it (d20-checks.md, rule 10; AC-09):
## gives the faces of `tokens` in order, then rolls `fallback`. A token that is not a whole number 1…20 is
## logged and replaced by one fallback roll; it is spent either way. The position lives only in
## this instance: a new instance starts the list again, a replayed chapter does not.
##
## Usage: [code]ScriptedD20Source.new("14,3".split(","), EngineD20Source.new(), log)[/code]

var _tokens: PackedStringArray
var _fallback: D20Source
var _log: Callable
var _next: int = 0


## `log_error` takes one String.
func _init(tokens: PackedStringArray, fallback: D20Source, log_error: Callable) -> void:
	_tokens = tokens
	_fallback = fallback
	_log = log_error


func roll() -> int:
	if _next >= _tokens.size():
		return _fallback.roll()
	var token: String = _tokens[_next].strip_edges()
	_next += 1
	# to_int() reads "12.5" as 12: only is_valid_int() tells a whole number
	var face: int = token.to_int()
	if token.is_valid_int() and face >= 1 and face <= 20:
		return face
	_log.call("ScriptedD20Source: «%s» — не грань 1…20, бросает запасной источник" % token)
	return _fallback.roll()
