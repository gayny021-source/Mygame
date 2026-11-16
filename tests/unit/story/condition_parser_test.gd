extends GdUnitTestSuite
## Unit tests for ConditionParser (ADR-0001 §5, story S2): the grammar, DT-08 for
## syntax with the 1-based position in the text, BS-01 for names the hero does not
## declare (branching-story.md, AC-01). No file is read.

const UNKNOWN_FLAG_POSITION: int = 13
## More brackets than MAX_DEPTH, still under MAX_LENGTH.
const DEEP_BRACKETS: int = 500


func _known() -> ConditionVocabulary:
	var known: ConditionVocabulary = ConditionVocabulary.new()
	known.flags = ["f_a", "f_b", "f_c", "f_d", "android", "notary", "order"]
	known.categories = ["wound"]
	known.groups = ["mood", "temper"]
	known.flag_groups = {"f_a": "mood", "f_b": "mood", "f_c": "temper"}
	return known


func _parse(text: String) -> ConditionParser.ParseResult:
	return ConditionParser.parse(text, _known())


func _lines(result: ConditionParser.ParseResult) -> Array[String]:
	var lines: Array[String] = []
	for issue: DataIssue in result.issues:
		lines.append("%s %s" % [issue.code, issue.message])
	return lines


func _codes(result: ConditionParser.ParseResult) -> Array[String]:
	var codes: Array[String] = []
	for issue: DataIssue in result.issues:
		codes.append(issue.code)
	return codes


# Одна находка DT-08 на заданной позиции и нет дерева.
func _assert_syntax_error(text: String, position: int) -> void:
	var result: ConditionParser.ParseResult = _parse(text)
	assert_array(_codes(result)).is_equal(["DT-08"] as Array[String])
	assert_object(result.condition).is_null()
	assert_str(result.issues[0].message).starts_with("позиция %d:" % position)
	assert_str(result.issues[0].severity).is_equal(DataIssue.ERROR)


# --- atoms ---

func test_parse_flag_returns_flag_node() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_a")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.FLAG)
	assert_array(Array(result.condition.flags)).is_equal(["f_a"])


func test_parse_any_returns_any_node_with_all_flags() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("any(f_a, f_b,f_c)")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.ANY)
	assert_array(Array(result.condition.flags)).is_equal(["f_a", "f_b", "f_c"])


func test_parse_cat_returns_category_node() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("cat(wound)")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.CATEGORY)
	assert_str(result.condition.name).is_equal("wound")


func test_parse_group_returns_group_node_with_expected_flag() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(mood) == f_a")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.GROUP)
	assert_str(result.condition.name).is_equal("mood")
	assert_array(Array(result.condition.flags)).is_equal(["f_a"])


func test_parse_ids_that_start_with_a_keyword_are_plain_flags() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("android and notary and order")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.children.size()).is_equal(3)
	assert_array(Array(result.condition.children[1].flags)).is_equal(["notary"])


# --- whitespace ---

func test_parse_spaces_and_tabs_around_tokens_are_ignored() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("  group ( mood )==f_a\tand any( f_b ) ")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.children.size()).is_equal(2)


func test_parse_line_breaks_are_whitespace() -> void:
	# Act
	var windows: ConditionParser.ParseResult = _parse("f_a\r\nand f_b\r\n")
	var unix: ConditionParser.ParseResult = _parse("f_a\nand\nf_b")
	# Assert
	assert_array(_lines(windows)).is_empty()
	assert_array(_lines(unix)).is_empty()
	assert_int(windows.condition.children.size()).is_equal(2)
	assert_int(unix.condition.children.size()).is_equal(2)


func test_parse_line_break_between_ids_does_not_join_them() -> void:
	_assert_syntax_error("f_a\nf_b", 5)


func test_parse_invisible_symbol_is_dt08_with_its_code() -> void:
	# Act
	var nbsp: ConditionParser.ParseResult = _parse("f_a and f_b")
	var zero_width: ConditionParser.ParseResult = _parse("f_a ​and f_b")
	# Assert
	assert_array(_codes(nbsp)).is_equal(["DT-08"] as Array[String])
	assert_str(nbsp.issues[0].message).starts_with("позиция 4:")
	assert_str(nbsp.issues[0].message).contains("U+00A0")
	assert_array(_codes(zero_width)).is_equal(["DT-08"] as Array[String])
	assert_str(zero_width.issues[0].message).starts_with("позиция 5:")
	assert_str(zero_width.issues[0].message).contains("U+200B")


# --- connectives, precedence, brackets ---

func test_parse_and_chain_returns_one_flat_and_node() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_a and f_b and f_c")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.AND)
	assert_int(result.condition.children.size()).is_equal(3)


func test_parse_or_chain_returns_one_flat_or_node() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_a or f_b or f_c")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.OR)
	assert_int(result.condition.children.size()).is_equal(3)


func test_parse_not_binds_tighter_than_and() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("not f_a and f_b")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.AND)
	assert_int(result.condition.children[0].kind).is_equal(Condition.Kind.NOT)
	assert_int(result.condition.children[1].kind).is_equal(Condition.Kind.FLAG)


func test_parse_not_before_brackets_negates_whole_group() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("not (f_a or f_b)")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.kind).is_equal(Condition.Kind.NOT)
	assert_int(result.condition.children[0].kind).is_equal(Condition.Kind.OR)


func test_parse_double_not_is_accepted() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("not not f_a")
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.children[0].kind).is_equal(Condition.Kind.NOT)


func test_parse_brackets_allow_mixing_and_with_or() -> void:
	# Act
	var left: ConditionParser.ParseResult = _parse("(f_a and f_b) or f_c")
	var right: ConditionParser.ParseResult = _parse("f_a and (f_b or f_c)")
	# Assert
	assert_array(_lines(left)).is_empty()
	assert_array(_lines(right)).is_empty()
	assert_int(left.condition.kind).is_equal(Condition.Kind.OR)
	assert_int(left.condition.children[0].kind).is_equal(Condition.Kind.AND)
	assert_int(right.condition.kind).is_equal(Condition.Kind.AND)
	assert_int(right.condition.children[1].kind).is_equal(Condition.Kind.OR)


func test_parse_and_then_or_without_brackets_is_dt08_at_second_connective() -> void:
	_assert_syntax_error("f_a and f_b or f_c", 13)


func test_parse_or_then_and_without_brackets_is_dt08_at_second_connective() -> void:
	_assert_syntax_error("f_a or f_b and f_c", 12)


func test_parse_mixing_inside_brackets_is_dt08() -> void:
	_assert_syntax_error("f_d and (f_a or f_b and f_c)", 21)


# --- empty text ---

func test_parse_empty_text_is_dt08() -> void:
	_assert_syntax_error("", 1)


func test_parse_blank_text_is_dt08() -> void:
	_assert_syntax_error("  \t ", 5)
	_assert_syntax_error("\r\n", 3)


# --- unknown names ---

func test_parse_unknown_flag_is_bs01_with_position() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_a and not f_zzz")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])
	assert_object(result.condition).is_null()
	assert_str(result.issues[0].message).starts_with("позиция %d:" % UNKNOWN_FLAG_POSITION)
	assert_str(result.issues[0].message).contains("f_zzz")


func test_parse_unknown_flag_inside_any_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("any(f_a, f_zzz)")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_parse_unknown_category_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("cat(f_a)")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_parse_unknown_group_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(wound) == f_a")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_parse_unknown_flag_after_group_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(mood) == mood")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_parse_flag_of_another_group_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(mood) == f_c")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])
	assert_str(result.issues[0].message).contains("f_c").contains("mood")


func test_parse_flag_without_group_after_group_is_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(mood) == f_d")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])


func test_parse_flag_of_the_named_group_is_clean() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("group(temper) == f_c")
	# Assert
	assert_array(_lines(result)).is_empty()


func test_parse_group_membership_is_not_checked_without_vocabulary() -> void:
	# Act
	var result: ConditionParser.ParseResult = ConditionParser.parse("group(mood) == f_c", null)
	# Assert
	assert_array(_lines(result)).is_empty()


func test_parse_every_unknown_name_gets_its_own_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_x or cat(c_x) or group(g_x) == f_y")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01", "BS-01", "BS-01", "BS-01"] as Array[String])


func test_parse_repeated_unknown_name_is_one_bs01_at_first_use() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_a and f_x and any(f_x, f_x) and not f_x")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01"] as Array[String])
	assert_str(result.issues[0].message).starts_with("позиция 9:")


func test_parse_same_unknown_name_as_flag_and_category_is_two_bs01() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse("f_x and cat(f_x) and cat(f_x)")
	# Assert
	assert_array(_codes(result)).is_equal(["BS-01", "BS-01"] as Array[String])


func test_parse_without_vocabulary_checks_syntax_only() -> void:
	# Act
	var result: ConditionParser.ParseResult = ConditionParser.parse("f_zzz and cat(c_x) and group(g_x) == f_y", null)
	var broken: ConditionParser.ParseResult = ConditionParser.parse("f_zzz and", null)
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.children.size()).is_equal(3)
	assert_array(_codes(broken)).is_equal(["DT-08"] as Array[String])


# --- garbage ---

func test_parse_unclosed_bracket_is_dt08_at_end() -> void:
	_assert_syntax_error("(f_a and f_b", 13)


func test_parse_extra_closing_bracket_is_dt08() -> void:
	_assert_syntax_error("f_a)", 4)


func test_parse_empty_brackets_is_dt08() -> void:
	_assert_syntax_error("()", 2)


func test_parse_double_connective_is_dt08() -> void:
	_assert_syntax_error("f_a and and f_b", 9)


func test_parse_leading_connective_is_dt08() -> void:
	_assert_syntax_error("or f_a", 1)


func test_parse_trailing_connective_is_dt08() -> void:
	_assert_syntax_error("f_a and", 8)


func test_parse_trailing_not_is_dt08() -> void:
	_assert_syntax_error("not", 4)


func test_parse_two_flags_without_connective_is_dt08() -> void:
	_assert_syntax_error("f_a f_b", 5)


func test_parse_foreign_symbols_are_dt08() -> void:
	_assert_syntax_error("f_a && f_b", 5)
	_assert_syntax_error("f_a = f_b", 5)
	_assert_syntax_error("!f_a", 1)
	_assert_syntax_error("f_a > 2", 5)


func test_parse_cyrillic_in_identifier_is_dt08() -> void:
	_assert_syntax_error("флаг", 1)
	_assert_syntax_error("f_пасть", 3)
	_assert_syntax_error("f_a и f_b", 5)


func test_parse_uppercase_or_leading_digit_or_underscore_is_dt08() -> void:
	_assert_syntax_error("F_a", 1)
	_assert_syntax_error("f_A", 3)
	_assert_syntax_error("1a", 1)
	_assert_syntax_error("_a", 1)
	_assert_syntax_error("f_a AND f_b", 5)


func test_parse_reserved_word_as_name_is_dt08() -> void:
	_assert_syntax_error("f_a and any", 12)
	_assert_syntax_error("any(not)", 5)
	_assert_syntax_error("cat(group)", 5)
	_assert_syntax_error("group(mood) == or", 16)


func test_parse_broken_any_is_dt08() -> void:
	_assert_syntax_error("any()", 5)
	_assert_syntax_error("any(f_a,)", 9)
	_assert_syntax_error("any(f_a f_b)", 9)
	_assert_syntax_error("any(f_a", 8)
	_assert_syntax_error("any f_a", 5)


func test_parse_broken_cat_is_dt08() -> void:
	_assert_syntax_error("cat()", 5)
	_assert_syntax_error("cat(wound, wound)", 10)
	_assert_syntax_error("cat wound", 5)


func test_parse_broken_group_is_dt08() -> void:
	_assert_syntax_error("group(mood)", 12)
	_assert_syntax_error("group(mood) f_a", 13)
	_assert_syntax_error("group(mood) ==", 15)
	_assert_syntax_error("group(mood) == (f_a)", 16)
	_assert_syntax_error("group mood == f_a", 7)
	_assert_syntax_error("group(mood == f_a", 12)


func test_parse_single_equals_after_group_is_dt08() -> void:
	_assert_syntax_error("group(mood) = f_a", 13)


# --- length and depth ---

func test_parse_long_flat_chain_is_accepted() -> void:
	# Act
	var result: ConditionParser.ParseResult = _parse(ConditionFixtures.or_chain())
	# Assert
	assert_array(_lines(result)).is_empty()
	assert_int(result.condition.children.size()).is_equal(ConditionFixtures.CHAIN_TERMS + 1)


func test_parse_text_of_max_length_is_accepted() -> void:
	# Arrange
	var chain: String = ConditionFixtures.or_chain()
	var text: String = chain + " ".repeat(ConditionParser.MAX_LENGTH - chain.length())
	# Act
	var result: ConditionParser.ParseResult = _parse(text)
	# Assert
	assert_int(text.length()).is_equal(ConditionParser.MAX_LENGTH)
	assert_array(_lines(result)).is_empty()


func test_parse_text_over_max_length_is_dt08_at_first_extra_symbol() -> void:
	# Arrange
	var chain: String = ConditionFixtures.or_chain()
	var text: String = chain + " ".repeat(ConditionParser.MAX_LENGTH + 1 - chain.length())
	# Act + Assert
	_assert_syntax_error(text, ConditionParser.MAX_LENGTH + 1)


func test_parse_long_garbage_is_one_dt08() -> void:
	_assert_syntax_error("f_a ".repeat(ConditionParser.MAX_LENGTH), ConditionParser.MAX_LENGTH + 1)
	_assert_syntax_error("f_a ".repeat(ConditionFixtures.CHAIN_TERMS), 5)


func test_parse_nesting_at_max_depth_is_accepted() -> void:
	# Arrange
	var depth: int = ConditionParser.MAX_DEPTH
	var brackets: String = "(".repeat(depth) + "f_a" + ")".repeat(depth)
	var negations: String = "not ".repeat(depth) + "f_a"
	# Act
	var bracketed: ConditionParser.ParseResult = _parse(brackets)
	var negated: ConditionParser.ParseResult = _parse(negations)
	# Assert
	assert_array(_lines(bracketed)).is_empty()
	assert_array(_lines(negated)).is_empty()


func test_parse_brackets_over_max_depth_are_dt08_at_first_extra_level() -> void:
	# Arrange
	var depth: int = ConditionParser.MAX_DEPTH + 1
	# Act + Assert
	_assert_syntax_error("(".repeat(depth) + "f_a" + ")".repeat(depth), depth)


func test_parse_negations_over_max_depth_are_dt08_at_first_extra_level() -> void:
	# Arrange
	var depth: int = ConditionParser.MAX_DEPTH
	# Act + Assert
	_assert_syntax_error("not ".repeat(depth + 1) + "f_a", depth * 4 + 1)


func test_parse_very_deep_nesting_is_one_dt08_not_a_crash() -> void:
	_assert_syntax_error("(".repeat(DEEP_BRACKETS) + "f_a", ConditionParser.MAX_DEPTH + 1)
