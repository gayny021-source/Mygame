extends Control
## Boot screen: shows the game title. Entry point (`run/main_scene`) until real menus exist.
##
## The Android Back button must not quit the game (`application/config/quit_on_go_back`
## is false); it arrives here as NOTIFICATION_WM_GO_BACK_REQUEST (1007). The boot screen
## is the root screen with nothing to lose, so Back closes the game here
## (design/accessibility-requirements.md, M12: Back closes or returns without side effects).


## Emitted when the Back button is pressed; later screens can connect to navigate.
signal back_requested


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()
		get_tree().quit()
