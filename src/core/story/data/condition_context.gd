@abstract
class_name ConditionContext
extends RefCounted
## Flag state a Condition is evaluated over (ADR-0001 §5, Key Interfaces; run-state.md, rule 4).
## RunState implements it; tests use FakeFlags.
##
## Usage: [code]condition.evaluate(ctx)[/code], where [code]ctx[/code] extends this class.

## True when the flag `id` is set.
@abstract func has_flag(id: String) -> bool

## True when at least one flag of `category` is set.
@abstract func any_in_category(category: String) -> bool

## Id of the flag standing in `group`; empty when none stands.
@abstract func flag_in_group(group: String) -> String
