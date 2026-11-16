class_name CheckFixtures
extends RefCounted
## Builders of d20 test data (d20-checks.md, the reference check `bridge_strength`; story S7).

const SUCCESS := "bridge_win"
const FAILURE := "bridge_fall"
const CRIT_SUCCESS := "Мост выдержал."
const CRIT_FAILURE := "Доска треснула."


## The reference check on `level` of the stat `stat_id`, with both crit lines.
static func check(level: String = "medium", stat_id: String = "strength") -> CheckData:
	var data: CheckData = CheckData.new()
	data.id = "bridge_strength"
	data.stat = stat_id
	data.level = level
	data.success = SUCCESS
	data.failure = FAILURE
	data.crit_success_line = CRIT_SUCCESS
	data.crit_failure_line = CRIT_FAILURE
	return data


## The project config assets/data/config/d20.json (TD S7 round 1, G1: the values live only there).
static func config() -> D20Config:
	var issues: Array[DataIssue] = []
	return D20Config.load_file(D20Config.PATH, issues)


## A hero with the one stat `stat_id` of `bonus`.
static func hero(stat_id: String, bonus: int) -> HeroData:
	var stat: StatData = StatData.new()
	stat.id = stat_id
	stat.bonus = bonus
	var data: HeroData = HeroData.new()
	data.stats.append(stat)
	return data
