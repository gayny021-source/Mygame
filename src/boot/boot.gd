extends Control
## Launch root (`run/main_scene`; story RT1). Builds the services (BootServices: d20 and caption
## configs, heroes, one RunSession per hero over the SaveService writer) and shows a plain state
## while there is no screen to open: the title, plus the reason in `Status` when something is missing.
## Any failed load only logs and shows text; boot never crashes.
##
## The Android Back button must not quit the game (`application/config/quit_on_go_back`
## is false); it arrives here as NOTIFICATION_WM_GO_BACK_REQUEST (1007). The boot screen
## is the root screen with nothing to lose, so Back closes the game here
## (design/accessibility-requirements.md, M12: Back closes or returns without side effects).


## Null until `_ready`; the screens of later stories take sessions from here.
var services: BootServices
## Text scale of the theme: 1.0 = 100 %, 2.0 = 200 % (reading-screen.md; later a setting).
@export_range(1.0, 2.0) var text_scale: float = 1.0

var _started: bool = false
var _screen: ReadingScreen
var _quitting: bool = false

@onready var _title: Label = %Title
@onready var _status: Label = %Status


func _ready() -> void:
	if _started:
		return
	_started = true
	_title.text = tr("Критический провал")
	theme = ThemeScale.scaled(theme, text_scale)
	var save: SaveNode = get_node_or_null("/root/SaveService") as SaveNode
	if save == null:
		# the service is missing at start, not a failed write: rule 13 keeps write failures from the player
		_status.text = tr("Сохранение недоступно")
		push_error("RT-02 автозагрузка SaveService не найдена: сервисы не собраны")
		return
	services = BootServices.build(save.writer, _log)
	_status.text = services.status
	if not services.sessions.is_empty():
		_open_reading(services.sessions.keys()[0])


func _notification(what: int) -> void:
	# the reading screen owns Back once it is shown (reading-screen.md: Back never quits there)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _screen == null:
		_quit()


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	var save: SaveNode = get_node_or_null("/root/SaveService") as SaveNode
	if save != null:
		save.flush(save.pause_flush_ms)
	get_tree().quit()


func _log(line: String) -> void:
	push_warning(line)


# shortcut: the first hero by id; a hero choice screen comes with the menu story.
func _open_reading(hero_id: String) -> void:
	_screen = (load("res://src/ui/reading/reading_screen.tscn") as PackedScene).instantiate() as ReadingScreen
	add_child(_screen)
	_screen.theme = theme
	_screen.setup(services.sessions[hero_id], services.heroes[hero_id])
	_screen.menu_requested.connect(on_menu_requested)
	_screen.resume()
	$Safe.visible = false


## «В меню» of the reading screen. No menu screen exists yet, so nothing happens and the save is not
## touched (reading-screen.md, Interaction Map: the save stays); the screen stays where it is.
## shortcut: a log line only, until the «Меню и пауза» story.
func on_menu_requested() -> void:
	push_warning("SCR1 «В меню»: меню-экрана ещё нет, ничего не происходит")
