extends GdUnitTestSuite
## Unit tests for BridgeData.joined: the insert of a bridge and its spaces (UR-1, CEO decision;
## branching-story.md, AC-52; story S6). No spaces sit at `{insert}` in `base` or at the edges of an
## insert; a shown insert is parted from its neighbours by one space (none before a closing sign).


func _bridge(base: String) -> BridgeData:
	var bridge: BridgeData = BridgeData.new()
	bridge.base = base
	return bridge


func _assert_clean(text: String) -> void:
	assert_bool(text.contains("  ")).is_false()
	assert_bool(text.contains(" ,")).is_false()
	assert_str(text).is_equal(text.strip_edges())


func test_join_ac52_insert_shown_and_hidden() -> void:
	# Arrange
	var bridge: BridgeData = _bridge("Мост" + BridgeData.INSERT_MARK + ".")
	# Act
	var shown: String = bridge.joined("и ветер")
	var hidden: String = bridge.joined("")
	# Assert
	assert_str(shown).is_equal("Мост и ветер.")
	assert_str(hidden).is_equal("Мост.")


func test_join_between_two_words_gets_one_space_each_side() -> void:
	# Arrange
	var bridge: BridgeData = _bridge("А{insert}б")
	# Act / Assert
	assert_str(bridge.joined("X")).is_equal("А X б")
	assert_str(bridge.joined("")).is_equal("А б")


func test_join_insert_at_the_start_and_at_the_end_of_base() -> void:
	# Arrange
	var first: BridgeData = _bridge("{insert}мост.")
	var last: BridgeData = _bridge("Мост.{insert}")
	# Act / Assert
	assert_str(first.joined("Ветер,")).is_equal("Ветер, мост.")
	assert_str(first.joined("")).is_equal("мост.")
	assert_str(last.joined("Ветер.")).is_equal("Мост. Ветер.")
	assert_str(last.joined("")).is_equal("Мост.")


func test_join_closing_sign_on_the_right_gets_no_space() -> void:
	# Arrange
	var signs: PackedStringArray = [", дальше.", "…", "» сказал он.", ") дальше."]
	for sign: String in signs:
		var bridge: BridgeData = _bridge("Мост{insert}" + sign)
		# Act
		var shown: String = bridge.joined("ветер")
		var hidden: String = bridge.joined("")
		# Assert
		assert_str(shown).is_equal("Мост ветер" + sign)
		assert_str(hidden).is_equal("Мост" + sign)
		_assert_clean(shown)
		_assert_clean(hidden)


func test_join_dash_on_the_right_gets_a_space() -> void:
	# Arrange
	var bridge: BridgeData = _bridge("Мост{insert}— дальше.")
	# Act / Assert
	assert_str(bridge.joined("ветер")).is_equal("Мост ветер — дальше.")
	assert_str(bridge.joined("")).is_equal("Мост — дальше.")


func test_join_opening_quote_on_the_left_gets_no_space() -> void:
	# Arrange
	var bridge: BridgeData = _bridge("Он сказал: «{insert}»")
	# Act / Assert
	assert_str(bridge.joined("Ветер")).is_equal("Он сказал: «Ветер»")


func test_join_without_a_mark_returns_base() -> void:
	# Arrange
	var bridge: BridgeData = _bridge("Мост дальше.")
	# Act / Assert
	assert_str(bridge.joined("ветер")).is_equal("Мост дальше.")
	assert_str(bridge.joined("")).is_equal("Мост дальше.")


# --- Audit round 1: НП-62 quotes, split ---

func test_join_russian_closing_quote_on_the_left_gets_a_space_and_on_the_right_none() -> void:
	# Arrange
	var after_quote: BridgeData = _bridge("„Мост“{insert}.")
	var before_quote: BridgeData = _bridge("„Мост{insert}“ — сказал он.")
	# Act / Assert
	assert_str(after_quote.joined("и ветер")).is_equal("„Мост“ и ветер.")
	assert_str(before_quote.joined("и ветер")).is_equal("„Мост и ветер“ — сказал он.")
	assert_str(before_quote.joined("")).is_equal("„Мост“ — сказал он.")


func test_split_gives_the_parts_around_the_mark_or_nothing() -> void:
	# Arrange / Act / Assert
	assert_array(Array(_bridge("Мост{insert}.").split())).contains_exactly(["Мост", "."])
	assert_array(Array(_bridge("Мост.").split())).is_empty()
