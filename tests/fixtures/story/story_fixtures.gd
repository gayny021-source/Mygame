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
	return {"id": id, "category": category, "title": "Название " + id}


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
