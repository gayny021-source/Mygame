extends GdUnitTestSuite
## Unit tests for the screen limits F4 (warnings of BS-06; AC-31) and the bridge punctuation
## (UR-1, proposal for BS-06; AC-06). Messages of warnings start with a tag F4/<limit>.


func _issues(data: Dictionary, options: ValidatorOptions = null) -> Array[DataIssue]:
	var used: ValidatorOptions = options if options != null else ValidatorOptions.new()
	return DataValidator.validate(MeaningFixtures.hero_of([data], MeaningFixtures.flags()), used)


func _tagged(data: Dictionary, tag: String, options: ValidatorOptions = null) -> int:
	var total: int = 0
	for issue: DataIssue in _issues(data, options):
		total += 1 if issue.code == "BS-06" and issue.severity == DataIssue.WARNING and issue.message.begins_with(tag) else 0
	return total


func _punctuation_errors(base: String, inserts: Array = []) -> int:
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	var bridge: Dictionary = {"base": base}
	if not inserts.is_empty():
		bridge["inserts"] = inserts
	GraphFixtures.find(data["transitions"], "t_s1")["bridge"] = bridge
	var total: int = 0
	for issue: DataIssue in _issues(data):
		total += 1 if issue.code == "BS-06" and issue.severity == DataIssue.ERROR and issue.message.begins_with("UR-1") else 0
	return total


func _scene_paragraphs(data: Dictionary, paragraphs: Array) -> void:
	GraphFixtures.find(data["scenes"], "s2")["paragraphs"] = paragraphs


func test_f4_paragraph_of_60_words_passes_and_61_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(data, [MeaningFixtures.words(60)])
	var long: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(long, [MeaningFixtures.words(61)])
	# Act / Assert
	assert_int(_tagged(data, "F4/words")).is_equal(0)
	assert_int(_tagged(long, "F4/words")).is_equal(1)


func test_f4_screen_of_six_paragraphs_with_the_bridge_passes_and_seven_warn() -> void:
	# Arrange
	var six: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(six, ["a.", "b.", "c.", "d.", "e."])
	var seven: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(seven, ["a.", "b.", "c.", "d.", "e.", "f."])
	# Act / Assert
	assert_int(_tagged(six, "F4/screen")).is_equal(0)
	assert_int(_tagged(seven, "F4/screen")).is_equal(1)


func test_f4_two_conditional_paragraphs_pass_and_three_warn() -> void:
	# Arrange
	var two: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(two, [{"text": "a.", "if": "f_a"}, {"text": "b.", "if": "f_a"}, "c."])
	var three: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(three, [{"text": "a.", "if": "f_a"}, {"text": "b.", "if": "f_a"}, {"text": "c.", "if": "f_a"}, "d."])
	# Act / Assert
	assert_int(_tagged(two, "F4/conditional")).is_equal(0)
	assert_int(_tagged(three, "F4/conditional")).is_equal(1)


func test_f4_three_flags_in_prose_pass_and_four_warn() -> void:
	# Arrange
	var three: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(three, [{"text": "a.", "if": "f_a or f_b or f_c"}, "b."])
	var four: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(four, [{"text": "a.", "if": "f_a or f_b or f_c or f_d"}, "b."])
	# Act / Assert
	assert_int(_tagged(three, "F4/flags")).is_equal(0)
	assert_int(_tagged(four, "F4/flags")).is_equal(1)


func test_f4_outcome_of_six_paragraphs_passes_and_seven_warn() -> void:
	# Arrange
	var six: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(six["outcomes"], "oa")["paragraphs"] = ["a.", "b.", "c.", "d.", "e.", "f."]
	var seven: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(seven["outcomes"], "oa")["paragraphs"] = ["a.", "b.", "c.", "d.", "e.", "f.", "g."]
	# Act / Assert
	assert_int(_tagged(six, "F4/outcome")).is_equal(0)
	assert_int(_tagged(seven, "F4/outcome")).is_equal(1)


func test_f4_past_options_follow_the_limit_of_the_options() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.past_options_max = 2
	var two: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(two["scenes"], "s1")["options"].append(GraphFixtures.normal("c", "oa"))
	GraphFixtures.find(two["scenes"], "s1")["options"][0]["if"] = "f_a"
	GraphFixtures.find(two["scenes"], "s1")["options"][1]["if"] = "f_a"
	var three: Dictionary = MeaningFixtures.fork()
	GraphFixtures.find(three["scenes"], "s1")["options"].append(GraphFixtures.normal("c", "oa"))
	for option: Dictionary in GraphFixtures.find(three["scenes"], "s1")["options"]:
		option["if"] = "f_a"
	# Act / Assert
	assert_int(_tagged(two, "F4/past", options)).is_equal(0)
	assert_int(_tagged(three, "F4/past", options)).is_equal(1)


func test_f4_past_option_with_an_exception_is_not_counted() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.fork()
	for option: Dictionary in GraphFixtures.find(data["scenes"], "s1")["options"]:
		option["if"] = "f_a"
		option["exception"] = "Так задумано."
	# Act / Assert
	assert_int(_tagged(data, "F4/past")).is_equal(0)


func test_f4_coda_of_three_paragraphs_passes_and_four_warn() -> void:
	# Arrange
	var three: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(three["transitions"], "t_s2")["coda"] = ["a.", "b.", "c."]
	var four: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(four["transitions"], "t_s2")["coda"] = ["a.", "b.", "c.", "d."]
	# Act / Assert
	assert_int(_tagged(three, "F4/coda")).is_equal(0)
	assert_int(_tagged(four, "F4/coda")).is_equal(1)


func test_f4_bridge_of_61_words_warns() -> void:
	# Arrange
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["transitions"], "t_s1")["bridge"] = {"base": MeaningFixtures.words(61) + "."}
	# Act / Assert
	assert_int(_tagged(data, "F4/bridge")).is_equal(1)


func test_f4_limits_come_from_the_options() -> void:
	# Arrange
	var options: ValidatorOptions = ValidatorOptions.new()
	options.paragraph_words_max = 10
	var data: Dictionary = MeaningFixtures.chain(["s1", "s2"])
	_scene_paragraphs(data, [MeaningFixtures.words(11)])
	# Act / Assert
	assert_int(_tagged(data, "F4/words", options)).is_equal(1)


# --- UR-1: punctuation of a bridge ---

func test_ur1_clean_bridge_passes() -> void:
	# Arrange / Act / Assert
	assert_int(_punctuation_errors("Мост, который был. Дальше.")).is_equal(0)


func test_ur1_double_space_is_an_error() -> void:
	# Arrange / Act / Assert
	assert_int(_punctuation_errors("Мост  дальше.")).is_equal(1)


func test_ur1_space_before_a_sign_is_an_error() -> void:
	# Arrange / Act / Assert
	assert_int(_punctuation_errors("Мост , дальше.")).is_equal(1)


func test_ur1_sign_at_the_start_or_a_dangling_sign_at_the_end_is_an_error() -> void:
	# Arrange / Act / Assert
	assert_int(_punctuation_errors(", мост.")).is_equal(1)
	assert_int(_punctuation_errors("Мост,")).is_equal(1)


func test_ur1_bridge_with_an_insert_is_checked_without_the_insert() -> void:
	# Arrange
	var good: Array = [{"text": "и ветер", "if": "f_a"}]
	# Act / Assert
	assert_int(_punctuation_errors("Мост{insert} дальше.", good)).is_equal(0)
	assert_int(_punctuation_errors("Мост {insert} дальше.", good)).is_equal(1)
