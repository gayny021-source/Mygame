extends GdUnitTestSuite
## Unit tests for Condition.evaluate (ADR-0001 §5, story S2; branching-story.md,
## Core Rules 7) over FakeFlags, the test stand-in for RunState.

const LONG_CHAIN_TERMS: int = 2000


func _flags(set_flags: PackedStringArray) -> FakeFlags:
	var ctx: FakeFlags = FakeFlags.new()
	ctx.flags = set_flags
	return ctx


# Разбор без словаря: здесь проверяется только вычисление.
func _eval(text: String, ctx: ConditionContext) -> bool:
	var result: ConditionParser.ParseResult = ConditionParser.parse(text, null)
	assert_array(result.issues).is_empty()
	return result.condition.evaluate(ctx)


func _repeat(part: String, times: int) -> String:
	var parts: PackedStringArray = []
	parts.resize(times)
	parts.fill(part)
	return "".join(parts)


func test_evaluate_flag_is_true_only_when_flag_is_set() -> void:
	assert_bool(_eval("f_a", _flags(["f_a"]))).is_true()
	assert_bool(_eval("f_a", _flags(["f_b"]))).is_false()
	assert_bool(_eval("f_a", _flags([]))).is_false()


func test_evaluate_any_is_true_when_one_listed_flag_is_set() -> void:
	assert_bool(_eval("any(f_a, f_b, f_c)", _flags(["f_c"]))).is_true()
	assert_bool(_eval("any(f_a, f_b, f_c)", _flags(["f_d"]))).is_false()


func test_evaluate_cat_asks_context_for_that_category() -> void:
	# Arrange
	var ctx: FakeFlags = _flags([])
	ctx.categories = ["wound"]
	# Act + Assert
	assert_bool(_eval("cat(wound)", ctx)).is_true()
	assert_bool(_eval("cat(debt)", ctx)).is_false()


func test_evaluate_group_compares_standing_flag() -> void:
	# Arrange
	var ctx: FakeFlags = _flags([])
	ctx.groups = {"mood": "f_calm"}
	# Act + Assert
	assert_bool(_eval("group(mood) == f_calm", ctx)).is_true()
	assert_bool(_eval("group(mood) == f_angry", ctx)).is_false()


func test_evaluate_group_without_standing_flag_is_false() -> void:
	assert_bool(_eval("group(mood) == f_calm", _flags(["f_calm"]))).is_false()


func test_evaluate_not_inverts() -> void:
	assert_bool(_eval("not f_a", _flags([]))).is_true()
	assert_bool(_eval("not f_a", _flags(["f_a"]))).is_false()
	assert_bool(_eval("not not f_a", _flags(["f_a"]))).is_true()


func test_evaluate_and_needs_every_operand() -> void:
	assert_bool(_eval("f_a and f_b and f_c", _flags(["f_a", "f_b", "f_c"]))).is_true()
	assert_bool(_eval("f_a and f_b and f_c", _flags(["f_a", "f_c"]))).is_false()


func test_evaluate_or_needs_one_operand() -> void:
	assert_bool(_eval("f_a or f_b or f_c", _flags(["f_c"]))).is_true()
	assert_bool(_eval("f_a or f_b or f_c", _flags([]))).is_false()


func test_evaluate_not_applies_to_nearest_operand_only() -> void:
	assert_bool(_eval("not f_a and f_b", _flags(["f_b"]))).is_true()
	assert_bool(_eval("not f_a and f_b", _flags([]))).is_false()
	assert_bool(_eval("not (f_a and f_b)", _flags([]))).is_true()


func test_evaluate_brackets_decide_the_grouping() -> void:
	# Arrange: при f_c без f_a две расстановки скобок дают разный ответ
	var ctx: FakeFlags = _flags(["f_c"])
	# Act + Assert
	assert_bool(_eval("(f_a and f_b) or f_c", ctx)).is_true()
	assert_bool(_eval("f_a and (f_b or f_c)", ctx)).is_false()


func test_evaluate_mixed_atoms_in_one_condition() -> void:
	# Arrange
	var ctx: FakeFlags = _flags(["f_a"])
	ctx.categories = ["wound"]
	ctx.groups = {"mood": "f_calm"}
	# Act + Assert
	assert_bool(_eval("f_a and cat(wound) and group(mood) == f_calm and not any(f_b, f_c)", ctx)).is_true()
	assert_bool(_eval("f_b or (cat(debt) or group(mood) == f_angry)", ctx)).is_false()


func test_evaluate_long_chain_and_max_depth_do_not_overflow() -> void:
	# Arrange
	var chain: String = "f_a" + _repeat(" or f_b", LONG_CHAIN_TERMS)
	var depth: int = ConditionParser.MAX_DEPTH
	var nested: String = _repeat("(", depth) + "f_b" + _repeat(")", depth)
	var negated: String = _repeat("not ", depth) + "f_b"
	# Act + Assert
	assert_bool(_eval(chain, _flags(["f_b"]))).is_true()
	assert_bool(_eval(nested, _flags(["f_b"]))).is_true()
	assert_bool(_eval(negated, _flags(["f_b"]))).is_true()
