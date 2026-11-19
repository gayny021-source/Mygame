class_name RollScreen
extends Control
## The Roll screen (design/ux/roll-screen.md; story SCR2): the stake of one risky check, the d20 tumble, the
## step-by-step result. It computes nothing: the face, total, crit and the write wait belong to RunSession
## (roll, waiting, show_released); this screen owns timing, guard windows, skip and layout.
## The face is known at «Бросить» but shown only when no write waits (СХР F3); the tumble starts at once.
##
## Usage: [code]screen.setup(session); screen.open()[/code] after `RunSession.choose_check` was true;
## `exited` says where to go next (the host shows the Reading screen again).

## kind: Exit.CANCELLED (back to the choice), CONTINUED (`page` is the outcome page), FLOW_ERROR (the
## check was closed without an outcome: the Reading screen shows «Не удалось продолжить» via `refresh`).
signal exited(kind: int, page: StoryScreen)
## «Бросить» was accepted (Events Fired: «Бросок начат»).
signal rolled(check_id: String)
## The digit of the die changed (a flicker or the final face).
signal face_changed(face: int)
## The die stands on the natural face.
signal die_landed(face: int)
## The verdict or cartouche frame: once per roll («Итог показан»).
signal result_shown(success: bool, crit: int)

enum Phase { CHOSEN, TUMBLING, WAITING, REVEALING, SHOWN, APPLYING, ERROR, CLOSED }
enum Exit { CANCELLED, CONTINUED, FLOW_ERROR }

const GUARD_MS: int = 300
## 13 face changes, 50 → 270 ms, sum 1600 (roll-screen.md, Transitions); built once.
const FLICKER_MS: Array[int] = [50, 50, 52, 58, 68, 82, 100, 122, 128, 160, 212, 248, 270]
const SPIN_S: float = 1.6
const WAIT_FLICKER_S: float = 0.27
const WAIT_END_S: float = 0.13
const STEP_S: float = 0.3
const VERDICT_S: float = 0.5
const CRIT_MS: int = 800
const CRIT_SHORT_MS: int = 500
const FRAME_FLASH_S: float = 0.3
const BASE_FONT: float = 48.0
const DIE_PX: float = 340.0
const DIE_PX_BIG: float = 280.0
const MINUS := "−"
const NBSP := " "
const TEX_UNKNOWN: Texture2D = preload("res://assets/art/roll/die_unknown.svg")
const TEX_TUMBLE: Texture2D = preload("res://assets/art/roll/die_tumble.svg")
const TEX_NEUTRAL: Texture2D = preload("res://assets/art/roll/die_neutral.svg")
const TEX_SUCCESS: Texture2D = preload("res://assets/art/roll/die_success.svg")
const TEX_FAILURE: Texture2D = preload("res://assets/art/roll/die_failure.svg")
const TEX_CRIT20: Texture2D = preload("res://assets/art/roll/die_crit20.svg")
const TEX_CRIT1: Texture2D = preload("res://assets/art/roll/die_crit1.svg")
const FONT_BOLD: Font = preload("res://assets/fonts/Literata-Bold.ttf")

## Time source in ms; a test replaces it.
var clock: Callable = Time.get_ticks_msec
## Face flicker source, injected (TD G5); it is not the d20 source. A test seeds it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Fade length of entry and exit; 0 = none.
var fade_s: float = 0.2
## «Меньше анимации» set by hand (a test, the future settings screen).
var reduce_motion: bool = false
## «Меньше анимации» from the system.
## shortcut: no Android API for «Удалить анимацию» in docs/engine-reference; the probe RS-D6 decides what
## replaces this default (always false) — until then only `reduce_motion` can switch the mode.
var reduce_motion_source: Callable = func() -> bool: return false

var _session: RunSession
var _brief: CheckBrief
var _result: D20Result
var _phase: Phase = Phase.CLOSED
var _reduced: bool
var _guard_until: int
var _skip_wanted: bool
var _landed: bool
var _announced: bool
var _page: StoryScreen
var _motion: Tween
var _arm: Tween
var _fade: Tween
var _flash: Tween
var _need_text: String

@onready var _back: Button = %Back
@onready var _reroll: Button = %Reroll
@onready var _action: Button = %Action
@onready var _slot: ScrollContainer = %Slot
@onready var _option_text: Label = %OptionText
@onready var _caption: Label = %Caption
@onready var _verdict: Label = %Verdict
@onready var _cartouche: PanelContainer = %Cartouche
@onready var _cartouche_label: Label = %CartoucheLabel
@onready var _calc: Label = %Calc
@onready var _bonus: Label = %Bonus
@onready var _need: Label = %NeedLabel
@onready var _die: Control = %Die
@onready var _die_art: TextureRect = %DieArt
@onready var _die_label: Label = %DieLabel
@onready var _spotlight: TextureRect = %Spotlight
@onready var _fade_rect: ColorRect = %Fade


func _ready() -> void:
	_back.text = tr("Передумать")
	_back.pressed.connect(cancel_pressed)
	_action.pressed.connect(_on_action)
	_reroll.disabled = true
	_reroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.modulate.a = 0.0
	_cartouche.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"normal", &"Button"))
	_option_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict.add_theme_font_override(&"font", FONT_BOLD)
	var digits: FontVariation = FontVariation.new()
	digits.base_font = get_theme_default_font()
	# shortcut: tabular digits (tnum) of Literata are not verified (RS-D4): check on a device
	digits.opentype_features = {"tnum": 1}
	_die_label.add_theme_font_override(&"font", digits)
	_die_label.add_theme_font_size_override(&"font_size", 120)
	_fade_rect.modulate.a = 0.0
	_apply_scale()


func _exit_tree() -> void:
	_kill_motion()
	_kill(_arm)
	_kill(_fade)
	_kill(_flash)
	_disconnect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_apply_scale()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_kill_motion()
		_kill(_arm)
	elif what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_resumed()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		skip()


## Binds the screen to one run.
func setup(session: RunSession) -> void:
	_disconnect()
	_session = session
	_session.show_released.connect(_on_released)


## Reads the open check (or the restored roll) and draws the first state.
func open() -> void:
	_kill_motion()
	_kill(_arm)
	_brief = _session.check_brief()
	if _brief == null:
		push_warning("SCR2 нет открытой проверки: экран не открыт")
		return
	_reduced = reduce_motion or bool(reduce_motion_source.call())
	_skip_wanted = false
	_landed = false
	_announced = false
	_start_guard()
	_fill_stake()
	if _session.has_restored_turn():
		_result = _session.restored_result()
		_show_full(CRIT_SHORT_MS)
		return
	_phase = Phase.CHOSEN
	_fade_in()


## «Бросить»: the core rolls and commits; the tumble starts at once.
func roll_pressed() -> void:
	if _phase != Phase.CHOSEN or _blocked():
		return
	var result: D20Result = _session.roll()
	if result == null:
		push_warning("SCR2 бросок не принят ядром: остаёмся в «Выбрана»")
		return
	_result = result
	_phase = Phase.TUMBLING
	_start_guard()
	_hide_slot(_back)
	_hide_slot(_action)
	rolled.emit(_brief.check_id)
	if _reduced:
		_tumble_over()
		return
	_die_art.texture = TEX_TUMBLE
	_motion = create_tween()
	for interval: int in FLICKER_MS:
		_motion.tween_interval(interval / 1000.0)
		_motion.tween_callback(flicker)
	_motion.tween_callback(_tumble_over)
	_motion.parallel().tween_property(_die, ^"rotation", TAU * 2.0, SPIN_S).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## «Передумать»: only before the roll.
func cancel_pressed() -> void:
	if _phase != Phase.CHOSEN or _blocked():
		return
	if not _session.cancel_check():
		return
	_phase = Phase.CLOSED
	_leave(Exit.CANCELLED, null)


## «Продолжить»: commit 7 inside the core; the outcome page follows `show_released`.
func continue_pressed() -> void:
	if _phase != Phase.SHOWN or _blocked() or _action.disabled:
		return
	_phase = Phase.APPLYING
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var page: StoryScreen = _session.continue_check()
	if page != null:
		_page = page
		if not _session.waiting():
			_leave(Exit.CONTINUED, page)
		return
	if _session.flow_error():
		_phase = Phase.ERROR
		if _session.close_check():
			_leave(Exit.FLOW_ERROR, null)
		return
	_phase = Phase.SHOWN
	tick()


## Skip: the whole result at once; with a write still waiting the wish is kept until `show_released`.
func skip() -> void:
	var rolling: bool = _phase == Phase.TUMBLING or _phase == Phase.WAITING or _phase == Phase.REVEALING
	if not rolling or _blocked():
		return
	if _session.waiting():
		_skip_wanted = true
		return
	_show_full(CRIT_SHORT_MS)


## System Back (roll-screen.md, Interaction Map); the game never quits.
func go_back() -> void:
	if _blocked():
		return
	match _phase:
		Phase.CHOSEN:
			cancel_pressed()
		Phase.TUMBLING, Phase.WAITING, Phase.REVEALING:
			skip()
		Phase.SHOWN:
			if not _action.disabled:
				_flash_frame()


## One flicker of the digit.
func flicker() -> void:
	_set_face(rng.randi_range(1, 20))


## Turns the continue button on once the window (and a crit animation) are over; the arm tween calls it.
func tick() -> void:
	if _phase != Phase.SHOWN or _now() < _guard_until:
		return
	_action.disabled = false
	_action.mouse_filter = Control.MOUSE_FILTER_STOP
	_action.focus_mode = Control.FOCUS_ALL


# ---- test-only (TD G4) ----

func phase() -> int:
	return _phase


## Plays the end of the tumble at once.
func finish_tumble() -> void:
	if _phase != Phase.TUMBLING:
		return
	_kill_motion()
	_tumble_over()


## Plays the end of the write wait flicker at once: the last flicker, then the static die.
func finish_wait() -> void:
	if _phase != Phase.WAITING:
		return
	_kill_motion()
	flicker()
	_die_art.texture = TEX_NEUTRAL


# ---- end of test-only ----

func _now() -> int:
	return clock.call()


func _blocked() -> bool:
	return _now() < _guard_until


func _start_guard() -> void:
	_guard_until = _now() + GUARD_MS


func _disconnect() -> void:
	if _session != null and _session.show_released.is_connected(_on_released):
		_session.show_released.disconnect(_on_released)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _kill_motion() -> void:
	_kill(_motion)
	_die.rotation = 0.0
	_die.scale = Vector2.ONE


func _apply_scale() -> void:
	var text_scale: float = get_theme_default_font_size() / BASE_FONT
	var half: float = (DIE_PX_BIG if text_scale >= 2.0 else DIE_PX) / 2.0
	_die.offset_left = -half
	_die.offset_top = -half
	_die.offset_right = half
	_die.offset_bottom = half
	_die.pivot_offset = Vector2(half, half)
	_verdict.add_theme_font_size_override(&"font_size", int(maxf(64.0, BASE_FONT * text_scale)))
	_cartouche_label.add_theme_font_size_override(&"font_size", int(maxf(88.0, BASE_FONT * text_scale)))


func _fill_stake() -> void:
	var text: String = _brief.option_text
	if not _brief.option_reason.is_empty():
		text = _brief.option_reason + " " + text
	_option_text.text = text
	_option_text.visible = true
	_caption.text = _brief.caption
	_caption.visible = true
	_need_text = tr("Нужно выбросить %d") % _brief.need if _brief.need >= 20 else tr("Нужно выбросить %d или больше") % _brief.need
	_need.text = _need_text
	_verdict.modulate.a = 0.0
	_verdict.visible = true
	_cartouche.visible = false
	_calc.visible = false
	_bonus.visible = false
	_die_art.texture = TEX_UNKNOWN
	_die_label.text = "?"
	_slot.scroll_vertical = 0
	_show_slot(_back)
	_show_slot(_action)
	_action.text = tr("Бросить")
	_action.disabled = false


func _hide_slot(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate.a = 0.0
	button.focus_mode = Control.FOCUS_NONE


func _show_slot(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate.a = 1.0
	button.focus_mode = Control.FOCUS_ALL


func _set_face(face: int) -> void:
	_die_label.text = str(face)
	face_changed.emit(face)


func _tumble_over() -> void:
	_kill_motion()
	if _session.waiting():
		_phase = Phase.WAITING
		_die_art.texture = TEX_NEUTRAL
		if not _reduced:
			_motion = create_tween()
			_motion.tween_interval(WAIT_FLICKER_S)
			_motion.tween_callback(flicker)
			_motion.tween_interval(WAIT_END_S)
		return
	_reveal()


func _on_released() -> void:
	if _phase == Phase.WAITING:
		_kill_motion()
		_reveal()
	elif _phase == Phase.APPLYING:
		_leave(Exit.CONTINUED, _page)


func _reveal() -> void:
	if _skip_wanted or _reduced:
		_show_full(CRIT_SHORT_MS if _skip_wanted else 0)
		return
	_phase = Phase.REVEALING
	_land()
	_set_calc(1)
	_motion = create_tween()
	_motion.tween_property(_die, ^"scale", Vector2(1.06, 0.94), STEP_S * 0.5)
	_motion.tween_property(_die, ^"scale", Vector2.ONE, STEP_S * 0.5)
	_motion.tween_callback(_set_calc.bind(2))
	_motion.tween_interval(STEP_S)
	_motion.tween_callback(_set_calc.bind(3))
	_motion.tween_interval(VERDICT_S)
	_motion.tween_callback(_conclude.bind(CRIT_MS))


func _land() -> void:
	_die_art.texture = TEX_NEUTRAL
	_set_face(_result.roll)
	_option_text.visible = false
	_caption.visible = false
	_slot.scroll_vertical = 0
	if not _landed:
		_landed = true
		die_landed.emit(_result.roll)


func _show_full(crit_ms: int) -> void:
	_kill_motion()
	_land()
	_set_calc(3)
	_conclude(crit_ms)


func _set_calc(stage: int) -> void:
	var sign_text: String = "+" if _result.bonus >= 0 else MINUS
	var text: String = "%s:%s%d" % [_brief.stat_name, NBSP, _result.roll]
	if stage >= 2:
		text += "%s%s%s%d" % [NBSP, sign_text, NBSP, absi(_result.bonus)]
	if stage >= 3:
		text += "%s=%s%d %s%s%d" % [NBSP, NBSP, _result.total, tr("против"), NBSP, _result.dc]
	_calc.text = text
	_calc.visible = true


func _conclude(crit_ms: int) -> void:
	_phase = Phase.SHOWN
	var crit: bool = _result.crit != D20Result.Crit.NONE
	var texture: Texture2D = TEX_SUCCESS if _result.success else TEX_FAILURE
	if crit:
		texture = TEX_CRIT20 if _result.crit == D20Result.Crit.SUCCESS else TEX_CRIT1
	_die_art.texture = texture
	_die_label.add_theme_color_override(&"font_color", Color(0.09019608, 0.07843137, 0.05882353) if _result.success else Color.WHITE)
	_fill_verdict(crit)
	var anim_ms: int = 0 if (_reduced or not crit) else crit_ms
	if anim_ms > 0:
		_play_crit(anim_ms)
	elif not _reduced and not crit:
		_settle_die()
	_hide_slot(_back)
	_action.text = tr("Продолжить")
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.modulate.a = 1.0
	_action.disabled = true
	var wait_ms: int = maxi(GUARD_MS, anim_ms)
	_guard_until = _now() + wait_ms
	_kill(_arm)
	_arm = create_tween()
	_arm.tween_interval(wait_ms / 1000.0)
	_arm.tween_callback(tick)
	if not _announced:
		_announced = true
		result_shown.emit(_result.success, _result.crit)


func _fill_verdict(crit: bool) -> void:
	_verdict.visible = not crit
	_verdict.text = tr("Успех") if _result.success else tr("Провал")
	_verdict.modulate.a = 1.0
	_cartouche.visible = crit
	_cartouche_label.text = tr("Критический успех") if _result.success else tr("Критический провал")
	var decided: bool = _result.bonus_decided and not crit
	_bonus.visible = decided
	if decided:
		var signed: String = ("+" if _result.bonus >= 0 else MINUS) + str(absi(_result.bonus))
		var word: String = tr("решила") if _result.success else tr("подвела")
		_bonus.text = "%s %s %s" % [_brief.stat_name, signed, word]


## Success bounces, failure sags; no shaking (Transitions, Q10).
func _settle_die() -> void:
	_motion = create_tween()
	var squash: Vector2 = Vector2(0.94, 1.08) if _result.success else Vector2(1.08, 0.92)
	_motion.tween_property(_die, ^"scale", squash, 0.15)
	_motion.tween_property(_die, ^"scale", Vector2.ONE, 0.15)


## One flash of the light circle stands for the rays (art shortcut: no ray drawing yet).
func _play_crit(ms: int) -> void:
	var seconds: float = ms / 1000.0
	_motion = create_tween()
	_motion.tween_property(_die, ^"scale", Vector2(1.12, 1.12), seconds * 0.4)
	_motion.tween_property(_die, ^"scale", Vector2.ONE, seconds * 0.6)
	_kill(_flash)
	_flash = create_tween()
	_flash.tween_property(_spotlight, ^"scale", Vector2(1.1, 1.1), seconds * 0.4)
	_flash.tween_property(_spotlight, ^"scale", Vector2.ONE, seconds * 0.6)


## «Назад» on an active result applies nothing: the frame of the button thickens for 300 ms.
func _flash_frame() -> void:
	if _reduced:
		return
	var frame: StyleBoxFlat = (_action.get_theme_stylebox(&"normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	frame.set_border_width_all(frame.border_width_left + 6)
	_action.add_theme_stylebox_override(&"normal", frame)
	_kill(_flash)
	_flash = create_tween()
	_flash.tween_interval(FRAME_FLASH_S)
	_flash.tween_callback(_action.remove_theme_stylebox_override.bind(&"normal"))


func _resumed() -> void:
	_start_guard()
	_reduced = reduce_motion or bool(reduce_motion_source.call())
	var rolling: bool = _phase == Phase.TUMBLING or _phase == Phase.WAITING or _phase == Phase.REVEALING
	if not rolling:
		return
	if _session.waiting():
		_phase = Phase.WAITING
		_die_art.texture = TEX_NEUTRAL
		return
	_show_full(CRIT_SHORT_MS)


func _fade_in() -> void:
	if fade_s <= 0.0 or _reduced:
		return
	_kill(_fade)
	_fade_rect.modulate.a = 1.0
	_fade = create_tween()
	_fade.tween_property(_fade_rect, ^"modulate:a", 0.0, fade_s)


func _leave(kind: int, page: StoryScreen) -> void:
	_phase = Phase.CLOSED
	if fade_s <= 0.0 or _reduced:
		exited.emit(kind, page)
		return
	_kill(_fade)
	_fade = create_tween()
	_fade.tween_property(_fade_rect, ^"modulate:a", 1.0, fade_s)
	_fade.tween_callback(exited.emit.bind(kind, page))


func _on_action() -> void:
	if _phase == Phase.CHOSEN:
		roll_pressed()
	else:
		continue_pressed()
