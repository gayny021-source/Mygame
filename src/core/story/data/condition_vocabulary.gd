class_name ConditionVocabulary
extends RefCounted
## Names a condition may refer to: the hero's declared flags, categories and groups
## (ADR-0001 §5). ConditionParser reports any other name as BS-01.

var flags: PackedStringArray = []
var categories: PackedStringArray = []
var groups: PackedStringArray = []
