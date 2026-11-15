class_name HeroLoader
extends RefCounted
## Loads hero.json and the hero's chapters into HeroData (ADR-0001 §2, §4, story S1).
## Adds the hero part of BS-01: the hero's id is its folder name, stats and chapters
## are listed once, every listed chapter has a file, `ending:<id>` is one of the
## hero's endings, a check rolls on one of the hero's stats, ids are unique across
## the hero's chapters. flags.json is not read yet (story S3).

const DATA_ROOT := "res://assets/data/heroes"
const HERO_KEYS: PackedStringArray = ["schema_version", "id", "stats", "chapters", "endings", "portrait", "accent", "sum_exception"]
const STAT_KEYS: PackedStringArray = ["id", "bonus"]


## Loads the hero `hero_id` from `<root>/<hero_id>/`; tests pass the fixtures folder as `root`.
## The hero is in `data` only when there are no issues.
static func load_hero(hero_id: String, root: String = DATA_ROOT) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	# id героя становится именем каталога: «../» не должен увести чтение из каталога данных
	if not DictReader.is_id(hero_id):
		result.issues.append(DataIssue.new("DT-06", root, "", "id героя «%s» не подходит под ^[a-z][a-z0-9_]*$" % hero_id))
		return result
	var dir: String = "%s/%s" % [root, hero_id]
	var hero_path: String = dir + "/hero.json"
	var data: Dictionary = ChapterLoader.read_object(hero_path, result.issues)
	if not result.issues.is_empty():
		return result
	var reader: DictReader = DictReader.new(data, hero_path, result.issues)
	if not reader.schema_ok(HERO_KEYS):
		return result
	var hero: HeroData = HeroData.new()
	hero.id = reader.id()
	if not hero.id.is_empty() and hero.id != hero_id:
		reader.issue("BS-01", "id", "каталог героя «%s» содержит id «%s»" % [hero_id, hero.id])
	var stat_ids: PackedStringArray = []
	for stat_reader: DictReader in reader.children("stats", STAT_KEYS):
		var stat: StatData = StatData.new()
		stat.id = stat_reader.id()
		stat.bonus = stat_reader.integer("bonus")
		if not stat.id.is_empty() and stat_ids.has(stat.id):
			stat_reader.issue("BS-01", "id", "характеристика «%s» повторяется" % stat.id)
		stat_ids.append(stat.id)
		hero.stats.append(stat)
	hero.chapter_ids = reader.strings("chapters")
	if reader.has("chapters") and hero.chapter_ids.is_empty():
		reader.issue("BS-01", "chapters", "у героя нет ни одной главы")
	hero.endings = reader.strings("endings")
	hero.portrait = reader.text("portrait")
	hero.accent = reader.text("accent")
	hero.sum_exception = reader.text("sum_exception", false)
	var seen_ids: PackedStringArray = []
	for i: int in hero.chapter_ids.size():
		var chapter_id: String = hero.chapter_ids[i]
		# id главы становится именем файла: «../» в данных не должен увести чтение из каталога героя
		if not DictReader.is_id(chapter_id):
			reader.issue("DT-06", "chapters/%d" % i, "id «%s» не подходит под ^[a-z][a-z0-9_]*$" % chapter_id)
			continue
		# повтор не загружается второй раз: иначе каждый id главы стал бы ложным дублем
		if hero.chapter_ids.find(chapter_id) < i:
			reader.issue("BS-01", "chapters/%d" % i, "глава «%s» перечислена повторно" % chapter_id)
			continue
		var chapter_path: String = "%s/chapters/%s.json" % [dir, chapter_id]
		if not FileAccess.file_exists(chapter_path):
			reader.issue("BS-01", "chapters/%d" % i, "у главы «%s» нет файла %s" % [chapter_id, chapter_path])
			continue
		var chapter: ChapterData = _load_chapter(chapter_path, chapter_id, hero.endings, stat_ids, seen_ids, result.issues)
		if chapter != null:
			hero.chapters.append(chapter)
	if result.issues.is_empty():
		result.data = hero
	return result


static func _load_chapter(path: String, chapter_id: String, endings: PackedStringArray, stat_ids: PackedStringArray, seen_ids: PackedStringArray, issues: Array[DataIssue]) -> ChapterData:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return null
	var chapter: ChapterData = ChapterLoader.parse(data, path, issues)
	if chapter == null:
		return null
	if chapter.id != chapter_id:
		issues.append(DataIssue.new("BS-01", path + "/id", chapter.id, "файл главы «%s» содержит id «%s»" % [chapter_id, chapter.id]))
	for i: int in chapter.transitions.size():
		var transition: TransitionData = chapter.transitions[i]
		if transition.to_kind == TransitionData.TO_ENDING and not endings.has(transition.to_id):
			var transition_path: String = "%s/transitions/%s/to" % [path, DictReader.label(transition.id, i)]
			issues.append(DataIssue.new("BS-01", transition_path, transition.id, "концовки «%s» нет в endings героя" % transition.to_id))
	for i: int in chapter.scenes.size():
		var scene: SceneData = chapter.scenes[i]
		for j: int in scene.options.size():
			var check: CheckData = scene.options[j].check
			# пустой stat: о нём уже есть DT-находка
			if check == null or check.stat.is_empty() or stat_ids.has(check.stat):
				continue
			var stat_path: String = "%s/scenes/%s/options/%s/check/stat" % [path, DictReader.label(scene.id, i), DictReader.label(scene.options[j].id, j)]
			issues.append(DataIssue.new("BS-01", stat_path, check.id, "характеристики «%s» нет в stats героя" % check.stat))
	var own_ids: PackedStringArray = ChapterLoader.owned_ids(chapter)
	for id: String in own_ids:
		if not id.is_empty() and seen_ids.has(id):
			issues.append(DataIssue.new("BS-01", "%s/%s" % [path, id], id, "id «%s» уже есть в другой главе героя" % id))
	seen_ids.append_array(own_ids)
	return chapter
