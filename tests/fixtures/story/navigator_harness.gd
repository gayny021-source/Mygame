class_name NavigatorHarness
extends RefCounted
## Test harness of StoryNavigator (story S6): one hero, a spy RunState, the navigator log and one
## journal of `chapter_finished` and `end_chapter` calls in their order. `choose` plays the part of
## the Choice system: it applies the outcome to the state, then tells the navigator.


## RunState that counts apply_outcome calls and journals end_chapter.
class SpyRunState extends RunState:
	var applied: int = 0
	var _events: Array[String]


	func _init(declarations: Array[FlagDecl], events: Array[String], log_error: Callable) -> void:
		super(declarations, log_error)
		_events = events


	func apply_outcome(scene_id: String, outcome_id: String, sets: PackedStringArray, clears: PackedStringArray) -> void:
		applied += 1
		super(scene_id, outcome_id, sets, clears)


	func end_chapter() -> void:
		_events.append("end_chapter")
		super()


var hero: HeroData
var nav: StoryNavigator
var state: SpyRunState
var errors: Array[String] = []
var events: Array[String] = []
var state_errors: Array[String] = []
## Outcomes applied by `choose` and `set_flags`, as [scene, outcome, sets, clears], for a replay.
var applied: Array[Array] = []


func _init(hero_data: HeroData) -> void:
	hero = hero_data
	state = SpyRunState.new(hero.flags, events, _appender(state_errors, ""))
	nav = StoryNavigator.new(hero, _appender(events, "finished:"), _appender(errors, ""))


## Harness over chapters `chapters` with StoryFixtures.nav_flags().
static func of(chapters: Array, endings: PackedStringArray = []) -> NavigatorHarness:
	var hero_data: HeroData = MeaningFixtures.hero_of(chapters, StoryFixtures.nav_flags())
	hero_data.endings = endings
	return NavigatorHarness.new(hero_data)


## Applies the outcome `outcome_id` as the Choice system does, then calls outcome_applied.
func choose(outcome_id: String) -> StoryScreen:
	var outcome: OutcomeData = find_outcome(outcome_id)
	_apply(nav.position().scene, outcome_id, outcome.sets, outcome.clears)
	return nav.outcome_applied(outcome_id)


## Sets flags outside any outcome (test setup).
func set_flags(ids: PackedStringArray) -> void:
	_apply("", "test", ids, PackedStringArray())


## New harness on the same hero whose state replays every outcome applied here: a fresh load.
func reloaded() -> NavigatorHarness:
	var fresh: NavigatorHarness = NavigatorHarness.new(hero)
	for entry: Array in applied:
		fresh._apply(entry[0], entry[1], entry[2], entry[3])
	return fresh


func find_outcome(outcome_id: String) -> OutcomeData:
	for chapter: ChapterData in hero.chapters:
		for outcome: OutcomeData in chapter.outcomes:
			if outcome.id == outcome_id:
				return outcome
	return null


## Paragraph texts of a screen in order.
static func texts(screen: StoryScreen) -> Array[String]:
	var result: Array[String] = []
	for paragraph: ParagraphData in screen.paragraphs:
		result.append(paragraph.text)
	return result


## Everything a screen shows, as one line, to compare two screens.
static func describe(screen: StoryScreen) -> String:
	var scene_id: String = screen.scene.id if screen.scene != null else ""
	var outcome_id: String = screen.outcome.id if screen.outcome != null else ""
	var transition_id: String = screen.transition.id if screen.transition != null else ""
	var parts: Array[String] = [str(screen.kind), scene_id, screen.chapter_title, screen.bridge, "|".join(PackedStringArray(texts(screen))), outcome_id, transition_id]
	return " / ".join(PackedStringArray(parts))


func _apply(scene_id: String, outcome_id: String, sets: PackedStringArray, clears: PackedStringArray) -> void:
	applied.append([scene_id, outcome_id, sets, clears])
	state.apply_outcome(scene_id, outcome_id, sets, clears)


static func _appender(into: Array[String], prefix: String) -> Callable:
	return func(text: String) -> void: into.append(prefix + text)
