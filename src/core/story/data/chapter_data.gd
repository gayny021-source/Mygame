class_name ChapterData
extends RefCounted
## One chapter (ADR-0001 §1; branching-story.md, Core Rules 2). Links between records are ids.

var id: String
var title: String
var goal: String
## Optional chapter stake (panel line «Ставка», chapter-goal.md); empty when the data has none.
var stake: String
var goal_fail_flag: String
var starts: Array[StartData] = []
var milestones: Array[MilestoneData] = []
var scenes: Array[SceneData] = []
var outcomes: Array[OutcomeData] = []
var transitions: Array[TransitionData] = []
