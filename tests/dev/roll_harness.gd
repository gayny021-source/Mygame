extends Control
## Dev harness of the Roll screen for screenshots (story SCR2): the hero_stub fixture over an in-memory
## writer, the check s02_risk with a scripted face. Not game data. Args after `--`: scale=1|2,
## state=chosen|tumble|success|failure|crit20|crit1|restored, face=N (default by state).

const ROOT := "res://tests/fixtures/story"
const FACES: Dictionary[String, String] = {"success": "18", "failure": "3", "crit20": "20", "crit1": "1", "restored": "18"}

var _rig: WriterRig = WriterRig.new()
var _screen: RollScreen
var _session: RunSession
var _args: Dictionary[String, String] = {}
var _state: String
var _frame: int = 0
var _now: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.split("=")
		_args[pair[0]] = pair[1] if pair.size() > 1 else "1"
	_state = _args.get("state", "chosen")
	var issues: Array[DataIssue] = []
	var hero: HeroData = HeroLoader.load_hero("hero_stub", ROOT).data as HeroData
	var face: String = _args.get("face", FACES.get(_state, "18"))
	var source: D20Source = ScriptedD20Source.new(PackedStringArray([face]), EngineD20Source.new(), func(line: String) -> void: print(line))
	var d20: D20Check = D20Check.new(D20Config.load_file(D20Config.PATH, issues), source)
	_session = RunSession.new(hero, _rig.writer, d20, func() -> String: return "dev", func(line: String) -> void: print(line), CaptionTexts.load_file(CaptionTexts.PATH, issues))
	_to_check()
	if _state == "restored":
		_session.roll()
		_pump()
		_rig.restart()
		_session = RunSession.new(hero, _rig.writer, d20, func() -> String: return "dev", func(line: String) -> void: print(line), CaptionTexts.load_file(CaptionTexts.PATH, issues))
		_session.load_saved()
		_pump()
	var base: Theme = load("res://src/ui/reading_theme.tres") as Theme
	_screen = (load("res://src/ui/roll/roll_screen.tscn") as PackedScene).instantiate() as RollScreen
	_screen.theme = ThemeScale.scaled(base, float(_args.get("scale", "1")))
	_screen.clock = func() -> int: return _now
	_screen.fade_s = 0.0
	add_child(_screen)
	_screen.setup(_session)
	_screen.open()


func _pump() -> void:
	for index: int in 40:
		_rig.pump(1)


func _option(id: String) -> OptionData:
	for option: OptionData in _session.screen().scene.options:
		if option.id == id:
			return option
	return null


func _to_check() -> void:
	_session.start_new()
	_pump()
	_session.report_stake_visible(_session.screen().scene.id)
	_session.apply_plain(_option("s01_go"))
	_pump()
	_session.advance()
	_pump()
	_session.report_stake_visible(_session.screen().scene.id)
	_session.choose_check(_option("s02_risk"))


func _process(_delta: float) -> void:
	_frame += 1
	_now += 100
	_rig.pump(1)
	if _frame == 5 and _state != "chosen" and _state != "restored":
		_screen.roll_pressed()
	if _frame == 20 and _state == "tumble":
		return
	if _frame == 30 and _state != "chosen" and _state != "tumble" and _state != "restored":
		_screen.skip()
