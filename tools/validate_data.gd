extends SceneTree
## CLI of the story data check (ADR-0001 §3, §4, §6; branching-story.md, Core Rules 14; story S5).
## For every hero folder under the data root: the text lint of every JSON file before the parser (JsonLint:
## duplicate keys, trailing commas, BOM, not UTF-8), the loaders (DT-NN, BS-01), DataValidator (BS-02…BS-25,
## F4 warnings, UR-1) and ReleasedIds.diff (BS-26). Limits come from the config file, not from code.
## Prints one line per finding, then every check that did not run, by name.
## Exit 0: no errors (warnings are a report). 1: errors. 2: nothing was checked (an unknown argument, or no
## hero under the root).
##
## Usage, from the project root, after `godot --headless --path . --import`:
##   godot --headless --path . -s res://tools/validate_data.gd
##   godot --headless --path . -s res://tools/validate_data.gd -- --freeze
##   godot --headless --path . -s res://tools/validate_data.gd -- --root=res://tests/fixtures/story
## `--freeze` writes `<hero>/released_ids.json` for every hero without errors, through a `.tmp` file and a rename;
## a list that already holds exactly the current ids is left as it is, with its date. A person commits it (ADR-0001 §3).

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
	var unknown: PackedStringArray = unknown_args(args)
	if not unknown.is_empty():
		print("НЕ ПРОВЕРЕНО: неизвестные аргументы %s; допустимы %s и %s<каталог>" % [", ".join(unknown), FREEZE_ARG, ROOT_ARG])
		quit(2)
		return
	var root: String = HeroLoader.DATA_ROOT
	for arg: String in args:
		if arg.begins_with(ROOT_ARG):
			root = arg.trim_prefix(ROOT_ARG)
	var config_issues: Array[DataIssue] = []
	var config: Variant = _read_json(CONFIG, config_issues)
	var options: ValidatorOptions = ValidatorOptions.new()
	if config != null:
		options = ValidatorOptions.from_dict(config, CONFIG, config_issues)
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


## Arguments the CLI does not know, `--root=` without a folder included: a typo must not change what is checked.
static func unknown_args(args: PackedStringArray) -> PackedStringArray:
	var unknown: PackedStringArray = []
	for arg: String in args:
		var is_root: bool = arg.begins_with(ROOT_ARG) and arg.length() > ROOT_ARG.length()
		if arg != FREEZE_ARG and not is_root:
			unknown.append(arg)
	return unknown


func _check_hero(root: String, hero_id: String, options: ValidatorOptions, freeze: bool) -> void:
	var dir: String = "%s/%s" % [root, hero_id]
	var issues: Array[DataIssue] = []
	for path: String in _json_files(dir):
		issues.append_array(JsonLint.check(FileAccess.get_file_as_bytes(path), path))
	var loaded: LoadResult = HeroLoader.load_hero(hero_id, root)
	issues.append_array(loaded.issues)
	var hero: HeroData = loaded.data
	if hero == null:
		_print(issues)
		print("герой %s: граф не проверен — ошибки загрузки" % hero_id)
		return
	issues.append_array(DataValidator.validate(hero, options))
	var released_path: String = "%s/%s" % [dir, RELEASED]
	var snapshot: ReleasedIds.Snapshot = null
	if FileAccess.file_exists(released_path):
		var released: Variant = _read_json(released_path, issues)
		if released != null:
			snapshot = ReleasedIds.read(released, released_path, issues)
		if snapshot != null:
			issues.append_array(ReleasedIds.compare(hero, snapshot, released_path + "/ids"))
	else:
		print("герой %s: BS-26 не проверен — нет %s (до первого выпуска)" % [hero_id, RELEASED])
	var errors_before: int = _errors
	_print(issues)
	if freeze:
		_freeze(hero, released_path, snapshot, _errors > errors_before)


# JSON files of the hero folder and of its chapters folder, except released_ids.json (read once, in _check_hero).
func _json_files(dir: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for folder: String in [dir, dir + "/chapters"]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension() == "json" and file != RELEASED:
				paths.append("%s/%s" % [folder, file])
	return paths


# One read of a JSON file: the text lint, then the parser. null when the file is absent or is not an object.
func _read_json(path: String, issues: Array[DataIssue]) -> Variant:
	if not FileAccess.file_exists(path):
		issues.append(DataIssue.new("DT-01", path, "", "файла нет"))
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	issues.append_array(JsonLint.check(bytes, path))
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		# get_error_line() считает строки с нуля
		issues.append(DataIssue.new("DT-01", "%s:%d" % [path, json.get_error_line() + 1], "", json.get_error_message()))
		return null
	if not json.data is Dictionary:
		issues.append(DataIssue.new("DT-02", path, "", "корень файла — не объект"))
		return null
	return json.data


func _freeze(hero: HeroData, path: String, snapshot: ReleasedIds.Snapshot, has_errors: bool) -> void:
	if has_errors:
		print("герой %s: --freeze отменён — в данных есть ошибки" % hero.id)
		return
	if snapshot != null and ReleasedIds.unchanged(hero, snapshot):
		print("герой %s: %s без изменений, оставлен с датой %s" % [hero.id, path, snapshot.released_at])
		return
	var content: Dictionary = ReleasedIds.freeze(hero, Time.get_date_string_from_system())
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_fail("%s: не открыт для записи (%s), %s не изменён" % [temp, error_string(FileAccess.get_open_error()), path])
		return
	var written: bool = file.store_string(JSON.stringify(content, "\t") + "\n")
	file.close()
	if not written:
		DirAccess.remove_absolute(temp)
		_fail("%s: запись не удалась, %s не изменён" % [temp, path])
		return
	var moved: Error = DirAccess.rename_absolute(temp, path)
	if moved != OK:
		DirAccess.remove_absolute(temp)
		_fail("%s: не переименован в %s (%s), %s не изменён" % [temp, path, error_string(moved), path])
		return
	print("герой %s: записан %s" % [hero.id, path])


func _fail(message: String) -> void:
	_errors += 1
	print("[error] " + message)


func _print(issues: Array[DataIssue]) -> void:
	for issue: DataIssue in issues:
		if issue.severity == DataIssue.ERROR:
			_errors += 1
		else:
			_warnings += 1
		var owner: String = "" if issue.object_id.is_empty() else " (%s)" % issue.object_id
		print("[%s] %s %s%s: %s" % [issue.severity, issue.code, issue.path, owner, issue.message])
