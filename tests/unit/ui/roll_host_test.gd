extends GdUnitTestSuite
## The Roll screen in the game (story SCR2): a risky card opens it over the Reading screen, every way out
## returns to the Reading screen in the right state (roll-screen.md, Lifecycle).

var _t: SessionRig
var _reading: ReadingScreen
var _host: RollHost
var _now: int


func before_test() -> void:
	_now = 10000
	_t = SessionRig.new()
	_reading = (load("res://src/ui/reading/reading_screen.tscn") as PackedScene).instantiate() as ReadingScreen
	_reading.clock = func() -> int: return _now
	add_child(_reading)
	_reading.setup(_t.session, _t.hero)
	_host = RollHost.new()
	_host.clock = func() -> int: return _now
	_host.fade_s = 0.0
	add_child(_host)
	_host.setup(_reading, _t.session)
	_reading.start()
	_t.settle()
	_reading.stake_seen()
	_now += 400


func after_test() -> void:
	_host.queue_free()
	_reading.queue_free()


func _risky() -> OptionCard:
	for card: OptionCard in _reading.cards():
		if card.view.option.id == "r":
			return card
	return null


func _open_roll() -> RollScreen:
	_reading.card_tapped(_risky())
	var roll: RollScreen = _host.roll_screen
	return roll


func test_a_risky_card_opens_the_roll_screen_once() -> void:
	var roll: RollScreen = _open_roll()
	assert_object(roll).is_not_null()
	_reading.card_tapped(_risky())
	assert_object(_host.roll_screen).is_same(roll)


func test_cancel_returns_to_the_choice_and_the_card_can_be_taken_again() -> void:
	var roll: RollScreen = _open_roll()
	_now += 400
	roll.cancel_pressed()
	await get_tree().process_frame
	assert_object(_host.roll_screen).is_null()
	_reading.card_tapped(_risky())
	assert_object(_host.roll_screen).is_not_null()


func test_continue_shows_the_outcome_page() -> void:
	var roll: RollScreen = _open_roll()
	_now += 400
	roll.roll_pressed()
	_t.settle()
	_now += 400
	roll.skip()
	_now += 400
	roll.tick()
	roll.continue_pressed()
	_t.settle()
	assert_object(_host.roll_screen).is_null()
	assert_int(_reading.page_kind()).is_equal(StoryScreen.Kind.OUTCOME)


func test_a_loaded_restored_roll_opens_the_roll_screen() -> void:
	var roll: RollScreen = _open_roll()
	_now += 400
	roll.roll_pressed()
	_t.settle()
	_host.queue_free()
	_reading.queue_free()
	_t.restart()
	_reading = (load("res://src/ui/reading/reading_screen.tscn") as PackedScene).instantiate() as ReadingScreen
	_reading.clock = func() -> int: return _now
	add_child(_reading)
	_reading.setup(_t.session, _t.hero)
	_host = RollHost.new()
	_host.clock = func() -> int: return _now
	_host.fade_s = 0.0
	add_child(_host)
	_host.setup(_reading, _t.session)
	_t.session.load_saved()
	_t.settle()
	assert_object(_host.roll_screen).is_not_null()
	assert_int(_host.roll_screen.phase).is_equal(RollScreen.Phase.SHOWN)
