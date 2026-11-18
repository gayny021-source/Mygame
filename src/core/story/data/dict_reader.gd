class_name DictReader
extends RefCounted
## Typed reads from one JSON object. Data is a trust boundary (ADR-0001 §4): a
## wrong type, a missing or an unknown key becomes a DataIssue, never a crash.

const SCHEMA_VERSION: int = 1
## 2^53: above it a JSON number (a float) no longer holds every whole number.
const MAX_WHOLE: float = 9007199254740992.0

static var _id_pattern: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")

## Path of this object for findings: `<source>/<key>/<id or index>/...`.
var path: String
## The object's `id`, or empty when it has none.
var object_id: String
var _data: Dictionary
var _issues: Array[DataIssue]


## Wraps one JSON object; findings are appended to [param issues].
func _init(data: Dictionary, object_path: String, issues: Array[DataIssue]) -> void:
	_data = data
	path = object_path
	_issues = issues
	if has_text("id"):
		object_id = data["id"]


## True when `value` matches `^[a-z][a-z0-9_]*$` (branching-story.md, Core Rules 2).
static func is_id(value: String) -> bool:
	var found: RegExMatch = _id_pattern.search(value)
	# `$` также совпадает перед завершающим переводом строки, поэтому сверяем всё значение
	return found != null and found.get_string() == value


## Path segment of a list element: its `id`, or its index when the id is empty.
static func label(id: String, index: int) -> String:
	return str(index) if id.is_empty() else id


## Adds a finding about the key `key` of this object.
func issue(code: String, key: String, message: String) -> void:
	_issues.append(DataIssue.new(code, "%s/%s" % [path, key], object_id, message))


## True when `key` holds a string.
func has_text(key: String) -> bool:
	return _data.get(key) is String


## True when the object has the key `key`, whatever its value.
func has(key: String) -> bool:
	return _data.has(key)


## True when `key` holds an array. A list that is absent or of another type already
## has its DT finding, so checks that depend on it are skipped.
func has_list(key: String) -> bool:
	return _data.get(key) is Array


## First call on the root object of a file. Checks `schema_version` (absent is
## DT-03, not a whole number is DT-02, another version is DT-07), then the keys:
## a file of another version is not read any further.
func schema_ok(known_keys: PackedStringArray) -> bool:
	var before: int = _issues.size()
	var version: int = integer("schema_version")
	if _issues.size() > before:
		return false
	if version != SCHEMA_VERSION:
		issue("DT-07", "schema_version", "версия схемы %d, загрузчик читает только %d" % [version, SCHEMA_VERSION])
		return false
	_check_keys(known_keys)
	return true


## Required `id`; DT-06 when it does not match the id pattern (an empty id too).
func id() -> String:
	var value: String = _string("id", true)
	if has_text("id") and not is_id(value):
		issue("DT-06", "id", "id «%s» не подходит под ^[a-z][a-z0-9_]*$" % value)
	return value


## String value; empty when the key is absent or holds another type.
## An empty required string is DT-02.
func text(key: String, required: bool = true) -> String:
	var value: String = _string(key, required)
	if required and value.is_empty() and has_text(key):
		issue("DT-02", key, "обязательная строка пуста")
	return value


## Optional `if` text. A present but empty string is DT-08 (no condition means no key).
func condition() -> String:
	var value: String = text("if", false)
	if has_text("if") and value.is_empty():
		issue("DT-08", "if", "пустая строка if; если условия нет, уберите ключ")
	return value


## Required string from `allowed`; DT-05 for any other non-empty string.
func one_of(key: String, allowed: PackedStringArray) -> String:
	var value: String = text(key)
	if not value.is_empty() and not allowed.has(value):
		issue("DT-05", key, "значение «%s» не из списка: %s" % [value, ", ".join(allowed)])
	return value


## Bool, false by default; with `required` an absent key is DT-03.
func flag(key: String, required: bool = false) -> bool:
	return typed(key, TYPE_BOOL, required) == true


## Required whole number. JSON gives every number as float, so a fraction or a
## value beyond ±2^53 is DT-02; an int comes only from a Dictionary built in code.
func integer(key: String) -> int:
	if _data.get(key) is int:
		return _data[key]
	var value: Variant = typed(key, TYPE_FLOAT, true)
	if value == null:
		return 0
	var number: float = value
	if number != floorf(number) or absf(number) > MAX_WHOLE:
		issue("DT-02", key, "ожидалось целое число в пределах ±2^53, получено %s" % number)
		return 0
	return int(number)


## Array of strings; an element of another type is DT-02 and is skipped.
func strings(key: String, required: bool = true) -> PackedStringArray:
	return PackedStringArray(strings_by_index(key, required).values())


## Strings of the array under `key` by their index in the JSON array, in file order.
## An element of another type is DT-02 and is skipped, so the indexes may have gaps:
## a finding about an element names the index the writer sees in the file.
func strings_by_index(key: String, required: bool = true) -> Dictionary:
	var result: Dictionary = {}
	var items: Array = _list(key, required)
	for i: int in items.size():
		if items[i] is String:
			result[i] = items[i]
		else:
			issue("DT-02", "%s/%d" % [key, i], "ожидалась строка")
	return result


## Reader of the object under `key`; null when the key is absent or is not an object.
func child(key: String, known_keys: PackedStringArray) -> DictReader:
	var value: Variant = typed(key, TYPE_DICTIONARY, false)
	if value == null:
		return null
	var reader: DictReader = DictReader.new(value, "%s/%s" % [path, key], _issues)
	reader._check_keys(known_keys)
	return reader


## Readers of the objects in the array under `key`. With `text_shorthand` a string
## element stands for `{"text": <string>}` (ADR-0001 §1, paragraph forms).
func children(key: String, known_keys: PackedStringArray, required: bool = true, text_shorthand: bool = false) -> Array[DictReader]:
	var result: Array[DictReader] = []
	var items: Array = _list(key, required)
	for i: int in items.size():
		var item: Variant = items[i]
		if text_shorthand and item is String:
			item = {"text": item}
		if not item is Dictionary:
			issue("DT-02", "%s/%d" % [key, i], "ожидался объект")
			continue
		var element: Dictionary = item
		var element_id: Variant = element.get("id")
		var element_label: String = label(element_id if element_id is String else "", i)
		var reader: DictReader = DictReader.new(element, "%s/%s/%s" % [path, key, element_label], _issues)
		reader._check_keys(known_keys)
		result.append(reader)
	return result


# Ключи вне таблицы ADR-0001 — DT-04; ключи `_*` оставлены сценаристу под заметки.
func _check_keys(known_keys: PackedStringArray) -> void:
	for key: String in _data:
		if not key.begins_with("_") and not known_keys.has(key):
			issue("DT-04", key, "неизвестный ключ")


func _string(key: String, required: bool) -> String:
	var value: Variant = typed(key, TYPE_STRING, required)
	if value == null:
		return ""
	return value


func _list(key: String, required: bool) -> Array:
	var value: Variant = typed(key, TYPE_ARRAY, required)
	if value == null:
		return []
	return value


## Raw value of `type` under `key`; null when absent (DT-03 with `required`) or of another type
## (DT-02). For a nested object handed whole to another reader's from_dict (RunBody, ADR-0002 §6).
func typed(key: String, type: Variant.Type, required: bool) -> Variant:
	if not _data.has(key):
		if required:
			issue("DT-03", key, "нет обязательного ключа")
		return null
	var value: Variant = _data[key]
	if typeof(value) != type:
		issue("DT-02", key, "ожидался тип %s, получен %s" % [type_string(type), type_string(typeof(value))])
		return null
	return value
