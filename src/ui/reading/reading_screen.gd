class_name ReadingScreen
extends Control
## The Reading screen (design/ux/reading-screen.md; story SCR1): draws the StoryScreen of a RunSession
## and passes every touch back to it. It computes nothing: option states, captions, the "stake read"
## latch and the guards belong to the core; the screen reports only that the last stake line is in view.
## The flow is rebuilt only for a new StoryScreen (`show_page`) or a theme/size change (`rebuild`).
## The Roll screen is another story: a risky card ends in `check_requested`.
##
## Usage: [code]screen.setup(session, hero); screen.resume()[/code]

## A risky card was accepted by the core (choose_check); the Roll screen takes over from here.
signal check_requested(option: OptionData)
## «В меню» of the fallback, ending and error pages.
signal menu_requested()

## Guard window after every change of page: touches are dropped, not queued (БС:950).
const GUARD_MS: int = 300
## Height of the hint strip at 100 % text (≈55 px; x2 at 200 %).
const BAND_PX: float = 55.0
const FADE_S: float = 0.12
const BASE_FONT: float = 48.0
const SPACING: int = 24
const FRAME_HEIGHT: float = 656.0
const INK := Color(0.09019608, 0.07843137, 0.05882353)
const ACCENTS: Dictionary[String, Color] = {"carmine": Color(0.58, 0.1, 0.16)}

## Time source in ms; a test replaces it.
var clock: Callable = Time.get_ticks_msec
## «Меньше анимации»: the page appears at once.
var reduce_motion: bool = false

var _session: RunSession
var _hero: HeroData
var _page: StoryScreen
var _pending: StoryScreen
var _guard_until: int
## True while this screen reports the outcome text to the core (see `_on_goal_changed`).
var _reporting: bool
var _stake_label: RichTextLabel
var _cards: Array[OptionCard] = []
var _tween: Tween
var _error: VBoxContainer
var _error_buttons: Array[Button] = []
## Height of the hint line, measured once per build (shaping the text on every scroll tick is waste).
var _hint_h: float = 0.0

@onready var _goal: TapPanel = %Goal
@onready var _accent: ColorRect = %Accent
@onready var _dots: HBoxContainer = %Dots
@onready var _goal_label: Label = %GoalLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _flow: VBoxContainer = %Flow
@onready var _fade: TextureRect = %Fade
@onready var _hint: PanelContainer = %Hint
@onready var _hint_label: Label = %HintLabel
@onready var _sheet_layer: Control = %SheetLayer
@onready var _scrim: ColorRect = %Scrim
@onready var _sheet_body: VBoxContainer = %SheetBody
@onready var _close: Button = %Close
@onready var _sheet: PanelContainer = %Sheet


func _ready() -> void:
	_goal.tapped.connect(goal_tapped)
	_goal.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"disabled", &"Button"))
	# the theme has no PanelContainer style: the engine default is a dark slab
	_hint.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"disabled", &"Button"))
	_sheet.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"normal", &"Button"))
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = tr("Дочитайте до конца")
	_close.text = tr("Закрыть")
	_close.pressed.connect(close_panel)
	_scrim.gui_input.connect(_on_scrim_input)
	# layout settles after the page is built and after a size change: look again then, not per frame
	_scroll.resized.connect(_on_scroll_resized)
	_flow.sort_children.connect(_check_stake)
	_scroll.get_v_scroll_bar().changed.connect(_check_stake)
	# a scroll moves the children after the value changes: look again once they have moved
	_scroll.sort_children.connect(_check_stake)
	_sheet_layer.visible = false
	_hint.visible = false
	_fade.visible = false


func _enter_tree() -> void:
	_connect()


func _exit_tree() -> void:
	_kill_tween()
	_disconnect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		# scroll, panel and the like live in memory only; the core latch stays (reading-screen.md, Lifecycle)
		close_panel()


## Binds the screen to one run; the hero gives the goal chain and the hero card.
func setup(session: RunSession, hero: HeroData) -> void:
	_disconnect()
	_session = session
	_hero = hero
	_connect()


## A new run from chapter 1.
func start() -> void:
	_present(_session.start_new())


## Continues the saved run; an empty slot starts a new one (see `on_loaded`).
func resume() -> void:
	if _session.load_saved() == 0:
		push_warning("SCR1 загрузка не поставлена в очередь: экран не открыт")


## Draws `page`: new flow, scroll at the top, panel closed, guard window running.
func show_page(page: StoryScreen) -> void:
	_page = page
	_pending = null
	_hint.visible = false
	_sheet_layer.visible = false
	_guard_until = _now() + GUARD_MS
	_build()
	_scroll.scroll_vertical = 0


## The same page again from the same model (theme or size changed); the latch is the core's.
func rebuild() -> void:
	if _page != null:
		_build()


## `loaded` of the session: OK builds a screen. On the flow-error screen any other answer (an empty slot too)
## is a failed load: the slot stays, the buttons come back. Elsewhere an empty slot starts a run; the rest is
## the business of the save-error spec (Q8).
func on_loaded(code: SaveWriter.LoadCode, page: StoryScreen) -> void:
	if code == SaveWriter.LoadCode.OK and page != null:
		show_page(page)
	elif _error != null:
		_load_failed()
	elif code == SaveWriter.LoadCode.EMPTY:
		start()


## The last stake line is in view: the core raises the latch, the cards open.
func stake_seen() -> void:
	if _page == null or _page.kind != StoryScreen.Kind.SCENE or _session.stake_read():
		return
	_session.report_stake_visible(_page.scene.id)
	_fade.visible = false
	_hint.visible = false
	_refresh_cards()


func card_tapped(card: OptionCard) -> void:
	if _blocked():
		return
	if card.view.state == OptionView.State.INACTIVE:
		_hint.visible = true
	elif card.view.state == OptionView.State.OPEN:
		_choose(card.view.option)


func next_pressed() -> void:
	if _blocked():
		return
	_present(_session.advance())


func goal_tapped() -> void:
	if _blocked():
		return
	_fill_sheet()
	_sheet_layer.visible = true


func close_panel() -> void:
	_sheet_layer.visible = false


## System Back: swallowed in the guard window; on the flow-error screen it is «В меню», otherwise it closes
## only the panel (the game stays; an ending, error or fallback page too, until the menu story exists).
func go_back() -> void:
	if _now() < _guard_until:
		return
	if _error != null:
		_error_menu()
		return
	close_panel()


## The session changed outside a touch of this screen (the Roll screen closed after a flow error):
## the cards take the new states and a flow error gets its screen.
func refresh() -> void:
	_refresh_cards()
	_show_flow_error()


func panel_open() -> bool:
	return _sheet_layer.visible


# ---- test-only (TD G4: no new getters; migrate tests to child nodes and signals when touched) ----

## Viewport height the goal-zone collapse looks at; 0 = the real viewport (a test sets it).
var collapse_height: float = 0.0



func hint_visible() -> bool:
	return _hint.visible


func goal_visible() -> bool:
	return _goal.visible


func next_visible() -> bool:
	return _flow.find_child("Next", false, false) != null


func cards() -> Array[OptionCard]:
	return _cards


func guard_until() -> int:
	return _guard_until


## -1 before the first page.
func page_kind() -> int:
	return _page.kind if _page != null else -1


func scene_id() -> String:
	return _page.scene.id if _page != null and _page.scene != null else ""


func flow_mouse_filter() -> int:
	if _stake_label == null:
		return -1
	return _stake_label.mouse_filter


func accent_mouse_filter() -> int:
	return _accent.mouse_filter


func hint_mouse_filter() -> int:
	return _hint.mouse_filter


func tween_running() -> bool:
	return _tween != null and _tween.is_valid()


# ---- end of test-only ----


## Height of the bottom band: the strip (≈55 px at 100 %, scaled) plus the hint line; it carries the fade
## and the hint, and the latch looks only above it (TD U1).
static func band(text_scale: float, hint_height: float) -> float:
	return BAND_PX * text_scale + hint_height


## CEO Q2: at 200 % on 1080×1920 the goal zone shrinks to one row of dots, the caption goes to the panel.
## shortcut: the rule is by size, not by a measured bridge line count; replace after a device measure.
static func collapse_goal(text_scale: float, viewport_height: float) -> bool:
	return text_scale >= 2.0 and viewport_height <= 1920.0


## True when a line ends below the top of the view and above the free bottom (view minus the band).
static func line_in_view(line_bottom: float, view_top: float, free_bottom: float) -> bool:
	return line_bottom >= view_top and line_bottom <= free_bottom


func _now() -> int:
	return clock.call()


func _blocked() -> bool:
	return panel_open() or _now() < _guard_until or _session.waiting()


func _scale() -> float:
	return get_theme_default_font_size() / BASE_FONT


func _present(page: StoryScreen) -> void:
	if page == null:
		return
	if _session.waiting():
		_pending = page
	else:
		show_page(page)


func _connect() -> void:
	if _session == null or _session.show_released.is_connected(_on_released):
		return
	_session.show_released.connect(_on_released)
	_session.loaded.connect(on_loaded)
	_session.goal_changed.connect(_on_goal_changed)


# The goal zone follows the «outcome text shown» event of this screen only: other changes of the view
# wait for the page they belong to (chapter-goal.md, rule 5: the model sees the old value until the move ends).
func _on_goal_changed() -> void:
	if _reporting and _page != null:
		_fill_goal()


func _disconnect() -> void:
	if _session == null or not _session.show_released.is_connected(_on_released):
		return
	_session.show_released.disconnect(_on_released)
	_session.loaded.disconnect(on_loaded)
	_session.goal_changed.disconnect(_on_goal_changed)


# Measured from the font, not read from the node: a hidden autowrapped label keeps a column-of-words size.
func _hint_height() -> float:
	var font: Font = _hint_label.get_theme_font(&"font")
	var font_size: int = _hint_label.get_theme_font_size(&"font_size")
	var margins: Vector2 = _hint.get_theme_stylebox(&"panel").get_minimum_size()
	var column: float = _scroll.size.x if _scroll.size.x > 0.0 else get_viewport().get_visible_rect().size.x
	var width: float = maxf(column - margins.x, 1.0)
	var text_height: float = font.get_multiline_string_size(_hint_label.text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y
	return text_height + margins.y


func _band() -> float:
	return band(_scale(), _hint_h)


func _on_released() -> void:
	if _pending != null:
		show_page(_pending)


func _choose(option: OptionData) -> void:
	if option.check != null:
		# shortcut (TD C5): a second tap after check_requested is ignored by the core guard; the Roll story
		# decides whether this screen offers a way back
		if _session.choose_check(option):
			check_requested.emit(option)
		return
	var page: StoryScreen = _session.apply_plain(option)
	_refresh_cards()
	_present(page)
	_show_flow_error()


func _refresh_cards() -> void:
	var views: Array[OptionView] = _session.option_views()
	for index: int in mini(views.size(), _cards.size()):
		_cards[index].bind(views[index])


func _on_scrim_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		close_panel()


func _on_scroll_resized() -> void:
	_hint_h = _hint_height()


func _check_stake() -> void:
	if _stake_label == null or _session.stake_read():
		return
	var top: float = _scroll.global_position.y
	var free_bottom: float = top + _scroll.size.y - _band()
	var line_bottom: float = _stake_label.global_position.y + _stake_label.size.y
	if line_in_view(line_bottom, top, free_bottom):
		stake_seen()


func _build() -> void:
	_kill_tween()
	_cards = []
	_stake_label = null
	_clear_error()
	_hint_h = _hint_height()
	for child: Node in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	match _page.kind:
		StoryScreen.Kind.SCENE:
			if _session.flow_error():
				_build_flow_error()
			else:
				_build_scene()
		StoryScreen.Kind.OUTCOME:
			_build_outcome()
		StoryScreen.Kind.CODA:
			_add_paragraphs(_page.transition.coda)
			_add_button("Next", tr("Дальше"), next_pressed)
		StoryScreen.Kind.ENDING:
			_add_note(tr("Конец главы"))
		_:
			_add_note(tr("Экран недоступен"))
	_flow.add_child(_spacer(_band() + BAND_PX * _scale()))
	_fill_goal()
	_fade.custom_minimum_size.y = _band()
	_fade.visible = _page.kind == StoryScreen.Kind.SCENE and not _session.stake_read() and _error == null
	_appear()
	_check_stake.call_deferred()
	if _page.kind == StoryScreen.Kind.OUTCOME:
		_reporting = true
		_session.report_outcome_text_shown()
		_reporting = false


func _build_scene() -> void:
	if not _page.chapter_title.is_empty():
		var title: Label = Label.new()
		title.theme_type_variation = &"TitleLabel"
		title.text = _page.chapter_title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_flow.add_child(title)
	_flow.add_child(_frame())
	if not _page.bridge.is_empty():
		_stake_label = _paragraph(_page.bridge)
	for paragraph: ParagraphData in _page.paragraphs:
		_stake_label = _paragraph(paragraph.text)
	if _session.no_open_options():
		_add_note(tr("Открытых вариантов нет."))
		return
	for view: OptionView in _session.option_views():
		var card: OptionCard = OptionCard.new()
		_flow.add_child(card)
		card.bind(view)
		card.tapped.connect(card_tapped.bind(card))
		_cards.append(card)
	if _stake_label == null:
		# no bridge and no paragraph: there is no stake line to read, the cards open at once (TD C3)
		stake_seen()


# The screen after a refused outcome (СВ Э-23): it replaces the scroll, buttons pinned to the bottom of
# the Safe Area column; the title and the line are above them. «Загрузить» reloads the last save.
func _build_flow_error() -> void:
	_scroll.visible = false
	_hint.visible = false
	_error = VBoxContainer.new()
	_error.name = "FlowError"
	_error.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_error.add_theme_constant_override(&"separation", int(maxf(SPACING * _scale(), SPACING)))
	_scroll.get_parent().add_child(_error)
	var title: Label = Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.text = tr("Не удалось продолжить")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_child(title)
	var note: Label = Label.new()
	note.name = "Note"
	note.text = tr("Заглушка, текст пишет writer: ход не продолжился.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_child(note)
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_error.add_child(fill)
	_error_buttons = [_error_button("Load", tr("Загрузить"), _error_load), _error_button("Menu", tr("В меню"), _error_menu)]
	_error_buttons[0].grab_focus.call_deferred()


func _error_button(node_name: String, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(OptionCard.MIN_HEIGHT, OptionCard.MIN_HEIGHT)
	button.pressed.connect(action)
	_error.add_child(button)
	return button


# A flow error that appeared on the page on show: the page is drawn again, as the error screen.
func _show_flow_error() -> void:
	if _session.flow_error() and _error == null and _page != null and _page.kind == StoryScreen.Kind.SCENE:
		show_page(_page)


func _clear_error() -> void:
	_scroll.visible = true
	_error_buttons = []
	if _error == null:
		return
	_error.get_parent().remove_child(_error)
	_error.queue_free()
	_error = null


func _set_error_buttons(disabled: bool) -> void:
	for button: Button in _error_buttons:
		button.disabled = disabled


# The first accepted touch switches both buttons off (reading-screen.md, Interaction Map).
func _error_load() -> void:
	if _blocked() or _error_buttons[0].disabled:
		return
	_set_error_buttons(true)
	if _session.load_saved() == 0:
		_load_failed()


# «В меню» and Back do not switch the buttons off: the menu does not exist yet, so nothing leaves the screen.
func _error_menu() -> void:
	if _blocked():
		return
	_say(tr("Меню появится позже. (текст пишет writer)"))
	menu_requested.emit()


func _load_failed() -> void:
	_set_error_buttons(false)
	_say(tr("Не удалось загрузить сохранение. (текст пишет writer)"))


# One short message line under the explanation; the next one replaces it.
func _say(text: String) -> void:
	var line: Label = _error.find_child("Message", false, false) as Label
	if line == null:
		line = Label.new()
		line.name = "Message"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_error.add_child(line)
		_error.move_child(line, 2)
	line.text = text


func _build_outcome() -> void:
	_flow.add_child(_frame())
	var context: Label = Label.new()
	context.theme_type_variation = &"CaptionLabel"
	context.text = _page.option.text if _page.option != null else ""
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flow.add_child(context)
	_add_paragraphs(_page.outcome.paragraphs)
	_add_button("Next", tr("Дальше"), next_pressed)


func _add_note(text: String) -> void:
	var note: Label = Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flow.add_child(note)
	_add_menu_button()


func _add_menu_button() -> void:
	_add_button("Menu", tr("В меню"), _menu_pressed)


func _menu_pressed() -> void:
	if not _blocked():
		menu_requested.emit()


func _add_paragraphs(list: Array[ParagraphData]) -> void:
	for paragraph: ParagraphData in list:
		_paragraph(paragraph.text)


func _paragraph(text: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.text = text
	_flow.add_child(label)
	return label


# shortcut: no illustration assets yet, so every frame is the fallback one (empty frame, no touch);
# replace with the real frame and the full-screen view when «Иллюстрации сцен» is built.
func _frame() -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size.y = FRAME_HEIGHT
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"disabled", &"Button"))
	return frame


func _add_button(node_name: String, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = OptionCard.MIN_HEIGHT
	button.pressed.connect(action)
	_flow.add_child(button)


func _spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _chapter() -> ChapterData:
	if _page == null or _page.scene == null:
		return null
	for chapter: ChapterData in _hero.chapters:
		if chapter.scenes.has(_page.scene):
			return chapter
	return null


func _fill_goal() -> void:
	var chapter: ChapterData = _chapter()
	var shown: bool = chapter != null and _page.kind in [StoryScreen.Kind.SCENE, StoryScreen.Kind.OUTCOME]
	_goal.visible = shown
	_accent.color = ACCENTS.get(_hero.accent, ACCENTS["carmine"])
	if not shown:
		return
	var height: float = collapse_height if collapse_height > 0.0 else get_viewport().get_visible_rect().size.y
	_goal_label.visible = not collapse_goal(_scale(), height)
	var view: GoalView = _session.goal_view()
	_goal_label.text = _caption_text(view)
	for dot: Node in _dots.get_children():
		_dots.remove_child(dot)
		dot.queue_free()
	var finished: bool = view.mode in [GoalView.Mode.DONE_OK, GoalView.Mode.DONE_FAILED]
	for number: int in range(1, view.milestones_total + 1):
		var current: bool = number == view.position and not (finished and view.position == view.milestones_total)
		_dots.add_child(_dot(number <= view.position, current))


func _caption_text(view: GoalView) -> String:
	match view.caption:
		GoalView.Caption.GOAL:
			return tr("Цель: %s") % view.caption_text
		GoalView.Caption.FAILED:
			return tr("Цель провалена: %s") % view.caption_text
		GoalView.Caption.FULFILLED:
			return tr("Цель исполнена: %s") % view.caption_text
		GoalView.Caption.STEP:
			return view.caption_text
	return ""


func _dot(done: bool, current: bool) -> Panel:
	var dot: Panel = Panel.new()
	dot.custom_minimum_size = Vector2(36, 36) * _scale()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(32)
	style.set_border_width_all(10 if current else 4)
	style.border_color = INK
	style.bg_color = INK if done else Color(0, 0, 0, 0)
	dot.add_theme_stylebox_override(&"panel", style)
	return dot


func _fill_sheet() -> void:
	for child: Node in _sheet_body.get_children():
		_sheet_body.remove_child(child)
		child.queue_free()
	var chapter: ChapterData = _chapter()
	var view: GoalView = _session.goal_view()
	if view.mode in [GoalView.Mode.FROZEN, GoalView.Mode.DONE_OK, GoalView.Mode.DONE_FAILED]:
		_sheet_line(_caption_text(view), &"Label")
	_sheet_line(tr("Цель главы"), &"CaptionLabel")
	if not view.goal.is_empty():
		_sheet_line(view.goal, &"Label")
	# shortcut: heroes.md gives no display name yet; the id stands in for it
	_sheet_line(_hero.id, &"TitleLabel")
	for stat: StatData in _hero.stats:
		_sheet_line("%s %s" % [stat.name, _signed(stat.bonus)], &"Label")
	for decl: FlagDecl in _session.visible_flags():
		_sheet_line(decl.title, &"CaptionLabel")


func _sheet_line(text: String, variation: StringName) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_body.add_child(label)


static func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else "%s%d" % [CaptionTexts.MINUS, -value]


func _appear() -> void:
	_flow.modulate.a = 1.0
	if reduce_motion or not is_inside_tree():
		return
	_flow.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_flow, "modulate:a", 1.0, FADE_S)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if is_node_ready():
		_flow.modulate.a = 1.0
