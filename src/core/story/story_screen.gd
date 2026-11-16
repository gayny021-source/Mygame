class_name StoryScreen
extends RefCounted
## One screen of the story as StoryNavigator computed it (branching-story.md, rules 3-8; story S6).
## A value: the UI draws it, nothing in it is recomputed later.

enum Kind { SCENE, OUTCOME, CODA, ENDING, ERROR }

var kind: Kind
## SCENE: the scene (illustration, options in author order). OUTCOME, CODA: the scene left.
var scene: SceneData
## Title of the chapter over the first paragraph; set only when the scene was entered by a start.
var chapter_title: String
## Joined bridge of the entry transition; empty when none.
var bridge: String
## Paragraphs already filtered by the flags, in data order.
var paragraphs: Array[ParagraphData] = []
## OUTCOME: the outcome shown.
var outcome: OutcomeData
## OUTCOME: the option owning the outcome (context line of UR-3).
var option: OptionData
## OUTCOME: the chosen route, or null. CODA: the chapter_end transition. ENDING: `to_id` is the ending.
var transition: TransitionData


func _init(screen_kind: Kind) -> void:
	kind = screen_kind
