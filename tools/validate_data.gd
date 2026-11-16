extends SceneTree
## CLI of the story data check (ADR-0001 §3, §4, §6; branching-story.md, Core Rules 14; story S5).
## For every hero folder under the data root: the text lint of every JSON file before the parser (JsonLint:
## duplicate keys, trailing commas, BOM, not UTF-8), the loaders (DT-NN, BS-01), DataValidator (BS-02…BS-25,
## F4 warnings, UR-1) and ReleasedIds.diff (BS-26). Limits come from the config file, not from code.
## Prints one line per finding, then every check that did not run, by name.
## Exit 0: no errors (warnings are a report). 1: errors. 2: nothing was checked (no hero under the root).
##
## Usage, from the project root, after `godot --headless --path . --import`:
##   godot --headless --path . -s res://tools/validate_data.gd
##   godot --headless --path . -s res://tools/validate_data.gd -- --freeze
##   godot --headless --path . -s res://tools/validate_data.gd -- --root=res://tests/fixtures/story
## `--freeze` writes `<hero>/released_ids.json` for every hero without errors; a person commits it (ADR-0001 §3).

const CONFIG := "res://assets/data/config/story_limits.json"
const RELEASED := "released_ids.json"
const ROOT_ARG := "--root="
const FREEZE_ARG := "--freeze"
## Rules of branching-story.md whose input is not in the data yet: listed on every run, so a skip is never silent.
const NOT_ASSESSED: PackedStringArray = [
	"BS-12 (price читает только эпилог): строк эпилога нет в данных",
	"BS-12 (мёртвое место, O-5; мёртвая ветка F6): нужна модель вероятностей",
	"BS-16 (частота F5, AC-32) и запрет ранних концовок в MVP (AC-63): нужен конфиг d20",
	"BS-20, BS-22 (кадры исходов, два финала с одним кадром): у исхода нет ключа illustration в ADR-0001",
]

var _errors: int = 0
var _warnings: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var root: String = HeroLoader.DATA_ROOT
	for arg: String in args:
		if arg.begins_with(ROOT_ARG):
			root = arg.trim_prefix(ROOT_ARG)
	var config_issues: Array[DataIssue] = _lint(CONFIG)
	var options: ValidatorOptions = ValidatorOptions.load_file(CONFIG, config_issues)
	_print(config_issues)
	if _errors > 0:
		print("НЕ ПРОВЕРЕНО: в конфиге пределов %s ошибки, данные не проверялись" % CONFIG)
		quit(1)
		return
	var heroes: PackedStringArray = DirAccess.get_directories_at(root) if DirAccess.dir_exists_absolute(root) else PackedStringArray()
	if heroes.is_empty():
		print("НЕ ПРОВЕРЕНО: в %s нет ни одного героя" % root)
		quit(2)
		return
	for hero_id: String in heroes:
		_check_hero(root, hero_id, options, args.has(FREEZE_ARG))
	for name: String in options.skipped_checks() + NOT_ASSESSED:
		print("не проверено: " + name)
	print("итог: героев %d, ошибок %d, предупреждений %d" % [heroes.size(), _errors, _warnings])
	quit(1 if _errors > 0 else 0)


func _check_hero(root: String, hero_id: String, options: ValidatorOptions, freeze: bool) -> void:
	var dir: String = "%s/%s" % [root, hero_id]
	var issues: Array[DataIssue] = []
	for path: String in _json_files(dir):
		issues.append_array(_lint(path))
	var loaded: LoadResult = HeroLoader.load_hero(hero_id, root)
	issues.append_array(loaded.issues)
	var hero: HeroData = loaded.data
	if hero == null:
		_print(issues)
		print("герой %s: граф не проверен — ошибки загрузки" % hero_id)
		return
	issues.append_array(DataValidator.validate(hero, options))
	var released_path: String = "%s/%s" % [dir, RELEASED]
	if FileAccess.file_exists(released_path):
		var before: int = issues.size()
		var released: Dictionary = ChapterLoader.read_object(released_path, issues)
		if issues.size() == before:
			issues.append_array(ReleasedIds.diff(hero, released))
	else:
		print("герой %s: BS-26 не проверен — нет %s (до первого выпуска)" % [hero_id, RELEASED])
	var errors_before: int = _errors
	_print(issues)
	if freeze:
		_freeze(hero, released_path, _errors > errors_before)


# JSON files of the hero folder and of its chapters folder.
func _json_files(dir: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for folder: String in [dir, dir + "/chapters"]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension() == "json":
				paths.append("%s/%s" % [folder, file])
	return paths


func _lint(path: String) -> Array[DataIssue]:
	if not FileAccess.file_exists(path):
		return []
	return JsonLint.check(FileAccess.get_file_as_bytes(path), path)


func _freeze(hero: HeroData, path: String, has_errors: bool) -> void:
	if has_errors:
		print("герой %s: --freeze отменён — в данных есть ошибки" % hero.id)
		return
	var content: Dictionary = ReleasedIds.freeze(hero, Time.get_date_string_from_system())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(content, "\t") + "\n"):
		_errors += 1
		print("[error] %s: не записан (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	print("герой %s: записан %s" % [hero.id, path])


func _print(issues: Array[DataIssue]) -> void:
	for issue: DataIssue in issues:
		if issue.severity == DataIssue.ERROR:
			_errors += 1
		else:
			_warnings += 1
		var owner: String = "" if issue.object_id.is_empty() else " (%s)" % issue.object_id
		print("[%s] %s %s%s: %s" % [issue.severity, issue.code, issue.path, owner, issue.message])
