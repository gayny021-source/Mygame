class_name JsonLint
extends RefCounted
## Text pass over a JSON file before the parser (ADR-0001, Decision 4; S1 findings; story S5). The engine
## parser accepts a duplicate key (the last value wins), a trailing comma and a BOM, so only this pass sees
## them; bytes that are not UTF-8 are reported here too. Every finding is DT-01 with `<source>:<line>`.
## Syntax errors are left to the parser (ChapterLoader.read_object).
##
## Usage: [code]var issues: Array[DataIssue] = JsonLint.check(FileAccess.get_file_as_bytes(path), path)[/code]

const BOM: PackedByteArray = [0xEF, 0xBB, 0xBF]
const SPACE := " \t\r\n"
const ESCAPES: Dictionary[String, String] = {"\"": "\"", "\\": "\\", "/": "/", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t"}


## Findings of the text `bytes` of the file `source`; empty bytes have none.
static func check(bytes: PackedByteArray, source: String) -> Array[DataIssue]:
	var issues: Array[DataIssue] = []
	var start: int = 0
	if bytes.slice(0, 3) == BOM:
		issues.append(_issue(source, 1, "BOM в начале файла: сохраните в UTF-8 без BOM"))
		start = 3
	var bad: int = _bad_utf8(bytes, start)
	if bad >= 0:
		var line: int = bytes.slice(0, bad).count(0x0A) + 1
		issues.append(_issue(source, line, "байт 0x%02X не UTF-8: сохраните файл в UTF-8" % bytes[bad]))
		return issues
	_scan(bytes.slice(start).get_string_from_utf8(), source, issues)
	return issues


static func _issue(source: String, line: int, message: String) -> DataIssue:
	return DataIssue.new("DT-01", "%s:%d" % [source, line], "", message)


# Index of the first byte that breaks UTF-8 from `start`, or -1.
# Known limit (TD S5 round 1, rejected as YAGNI): overlong 3- and 4-byte forms and surrogates pass.
static func _bad_utf8(bytes: PackedByteArray, start: int) -> int:
	var i: int = start
	while i < bytes.size():
		var lead: int = bytes[i]
		var extra: int = -1
		if lead < 0x80:
			extra = 0
		elif lead >= 0xC2 and lead <= 0xDF:
			extra = 1
		elif lead >= 0xE0 and lead <= 0xEF:
			extra = 2
		elif lead >= 0xF0 and lead <= 0xF4:
			extra = 3
		if extra < 0 or i + extra >= bytes.size():
			return i
		for k: int in range(1, extra + 1):
			if (bytes[i + k] & 0xC0) != 0x80:
				return i
		i += extra + 1
	return -1


# One frame per open bracket: the keys seen in an object; arrays get a frame with no keys.
static func _scan(text: String, source: String, issues: Array[DataIssue]) -> void:
	var keys: Array[Dictionary] = []
	var is_object: Array[bool] = []
	var expect_key: bool = false
	var after_comma: bool = false
	var line: int = 1
	var i: int = 0
	while i < text.length():
		var symbol: String = text[i]
		if symbol == "\"":
			var end: int = _string_end(text, i)
			if expect_key:
				_key(text.substr(i + 1, end - i - 1), keys[-1], source, line, issues)
				expect_key = false
			line += text.substr(i, end - i).count("\n")
			after_comma = false
			i = end + 1
			continue
		match symbol:
			"\n":
				line += 1
			"{", "[":
				var frame: Dictionary[String, bool] = {}
				keys.append(frame)
				is_object.append(symbol == "{")
				expect_key = symbol == "{"
				after_comma = false
			"}", "]":
				if after_comma:
					issues.append(_issue(source, line, "висячая запятая перед «%s»" % symbol))
				if not keys.is_empty():
					keys.pop_back()
					is_object.pop_back()
				expect_key = false
				after_comma = false
			",":
				after_comma = true
				expect_key = not is_object.is_empty() and is_object[-1]
			_:
				if not SPACE.contains(symbol):
					after_comma = false
		i += 1


# Keys are compared after escapes: "a" and "\u0061" are one key for the parser.
static func _key(raw: String, seen: Dictionary[String, bool], source: String, line: int, issues: Array[DataIssue]) -> void:
	var key: String = _unescape(raw)
	if seen.has(key):
		issues.append(_issue(source, line, "ключ «%s» повторяется в одном объекте: парсер молча оставит последний" % key))
	seen[key] = true


# JSON escapes of a string body: \uXXXX and the one-letter ones; anything else is left as written.
static func _unescape(raw: String) -> String:
	if not raw.contains("\\"):
		return raw
	var result: String = ""
	var i: int = 0
	while i < raw.length():
		var symbol: String = raw[i]
		if symbol != "\\" or i + 1 >= raw.length():
			result += symbol
			i += 1
			continue
		var letter: String = raw[i + 1]
		var hex: String = raw.substr(i + 2, 4)
		if letter == "u" and hex.length() == 4 and hex.is_valid_hex_number():
			result += char(hex.hex_to_int())
			i += 6
			continue
		result += ESCAPES.get(letter, "\\" + letter)
		i += 2
	return result


# Index of the closing quote of the string that opens at `start` (or the end of the text).
static func _string_end(text: String, start: int) -> int:
	var j: int = start + 1
	while j < text.length():
		var symbol: String = text[j]
		if symbol == "\\":
			j += 2
			continue
		if symbol == "\"":
			return j
		j += 1
	return text.length()
