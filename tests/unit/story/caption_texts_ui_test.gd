extends GdUnitTestSuite
## Unit tests of CaptionTexts (reading-screen.md, «готовая подпись»; d20-checks.md AC-07; story UI1).

func _texts() -> CaptionTexts:
	var issues: Array[DataIssue] = []
	return CaptionTexts.load_file(CaptionTexts.PATH, issues)


func test_the_shipped_file_is_valid() -> void:
	assert_bool(_texts().valid).is_true()


func test_signed_bonus_uses_plus_zero_and_true_minus() -> void:
	assert_str(CaptionTexts.signed(4)).is_equal("+4")
	assert_str(CaptionTexts.signed(0)).is_equal("0")
	assert_str(CaptionTexts.signed(-1)).is_equal("−1")


func test_risky_closed_and_plain_lines() -> void:
	var texts: CaptionTexts = _texts()
	assert_str(texts.risky("strength", 4, "medium", 13, 60)).is_equal("Сила +4 · Средне 13 · шанс 60 %")
	assert_str(texts.closed("strength", "Сломана рука")).is_equal("Сила закрыта: Сломана рука")
	assert_str(texts.plain()).is_equal("Без броска")
	assert_str(texts.plain("цена")).is_equal("Без броска · цена")


func test_an_unnamed_stat_and_level_fall_back_to_the_id() -> void:
	var texts: CaptionTexts = _texts()
	assert_str(texts.stat_name("charm")).is_equal("charm")
	assert_str(texts.level_word("epic")).is_equal("epic")


func test_a_file_without_a_template_is_invalid_and_reported() -> void:
	var issues: Array[DataIssue] = []
	var texts: CaptionTexts = CaptionTexts.from_dict({"risky": "x"}, "t", issues)
	assert_bool(texts.valid).is_false()
	assert_int(issues.size()).is_equal(1)
