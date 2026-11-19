extends GdUnitTestSuite
## Unit tests of the Reading-screen core of RunSession (reading-screen.md, Dependencies; choice-system.md,
## rules 1, 4, 7-9, 15; story UI1): option states, captions, no-open flag, stake latch, waiting guards.

const STATE := OptionView.State
const MINUS := "−"

var _t: SessionRig


func before_test() -> void:
	_t = SessionRig.new()


func _flag(id: String) -> FlagDecl:
	for decl: FlagDecl in _t.hero.flags:
		if decl.id == id:
			return decl
	return null


# s2 has only the risky option of s1 (a hindrance set in s1 can close it there).
func _risky_in_s2() -> void:
	var s1: SceneData = _t.hero.chapters[0].scenes[0]
	var s2: SceneData = _t.hero.chapters[0].scenes[1]
	s2.options.clear()
	for option: OptionData in s1.options:
		if option.check != null:
			s2.options.append(option)


func _view(id: String) -> OptionView:
	for view: OptionView in _t.session.option_views():
		if view.option.id == id:
			return view
	return null


func _states() -> Array:
	var result: Array = []
	for view: OptionView in _t.session.option_views():
		result.append(view.state)
	return result


func test_options_are_inactive_until_the_stake_is_read_then_open() -> void:
	# Arrange
	_t.started(false)
	var before: Array = _states()
	# Act
	_t.session.report_stake_visible()
	# Assert
	assert_array(before).is_equal([STATE.INACTIVE, STATE.INACTIVE, STATE.INACTIVE])
	assert_bool(_t.session.stake_read()).is_true()
	assert_array(_states()).is_equal([STATE.OPEN, STATE.OPEN, STATE.OPEN])


func test_captions_are_ready_lines() -> void:
	# Arrange
	_t.started()
	# Assert
	assert_str(_view("a").caption).is_equal("Без броска")
	assert_str(_view("r").caption).is_equal("Сила +4 · Средне 13 · шанс 60 %")


func test_a_negative_bonus_is_written_with_the_true_minus() -> void:
	# Arrange
	_t.hero.stats[0].bonus = -1
	_t.started()
	# Assert: need 14, chance 35
	assert_str(_view("r").caption).is_equal("Сила %s1 · Средне 13 · шанс 35 %%" % MINUS)


func test_a_safe_option_names_its_price() -> void:
	# Arrange
	_flag("f_c").category = "price"
	_flag("f_c").title = "потерянное время"
	_t.hero.chapters[0].scenes[0].options[1].kind = OptionData.KIND_SAFE
	_t.started()
	# Assert
	assert_str(_view("c").caption).is_equal("Без броска\u00a0· потерянное время")


func test_a_hindrance_closes_the_risky_option_with_its_reason() -> void:
	# Arrange
	_flag("f_b").blocks = PackedStringArray(["strength"])
	_flag("f_b").title = "Сломана рука"
	_risky_in_s2()
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	# Act
	var view: OptionView = _view("r")
	# Assert: closed stays closed after the latch
	assert_int(view.state).is_equal(STATE.CLOSED)
	assert_str(view.caption).is_equal("Закрыто: Сила \u2014 Сломана рука")
	assert_str(view.reason).is_equal("Сломана рука")
	assert_bool(_t.session.no_open_options()).is_true()


func test_no_open_options_is_false_when_one_option_is_free() -> void:
	# Arrange
	_t.started()
	# Assert
	assert_bool(_t.session.no_open_options()).is_false()


func test_an_option_with_a_false_condition_is_not_in_the_choice() -> void:
	# Arrange
	_t.hero.chapters[0].scenes[0].options[0].condition = "f_d"
	_t.started()
	# Assert
	assert_object(_view("a")).is_null()
	assert_int(_t.session.option_views().size()).is_equal(2)


func test_a_risky_option_of_an_unknown_stat_is_hidden_and_logged() -> void:
	# Arrange
	_t.hero.chapters[0].scenes[0].options[2].check.stat = "luck"
	_t.started()
	# Assert
	assert_object(_view("r")).is_null()
	assert_int(_t.logs.size()).is_equal(1)


func test_a_stat_without_a_name_is_hidden_and_logged_never_shown_by_id() -> void:
	# Arrange
	_t.hero.stats[0].name = ""
	_t.started()
	# Assert
	assert_object(_view("r")).is_null()
	assert_int(_t.logs.size()).is_equal(1)


func test_the_stat_name_comes_from_the_hero_data() -> void:
	# Arrange
	_t.hero.stats[0].name = "Мощь"
	_t.started()
	# Assert
	assert_str(_view("r").caption).starts_with("Мощь\u00a0+4")


func test_latch_survives_cancel_and_resets_on_a_new_scene() -> void:
	# Arrange
	_t.started()
	_t.session.report_stake_visible()
	_t.session.choose_check(_t.option("r"))
	var chosen: Array = _states()
	_t.session.cancel_check()
	# Assert: the same scene keeps it, the options are free again
	assert_array(chosen).is_equal([STATE.BLOCKED, STATE.BLOCKED, STATE.CHOSEN])
	assert_array(_states()).is_equal([STATE.OPEN, STATE.OPEN, STATE.OPEN])
	# Act: another scene
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	# Assert
	assert_bool(_t.session.stake_read()).is_false()


func test_report_stake_visible_off_a_scene_is_ignored() -> void:
	# Act
	_t.session.report_stake_visible()
	# Assert: no run yet
	assert_bool(_t.session.stake_read()).is_false()


func test_latch_is_not_kept_by_a_load_and_pause_changes_nothing() -> void:
	# Arrange
	_t.started()
	_t.session.report_stake_visible()
	_t.restart()
	_t.session.load_saved()
	_t.settle()
	# Assert
	assert_bool(_t.session.stake_read()).is_false()
	assert_array(_states()).is_equal([STATE.INACTIVE, STATE.INACTIVE, STATE.INACTIVE])


func test_after_a_plain_choice_the_option_is_chosen_and_the_rest_blocked_while_it_waits() -> void:
	# Arrange
	_t.started()
	_t.session.report_stake_visible()
	# Act
	_t.session.apply_plain(_t.option("a"))
	# Assert
	assert_bool(_t.session.waiting()).is_true()
	assert_array(_states()).is_equal([STATE.CHOSEN, STATE.BLOCKED, STATE.BLOCKED])


func test_advance_and_second_choice_are_refused_while_waiting() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	var journal: int = _t.session.journal_size()
	var writes: int = _t.writes()
	# Act
	var advanced: StoryScreen = _t.session.advance()
	var again: StoryScreen = _t.session.apply_plain(_t.option("c"))
	var risky: bool = _t.session.choose_check(_t.option("r"))
	# Assert
	assert_object(advanced).is_null()
	assert_object(again).is_null()
	assert_bool(risky).is_false()
	assert_int(_t.session.journal_size()).is_equal(journal)
	assert_int(_t.writes()).is_equal(writes)


func test_advance_twice_moves_once() -> void:
	# Arrange
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	# Act
	var first: StoryScreen = _t.session.advance()
	var second: StoryScreen = _t.session.advance()
	# Assert
	assert_int(first.kind).is_equal(StoryScreen.Kind.SCENE)
	assert_object(second).is_null()


func test_core_refuses_a_touch_before_the_stake_is_read() -> void:
	# Arrange
	_t.started(false)
	var writes: int = _t.writes()
	# Act
	var plain: StoryScreen = _t.session.apply_plain(_t.option("a"))
	var risky: bool = _t.session.choose_check(_t.option("r"))
	# Assert
	assert_object(plain).is_null()
	assert_bool(risky).is_false()
	assert_int(_t.session.journal_size()).is_equal(0)
	assert_int(_t.writes()).is_equal(writes)
	assert_bool(_t.session.waiting()).is_false()


func test_core_refuses_a_hindered_risky_option_even_after_the_latch() -> void:
	# Arrange
	_flag("f_b").blocks = PackedStringArray(["strength"])
	_risky_in_s2()
	_t.started()
	_t.session.apply_plain(_t.option("a"))
	_t.settle()
	_t.session.advance()
	_t.session.report_stake_visible()
	var calls: int = _t.source.calls
	# Act
	var chosen: bool = _t.session.choose_check(_t.option("r"))
	# Assert
	assert_bool(chosen).is_false()
	assert_object(_t.session.roll()).is_null()
	assert_int(_t.source.calls).is_equal(calls)


func test_core_refuses_an_option_that_is_not_in_the_choice() -> void:
	# Arrange
	_t.hero.chapters[0].scenes[0].options[0].condition = "f_d"
	_t.started()
	# Act
	var screen: StoryScreen = _t.session.apply_plain(_t.hero.chapters[0].scenes[0].options[0])
	# Assert
	assert_object(screen).is_null()
	assert_int(_t.session.journal_size()).is_equal(0)


func test_option_views_are_copies_the_ui_cannot_use_to_open_a_card() -> void:
	# Arrange
	_t.started(false)
	_t.session.option_views()[0].state = STATE.OPEN
	# Assert
	assert_array(_states()).is_equal([STATE.INACTIVE, STATE.INACTIVE, STATE.INACTIVE])
	assert_object(_t.session.apply_plain(_t.option("a"))).is_null()
