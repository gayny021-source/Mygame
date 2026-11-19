class_name RollHost
extends Control
## Hosts the Roll screen over the Reading screen (roll-screen.md, Lifecycle: entry and exit). A risky card
## accepted by the core ends in `check_requested`; this node opens the Roll screen, and its `exited` goes
## back: the choice again (cancelled), the outcome page (continued) or the flow-error page (closed without
## an outcome). It owns no game state.
##
## Usage: [code]host = RollHost.new(); add_child(host); host.setup(reading_screen, session)[/code]

var _reading: ReadingScreen
var _session: RunSession
var _roll: RollScreen


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Binds the host to one reading screen and its session.
func setup(reading: ReadingScreen, session: RunSession) -> void:
	_reading = reading
	_session = session
	_reading.check_requested.connect(_open)


## The Roll screen on show, null when none.
func roll_screen() -> RollScreen:
	return _roll


func _open(_option: OptionData) -> void:
	if _roll != null:
		return
	_roll = (load("res://src/ui/roll/roll_screen.tscn") as PackedScene).instantiate() as RollScreen
	_roll.theme = _reading.theme
	add_child(_roll)
	_roll.setup(_session)
	_roll.exited.connect(_on_exited)
	_roll.open()


func _on_exited(kind: int, page: StoryScreen) -> void:
	_roll.queue_free()
	_roll = null
	if kind == RollScreen.Exit.CONTINUED:
		_reading.show_page(page)
	else:
		_reading.refresh()
