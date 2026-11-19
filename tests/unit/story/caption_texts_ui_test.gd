extends GdUnitTestSuite
## Unit tests of CaptionTexts (reading-screen.md, «готовая подпись»; d20-checks.md AC-07; story UI1).

func _texts() -> CaptionTexts:
	var issues: Array[DataIssue] = []
	return CaptionTexts.load_file(CaptionTexts.PATH, issues)


func test_the_shipped_file_reads_without_findings() -> void:
	var issues: Array[DataIssue] = []
	CaptionTexts.load_file(CaptionTexts.PATH, issues)
	assert_int(issues.size()).is_equal(0)


func test_signed_bonus_uses_plus_zero_and_true_minus() -> void:
	assert_str(CaptionTexts.signed(4)).is_equal("+4")
	assert_str(CaptionTexts.signed(0)).is_equal("0")
	assert_str(CaptionTexts.signed(-1)).is_equal("−1")


func test_risky_closed_and_plain_lines() -> void:
	var texts: CaptionTexts = _texts()
	assert_str(texts.risky("Сила", 4, "medium", 13, 60)).is_equal("Сила +4 · Средне 13 · шанс 60 %")
	assert_str(texts.closed("Сила", "Сломана рука")).is_equal("Закрыто: Сила \u2014 Сломана рука")
	assert_str(texts.plain()).is_equal("Без броска")
	assert_str(texts.plain("цена")).is_equal("Без броска\u00a0· цена")


func test_a_file_without_a_template_or_a_level_is_reported() -> void:
	var issues: Array[DataIssue] = []
	var data: Dictionary = {"schema_version": 1, "risky": "x", "plain": "p", "plain_price": "pp", "closed": "c", "levels": {"easy": "E"}}
	CaptionTexts.from_dict(data, "t", issues)
	assert_int(issues.size()).is_equal(2)
