class_name GoalView
extends RefCounted
## View model of the chapter goal (chapter-goal.md, rule 1): a plain value, a pure function of its inputs
## (GoalRules.view). The Reading screen lays it out; the phrases «Цель: …» are the UI's (tr()).

enum Mode { NOT_STARTED, RUNNING, FROZEN, DONE_OK, DONE_FAILED }
## What the pinned caption says: nothing, «Цель: <text>», the step text, «Цель провалена: <text>»,
## «Цель исполнена: <text>».
enum Caption { NONE, GOAL, STEP, FAILED, FULFILLED }

var mode: Mode = Mode.NOT_STARTED
## V, the number of milestones; 0 when the chapter has none (Э-06: no chain).
var milestones_total: int
## P, 1..V; 0 when there is no chain.
var position: int
var caption: Caption = Caption.NONE
## The goal or the step, by `caption`; empty for NONE.
var caption_text: String
## The goal in force for the attempt; empty when undefined (Э-18, Э-21 г).
var goal: String
# shortcut: ChapterData has no stake field, so it stays empty; fill it when the data gets «ставка главы».
## The chapter stake (panel line «Ставка»).
var stake: String
