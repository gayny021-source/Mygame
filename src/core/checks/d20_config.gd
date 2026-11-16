class_name D20Config
extends RefCounted
## Runtime config of the d20 checks, `assets/data/config/d20.json` (d20-checks.md, formulas 2-3 and Edge
## Cases «конфиг уровней»; ADR-0001 §6; story S7). The values live only in the file: a config that did not
## read whole, or breaks formula 3, is not `valid`, and then every risky option is hidden — there is no
## fallback to defaults. Negative values are legal.
##
## Usage: [code]var config: D20Config = D20Config.load_file(D20Config.PATH, issues)[/code]

const PATH := "res://assets/data/config/d20.json"
const KEYS: PackedStringArray = [
	"dc_easy", "dc_medium", "dc_hard", "chance_window_low", "chance_window_high", "profile_gap_min", "profile_floor_max",
]
## B_min, B_max of formula 3: frozen product constants (registry `stat_bonus_min/max`), changed only by a
## balance patch of the heroes, never by the level config (design/gdd/d20-checks.md:352, 364).
const STAT_BONUS_MIN := -1
const STAT_BONUS_MAX := 5

## True only when the file was read without findings and formula 3 holds.
var valid: bool = false
## Code of the first finding that left the config invalid; DT-01 until a file is read.
var issue_code: String = "DT-01"
var dc_easy: int
var dc_medium: int
var dc_hard: int
## P_lo, P_hi: the chance window of one roll, in percent.
var chance_window_low: int
var chance_window_high: int
## G_min, F_max (heroes.md, formula 3).
var profile_gap_min: int
var profile_floor_max: int


## Reads the config file at `path`; findings go to `issues`. A file that does not read gives an invalid config.
static func load_file(path: String, issues: Array[DataIssue]) -> D20Config:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return D20Config.new()
	return from_dict(data, path, issues)


## Config from a parsed object: every key is required (DT-03), unknown key DT-04, a fraction DT-02,
## a broken formula 3 DT-02 per violated condition. Any finding leaves it invalid.
static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> D20Config:
	var config: D20Config = D20Config.new()
	var before: int = issues.size()
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(KEYS + PackedStringArray(["schema_version"])):
		config.issue_code = issues[before].code
		return config
	config.dc_easy = reader.integer("dc_easy")
	config.dc_medium = reader.integer("dc_medium")
	config.dc_hard = reader.integer("dc_hard")
	config.chance_window_low = reader.integer("chance_window_low")
	config.chance_window_high = reader.integer("chance_window_high")
	config.profile_gap_min = reader.integer("profile_gap_min")
	config.profile_floor_max = reader.integer("profile_floor_max")
	if issues.size() == before:
		config.valid = config._levels_valid(reader)
	config.issue_code = "" if config.valid else issues[before].code
	return config


## DC of `level`, one of CheckData.LEVELS. Any other level is DT-02 and −1: the caller refuses the roll.
func dc(level: String, issues: Array[DataIssue]) -> int:
	match level:
		"easy":
			return dc_easy
		"medium":
			return dc_medium
		"hard":
			return dc_hard
	issues.append(DataIssue.new("DT-02", "d20/level", "", "уровень «%s» не из %s; проверка не бросается" % [level, ", ".join(CheckData.LEVELS)]))
	return -1


# Formula 3 condition by condition, each broken one a DT-02. P/5 is multiplied out: the same
# inequalities for a window in steps of 5, and no integer division.
func _levels_valid(reader: DictReader) -> bool:
	var valid_levels: bool = true
	var suffix: String = "; рискованные варианты скрыты"
	if chance_window_low < 0 or chance_window_low > chance_window_high or chance_window_high > 100:
		reader.issue("DT-02", "chance_window_low", "окно шанса %d…%d вне 0 ≤ P_lo ≤ P_hi ≤ 100%s" % [chance_window_low, chance_window_high, suffix])
		return false
	if dc_easy >= dc_medium or dc_medium >= dc_hard:
		reader.issue("DT-02", "dc_medium", "формула 3, условие 1: нужно dc_easy < dc_medium < dc_hard, а здесь %d, %d, %d%s" % [dc_easy, dc_medium, dc_hard, suffix])
		valid_levels = false
	if (dc_hard - dc_easy + profile_gap_min) * 5 > chance_window_high - chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 2: разброс dc_hard − dc_easy = %d больше (P_hi − P_lo)/5 − G_min%s" % [dc_hard - dc_easy, suffix])
		valid_levels = false
	var floor_chance: int = _raw_chance(dc_hard, profile_floor_max)
	if floor_chance < chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 3: дно профиля %d на Трудно %d даёт шанс %d %% < %d %%%s" % [profile_floor_max, dc_hard, floor_chance, chance_window_low, suffix])
		valid_levels = false
	var top_chance: int = _raw_chance(dc_easy, STAT_BONUS_MAX)
	if top_chance > chance_window_high:
		reader.issue("DT-02", "dc_easy", "формула 3, условие 4: бонус %d на Легко %d даёт шанс %d %% > %d %%%s" % [STAT_BONUS_MAX, dc_easy, top_chance, chance_window_high, suffix])
		valid_levels = false
	var bottom_chance: int = _raw_chance(dc_hard, STAT_BONUS_MIN)
	if bottom_chance < chance_window_low:
		reader.issue("DT-02", "dc_hard", "формула 3, условие 5: бонус %d на Трудно %d даёт шанс %d %% < %d %%%s" % [STAT_BONUS_MIN, dc_hard, bottom_chance, chance_window_low, suffix])
		valid_levels = false
	return valid_levels


# (21 − (DC − bonus)) × 5 without the clamp of formula 2: the inequalities of formula 3 are unclamped.
static func _raw_chance(level_dc: int, bonus: int) -> int:
	return (21 - level_dc + bonus) * 5
