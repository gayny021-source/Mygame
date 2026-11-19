extends Control
## Dev harness of the Reading screen for screenshots (story SCR1): the hero_stub fixture over an
## in-memory writer. Not game data. Args after `--`: scale=1|2, state=scene|unread|closed|panel|bridge|hint|bridgeend|bridgepanel|flowerror,
## end=1 (scroll to the end). `closed` gives the hero a wound that shuts Сила before s02.

const ROOT := "res://tests/fixtures/story"
const _TO_BRIDGE: Array[String] = ["start", "wait", "wait", "scroll", "wait", "wait", "card:s01_go", "next", "wait", "wait"]

var _rig: WriterRig = WriterRig.new()
var _screen: ReadingScreen
var _session: RunSession
var _steps: Array[String] = []
var _args: Dictionary[String, String] = {}
var _tick: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.split("=")
		_args[pair[0]] = pair[1] if pair.size() > 1 else "1"
	var issues: Array[DataIssue] = []
	var hero: HeroData = HeroLoader.load_hero("hero_stub", ROOT).data as HeroData
	var state: String = _args.get("state", "scene")
	if state == "closed":
		_wound(hero)
	var d20: D20Check = D20Check.new(D20Config.load_file(D20Config.PATH, issues), EngineD20Source.new())
	_session = RunSession.new(hero, _rig.writer, d20, func() -> String: return "dev", func(line: String) -> void: print(line), CaptionTexts.load_file(CaptionTexts.PATH, issues))
	var base: Theme = load("res://src/ui/reading_theme.tres") as Theme
	_screen = (load("res://src/ui/reading/reading_screen.tscn") as PackedScene).instantiate() as ReadingScreen
	_screen.theme = ThemeScale.scaled(base, float(_args.get("scale", "1")))
	_screen.reduce_motion = true
	_screen.clock = func() -> int:
		_tick += 1000
		return _tick
	add_child(_screen)
	_screen.setup(_session, hero)
	_steps.assign({"flowerror": ["start", "refuse", "wait", "wait", "scroll", "wait", "wait", "card:s01_go", "wait", "wait"], "scene": ["start"], "unread": ["start"], "panel": ["start", "panel"],
		"bridge": _TO_BRIDGE,
		"hint": _TO_BRIDGE + ["card:s02_risk"],
		"bridgeend": _TO_BRIDGE + ["wait", "wait", "scroll", "wait"],
		"bridgepanel": _TO_BRIDGE + ["panel"],
		"closed": ["start", "wait", "wait", "scroll", "wait", "wait", "card:s01_go", "next", "wait", "wait", "scroll", "wait", "wait"]}[state])
	if _args.has("end") and state != "closed":
		_steps.append_array(["wait", "wait", "scroll", "wait"])


func _wound(hero: HeroData) -> void:
	var decl: FlagDecl = FlagDecl.new()
	decl.id = "w_hand"
	decl.category = "wound"
	decl.title = "Рука повреждена"
	decl.visible = true
	decl.blocks = PackedStringArray(["strength"])
	hero.flags.append(decl)
	for outcome: OutcomeData in hero.chapters[0].outcomes:
		if outcome.id == "o_s01":
			outcome.sets.append("w_hand")


func _process(_delta: float) -> void:
	_rig.pump(2)
	if _steps.is_empty() or _session.waiting():
		return
	var step: String = _steps.pop_front()
	match step:
		"start":
			_screen.start()
		"scroll":
			var scroll: ScrollContainer = _screen.find_child("Scroll", true, false) as ScrollContainer
			scroll.scroll_vertical = 100000
		"refuse":
			_session._state = RefusingState.new(_session._hero.flags, Callable())
		"panel":
			_screen.goal_tapped()
		"wait":
			pass
		"next":
			_screen.next_pressed()
		_:
			for card: OptionCard in _screen.cards():
				if step == "card:" + card.view.option.id:
					_screen.card_tapped(card)
