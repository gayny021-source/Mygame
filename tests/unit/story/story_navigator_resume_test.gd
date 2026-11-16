extends GdUnitTestSuite
## Unit tests for StoryNavigator.resume: determinism of a reload, the pending outcome, refused loads
## and the unload on a coda (branching-story.md, rule 8; AC-43, AC-45…AC-47; story S6).
## A reload is a new navigator over a new RunState that replays the same outcomes (no snapshot yet).

const KIND := StoryScreen.Kind


func _f1() -> HeroData:
	var hero: HeroData = GraphFixtures.hero(GraphFixtures.f1_chapter(), GraphFixtures.f1_flags())
	hero.endings = ["end_a", "end_b", "end_c", "end_d"]
	return hero


# Outcome of the visible option number `pick`; a risky one takes success or failure by `pick`.
func _pick(run: NavigatorHarness, scene: SceneData, pick: int) -> String:
	var visible: Array[OptionData] = []
	for option: OptionData in scene.options:
		if run.nav.holds(option.condition):
			visible.append(option)
	var option: OptionData = visible[pick % visible.size()]
	if option.check == null:
		return option.outcome
	return option.check.success if (pick / visible.size()) % 2 == 0 else option.check.failure


# A fresh load of the position through its dictionary shows the same screen and journals nothing.
func _assert_reload(run: NavigatorHarness) -> void:
	var issues: Array[DataIssue] = []
	var saved: StoryPosition = StoryPosition.from_dict(run.nav.position().to_dict(), "save", issues)
	var fresh: NavigatorHarness = run.reloaded()
	var journal: int = fresh.state.journal().size()
	var screen: StoryScreen = fresh.nav.resume(saved, fresh.state)
	assert_str(NavigatorHarness.describe(screen)).is_equal(NavigatorHarness.describe(run.nav.screen()))
	assert_int(fresh.state.journal().size()).is_equal(journal)
	assert_int(fresh.state.applied).is_equal(run.applied.size())


# --- 12. Determinism (AC-46) ---

func test_f1_reload_shows_the_same_screen_on_20_flag_sets() -> void:
	# Arrange
	var hero: HeroData = _f1()
	for run_index: int in 20:
		var run: NavigatorHarness = NavigatorHarness.new(hero)
		if run_index % 2 == 1:
			run.set_flags(["f_past"])
		var screen: StoryScreen = run.nav.start_run(run.state)
		var step: int = 0
		# Act / Assert: every scene and every pending outcome on the way
		while screen.kind == KIND.SCENE:
			_assert_reload(run)
			screen = run.choose(_pick(run, screen.scene, run_index / 2 + step))
			if screen.kind == KIND.OUTCOME and not run.nav.position().pending_outcome.is_empty():
				_assert_reload(run)
			if screen.kind == KIND.OUTCOME:
				screen = run.nav.advance()
			step += 1
		assert_int(screen.kind).is_equal(KIND.ENDING)
		assert_array(run.errors).is_empty()


# --- 13. Load with a pending outcome (AC-43) ---

func test_load_with_a_pending_outcome_shows_it_again_without_applying_and_leads_the_same_way() -> void:
	# Arrange
	var run: NavigatorHarness = NavigatorHarness.of([StoryFixtures.nav_bridges()])
	run.nav.start_run(run.state)
	var shown: StoryScreen = run.choose("oa")
	var fresh: NavigatorHarness = run.reloaded()
	# Act
	var screen: StoryScreen = fresh.nav.resume(run.nav.position(), fresh.state)
	var next: StoryScreen = fresh.nav.advance()
	# Assert
	assert_str(NavigatorHarness.describe(screen)).is_equal(NavigatorHarness.describe(shown))
	assert_int(fresh.state.applied).is_equal(1)
	assert_str(next.bridge).is_equal("Мост и ветер.")
	assert_dict(fresh.nav.position().to_dict()).is_equal({"chapter": "m_g", "scene": "s2", "transition": "t_ab", "pending_outcome": ""})


# --- 14. Refused loads (AC-47) ---

func test_load_refuses_a_missing_chapter_scene_or_pending_outcome_and_drops_the_old_position() -> void:
	# Arrange
	var refused: Array[StoryPosition] = [
		StoryPosition.new("ch_gone", "s1"),
		StoryPosition.new("m_g", "s_gone"),
		StoryPosition.new("m_g", "s1", "", "o_gone"),
		StoryPosition.new("m_g", "s1", "", "o_s2"),
	]
	for saved: StoryPosition in refused:
		var run: NavigatorHarness = NavigatorHarness.of([StoryFixtures.nav_bridges()])
		run.nav.start_run(run.state)
		# Act
		var screen: StoryScreen = run.nav.resume(saved, run.state)
		# Assert
		assert_int(screen.kind).is_equal(KIND.ERROR)
		assert_int(run.errors.size()).is_equal(1)
		assert_object(run.nav.position()).is_null()
		assert_object(run.nav.advance()).is_null()


func test_load_with_a_missing_entry_transition_shows_the_scene_without_bridge_and_title() -> void:
	# Arrange
	var run: NavigatorHarness = NavigatorHarness.of([StoryFixtures.nav_bridges()])
	# Act
	var screen: StoryScreen = run.nav.resume(StoryPosition.new("m_g", "s2", "t_gone"), run.state)
	# Assert
	assert_int(screen.kind).is_equal(KIND.SCENE)
	assert_str(screen.bridge).is_empty()
	assert_str(screen.chapter_title).is_empty()
	assert_int(run.errors.size()).is_equal(1)


func test_load_after_a_data_update_shows_the_new_text() -> void:
	# Arrange
	var data: Dictionary = StoryFixtures.nav_bridges()
	GraphFixtures.find(data["scenes"], "s2")["paragraphs"] = ["Новый текст."]
	var run: NavigatorHarness = NavigatorHarness.of([data])
	# Act
	var screen: StoryScreen = run.nav.resume(StoryPosition.new("m_g", "s2", "t_ab"), run.state)
	# Assert
	assert_array(NavigatorHarness.texts(screen)).contains_exactly(["Новый текст."])


# --- 15. Unload on a coda (AC-45, the S6 part) ---

func test_unload_on_a_coda_resumes_at_the_outcome_and_changes_the_chapter_once() -> void:
	# Arrange
	var run: NavigatorHarness = NavigatorHarness.of([StoryFixtures.nav_chapter_a(), StoryFixtures.nav_chapter_b()])
	run.nav.start_run(run.state)
	run.choose("o_win")
	run.nav.advance()
	var saved: StoryPosition = run.nav.position()
	var fresh: NavigatorHarness = run.reloaded()
	# Act
	var outcome: StoryScreen = fresh.nav.resume(saved, fresh.state)
	var coda: StoryScreen = fresh.nav.advance()
	var next: StoryScreen = fresh.nav.advance()
	# Assert
	assert_dict(saved.to_dict()).is_equal({"chapter": "ch_a", "scene": "a1", "transition": "", "pending_outcome": "o_win"})
	assert_int(outcome.kind).is_equal(KIND.OUTCOME)
	assert_int(coda.kind).is_equal(KIND.CODA)
	assert_str(next.scene.id).is_equal("b1")
	assert_array(fresh.events).contains_exactly(["finished:ch_a", "end_chapter"])


# --- Audit round 1: C1 (check outcome pending at load, before S7) ---

func test_load_with_a_pending_check_outcome_shows_it_without_applying_and_leads_the_same_way() -> void:
	# Arrange
	var targets: Dictionary = {"t_s1": KIND.SCENE, "t_s2": KIND.CODA, "t_x": KIND.ENDING}
	for outcome_id: String in ["ow", "of"]:
		for target: String in targets:
			var data: Dictionary = MeaningFixtures.risky_fork()
			data["transitions"].append(GraphFixtures.to_ending("t_x", "end_x"))
			GraphFixtures.find(data["outcomes"], outcome_id)["routes"] = [{"transition": target}]
			var run: NavigatorHarness = NavigatorHarness.of([data], ["end_x"])
			# Act
			var shown: StoryScreen = run.nav.resume(StoryPosition.new("m_g", "s1", "", outcome_id), run.state)
			var next: StoryScreen = run.nav.advance()
			# Assert
			assert_int(shown.kind).is_equal(KIND.OUTCOME)
			assert_str(shown.transition.id).is_equal(target)
			assert_int(run.state.applied).is_equal(0)
			assert_int(next.kind).is_equal(targets[target])
