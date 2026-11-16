class_name FlagDecl
extends RefCounted
## Declaration of one flag from flags.json (ADR-0001 §1; run-state.md, Core Rules 1).

const CATEGORIES: PackedStringArray = ["wound", "item", "reputation", "debt", "companion", "price", "story"]
const SCOPE_RUN := "run"
const SCOPE_CHAPTER := "chapter"
const SCOPES: PackedStringArray = [SCOPE_RUN, SCOPE_CHAPTER]

var id: String
var category: String
var title: String
var scope: String = SCOPE_RUN
## Displacement group; empty when the flag is in none.
var group: String
var visible: bool
var exception: String
var deprecated: bool
## Ids of the hero stats the flag closes while it stands.
var blocks: PackedStringArray
