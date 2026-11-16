class_name GraphValidator
extends RefCounted
## Runs the structural checks over every chapter of a hero (ADR-0001, Key Interfaces; story S4).
## Pure: no files, no nodes. Meaning checks (traces, budgets, rhythm) and released ids are story S5.
##
## Usage: [code]var issues: Array[DataIssue] = GraphValidator.validate(hero, ValidatorOptions.new())[/code]


## All findings of BS-02…BS-06, BS-09 and BS-10 for the chapters of `hero`; errors and warnings together.
## Repeated ids are BS-01 of the loaders, which give no HeroData then: `hero` is trusted to have unique ids.
## A chapter with a loop (BS-05) gets a BS-10 warning instead of the shape check: its spine is undefined.
static func validate(hero: HeroData, options: ValidatorOptions) -> Array[DataIssue]:
	var issues: Array[DataIssue] = []
	for chapter: ChapterData in hero.chapters:
		var graph: StoryGraph = StoryGraph.new(chapter)
		BsStructure.check(hero, graph, options, issues)
		if graph.back_edges().is_empty():
			BsShape.check(hero, graph, options, issues)
		else:
			report(issues, "BS-10", chapter.id, chapter.id, "форма главы не проверена: в графе цикл (BS-05)", DataIssue.WARNING)
	return issues


## Appends one finding; `path` is `<chapter>/<kind>/<id>`.
static func report(issues: Array[DataIssue], code: String, path: String, object_id: String, message: String, severity: String = DataIssue.ERROR) -> void:
	var issue: DataIssue = DataIssue.new(code, path, object_id, message)
	issue.severity = severity
	issues.append(issue)
