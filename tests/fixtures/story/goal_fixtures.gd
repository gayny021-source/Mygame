class_name GoalFixtures
extends RefCounted
## Chapters with a goal for the tests of «Цель главы» (chapter-goal.md): m_g has milestones m1…m3 on
## s1, s2, s3 (s3 is the final), goal_fail_flag f_fail; m_h enters through two starts.

const GOAL := "Дойти до города"
const FAIL_GOAL := "Выжить любой ценой"


## s1 (m1): a plain, r risky (of sets f_fail); s2 (m2, node): g plain, x plain sets f_fail; s3 (m3, final): e plain, y sets f_fail.
static func chapter_g() -> Dictionary:
	var scenes: Array = [
		GraphFixtures.scene("s1", [GraphFixtures.normal("a", "oa"), GraphFixtures.risky("r", "ow", "of")]),
		GraphFixtures.scene("s2", [GraphFixtures.normal("g", "og"), GraphFixtures.normal("x", "ox")], true),
		GraphFixtures.scene("s3", [GraphFixtures.normal("e", "oe"), GraphFixtures.normal("y", "oy")]),
	]
	scenes[0]["milestone"] = "m1"
	scenes[1]["milestone"] = "m2"
	scenes[2]["milestone"] = "m3"
	scenes[2]["final"] = true
	var outcomes: Array = [
		GraphFixtures.outcome("oa", ["t_s1"]),
		GraphFixtures.outcome("ow", ["t_s1"]),
		GraphFixtures.outcome("of", ["t_s1"], ["f_fail"]),
		GraphFixtures.outcome("og", ["t_s2"]),
		GraphFixtures.outcome("ox", ["t_s2"], ["f_fail"]),
		GraphFixtures.outcome("oe", ["t_end"]),
		GraphFixtures.outcome("oy", ["t_end"], ["f_fail"]),
	]
	var transitions: Array = [GraphFixtures.to_scene("t_s1", "s2"), GraphFixtures.to_scene("t_s2", "s3"), GraphFixtures.to_end("t_end")]
	var data: Dictionary = GraphFixtures.chapter(scenes, outcomes, transitions)
	data["goal"] = GOAL
	data["goal_fail_flag"] = "f_fail"
	data["milestones"] = [{"id": "m1", "step": "Идти к мосту"}, {"id": "m2", "step": "Перейти мост"}, {"id": "m3", "step": "Войти в город"}]
	return data


## h1 (n1) and h2 (n2, final); the start st_fail reads f_fail and has its own goal.
static func chapter_h() -> Dictionary:
	var scenes: Array = [
		GraphFixtures.scene("h1", [GraphFixtures.normal("go", "oh1")]),
		GraphFixtures.scene("h2", [GraphFixtures.normal("end", "oh2")]),
	]
	scenes[0]["milestone"] = "n1"
	scenes[1]["milestone"] = "n2"
	scenes[1]["final"] = true
	var outcomes: Array = [GraphFixtures.outcome("oh1", ["t_h1"]), GraphFixtures.outcome("oh2", ["t_hend"])]
	var transitions: Array = [GraphFixtures.to_scene("t_h1", "h2"), GraphFixtures.to_end("t_hend")]
	var starts: Array = [{"id": "st_fail", "if": "f_fail", "scene": "h1", "goal": FAIL_GOAL}, {"id": "st_main", "scene": "h1"}]
	var data: Dictionary = GraphFixtures.chapter(scenes, outcomes, transitions, starts)
	data["id"] = "m_h"
	data["goal"] = "Идти дальше"
	data["milestones"] = [{"id": "n1", "step": "Первый шаг"}, {"id": "n2", "step": "Второй шаг"}]
	return data


## Hero data of the chapters m_g and m_h as ChapterData (no run, no state).
static func chapters() -> Array[ChapterData]:
	var hero: HeroData = MeaningFixtures.hero_of([chapter_g(), chapter_h()], StoryFixtures.nav_flags())
	return hero.chapters
