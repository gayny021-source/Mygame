class_name D20Config
extends RefCounted
## Runtime config of the d20 checks, `assets/data/config/d20.json` (d20-checks.md, formulas 2-3;
## ADR-0001 §6; story S7): the three levels and the frozen product constants formula 3 holds them
## to. The defaults are the GDD values. A level set breaking formula 3 is DT-02, and the three
## `dc_*` return to their defaults. Negative values are legal (`stat_bonus_min` is −1).
##
## Usage: [code]var config: D20Config = D20Config.load_file(D20Config.PATH, issues)[/code]

const PATH := "res://assets/data/config/d20.json"
const KEYS: PackedStringArray = [
	"dc_easy", "dc_medium", "dc_hard", "chance_window_low", "chance_window_high", "profile_gap_min",
	"profile_floor_max", "stat_bonus_min", "stat_bonus_max",
]
const LEVEL_KEYS: PackedStringArray = ["dc_easy", "dc_medium", "dc_hard"]

var dc_easy: int = 11
var dc_medium: int = 13
var dc_hard: int = 15
## P_lo, P_hi: the chance window of one roll, in percent.
var chance_window_low: int = 25
var chance_window_high: int = 75
## G_min, F_max (heroes.md, formula 3).
var profile_gap_min: int = 4
var profile_floor_max: int = 0
## B_min, B_max: frozen, changed only by a balance patch of the heroes.
var stat_bonus_min: int = -1
var stat_bonus_max: int = 5


## Reads the config file at `path`; findings go to `issues`, a file that does not read leaves the defaults.
static func load_file(path: String, issues: Array[DataIssue]) -> D20Config:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return D20Config.new()
	return from_dict(data, path, issues)


## Config from a parsed object: unknown key DT-04, a fraction DT-02 (that value keeps its default),
## a broken formula 3 DT-02 per violated condition.
static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> D20Config:
	var config: D20Config = D20Config.new()
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(KEYS + PackedStringArray(["schema_version"])):
		return config
	for key: String in KEYS:
		if not reader.has(key):
			continue
		var before: int = issues.size()
		var value: int = reader.integer(key)
		if issues.size() > before:
			continue
		config.set(key, value)
	if not config._levels_valid(reader):
		var defaults: D20Config = D20Config.new()
		for key: String in LEVEL_KEYS:
			config.set(key, defaults.get(key))
	return config


## DC of `level`, one of CheckData.LEVELS (the loader guarantees it, DT-05).
func dc(level: String) -> int:
	var levels: Array[int] = [dc_easy, dc_medium, dc_hard]
	return levels[CheckData.LEVELS.find(level)]


# Formula 3 condition by condition, each broken one a DT-02. P/5 is multiplied out: the same
# inequalities for a window in steps of 5, and no integer division.
func _levels_valid(reader: DictReader) -> bool:
	var valid: bool = true
	var defaults: D20Config = D20Config.new()
	var suffix: String = "; dc_* возвращены к %d/%d/%d" % [defaults.dc_easy, defaults.dc_medium, defaults.dc_hard]
	if dc_easy >= dc_medium or dc_medium >= dc_hard:
		reader.issue("DT-02", "dc_medium", "формула 3, условие 1: нужно dc_easy < dc_medium < dc_hard, а здесь %d, %d, %d%s" % [dc_easy, dc_medium, dc_hard, suffix])
		valid = false
	if (dc_hard - dc_easy + profile_gap_min) * 5 > chance_window_high - chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 2: разброс dc_hard − dc_easy = %d больше (P_hi − P_lo)/5 − G_min%s" % [dc_hard - dc_easy, suffix])
		valid = false
	var floor_chance: int = _raw_chance(dc_hard, profile_floor_max)
	if floor_chance < chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 3: дно профиля %d на Трудно %d даёт шанс %d %% < %d %%%s" % [profile_floor_max, dc_hard, floor_chance, chance_window_low, suffix])
		valid = false
	var top_chance: int = _raw_chance(dc_easy, stat_bonus_max)
	if top_chance > chance_window_high:
		reader.issue("DT-02", "dc_easy", "формула 3, условие 4: бонус %d на Легко %d даёт шанс %d %% > %d %%%s" % [stat_bonus_max, dc_easy, top_chance, chance_window_high, suffix])
		valid = false
	var bottom_chance: int = _raw_chance(dc_hard, stat_bonus_min)
	if bottom_chance < chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 5: бонус %d на Трудно %d даёт шанс %d %% < %d %%%s" % [stat_bonus_min, dc_hard, bottom_chance, chance_window_low, suffix])
		valid = false
	return valid


# (21 − (DC − bonus)) × 5 without the clamp of formula 2: the inequalities of formula 3 are unclamped.
static func _raw_chance(level_dc: int, bonus: int) -> int:
	return (21 - level_dc + bonus) * 5
