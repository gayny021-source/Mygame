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


## Emitted when the Back button is pressed; later screens can connect to navigate.
signal back_requested

## Null until `_ready`; the screens of later stories take sessions from here.
var services: BootServices

@onready var _status: Label = %Status


func _ready() -> void:
	var save: SaveNode = get_node_or_null("/root/SaveService") as SaveNode
	if save == null or save.writer == null:
		_status.text = "Сохранение недоступно"
		push_error("RT-02 автозагрузка SaveService не найдена: сервисы не собраны")
		return
	services = BootServices.build(save.writer, _log)
	_status.text = services.status


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()
		_quit()


func _quit() -> void:
	var save: SaveNode = get_node_or_null("/root/SaveService") as SaveNode
	if save != null:
		save.flush()
	get_tree().quit()


func _log(line: String) -> void:
	push_warning(line)
