class_name ConditionFixtures
extends RefCounted
## Shared texts for the condition tests (ADR-0001 §5).

## Operands after the first one in `or_chain()`; the text stays under ConditionParser.MAX_LENGTH.
const CHAIN_TERMS: int = 140


## Long flat chain `f_a or f_b or f_b ...`: true exactly when `f_a` or `f_b` is set.
static func or_chain() -> String:
	return "f_a" + " or f_b".repeat(CHAIN_TERMS)
