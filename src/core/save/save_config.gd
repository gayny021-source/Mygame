class_name SaveConfig
extends RefCounted
## Save config from assets/data/config/save.json (ADR-0002 §4; save-system.md F3; story SV4): `wait_ms` is
## T_ожид. A config with findings is not valid and keeps DEFAULT_WAIT_MS, the GDD candidate.
##
## Usage: [code]var config: SaveConfig = SaveConfig.load_file(SaveConfig.PATH, issues)[/code]

const PATH := "res://assets/data/config/save.json"
const KEYS: PackedStringArray = ["wait_ms"]
## ADR-0002 §4: allowed 500…5000 ms.
const WAIT_MIN_MS: int = 500
const WAIT_MAX_MS: int = 5000
const DEFAULT_WAIT_MS: int = 2000

var valid: bool = false
var wait_ms: int = DEFAULT_WAIT_MS


## Reads the file at `path`; findings go to `issues`.
static func load_file(path: String, issues: Array[DataIssue]) -> SaveConfig:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return SaveConfig.new()
	return from_dict(data, path, issues)


## Config from a parsed object: `wait_ms` required (DT-03), a fraction or a value outside the range DT-02,
## an unknown key DT-04. Any finding leaves the default and `valid` false.
static func from_dict(data: Dictionary, source: String, issues: Array[DataIssue]) -> SaveConfig:
	var config: SaveConfig = SaveConfig.new()
	var before: int = issues.size()
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(KEYS + PackedStringArray(["schema_version"])):
		return config
	var wait: int = reader.integer("wait_ms")
	if issues.size() == before and (wait < WAIT_MIN_MS or wait > WAIT_MAX_MS):
		reader.issue("DT-02", "wait_ms", "%d вне %d…%d" % [wait, WAIT_MIN_MS, WAIT_MAX_MS])
	if issues.size() > before:
		return config
	config.wait_ms = wait
	config.valid = true
	return config
