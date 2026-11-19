class_name RollHost
extends Control
## Hosts the Roll screen over the Reading screen (roll-screen.md, Lifecycle: entry and exit). A risky card
## accepted by the core ends in `check_requested`; this node opens the Roll screen, and its `exited` goes
## back: the choice again (cancelled), the outcome page (continued) or the flow-error page (closed without
## an outcome). It owns no game state.
##
## Usage: [code]host = RollHost.new(); add_child(host); host.setup(reading_screen, session)[/code]

const SCENE: PackedScene = preload("res://src/ui/roll/roll_screen.tscn")

var _reading: ReadingScreen
var _session: RunSession
## The Roll screen on show, null when none.
var roll_screen: RollScreen


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Binds the host to one reading screen and its session.
func setup(reading: ReadingScreen, session: RunSession) -> void:
	_reading = reading
	_session = session
	_reading.check_requested.connect(_open)
	_session.loaded.connect(_on_loaded)


func _open(_option: OptionData) -> void:
	if roll_screen != null:
		return
	roll_screen = SCENE.instantiate() as RollScreen
	roll_screen.theme = _reading.theme
	add_child(roll_screen)
	roll_screen.setup(_session)
	roll_screen.exited.connect(_on_exited)
	roll_screen.open()


# A roll saved before the process died: the Roll screen shows it at once (roll-screen.md, Lifecycle).
func _on_loaded(code: SaveWriter.LoadCode, _page: StoryScreen) -> void:
	if code == SaveWriter.LoadCode.OK and _session.has_restored_turn():
		_open(null)


func _on_exited(kind: int, page: StoryScreen) -> void:
	roll_screen.queue_free()
	roll_screen = null
	if kind == RollScreen.Exit.CONTINUED:
		_reading.show_page(page)
	else:
		_reading.refresh()
