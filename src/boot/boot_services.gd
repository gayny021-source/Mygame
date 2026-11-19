class_name BootServices
extends RefCounted
## Launch-time services of the game (stories RT1, S7; DD-022, DD-024): the d20 and caption configs,
## the heroes found on disk and one RunSession per hero over the shared SaveWriter. Nothing here
## throws: every failed load goes to `log_line` as `CODE path: message`, and `status` says why
## the game cannot start. Without heroes (`sessions` empty) there is nothing to play yet.
##
## Usage: [code]var services: BootServices = BootServices.build(save.writer, log_line)[/code]

var d20_config: D20Config
var captions: CaptionTexts
var d20: D20Check
## Hero id -> RunSession.
var sessions: Dictionary[String, RunSession] = {}
## Human-readable state for the boot screen; empty when the heroes loaded.
var status: String = ""


## Loads configs and heroes from `heroes_root`. An invalid d20 config is logged (DT-01/DT-02) and
## kept: the core hides risky options itself (DD-022).
static func build(writer: SaveWriter, log_line: Callable, heroes_root: String = HeroLoader.DATA_ROOT, d20_path: String = D20Config.PATH, captions_path: String = CaptionTexts.PATH) -> BootServices:
	var services: BootServices = BootServices.new()
	var issues: Array[DataIssue] = []
	services.d20_config = D20Config.load_file(d20_path, issues)
	services.captions = CaptionTexts.load_file(captions_path, issues)
	_log_issues(issues, log_line)
	if not services.d20_config.valid:
		log_line.call("%s d20-конфиг не годен: рискованные варианты скрыты" % services.d20_config.issue_code)
	services.d20 = D20Check.new(services.d20_config, EngineD20Source.new())
	services._load_heroes(writer, log_line, heroes_root)
	return services


func _load_heroes(writer: SaveWriter, log_line: Callable, root: String) -> void:
	var ids: PackedStringArray = DirAccess.get_directories_at(root) if DirAccess.dir_exists_absolute(root) else PackedStringArray()
	ids.sort()
	for id: String in ids:
		var result: LoadResult = HeroLoader.load_hero(id, root)
		_log_issues(result.issues, log_line)
		var hero: HeroData = result.data as HeroData
		if hero != null:
			sessions[id] = RunSession.new(hero, writer, d20, _new_run_id, log_line, captions)
	if sessions.is_empty():
		status = tr("Нет данных героев")
		log_line.call("RT-01 героев в %s нет: играть нечего" % root)


static func _new_run_id() -> String:
	return "%08x%08x" % [randi(), randi()]


static func _log_issues(issues: Array[DataIssue], log_line: Callable) -> void:
	for issue: DataIssue in issues:
		log_line.call("%s %s: %s" % [issue.code, issue.path, issue.message])
