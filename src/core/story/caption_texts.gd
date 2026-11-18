class_name CaptionTexts
extends RefCounted
## Option captions of the Reading and Roll screens (reading-screen.md, Dependencies «готовая подпись»;
## choice-system.md, rule 4; d20-checks.md AC-07). The words live in `assets/data/config/captions.json`,
## the code only fills the templates and writes the sign (U+2212 for a minus, `+` for a plus).
## A file that did not read whole is not `valid`: the captions are empty and the caller logs it.
##
## Usage: [code]var line: String = texts.risky("strength", 4, "medium", 13, 60)[/code]

const PATH := "res://assets/data/config/captions.json"
const MINUS := "−"
const TEMPLATES: PackedStringArray = ["risky", "plain", "plain_price", "closed"]

var valid: bool = false
var _templates: Dictionary[String, String] = {}
var _levels: Dictionary = {}
var _stats: Dictionary = {}


## Reads the file at `path`; a finding goes to `issues` and leaves the texts invalid.
static func load_file(path: String, issues: Array[DataIssue]) -> CaptionTexts:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return CaptionTexts.new()
	return from_dict(data, path, issues)


static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> CaptionTexts:
	var texts: CaptionTexts = CaptionTexts.new()
	for key: String in TEMPLATES:
		if not data.get(key) is String:
			issues.append(DataIssue.new("DT-03", source, key, "нет шаблона подписи"))
			return texts
		texts._templates[key] = data[key]
	if not data.get("levels") is Dictionary or not data.get("stats") is Dictionary:
		issues.append(DataIssue.new("DT-03", source, "levels", "нет таблицы уровней или характеристик"))
		return texts
	texts._levels = data["levels"]
	texts._stats = data["stats"]
	texts.valid = true
	return texts


## Name of a stat; its id when the file does not name it.
func stat_name(stat_id: String) -> String:
	return str(_stats.get(stat_id, stat_id))


## Word of a check level; its id when the file does not name it.
func level_word(level: String) -> String:
	return str(_levels.get(level, level))


## «+4», «0», «−1».
static func signed(bonus: int) -> String:
	if bonus > 0:
		return "+%d" % bonus
	if bonus < 0:
		return "%s%d" % [MINUS, -bonus]
	return "0"


## «Сила +4 · Средне 13 · шанс 60 %».
func risky(stat_id: String, bonus: int, level: String, dc: int, chance: int) -> String:
	return _fill("risky", {"stat": stat_name(stat_id), "bonus": signed(bonus), "level": level_word(level), "dc": str(dc), "chance": str(chance)})


## «Без броска», with the price «Без броска · цена» when there is one.
func plain(price: String = "") -> String:
	if price.is_empty():
		return _fill("plain", {})
	return _fill("plain_price", {"price": price})


## «Сила закрыта: причина».
func closed(stat_id: String, reason: String) -> String:
	return _fill("closed", {"stat": stat_name(stat_id), "reason": reason})


func _fill(key: String, values: Dictionary) -> String:
	var line: String = _templates.get(key, "")
	for name: String in values:
		line = line.replace("{%s}" % name, values[name])
	return line
