class_name HeroLoader
extends RefCounted
## Loads hero.json and the hero's chapters into HeroData (ADR-0001 §2, §4, story S1).
## Adds the hero part of BS-01: `ending:<id>` is one of the hero's endings, ids are
## unique across the hero's chapters. flags.json is not read yet (story S3).

const DATA_ROOT := "res://assets/data/heroes"
const HERO_KEYS: PackedStringArray = ["schema_version", "id", "stats", "chapters", "endings", "portrait", "accent", "sum_exception"]
const STAT_KEYS: PackedStringArray = ["id", "bonus"]


## Loads the hero `hero_id` from `<root>/<hero_id>/`; tests pass the fixtures folder as `root`.
## The hero is in `data` only when there are no issues.
static func load_hero(hero_id: String, root: String = DATA_ROOT) -> LoadResult:
	var result: LoadResult = LoadResult.new()
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
	for stat: DictReader in reader.children("stats", STAT_KEYS):
		hero.stat_ids.append(stat.id())
		hero.stat_bonuses.append(stat.integer("bonus"))
	hero.chapter_ids = reader.strings("chapters")
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
		var chapter: ChapterData = _load_chapter("%s/chapters/%s.json" % [dir, chapter_id], chapter_id, hero.endings, seen_ids, result.issues)
		if chapter != null:
			hero.chapters.append(chapter)
	if result.issues.is_empty():
		result.data = hero
	return result


static func _load_chapter(path: String, chapter_id: String, endings: PackedStringArray, seen_ids: PackedStringArray, issues: Array[DataIssue]) -> ChapterData:
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
	var own_ids: PackedStringArray = ChapterLoader.owned_ids(chapter)
	for id: String in own_ids:
		if not id.is_empty() and seen_ids.has(id):
			issues.append(DataIssue.new("BS-01", "%s/%s" % [path, id], id, "id «%s» уже есть в другой главе героя" % id))
	seen_ids.append_array(own_ids)
	return chapter
