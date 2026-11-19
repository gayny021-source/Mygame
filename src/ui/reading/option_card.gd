class_name OptionCard
extends TapPanel
## One option card: `[reason] text` over the caption the core prepared (reading-screen.md, Component
## Inventory). It draws `OptionView` and nothing else: state differences are the frame (open: card,
## chosen: inverted, the rest: flat) plus the caption text, not colour alone.

const MIN_HEIGHT: float = 168.0

var view: OptionView

var _text: Label
var _caption: Label


func _init() -> void:
	super()
	custom_minimum_size.y = MIN_HEIGHT
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_text = _label(&"Label")
	_caption = _label(&"CaptionLabel")
	column.add_child(_text)
	column.add_child(_caption)


## Draws `option_view`; cheap, so the screen calls it again when only the state changed.
func bind(option_view: OptionView) -> void:
	view = option_view
	var tag: String = "[%s] " % view.option.reason if not view.option.reason.is_empty() else ""
	_text.text = tag + view.option.text
	_caption.text = view.caption
	_restyle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and view != null:
		_restyle()


func _on_down_changed(_is_pressed: bool) -> void:
	_restyle()


func _label(variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _restyle() -> void:
	var item: StringName = &"disabled"
	if view.state == OptionView.State.OPEN:
		item = &"pressed" if is_down() else &"normal"
	elif view.state == OptionView.State.CHOSEN:
		item = &"pressed"
	add_theme_stylebox_override(&"panel", get_theme_stylebox(item, &"Button"))
