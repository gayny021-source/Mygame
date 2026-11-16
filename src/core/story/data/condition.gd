class_name Condition
extends RefCounted
## Node of a parsed `if` condition (ADR-0001 §5; branching-story.md, Core Rules 7).
## Built only by ConditionParser, which bounds the depth of the tree.
##
## Usage: [code]if option.condition.evaluate(run_state): ...[/code]

enum Kind { FLAG, ANY, CATEGORY, GROUP, NOT, AND, OR }

## Node kind.
var kind: Kind
## CATEGORY: the category id. GROUP: the group id.
var name: String
## FLAG: the one flag. ANY: the listed flags. GROUP: the one flag expected to stand in the group.
var flags: PackedStringArray = []
## NOT: the one operand. AND, OR: two or more operands.
var children: Array[Condition] = []


func _init(node_kind: Kind) -> void:
	kind = node_kind


## True when the condition holds over the flag state `ctx`.
func evaluate(ctx: ConditionContext) -> bool:
	match kind:
		Kind.FLAG, Kind.ANY:
			return _any_flag(ctx)
		Kind.CATEGORY:
			return ctx.any_in_category(name)
		Kind.GROUP:
			return ctx.flag_in_group(name) == flags[0]
		Kind.NOT:
			return not children[0].evaluate(ctx)
		Kind.AND:
			return _all_children(ctx)
		Kind.OR:
			return _any_child(ctx)
	return false


func _any_flag(ctx: ConditionContext) -> bool:
	for id: String in flags:
		if ctx.has_flag(id):
			return true
	return false


func _all_children(ctx: ConditionContext) -> bool:
	for child: Condition in children:
		if not child.evaluate(ctx):
			return false
	return true


func _any_child(ctx: ConditionContext) -> bool:
	for child: Condition in children:
		if child.evaluate(ctx):
			return true
	return false
