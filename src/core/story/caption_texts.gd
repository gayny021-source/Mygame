class_name CaptionTexts
extends RefCounted
## Option captions of the Reading and Roll screens (reading-screen.md, Dependencies «готовая подпись»;
## choice-system.md, rule 4; d20-checks.md AC-07). The words live in `assets/data/config/captions.json`,
## the code only fills the templates and writes the sign (U+2212 for a minus, `+` for a plus).
## A file that did not read whole gives empty captions and findings in `issues`; the caller logs them.
## Stat names are not here: they come from the hero data (StatData.name).
##
## Usage: [code]var line: String = texts.risky("Сила", 4, "medium", 13, 60)[/code]

const PATH := "res://assets/data/config/captions.json"
const MINUS := "\u2212"
const KEYS: PackedStringArray = ["schema_version", "risky", "plain", "plain_price", "closed", "levels"]

var _risky: String
var _plain: String
var _plain_price: String
var _closed: String
var _levels: Dictionary[String, String] = {}


## Reads the file at `path`; a finding goes to `issues`, and the texts stay empty.
static func load_file(path: String, issues: Array[DataIssue]) -> CaptionTexts:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return CaptionTexts.new()
	return from_dict(data, path, issues)


## Texts from a parsed object; every template and every level word is required (DT-03, DT-02).
static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> CaptionTexts:
	var texts: CaptionTexts = CaptionTexts.new()
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(KEYS):
		return texts
	texts._risky = reader.text("risky")
	texts._plain = reader.text("plain")
	texts._plain_price = reader.text("plain_price")
	texts._closed = reader.text("closed")
	var levels: DictReader = reader.child("levels", CheckData.LEVELS)
	if levels == null:
		reader.issue("DT-03", "levels", "нет таблицы слов уровней")
		return texts
	for level: String in CheckData.LEVELS:
		texts._levels[level] = levels.text(level)
	return texts


## Word of a check level, one of CheckData.LEVELS (the file names all of them).
func level_word(level: String) -> String:
	return _levels[level]


## «+4», «0», «−1».
static func signed(bonus: int) -> String:
	if bonus > 0:
		return "+%d" % bonus
	if bonus < 0:
		return "%s%d" % [MINUS, -bonus]
	return "0"


## «Сила +4 · Средне 13 · шанс 60 %»; `stat_name` is the name from the hero data.
func risky(stat_name: String, bonus: int, level: String, dc: int, chance: int) -> String:
	return _fill(_risky, {"stat": stat_name, "bonus": signed(bonus), "level": level_word(level), "dc": str(dc), "chance": str(chance)})


## «Без броска», with the price «Без броска · цена» when there is one.
func plain(price: String = "") -> String:
	if price.is_empty():
		return _plain
	return _fill(_plain_price, {"price": price})


## «Закрыто: Сила — причина» (CEO 2026-11-19).
func closed(stat_name: String, reason: String) -> String:
	return _fill(_closed, {"stat": stat_name, "reason": reason})


static func _fill(template: String, values: Dictionary[String, String]) -> String:
	var line: String = template
	for key: String in values:
		line = line.replace("{%s}" % key, values[key])
	return line
