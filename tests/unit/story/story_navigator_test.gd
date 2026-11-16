extends GdUnitTestSuite
## Unit tests for StoryNavigator in play: entry, bridges, conditions, starts, outcomes, routes,
## «Дальше», codas and endings (branching-story.md, rules 2-8; AC-36…AC-53; story S6).
## NavigatorHarness plays the Choice system: the navigator itself never applies an outcome.

const KIND := StoryScreen.Kind


func _bridges() -> NavigatorHarness:
	return NavigatorHarness.of([StoryFixtures.nav_bridges()])


func _chapters(a: Dictionary = StoryFixtures.nav_chapter_a(), b: Dictionary = StoryFixtures.nav_chapter_b()) -> NavigatorHarness:
	return NavigatorHarness.of([a, b])


## s1 -> o1 with `routes`; t_a, t_b, t_z lead into s_a, s_b, s_z; `extra` transitions are added.
func _routes(routes: Array, extra: Array = []) -> NavigatorHarness:
	var scenes: Array = [GraphFixtures.scene("s1", [GraphFixtures.normal("go", "o1")])]
	var outcomes: Array = [GraphFixtures.outcome("o1", routes)]
	var transitions: Array = extra.duplicate()
	for id: String in ["s_a", "s_b", "s_z"]:
		scenes.append(GraphFixtures.scene(id, [GraphFixtures.normal(id + "_go", "o_" + id)]))
		outcomes.append(GraphFixtures.outcome("o_" + id, ["t_end"]))
		transitions.append(GraphFixtures.to_scene("t_" + id.substr(2), id))
	transitions.append(GraphFixtures.to_end("t_end"))
	return NavigatorHarness.of([GraphFixtures.chapter(scenes, outcomes, transitions)], ["end_x"])


# --- 3. Entry into a scene (AC-36, AC-52) ---

func test_start_scene_has_the_chapter_title_and_no_bridge() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	# Act
	var screen: StoryScreen = run.nav.start_run(run.state)
	# Assert
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_str(screen.scene.id).is_equal("s1")
	assert_str(screen.chapter_title).is_equal("Мини-глава")
	assert_str(screen.bridge).is_empty()
	assert_dict(run.nav.position().to_dict()).is_equal({"chapter": "m_g", "scene": "s1", "transition": "", "pending_outcome": ""})


func test_entry_bridge_takes_the_first_of_two_true_inserts() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.set_flags(["f_a", "f_b"])
	# Act
	var screen: StoryScreen = run.nav.resume(StoryPosition.new("m_g", "s2", "t_ab"), run.state)
	# Assert
	assert_str(screen.bridge).is_equal("Мост и ветер.")
	assert_str(screen.chapter_title).is_empty()


func test_entry_shows_true_paragraphs_in_data_order() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	run.choose("oa")
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_array(NavigatorHarness.texts(screen)).contains_exactly(["Первый.", "Третий."])


func test_scene_screen_is_not_recomputed_after_an_outcome() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	run.choose("oa")
	var scene: StoryScreen = run.nav.advance()
	var before: String = NavigatorHarness.describe(scene)
	# Act
	run.choose("o_s2")
	# Assert
	assert_str(NavigatorHarness.describe(scene)).is_equal(before)
	assert_bool(run.state.has_flag("f_c")).is_true()


# --- 4. Conditions ---

func test_undeclared_flag_even_under_not_is_false_and_logged_once() -> void:
	# Arrange
	var data: Dictionary = StoryFixtures.nav_bridges()
	var ghost: Dictionary = {"text": "Призрак.", "if": "not f_ghost"}
	GraphFixtures.find(data["scenes"], "s1")["paragraphs"] = ["Видно.", ghost]
	GraphFixtures.find(data["scenes"], "s2")["paragraphs"] = ["Тоже видно.", ghost.duplicate()]
	var run: NavigatorHarness = NavigatorHarness.of([data])
	# Act
	var first: StoryScreen = run.nav.start_run(run.state)
	run.choose("oc")
	var second: StoryScreen = run.nav.advance()
	# Assert
	assert_array(NavigatorHarness.texts(first)).contains_exactly(["Видно."])
	assert_array(NavigatorHarness.texts(second)).contains_exactly(["Тоже видно."])
	assert_int(run.errors.size()).is_equal(1)


func test_holds_answers_for_options_and_empty_is_true() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	run.set_flags(["f_a"])
	# Act / Assert
	assert_bool(run.nav.holds("")).is_true()
	assert_bool(run.nav.holds("f_a")).is_true()
	assert_bool(run.nav.holds("f_b")).is_false()
	assert_bool(run.nav.holds("not f_b")).is_true()


# --- 5. Starts (AC-48) ---

func test_start_without_failure_takes_the_main_record_and_chapter_flags_are_gone() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_str(screen.scene.id).is_equal("b1")
	assert_str(screen.chapter_title).is_equal("Глава Б")
	assert_array(run.errors).is_empty()


func test_start_after_failure_takes_the_failure_record() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	run.nav.start_run(run.state)
	run.choose("o_lose")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_str(screen.scene.id).is_equal("b_fail")
	assert_array(run.errors).is_empty()


func test_start_record_without_goal_while_the_failure_flag_stands_is_logged() -> void:
	# Arrange
	var b: Dictionary = StoryFixtures.nav_chapter_b()
	b["starts"][0].erase("goal")
	var run: NavigatorHarness = _chapters(StoryFixtures.nav_chapter_a(), b)
	run.nav.start_run(run.state)
	run.choose("o_lose")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_str(screen.scene.id).is_equal("b_fail")
	assert_int(run.errors.size()).is_equal(1)


func test_start_with_no_true_record_is_an_error() -> void:
	# Arrange
	var b: Dictionary = StoryFixtures.nav_chapter_b()
	b["starts"] = [b["starts"][0]]
	var run: NavigatorHarness = _chapters(StoryFixtures.nav_chapter_a(), b)
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_int(run.errors.size()).is_equal(1)


# --- 6. Outcomes (AC-38, AC-43, AC-44) ---

func test_outcome_paragraph_reading_its_own_flag_is_shown_and_never_applied_by_the_navigator() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	run.choose("oa")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.choose("o_s2")
	# Assert
	assert_int(screen.kind).is_equal(KIND.OUTCOME)
	assert_array(NavigatorHarness.texts(screen)).contains_exactly(["Знак f_d."])
	assert_str(screen.option.id).is_equal("s2_go")
	assert_int(run.state.applied).is_equal(run.applied.size())


func test_pending_outcome_is_set_without_a_check_and_empty_with_one() -> void:
	# Arrange
	var expected: Dictionary = {"ow": "", "of": "", "os": "os"}
	for outcome_id: String in expected:
		var run: NavigatorHarness = NavigatorHarness.of([MeaningFixtures.risky_fork()])
		run.nav.start_run(run.state)
		# Act
		run.choose(outcome_id)
		# Assert
		assert_str(run.nav.position().pending_outcome).is_equal(expected[outcome_id])


func test_normal_option_sets_the_pending_outcome() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	# Act
	run.choose("oa")
	# Assert
	assert_str(run.nav.position().pending_outcome).is_equal("oa")


func test_second_outcome_applied_is_refused_and_changes_nothing() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	var shown: StoryScreen = run.choose("oa")
	var position: Dictionary = run.nav.position().to_dict()
	# Act
	var same: StoryScreen = run.nav.outcome_applied("oa")
	var other: StoryScreen = run.nav.outcome_applied("ob")
	# Assert
	assert_object(same).is_null()
	assert_object(other).is_null()
	assert_object(run.nav.screen()).is_same(shown)
	assert_dict(run.nav.position().to_dict()).is_equal(position)


func test_outcome_of_another_scene_or_unknown_is_refused_and_logged() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	var scene: StoryScreen = run.nav.start_run(run.state)
	# Act
	var foreign: StoryScreen = run.nav.outcome_applied("o_s2")
	var unknown: StoryScreen = run.nav.outcome_applied("o_zz")
	# Assert
	assert_object(foreign).is_null()
	assert_object(unknown).is_null()
	assert_object(run.nav.screen()).is_same(scene)
	assert_int(run.errors.size()).is_equal(2)


# --- 7. Routes (AC-37, AC-51) ---

func test_route_first_true_from_the_top_wins() -> void:
	# Arrange
	var routes: Array = [{"if": "f_a", "transition": "t_a"}, {"if": "f_b", "transition": "t_b"}, "t_z"]
	var cases: Dictionary = {"t_a": ["f_a", "f_b"], "t_b": ["f_b"], "t_z": []}
	for expected: String in cases:
		var run: NavigatorHarness = _routes(routes)
		run.nav.start_run(run.state)
		run.set_flags(PackedStringArray(cases[expected]))
		# Act
		var screen: StoryScreen = run.choose("o1")
		# Assert
		assert_str(screen.transition.id).is_equal(expected)


func test_route_is_the_same_on_100_calls_with_one_flag_set() -> void:
	# Arrange
	var routes: Array = [{"if": "f_a", "transition": "t_a"}, {"if": "f_b", "transition": "t_b"}, "t_z"]
	var run: NavigatorHarness = _routes(routes)
	run.set_flags(["f_b"])
	var seen: Dictionary[String, bool] = {}
	# Act
	for i: int in 100:
		seen[run.nav.resume(StoryPosition.new("m_g", "s1", "", "o1"), run.state).transition.id] = true
	# Assert
	assert_array(seen.keys()).contains_exactly(["t_b"])


func test_route_to_a_missing_transition_foreign_scene_or_unknown_ending_is_skipped_and_logged() -> void:
	# Arrange
	var extra: Array = [GraphFixtures.to_scene("t_far", "elsewhere"), GraphFixtures.to_ending("t_lost", "end_lost")]
	var run: NavigatorHarness = _routes(["t_ghost", "t_far", "t_lost", "t_z"], extra)
	run.nav.start_run(run.state)
	# Act
	var screen: StoryScreen = run.choose("o1")
	# Assert
	assert_str(screen.transition.id).is_equal("t_z")
	assert_int(run.errors.size()).is_equal(3)


func test_no_valid_route_shows_the_outcome_then_advance_is_an_error() -> void:
	# Arrange
	var run: NavigatorHarness = _routes([{"if": "f_a", "transition": "t_a"}])
	run.nav.start_run(run.state)
	var shown: StoryScreen = run.choose("o1")
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_array(NavigatorHarness.texts(shown)).contains_exactly(["Исход."])
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_int(run.errors.size()).is_equal(1)
	assert_dict(run.nav.position().to_dict()).is_equal({"chapter": "m_g", "scene": "s1", "transition": "", "pending_outcome": "o1"})


# --- 8. «Дальше» (AC-39, AC-41) ---

func test_advance_in_a_scene_is_refused() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	# Act / Assert
	assert_object(run.nav.advance()).is_null()


func test_four_advances_after_an_outcome_change_the_scene_once() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	run.nav.start_run(run.state)
	run.choose("oa")
	# Act
	var first: StoryScreen = run.nav.advance()
	var rest: Array = [run.nav.advance(), run.nav.advance(), run.nav.advance()]
	# Assert
	assert_str(first.scene.id).is_equal("s2")
	assert_array(rest).contains_exactly([null, null, null])
	assert_dict(run.nav.position().to_dict()).is_equal({"chapter": "m_g", "scene": "s2", "transition": "t_ab", "pending_outcome": ""})


func test_two_outcomes_into_one_target_share_the_bridge_with_their_own_insert() -> void:
	# Arrange
	var expected: Dictionary = {"oa": "Мост и ветер.", "ob": "Мост и дождь.", "oc": "Другой мост."}
	for outcome_id: String in expected:
		var run: NavigatorHarness = _bridges()
		run.nav.start_run(run.state)
		run.choose(outcome_id)
		# Act
		var screen: StoryScreen = run.nav.advance()
		# Assert
		assert_str(screen.bridge).is_equal(expected[outcome_id])


# --- 9. Linear scene (AC-40) ---

func test_outcome_without_text_goes_straight_to_the_next_scene() -> void:
	# Arrange
	var data: Dictionary = GraphFixtures.chain(["s1", "s2"])
	GraphFixtures.find(data["outcomes"], "o_s1")["paragraphs"] = []
	var run: NavigatorHarness = NavigatorHarness.of([data])
	run.nav.start_run(run.state)
	# Act
	var screen: StoryScreen = run.choose("o_s1")
	# Assert
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_str(screen.scene.id).is_equal("s2")
	assert_str(screen.bridge).is_equal("Мост.")


# --- 10. End of a chapter (AC-53) ---

func test_coda_by_chapter_flags_comes_before_the_signal() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	run.nav.start_run(run.state)
	run.choose("o_win")
	# Act
	var coda: StoryScreen = run.nav.advance()
	# Assert
	assert_int(coda.kind).is_equal(KIND.CODA)
	assert_array(NavigatorHarness.texts(coda)).contains_exactly(["Кода А.", "Кода победы."])
	assert_array(run.events).is_empty()
	assert_str(run.nav.position().scene).is_equal("a1")


func test_coda_advance_signals_then_ends_the_chapter_then_starts_the_next_once() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	var again: StoryScreen = run.nav.advance()
	# Assert
	assert_array(run.events).contains_exactly(["finished:ch_a", "end_chapter"])
	assert_str(screen.chapter_title).is_equal("Глава Б")
	assert_object(again).is_null()
	assert_dict(run.nav.position().to_dict()).is_equal({"chapter": "ch_b", "scene": "b1", "transition": "", "pending_outcome": ""})


func test_chapter_end_in_the_last_chapter_is_an_error_without_signal() -> void:
	# Arrange
	var run: NavigatorHarness = NavigatorHarness.of([StoryFixtures.nav_chapter_b()])
	run.nav.start_run(run.state)
	run.choose("o_b1")
	var coda: StoryScreen = run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_int(coda.kind).is_equal(KIND.CODA)
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_array(run.events).is_empty()
	assert_int(run.errors.size()).is_equal(1)


func test_empty_coda_is_logged_and_the_chapter_changes_at_once() -> void:
	# Arrange
	var a: Dictionary = StoryFixtures.nav_chapter_a()
	a["transitions"][0]["coda"] = [{"text": "Кода.", "if": "f_a"}]
	var run: NavigatorHarness = _chapters(a)
	run.nav.start_run(run.state)
	run.choose("o_win")
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_str(screen.scene.id).is_equal("b1")
	assert_int(run.errors.size()).is_equal(1)
	assert_array(run.events).contains_exactly(["finished:ch_a", "end_chapter"])


# --- 11. Endings (AC-50) and 16. after ERROR / ENDING ---

func test_ending_screen_has_the_ending_and_no_bridge_or_coda() -> void:
	# Arrange
	var run: NavigatorHarness = _routes([{"transition": "t_x"}], [GraphFixtures.to_ending("t_x", "end_x")])
	run.nav.start_run(run.state)
	run.choose("o1")
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_int(screen.kind).is_equal(KIND.ENDING)
	assert_str(screen.transition.to_id).is_equal("end_x")
	assert_bool(screen.transition.early).is_false()
	assert_str(screen.bridge).is_empty()
	assert_array(screen.paragraphs).is_empty()


func test_after_ending_or_error_every_call_is_refused() -> void:
	# Arrange
	var ended: NavigatorHarness = _routes([{"transition": "t_x"}], [GraphFixtures.to_ending("t_x", "end_x")])
	ended.nav.start_run(ended.state)
	ended.choose("o1")
	ended.nav.advance()
	var failed: NavigatorHarness = _routes([{"if": "f_a", "transition": "t_a"}])
	failed.nav.start_run(failed.state)
	failed.choose("o1")
	failed.nav.advance()
	for run: NavigatorHarness in [ended, failed]:
		# Act / Assert
		assert_object(run.nav.advance()).is_null()
		assert_object(run.nav.outcome_applied("o1")).is_null()


func test_f1_open_final_option_follows_f_past_and_leads_to_its_own_ending() -> void:
	# Arrange
	var hero: HeroData = GraphFixtures.hero(GraphFixtures.f1_chapter(), GraphFixtures.f1_flags())
	hero.endings = ["end_a", "end_b", "end_c", "end_d"]
	var plain: NavigatorHarness = NavigatorHarness.new(hero)
	var past: NavigatorHarness = NavigatorHarness.new(hero)
	past.set_flags(["f_past"])
	var at_s11: StoryPosition = StoryPosition.new("ch_f1", "s11", "t_s10_s11")
	plain.nav.resume(at_s11, plain.state)
	past.nav.resume(at_s11, past.state)
	# Act
	plain.choose("o_s11_safe")
	past.choose("o_s11_open")
	var plain_end: StoryScreen = plain.nav.advance()
	var past_end: StoryScreen = past.nav.advance()
	# Assert
	assert_bool(plain.nav.holds("f_past")).is_false()
	assert_bool(past.nav.holds("f_past")).is_true()
	assert_str(plain_end.transition.to_id).is_equal("end_c")
	assert_str(past_end.transition.to_id).is_equal("end_d")


# --- Audit round 1: C2, C6, G5 ---

func test_chapter_finished_callback_calling_advance_is_refused_and_the_chapter_changes_once() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	var box: Array[StoryNavigator] = []
	var during: Array = []
	var calls: Array[int] = [0]
	var events: Array[String] = run.events
	var on_finished: Callable = func(chapter_id: String) -> void:
		events.append("finished:" + chapter_id)
		calls[0] += 1
		if calls[0] == 1:
			during.append(box[0].advance())
	run.nav = StoryNavigator.new(run.hero, on_finished, NavigatorHarness._appender(run.errors, ""))
	box.append(run.nav)
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	box.clear()
	# Assert
	assert_array(during).contains_exactly([null])
	assert_array(run.events).contains_exactly(["finished:ch_a", "end_chapter"])
	assert_str(screen.scene.id).is_equal("b1")


func test_invalid_chapter_finished_callback_is_an_error_without_end_chapter() -> void:
	# Arrange
	var run: NavigatorHarness = _chapters()
	run.nav = StoryNavigator.new(run.hero, Callable(), NavigatorHarness._appender(run.errors, ""))
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	# Act
	var screen: StoryScreen = run.nav.advance()
	# Assert
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_array(run.events).is_empty()
	assert_int(run.errors.size()).is_equal(1)


func test_start_run_of_a_hero_without_chapters_is_an_error() -> void:
	# Arrange
	var run: NavigatorHarness = NavigatorHarness.of([])
	# Act
	var screen: StoryScreen = run.nav.start_run(run.state)
	# Assert
	assert_int(screen.kind).is_equal(KIND.ERROR)
	assert_int(run.errors.size()).is_equal(1)
	assert_object(run.nav.position()).is_null()


func test_holds_before_any_run_is_false() -> void:
	# Arrange
	var run: NavigatorHarness = _bridges()
	# Act / Assert
	assert_bool(run.nav.holds("f_a")).is_false()
	assert_bool(run.nav.holds("")).is_false()
