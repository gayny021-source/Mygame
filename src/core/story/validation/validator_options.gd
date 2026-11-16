class_name ValidatorOptions
extends RefCounted
## Limits of the graph checks (branching-story.md, Formulas F1, F4, F8; ADR-0001, Key Interfaces).
## The caller injects them. Defaults are the GDD values until the CLI of story S5 reads them
## from the external config (shortcut: defaults live here; replace when `tools/validate_data.gd` lands).

## F4: most options in a scene (BS-06).
var options_max: int = 4
## F8: finales open without conditions on flags, and finales open only through past flags (BS-10).
var finales_base: int = 3
var finales_past: int = 1
## F1: safe range of the scene count of a chapter; outside it BS-10 warns.
var s_chapter_min: int = 8
var s_chapter_max: int = 16
## F1: safe range of the node scene count.
var n_node_min: int = 4
var n_node_max: int = 7
## F1: most scenes in the side branch.
var branch_max: int = 2
