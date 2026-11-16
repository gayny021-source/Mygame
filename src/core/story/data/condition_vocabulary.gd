class_name ConditionVocabulary
extends RefCounted
## Names a condition may refer to: the hero's declared flags, categories and groups
## (ADR-0001 §5). ConditionParser reports any other name as BS-01.

## Ids of the declared flags.
var flags: PackedStringArray = []
## Ids of the declared flag categories, for `cat(...)`.
var categories: PackedStringArray = []
## Ids of the declared displacement groups, for `group(...) ==`.
var groups: PackedStringArray = []
## Flag id -> id of its group; a flag in no group is absent. For `group(...) == flag`.
var flag_groups: Dictionary[String, String] = {}
