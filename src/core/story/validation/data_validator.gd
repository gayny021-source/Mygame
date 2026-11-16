class_name DataValidator
extends RefCounted
## Runs every graph check of the story data over one hero (ADR-0001 §4, §6; branching-story.md, Core Rules 14;
## story S5): the structure of S4 (GraphValidator: BS-02…BS-06, BS-09, BS-10) and the meaning checks —
## traces and flags (BsTraces), paths and budgets (BsBudget), screen limits and bridge punctuation (BsLimits),
## frames, titles and the goal pair (BsIds). BS-01 and DT-NN are the loaders'; BS-26 needs the released list
## and is ReleasedIds.diff. Pure: no files, no nodes.
##
## Usage: [code]var issues: Array[DataIssue] = DataValidator.validate(hero, ValidatorOptions.new())[/code]


## All findings for `hero`, errors and warnings together.
static func validate(hero: HeroData, options: ValidatorOptions) -> Array[DataIssue]:
	var issues: Array[DataIssue] = GraphValidator.validate(hero, options)
	var usage: FlagUsage = FlagUsage.new(hero)
	for chapter: ChapterData in hero.chapters:
		var graph: StoryGraph = StoryGraph.new(chapter)
		var paths: ChapterPaths = ChapterPaths.new(graph)
		BsTraces.check(hero, graph, usage, issues)
		BsBudget.check(hero, graph, paths, usage, options, issues)
		BsLimits.check(graph, usage, options, issues)
		BsIds.check(hero, graph, options, issues)
	BsTraces.check_hero(hero, usage, issues)
	BsIds.check_hero(hero, usage, options, issues)
	return issues
