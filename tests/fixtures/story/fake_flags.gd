class_name FakeFlags
extends ConditionContext
## Hand-set flag state for condition tests (ADR-0001 §5); stands in for RunState.

## Flags that are set.
var flags: PackedStringArray = []
## Categories that have at least one flag set.
var categories: PackedStringArray = []
## Group id -> id of the flag standing in it.
var groups: Dictionary = {}


func has_flag(id: String) -> bool:
	return flags.has(id)


func any_in_category(category: String) -> bool:
	return categories.has(category)


func flag_in_group(group: String) -> String:
	var standing: String = groups.get(group, "")
	return standing
