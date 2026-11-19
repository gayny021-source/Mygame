class_name BsIds
extends RefCounted
## Checks of named things around the graph (branching-story.md, Core Rules 2 and 14, Visual Requirements 1–7,
## UR-6; AC-19…AC-23, AC-25; story S5): BS-19 the goal fail flag and the start under it, BS-20 frames and
## characters from the catalogs, BS-21 repeated frames, BS-22 the frame of a final, BS-23 ending frames,
## BS-25 titles of start and node scenes. BS-20 and BS-23 run only on catalogs the caller passes in
## ValidatorOptions (O-18); ValidatorOptions.skipped_checks names them when they are absent.
## Not here: outcome frames (no `illustration` key on outcomes in ADR-0001) and the BS-22 warning on two
## finals with one frame (it needs them).


## Appends the findings of one chapter to `issues`.
static func check(hero: HeroData, graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	_catalogs(graph, options, issues)
	_repeated_frames(graph, issues)
	_final_frame(hero, graph, issues)
	_titles(graph, options, issues)


## Appends the hero-wide findings: BS-19 and BS-23.
static func check_hero(hero: HeroData, usage: FlagUsage, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	for i: int in hero.chapter_ids.size():
		var chapter: ChapterData = _chapter(hero, hero.chapter_ids[i])
		if chapter != null and not chapter.goal_fail_flag.is_empty():
			var next: ChapterData = _chapter(hero, hero.chapter_ids[i + 1]) if i + 1 < hero.chapter_ids.size() else null
			_goal_fail_flag(hero, chapter, next, usage, issues)
	if hero.name.is_empty():
		GraphValidator.report(issues, "BS-01", hero.id + "/name", hero.id, "у героя нет name: интерфейс покажет id", DataIssue.WARNING)
	if not options.ending_frames.is_empty():
		_ending_frames(hero, options, issues)


static func _chapter(hero: HeroData, chapter_id: String) -> ChapterData:
	for chapter: ChapterData in hero.chapters:
		if chapter.id == chapter_id:
			return chapter
	return null


# BS-19: category `story`, scope `run`, no group; no outcome clears it; the next chapter has a start that reads it.
static func _goal_fail_flag(hero: HeroData, chapter: ChapterData, next: ChapterData, usage: FlagUsage, issues: Array[DataIssue]) -> void:
	var flag: String = chapter.goal_fail_flag
	var path: String = "%s/goal_fail_flag" % chapter.id
	var decl: FlagDecl = usage.decls.get(flag)
	if decl != null and decl.category != "story":
		GraphValidator.report(issues, "BS-19", path, flag, "флаг провала цели категории «%s», нужна story" % decl.category)
	if decl != null and decl.scope != FlagDecl.SCOPE_RUN:
		GraphValidator.report(issues, "BS-19", path, flag, "флаг провала цели области «%s», нужна run" % decl.scope)
	if decl != null and not decl.group.is_empty():
		GraphValidator.report(issues, "BS-19", path, flag, "флаг провала цели в группе вытеснения «%s»" % decl.group)
	for owner: ChapterData in hero.chapters:
		for outcome: OutcomeData in owner.outcomes:
			if outcome.clears.has(flag):
				GraphValidator.report(issues, "BS-19", "%s/outcomes/%s" % [owner.id, outcome.id], outcome.id, "исход снимает флаг провала цели «%s»" % flag)
	if next == null:
		return
	for start: StartData in next.starts:
		if usage.flags_of(start.condition).has(flag):
			return
	GraphValidator.report(issues, "BS-19", "%s/starts" % next.id, next.id, "у главы нет записи starts под провал цели прошлой главы (флаг «%s»)" % flag)


# BS-20: scene frames from the frame catalog; `speaks` and `damage` from the character registry.
static func _catalogs(graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var chapter: ChapterData = graph.chapter
	if not options.frames.is_empty():
		for scene: SceneData in chapter.scenes:
			if not scene.illustration.is_empty() and not options.frames.has(scene.illustration):
				GraphValidator.report(issues, "BS-20", "%s/scenes/%s/illustration" % [chapter.id, scene.id], scene.id, "кадра «%s» нет в каталоге" % scene.illustration)
	if options.characters.is_empty():
		return
	for scene: SceneData in chapter.scenes:
		_characters(scene.paragraphs, "%s/scenes/%s" % [chapter.id, scene.id], scene.id, options, issues)
	for outcome: OutcomeData in chapter.outcomes:
		_characters(outcome.paragraphs, "%s/outcomes/%s" % [chapter.id, outcome.id], outcome.id, options, issues)
	for transition: TransitionData in chapter.transitions:
		_characters(transition.coda, "%s/transitions/%s" % [chapter.id, transition.id], transition.id, options, issues)


static func _characters(paragraphs: Array[ParagraphData], path: String, object_id: String, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	for i: int in paragraphs.size():
		for who: String in [paragraphs[i].speaks, paragraphs[i].damage]:
			if not who.is_empty() and not options.characters.has(who):
				GraphValidator.report(issues, "BS-20", "%s/paragraphs/%d" % [path, i], object_id, "персонажа «%s» нет в реестре" % who)


# BS-21: one frame in two scenes in a row, or in two node scenes of the chapter.
static func _repeated_frames(graph: StoryGraph, issues: Array[DataIssue]) -> void:
	var node_frames: Dictionary[String, String] = {}
	for scene: SceneData in graph.chapter.scenes:
		var frame: String = scene.illustration
		if frame.is_empty():
			continue
		var path: String = "%s/scenes/%s" % [graph.chapter.id, scene.id]
		for next: String in graph.successors(scene.id):
			if graph.scene_by_id[next].illustration == frame:
				GraphValidator.report(issues, "BS-21", path, scene.id, "кадр «%s» и у следующей сцены «%s»" % [frame, next], DataIssue.WARNING)
		if not scene.node:
			continue
		if node_frames.has(frame):
			GraphValidator.report(issues, "BS-21", path, scene.id, "кадр «%s» и у узловой сцены «%s»" % [frame, node_frames[frame]], DataIssue.WARNING)
		else:
			node_frames[frame] = scene.id


# BS-22: the final scene of a chapter that is not the hero's last has a frame.
static func _final_frame(hero: HeroData, graph: StoryGraph, issues: Array[DataIssue]) -> void:
	if hero.chapter_ids.is_empty() or hero.chapter_ids[-1] == graph.chapter.id:
		return
	for scene: SceneData in graph.chapter.scenes:
		if scene.final and scene.illustration.is_empty():
			GraphValidator.report(issues, "BS-22", "%s/scenes/%s/illustration" % [graph.chapter.id, scene.id], scene.id, "у финала не последней главы нет кадра")


# BS-23: every `ending:<id>` target has an ending frame; an ending frame is not a scene frame and not another ending's.
static func _ending_frames(hero: HeroData, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var scene_frames: Dictionary[String, String] = {}
	var named: Dictionary[String, bool] = {}
	for chapter: ChapterData in hero.chapters:
		for scene: SceneData in chapter.scenes:
			scene_frames[scene.illustration] = "%s/scenes/%s" % [chapter.id, scene.id]
		for transition: TransitionData in chapter.transitions:
			var ending: String = transition.to_id
			if transition.to_kind != TransitionData.TO_ENDING or named.has(ending):
				continue
			named[ending] = true
			if not options.ending_frames.has(ending):
				GraphValidator.report(issues, "BS-23", "%s/transitions/%s" % [chapter.id, transition.id], ending, "у концовки «%s» нет кадра концовки" % ending)
	var owners: Dictionary[String, String] = {}
	for ending: String in options.ending_frames:
		var frame: String = options.ending_frames[ending]
		if scene_frames.has(frame):
			GraphValidator.report(issues, "BS-23", scene_frames[frame], ending, "кадр концовки «%s» стоит у сцены" % frame)
		if owners.has(frame):
			GraphValidator.report(issues, "BS-23", "%s/endings/%s" % [hero.id, ending], ending, "кадр «%s» и у концовки «%s»" % [frame, owners[frame]])
		owners[frame] = ending


# BS-25: start and node scenes have a title, pairwise different in the chapter. A warning unless the switch says error.
static func _titles(graph: StoryGraph, options: ValidatorOptions, issues: Array[DataIssue]) -> void:
	var severity: String = DataIssue.ERROR if options.bs25_is_error else DataIssue.WARNING
	var entries: PackedStringArray = graph.entry_scenes()
	var seen: Dictionary[String, String] = {}
	for scene: SceneData in graph.chapter.scenes:
		if not scene.node and not entries.has(scene.id):
			continue
		var path: String = "%s/scenes/%s/title" % [graph.chapter.id, scene.id]
		if scene.title.is_empty():
			GraphValidator.report(issues, "BS-25", path, scene.id, "у точки схемы нет заголовка", severity)
		elif seen.has(scene.title):
			GraphValidator.report(issues, "BS-25", path, scene.id, "заголовок «%s» и у точки «%s»" % [scene.title, seen[scene.title]], severity)
		else:
			seen[scene.title] = scene.id
