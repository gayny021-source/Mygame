class_name SessionRig
extends RefCounted
## A RunSession over a WriterRig (story SV4): hero_g with chapter m_g (s1 a/b/risky r, s2 node) and
## m_h, a counting d20 source with a fixed face, run ids run1, run2 … The writer is a restartable
## process: restart() makes a new writer and a new session over the same files.

const HERO_ID := "hero_g"
const KEY := "run_hero_g"
const FACE: int = 14

var rig: WriterRig = WriterRig.new()
var hero: HeroData
var source: CountingD20Source = CountingD20Source.new(FACE)
var session: RunSession
var d20: D20Check
var logs: Array[String] = []
var released: int
## [code, screen] per `loaded`, in order.
var loads: Array[Array] = []
var _ids: int


func _init(hero_id: String = HERO_ID, chapters: Array = []) -> void:
	hero = NavigatorHarness.of(chapters if not chapters.is_empty() else [chapter_m_g(), chapter_m_h()]).hero
	hero.id = hero_id
	var stat: StatData = StatData.new()
	stat.id = "strength"
	stat.name = "Сила"
	stat.bonus = 4
	hero.stats.append(stat)
	_build()


## s1: options a, c (safe), r (risky: ow sets f_a, of); s2 is a node scene; ends into m_h.
static func chapter_m_g() -> Dictionary:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s1")["options"] = [GraphFixtures.normal("a", "oa"), GraphFixtures.normal("c", "oc"), GraphFixtures.risky("r", "ow", "of")]
	GraphFixtures.find(data["scenes"], "s2")["node"] = true
	data["outcomes"] = [
		GraphFixtures.outcome("oa", ["t_s1"], ["f_b"]),
		GraphFixtures.outcome("oc", ["t_s1"], ["f_c"]),
		GraphFixtures.outcome("ow", ["t_s1"], ["f_a"]),
		GraphFixtures.outcome("of", ["t_s1"], ["f_fail"]),
		GraphFixtures.outcome("o_s2", ["t_s2"]),
	]
	return data


static func chapter_m_h() -> Dictionary:
	return MeaningFixtures.chain(["s1", "s2"], "m_h")


func restart() -> void:
	rig.restart()
	_build()


func option(id: String) -> OptionData:
	for candidate: OptionData in session.screen().scene.options:
		if candidate.id == id:
			return candidate
	return null


## Frames until every queued write and load has ended.
func settle() -> void:
	rig.pump()


## Writes of the fake disk so far (open, store, close each count one path).
func writes() -> int:
	return rig.io.written.size()


## The body a fresh process loads from the files; empty when nothing loads.
func disk_body() -> Dictionary:
	var pick: SaveCodec.Pick = rig.loaded(KEY, hero.id)
	if pick.code != SaveCodec.Pick.Code.OK:
		return {}
	return rig.read(KEY, pick.slot, hero.id).body


## A start-to-"s1 shown" run, landed on disk; the stake is read unless `stake_read` is false.
func started(stake_read: bool = true) -> StoryScreen:
	var screen: StoryScreen = session.start_new()
	settle()
	if stake_read:
		read_stake()
	return screen


## The UI reports the stake of the scene on show as read.
func read_stake() -> void:
	var page: StoryScreen = session.screen()
	if page != null and page.scene != null:
		session.report_stake_visible(page.scene.id)


func _build() -> void:
	logs = []
	released = 0
	loads = []
	d20 = D20Check.new(CheckFixtures.config(), source)
	session = RunSession.new(hero, rig.writer, d20, _next_id, _log)
	session.show_released.connect(func() -> void: released += 1)
	session.loaded.connect(func(code: int, screen: StoryScreen) -> void: loads.append([code, screen]))


func _next_id() -> String:
	_ids += 1
	return "run%d" % _ids


func _log(line: String) -> void:
	logs.append(line)
