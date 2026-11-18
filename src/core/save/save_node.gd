class_name SaveNode
extends Node
## The one Node of the save layer (ADR-0002 §1; story SV4): the only place with the real clock and
## `_process`. Pause and return notifications write nothing (AC-22). Without an injected `writer`,
## `_ready` builds one over ThreadSaveIo with `wait_ms` of save.json.

## Highest format_version this build reads (ADR-0002 §2).
const FORMAT_VERSION: int = 1

var writer: SaveWriter


func _ready() -> void:
	if writer != null:
		return
	var issues: Array[DataIssue] = []
	var config: SaveConfig = SaveConfig.load_file(SaveConfig.PATH, issues)
	for issue: DataIssue in issues:
		_log("%s %s: %s" % [issue.code, issue.path, issue.message])
	writer = SaveWriter.new(ThreadSaveIo.new(), FORMAT_VERSION, _log, config.wait_ms)


func _process(_delta: float) -> void:
	writer.pump(Time.get_ticks_msec())


func _log(line: String) -> void:
	push_warning(line)
