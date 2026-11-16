class_name ValidatorOptions
extends RefCounted
## Limits of the graph and meaning checks (branching-story.md, Formulas F1–F8; ADR-0001, Key Interfaces).
## The caller injects them: the CLI `tools/validate_data.gd` reads `assets/data/config/story_limits.json`
## with `load_file`; tests build `new()`, whose defaults are the GDD values.
##
## Usage: [code]var options: ValidatorOptions = ValidatorOptions.load_file(path, issues)[/code]

## Integer limits the config may override; every name is a field below.
const LIMIT_KEYS: PackedStringArray = [
	"options_max", "finales_base", "finales_past", "s_chapter_min", "s_chapter_max", "n_node_min", "n_node_max",
	"branch_max", "path_words_min", "path_words_max", "k_budget", "k_min", "s_path_min", "spine_risky_max",
	"pause_scenes_min", "linear_run_max", "n_early_max", "paragraph_words_max", "screen_paragraphs_max",
	"conditional_paragraphs_max", "prose_flags_max", "outcome_paragraphs_max", "past_options_max", "coda_paragraphs_max",
]
const SWITCH_BS25 := "bs25_is_error"

## F4: most options in a scene (BS-06).
var options_max: int = 4
## F8: finales open without conditions on flags, and finales open only through past flags (BS-10).
var finales_base: int = 3
var finales_past: int = 1
## F1: safe range of the scene count of a chapter; outside it BS-10 warns.
var s_chapter_min: int = 8
var s_chapter_max: int = 16
## F1: safe range of the node scene count.
var n_node_min: int = 4
var n_node_max: int = 7
## F1: most scenes in the side branch.
var branch_max: int = 2
## F3: words on a path (BS-18).
var path_words_min: int = 1500
var path_words_max: int = 2000
## F2 (d20-checks.md, formula 7): ceiling and floor of risky choices on a path, the path length the floor needs (BS-14, BS-15).
var k_budget: int = 5
var k_min: int = 3
var s_path_min: int = 8
## F2: risky choices on a path outside the side branch (BS-14).
var spine_risky_max: int = 4
## F7: scenes without a risky option between two with one; linear scenes in a row (BS-13).
var pause_scenes_min: int = 1
var linear_run_max: int = 2
## F5: early endings in a chapter (BS-16).
var n_early_max: int = 1
## F4: screen limits (BS-06 warnings); a bridge has the word limit of a paragraph.
var paragraph_words_max: int = 60
var screen_paragraphs_max: int = 6
var conditional_paragraphs_max: int = 2
var prose_flags_max: int = 3
var outcome_paragraphs_max: int = 6
var past_options_max: int = 1
var coda_paragraphs_max: int = 3
## BS-25: a warning in MVP, an error from Vertical Slice (O-2).
var bs25_is_error: bool = false
## BS-20: the frame catalog; empty — the check does not run (O-18: no catalog yet).
var frames: PackedStringArray = []
## BS-20: the character registry for `speaks` and `damage`; empty — the check does not run.
var characters: PackedStringArray = []
## BS-23: ending id -> its frame; empty — the check does not run.
var ending_frames: Dictionary[String, String] = {}


## Reads the config file at `path`; findings go to `issues` and leave the defaults in place.
static func load_file(path: String, issues: Array[DataIssue]) -> ValidatorOptions:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return ValidatorOptions.new()
	return from_dict(data, path, issues)


## Options from a parsed config: named limits override the defaults. Unknown key DT-04, a fraction DT-02,
## another `schema_version` DT-07; a value with a finding keeps its default.
static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> ValidatorOptions:
	var options: ValidatorOptions = ValidatorOptions.new()
	var reader: DictReader = DictReader.new(data, source, issues)
	var known: PackedStringArray = LIMIT_KEYS + PackedStringArray(["schema_version", SWITCH_BS25])
	if not reader.schema_ok(known):
		return options
	for key: String in LIMIT_KEYS:
		if not reader.has(key):
			continue
		var before: int = issues.size()
		var value: int = reader.integer(key)
		if issues.size() == before:
			options.set(key, value)
	options.bs25_is_error = reader.flag(SWITCH_BS25)
	return options


## Checks that have no input and do not run, by name: the CLI prints them, so a skip is never silent.
func skipped_checks() -> PackedStringArray:
	var skipped: PackedStringArray = []
	if frames.is_empty():
		skipped.append("BS-20 (кадры сцен): нет каталога кадров, O-18")
	if characters.is_empty():
		skipped.append("BS-20 (говорит, урон): нет реестра персонажей, O-18")
	if ending_frames.is_empty():
		skipped.append("BS-23 (кадры концовок): нет данных концовок")
	return skipped
