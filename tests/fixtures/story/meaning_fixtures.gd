class_name MeaningFixtures
extends RefCounted
## Factory of mini-chapters for the meaning checks of story S5 (branching-story.md, AC-07…AC-27).
## Builds on GraphFixtures: every call returns fresh Dictionaries in the file format.

const FILLER := "слово "


## Declared flags of the S5 tests: readable ones, a price, a wound and two flags of one group.
static func flags() -> Array:
	var group_a: Dictionary = StoryFixtures.flag("f_g1")
	group_a["group"] = "mood"
	var group_b: Dictionary = StoryFixtures.flag("f_g2")
	group_b["group"] = "mood"
	return [
		StoryFixtures.flag("f_a"), StoryFixtures.flag("f_b"), StoryFixtures.flag("f_c"), StoryFixtures.flag("f_d"),
		StoryFixtures.flag("price_a", "price"), StoryFixtures.flag("hurt", "wound"), group_a, group_b,
		StoryFixtures.flag("f_fail"),
	]


## `count` words of filler as one string.
static func words(count: int) -> String:
	return (FILLER.repeat(count)).strip_edges()


## HeroData with several chapters; `ids` are the chapter order of the hero.
static func hero_of(chapters: Array, flag_dicts: Array = []) -> HeroData:
	var result: HeroData = HeroData.new()
	result.id = "hero_g"
	var issues: Array[DataIssue] = []
	result.flags = FlagLoader.parse(StoryFixtures.flags_file(flag_dicts), "test", PackedStringArray(["strength"]), issues)
	var known: ConditionVocabulary = FlagLoader.vocabulary(result.flags)
	for data: Dictionary in chapters:
		var loaded: ChapterData = ChapterLoader.parse(data, "test", issues, known)
		result.chapters.append(loaded)
		result.chapter_ids.append(loaded.id)
	return result


## Chapter `chapter_id` of the chain `ids` (copy of GraphFixtures.chain with another id).
static func chain(ids: Array, chapter_id: String = "m_g") -> Dictionary:
	var data: Dictionary = GraphFixtures.chain(ids)
	data["id"] = chapter_id
	return data


## s1 with two normal options oa and ob, both leading through t_s1 into s2, which ends the chapter.
static func fork() -> Dictionary:
	var data: Dictionary = chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s1")["options"] = [GraphFixtures.normal("a", "oa"), GraphFixtures.normal("b", "ob")]
	data["outcomes"] = [
		GraphFixtures.outcome("oa", ["t_s1"]),
		GraphFixtures.outcome("ob", ["t_s1"]),
		GraphFixtures.outcome("o_s2", ["t_s2"]),
	]
	return data


## s1 with a risky option r (outcomes ow, of) and a safe option sf (outcome os); all lead into s2.
static func risky_fork() -> Dictionary:
	var data: Dictionary = chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s1")["options"] = [GraphFixtures.risky("r", "ow", "of"), GraphFixtures.safe("sf", "os")]
	data["outcomes"] = [
		GraphFixtures.outcome("ow", ["t_s1"]),
		GraphFixtures.outcome("of", ["t_s1"]),
		GraphFixtures.outcome("os", ["t_s1"], ["price_a"]),
		GraphFixtures.outcome("o_s2", ["t_s2"]),
	]
	return data


## Puts a conditional paragraph reading `condition` first in the scene.
static func read_in_scene(data: Dictionary, scene_id: String, condition: String) -> void:
	var paragraphs: Array = GraphFixtures.find(data["scenes"], scene_id)["paragraphs"]
	paragraphs.insert(0, {"text": "Условный абзац.", "if": condition})


## Rewrites the scenes of a chain by letters: P risky, l linear, v and u two options. Scene ids s1…sN.
static func shape(letters: String) -> Dictionary:
	var ids: Array = []
	for i: int in letters.length():
		ids.append("s%d" % (i + 1))
	var data: Dictionary = chain(ids)
	for i: int in letters.length():
		var scene: Dictionary = GraphFixtures.find(data["scenes"], ids[i])
		var outcome_id: String = "o_" + ids[i]
		match letters[i]:
			"P":
				scene["options"] = [GraphFixtures.risky(ids[i] + "_r", outcome_id, outcome_id + "_f"), GraphFixtures.safe(ids[i] + "_s", outcome_id + "_s")]
				for extra: String in [outcome_id + "_f", outcome_id + "_s"]:
					data["outcomes"].append(GraphFixtures.outcome(extra, ["t_" + ids[i]]))
			"v", "u":
				scene["options"] = [GraphFixtures.normal(ids[i] + "_a", outcome_id), GraphFixtures.normal(ids[i] + "_b", outcome_id)]
	return data


## A chain of two scenes whose whole path has `total` words (bridge, outcomes and coda are one word each).
static func chain_of_words(total: int) -> Dictionary:
	var data: Dictionary = chain(["s1", "s2"])
	GraphFixtures.find(data["scenes"], "s1")["paragraphs"] = [words(10)]
	GraphFixtures.find(data["scenes"], "s2")["paragraphs"] = [words(total - 14)]
	return data


## The ch_f1 fixture made clean for the meaning checks of S5 (AC-27), in memory: the file stays as S1–S4 left it.
## Changes: node scenes get a first paragraph read on `f_past` (the 70 words are split 35 + 35 and the
## totals stay), long outcome paragraphs are split in two, equal-trace options and equal-trace risky
## options get an `exception`, and an outcome sets `f_past`.
static func f1_clean() -> Dictionary:
	var data: Dictionary = GraphFixtures.f1_chapter()
	for scene: Dictionary in data["scenes"]:
		scene["paragraphs"] = _split_all(scene["paragraphs"], scene.get("node", false))
		for option: Dictionary in scene["options"]:
			option["exception"] = "Заполнитель: следы вариантов равны по построению фикстуры."
	for outcome: Dictionary in data["outcomes"]:
		outcome["paragraphs"] = _split_all(outcome.get("paragraphs", []), false)
	GraphFixtures.find(data["outcomes"], "o_s02_win")["sets"] = ["f_past"]
	return data


static func _split_all(paragraphs: Array, conditional_first: bool) -> Array:
	var result: Array = []
	for paragraph: Variant in paragraphs:
		var text: String = paragraph if paragraph is String else paragraph["text"]
		var parts: PackedStringArray = text.split(" ")
		if parts.size() <= 60:
			result.append(paragraph)
			continue
		var half: int = parts.size() / 2
		var head: String = " ".join(parts.slice(0, half))
		var tail: String = " ".join(parts.slice(half))
		var is_first: bool = result.is_empty()
		result.append({"text": head, "if": "f_past"} if conditional_first and is_first else head)
		result.append(tail)
	return result
