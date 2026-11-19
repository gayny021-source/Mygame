extends GdUnitTestSuite
## The shipped hero data of Rovend (heroes.md, «Эталон»; branching-story.md, «Эталон»): the stat profile
## and the passport keys. No chapters exist yet, so the test reads hero.json, not the whole hero.

const PATH := HeroLoader.DATA_ROOT + "/rovend/hero.json"


func _stats() -> Dictionary:
	var issues: Array[DataIssue] = []
	var data: Dictionary = ChapterLoader.read_object(PATH, issues)
	assert_array(issues).is_empty()
	var stats: Dictionary = {}
	for item: Dictionary in data["stats"]:
		stats[item["id"]] = int(item["bonus"])
	return stats


func test_rovend_stats_match_the_reference_profile() -> void:
	assert_dict(_stats()).is_equal({"strength": 4, "charisma": 2, "mind": 0, "faith": -1})


func test_rovend_hero_json_has_only_adr_keys_and_no_flags_file() -> void:
	var issues: Array[DataIssue] = []
	var data: Dictionary = ChapterLoader.read_object(PATH, issues)
	for key: String in data:
		assert_bool(HeroLoader.HERO_KEYS.has(key)).is_true()
	assert_str(data["id"]).is_equal("rovend")
	assert_bool(FileAccess.file_exists(HeroLoader.DATA_ROOT + "/rovend/flags.json")).is_false()


func test_rovend_has_the_display_name() -> void:
	var issues: Array[DataIssue] = []
	var data: Dictionary = ChapterLoader.read_object(PATH, issues)
	assert_str(data["name"]).is_equal("сэр Ровенд Непоколебимый")
