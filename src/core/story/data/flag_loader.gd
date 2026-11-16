class_name FlagLoader
extends RefCounted
## Reads flags.json into FlagDecl (ADR-0001 §1 "Флаг", story S3; run-state.md, Core Rules 1).
## Adds DT-02…DT-07 for form and BS-01 for meaning: ids repeat, `blocks` names a stat the hero
## lacks, is empty, or goes with a hidden flag or without `scope`. Flag and group ids may not be
## words of the condition language (DT-06).

const FLAGS_KEYS: PackedStringArray = ["schema_version", "flags"]
const FLAG_KEYS: PackedStringArray = ["id", "category", "title", "scope", "group", "visible", "exception", "deprecated", "blocks"]


## Reads the file at `path`. The result is trustworthy only when `issues` got nothing new.
static func load_file(path: String, stat_ids: PackedStringArray, issues: Array[DataIssue]) -> Array[FlagDecl]:
	var before: int = issues.size()
	var data: Dictionary = ChapterLoader.read_object(path, issues)
	if issues.size() > before:
		return []
	return parse(data, path, stat_ids, issues)


## Builds the declarations from parsed JSON; `stat_ids` are the hero's stats, for `blocks`.
static func parse(data: Dictionary, source: String, stat_ids: PackedStringArray, issues: Array[DataIssue]) -> Array[FlagDecl]:
	var flags: Array[FlagDecl] = []
	var reader: DictReader = DictReader.new(data, source, issues)
	if not reader.schema_ok(FLAGS_KEYS):
		return flags
	var seen: PackedStringArray = []
	for item: DictReader in reader.children("flags", FLAG_KEYS):
		var decl: FlagDecl = _flag(item, stat_ids)
		if not decl.id.is_empty() and seen.has(decl.id):
			item.issue("BS-01", "id", "флаг «%s» объявлен повторно" % decl.id)
		seen.append(decl.id)
		flags.append(decl)
	return flags


## Names the hero's conditions may use: flags, the categories and groups they carry.
static func vocabulary(flags: Array[FlagDecl]) -> ConditionVocabulary:
	var known: ConditionVocabulary = ConditionVocabulary.new()
	for decl: FlagDecl in flags:
		known.flags.append(decl.id)
		if not decl.category.is_empty() and not known.categories.has(decl.category):
			known.categories.append(decl.category)
		if decl.group.is_empty():
			continue
		known.flag_groups[decl.id] = decl.group
		if not known.groups.has(decl.group):
			known.groups.append(decl.group)
	return known


static func _flag(reader: DictReader, stat_ids: PackedStringArray) -> FlagDecl:
	var decl: FlagDecl = FlagDecl.new()
	decl.id = reader.id()
	_forbid_reserved(reader, "id", decl.id)
	decl.category = reader.one_of("category", FlagDecl.CATEGORIES)
	decl.title = reader.text("title")
	if reader.has("scope"):
		decl.scope = reader.one_of("scope", FlagDecl.SCOPES)
	decl.group = _group(reader)
	decl.visible = reader.flag("visible")
	decl.exception = reader.text("exception", false)
	decl.deprecated = reader.flag("deprecated")
	if reader.has("blocks"):
		decl.blocks = reader.strings("blocks")
		_check_blocks(reader, decl, stat_ids)
	return decl


# Необязательная группа: пустая строка — DT-02, не id — DT-06, слово языка — DT-06.
static func _group(reader: DictReader) -> String:
	var group: String = reader.text("group", false)
	if not reader.has_text("group"):
		return group
	if group.is_empty():
		reader.issue("DT-02", "group", "строка group пуста; если группы нет, уберите ключ")
	elif not DictReader.is_id(group):
		reader.issue("DT-06", "group", "id группы «%s» не подходит под ^[a-z][a-z0-9_]*$" % group)
	else:
		_forbid_reserved(reader, "group", group)
	return group


static func _forbid_reserved(reader: DictReader, key: String, value: String) -> void:
	if ConditionParser.RESERVED.has(value):
		reader.issue("DT-06", key, "«%s» — слово языка условий, id им быть не может" % value)


# Помеха (heroes.md, правило 10): непустой список известных характеристик, видимый флаг, область задана.
static func _check_blocks(reader: DictReader, decl: FlagDecl, stat_ids: PackedStringArray) -> void:
	if reader.has_list("blocks") and decl.blocks.is_empty():
		reader.issue("BS-01", "blocks", "список blocks пуст; если флаг ничего не закрывает, уберите ключ")
	for stat: String in decl.blocks:
		if not stat_ids.has(stat):
			reader.issue("BS-01", "blocks", "характеристики «%s» нет в stats героя" % stat)
	if not decl.visible:
		reader.issue("BS-01", "visible", "у флага с blocks поле visible обязано быть true")
	if not reader.has("scope"):
		reader.issue("BS-01", "scope", "у флага с blocks поле scope обязательно, умолчания run нет")
