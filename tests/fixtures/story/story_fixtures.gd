class_name StoryFixtures
extends RefCounted
## Factory of story test data in the ADR-0001 format. Every call returns a fresh
## Dictionary, so a test breaks exactly one thing and shares no state.

const DIR := "res://tests/fixtures/story"
const CH_F1 := DIR + "/hero_stub/chapters/ch_f1.json"
const M_REFS := DIR + "/hero_refs/chapters/m_refs.json"
const DT01_BROKEN := DIR + "/dt01_broken.json"
const DT02_ROOT_ARRAY := DIR + "/dt02_root_array.json"
const MISSING_FILE := DIR + "/no_such_file.json"


## Smallest chapter the loader accepts: one start, one linear scene, one outcome,
## one transition to the end of the chapter.
static func minimal_chapter() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "m_min",
		"title": "Мини-глава",
		"goal": "Цель",
		"starts": [{"id": "st_main", "scene": "s1"}],
		"scenes": [{
			"id": "s1",
			"paragraphs": ["Абзац сцены."],
			"illustration": "ill_s1",
			"options": [{"id": "s1_go", "text": "Дальше", "kind": "normal", "outcome": "o1"}],
		}],
		"outcomes": [{"id": "o1", "routes": [{"transition": "t_end"}]}],
		"transitions": [{"id": "t_end", "to": "chapter_end", "coda": ["Кода."]}],
	}


## minimal_chapter() whose only option is risky, with a check on two outcomes.
static func chapter_with_check() -> Dictionary:
	var chapter: Dictionary = minimal_chapter()
	var check: Dictionary = {"id": "c1", "stat": "strength", "level": "medium", "success": "o1", "failure": "o2"}
	chapter["scenes"][0]["options"] = [{"id": "s1_risk", "text": "Рискнуть", "kind": "risky", "check": check}]
	chapter["outcomes"].append({"id": "o2", "routes": [{"transition": "t_end"}]})
	return chapter


## One flag declaration with the required keys only.
static func flag(id: String, category: String = "story") -> Dictionary:
	return {"id": id, "category": category, "title": "Название " + id, "visible": false}


## flags.json content for the given declarations.
static func flags_file(flags: Array) -> Dictionary:
	return {"schema_version": 1, "flags": flags}


## Vocabulary of flags f_known (group mood) and f_other, with the categories story and wound.
static func vocabulary() -> ConditionVocabulary:
	var known: ConditionVocabulary = ConditionVocabulary.new()
	known.flags = ["f_known", "f_other"]
	known.categories = ["story", "wound"]
	known.groups = ["mood"]
	known.flag_groups = {"f_known": "mood"}
	return known


## Flags of the navigator tests (story S6): f_a…f_d, f_fail (goal failure of ch_a, scope run)
## and f_ch (scope chapter).
static func nav_flags() -> Array:
	var chapter_flag: Dictionary = flag("f_ch")
	chapter_flag["scope"] = "chapter"
	return [flag("f_a"), flag("f_b"), flag("f_c"), flag("f_d"), flag("f_fail"), chapter_flag]


## Chapter m_g of the bridge cases: s1 options a, b, c. oa (sets f_a) and ob (sets f_b) lead
## through t_ab, a bridge with two inserts, into s2; oc leads through t_c, another bridge, into s2.
## s2 has three paragraphs, the middle one on f_c; o_s2 sets f_c and f_d, reads f_d, ends the chapter.
static func nav_bridges() -> Dictionary:
	var inserts: Array = [{"if": "f_a", "text": "и ветер"}, {"if": "f_b", "text": "и дождь"}]
	var scenes: Array = [
		GraphFixtures.scene("s1", [GraphFixtures.normal("a", "oa"), GraphFixtures.normal("b", "ob"), GraphFixtures.normal("c", "oc")]),
		GraphFixtures.scene("s2", [GraphFixtures.normal("s2_go", "o_s2")]),
	]
	scenes[1]["paragraphs"] = ["Первый.", {"text": "Скрытый.", "if": "f_c"}, "Третий."]
	var outcomes: Array = [
		GraphFixtures.outcome("oa", ["t_ab"], ["f_a"]),
		GraphFixtures.outcome("ob", ["t_ab"], ["f_b"]),
		GraphFixtures.outcome("oc", ["t_c"]),
		GraphFixtures.outcome("o_s2", ["t_end"], ["f_c", "f_d"], [{"text": "Знак f_d.", "if": "f_d"}]),
	]
	var transitions: Array = [
		{"id": "t_ab", "to": "scene:s2", "bridge": {"base": "Мост{insert}.", "inserts": inserts}},
		{"id": "t_c", "to": "scene:s2", "bridge": {"base": "Другой мост."}},
		GraphFixtures.to_end("t_end"),
	]
	return GraphFixtures.chapter(scenes, outcomes, transitions)


## Chapter ch_a: a1_win (o_win sets f_ch) or a1_lose (o_lose sets f_fail, the goal failure);
## both end the chapter; the coda has a paragraph on f_ch.
static func nav_chapter_a() -> Dictionary:
	var scenes: Array = [GraphFixtures.scene("a1", [GraphFixtures.normal("a1_win", "o_win"), GraphFixtures.normal("a1_lose", "o_lose")])]
	var outcomes: Array = [
		GraphFixtures.outcome("o_win", ["t_a_end"], ["f_ch"], ["Победа."]),
		GraphFixtures.outcome("o_lose", ["t_a_end"], ["f_fail"], ["Провал."]),
	]
	var coda: Array = ["Кода А.", {"text": "Кода победы.", "if": "f_ch"}]
	var transitions: Array = [{"id": "t_a_end", "to": "chapter_end", "coda": coda}]
	var data: Dictionary = GraphFixtures.chapter(scenes, outcomes, transitions, [{"id": "st_a", "scene": "a1"}])
	data["id"] = "ch_a"
	data["title"] = "Глава А"
	data["goal_fail_flag"] = "f_fail"
	return data


## Chapter ch_b, the last of the hero: st_fail (on f_fail, with its own goal) and st_ch (on the
## chapter flag f_ch) lead to b_fail, the main start st_b to b1; both scenes end the chapter.
static func nav_chapter_b() -> Dictionary:
	var scenes: Array = [
		GraphFixtures.scene("b1", [GraphFixtures.normal("b1_go", "o_b1")]),
		GraphFixtures.scene("b_fail", [GraphFixtures.normal("bf_go", "o_bf")]),
	]
	var outcomes: Array = [GraphFixtures.outcome("o_b1", ["t_b_end"]), GraphFixtures.outcome("o_bf", ["t_b_end"])]
	var starts: Array = [
		{"id": "st_fail", "if": "f_fail", "scene": "b_fail", "goal": "Цель после провала"},
		{"id": "st_ch", "if": "f_ch", "scene": "b_fail"},
		{"id": "st_b", "scene": "b1"},
	]
	var data: Dictionary = GraphFixtures.chapter(scenes, outcomes, [GraphFixtures.to_end("t_b_end")], starts)
	data["id"] = "ch_b"
	data["title"] = "Глава Б"
	return data
