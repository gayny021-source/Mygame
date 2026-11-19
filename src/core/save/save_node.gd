class_name SaveNode
extends Node
## The one Node of the save layer (ADR-0002 §1; story SV4): the only place with the real clock and
## `_process`. Pause and return notifications write nothing (AC-22). Without an injected `writer`,
## `_ready` builds one over ThreadSaveIo with `wait_ms` of save.json.

## Highest format_version this build reads (ADR-0002 §2).
const FORMAT_VERSION: int = 1

var writer: SaveWriter
## Longest wait of `flush` in ms; save.json `wait_ms` (T_ожид) unless a test sets it.
var flush_ms: int = SaveConfig.DEFAULT_WAIT_MS


func _ready() -> void:
	if writer != null:
		return
	var issues: Array[DataIssue] = []
	var config: SaveConfig = SaveConfig.load_file(SaveConfig.PATH, issues)
	for issue: DataIssue in issues:
		_log("%s %s: %s" % [issue.code, issue.path, issue.message])
	flush_ms = config.wait_ms
	writer = SaveWriter.new(ThreadSaveIo.new(), FORMAT_VERSION, _log, config.wait_ms)


func _process(_delta: float) -> void:
	writer.pump(Time.get_ticks_msec())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


## Waits for the running and queued writes, at most `flush_ms` (DD-024). Polls `is_task_completed`
## through the writer instead of `wait_for_task_completion`, which has no timeout: a hung disk
## cannot freeze the main thread into an ANR. Starts no write (AC-22). False on timeout, with a log line.
func flush() -> bool:
	if writer == null:
		return true
	var started: int = Time.get_ticks_msec()
	writer.pump(started)
	while not writer.idle():
		var now: int = Time.get_ticks_msec()
		if now - started >= flush_ms:
			_log("save: flush не дождался записи за %d мс" % flush_ms)
			return false
		OS.delay_msec(1)
		writer.pump(Time.get_ticks_msec())
	return true


func _log(line: String) -> void:
	push_warning(line)
