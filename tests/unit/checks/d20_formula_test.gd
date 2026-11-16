extends GdUnitTestSuite
## Unit tests for D20Check formulas 1-2, 4-6 and D20Result (d20-checks.md, AC-01…AC-06, AC-19; story S7).

const CRIT := D20Result.Crit
const LEVELS: Array[int] = [11, 13, 15]
const BONUSES: Array[int] = [-1, 0, 1, 2, 3, 4, 5]
## AC-02, formula 4: bonus, then chance and N for Easy 11, Medium 13, Hard 15.
const TABLE_4: Array[Array] = [
	[-1, 45, 12, 35, 14, 25, 16],
	[0, 50, 11, 40, 13, 30, 15],
	[1, 55, 10, 45, 12, 35, 14],
	[2, 60, 9, 50, 11, 40, 13],
	[3, 65, 8, 55, 10, 45, 12],
	[4, 70, 7, 60, 9, 50, 11],
	[5, 75, 6, 65, 8, 55, 10],
]
## AC-03: bonus, DC, face, total, success, crit.
const ROWS_AC03: Array[Array] = [
	[4, 13, 9, 13, true, CRIT.NONE],
	[4, 13, 8, 12, false, CRIT.NONE],
	[-1, 15, 16, 15, true, CRIT.NONE],
	[-1, 15, 20, 19, true, CRIT.SUCCESS],
	[4, 11, 1, 5, false, CRIT.FAILURE],
	[-1, 15, 1, 0, false, CRIT.FAILURE],
	[4, 11, 19, 23, true, CRIT.NONE],
	[-1, 13, 13, 12, false, CRIT.NONE],
]
## AC-04 pairs outside the window: bonus, DC.
const PAIRS_AC04: Array[Array] = [[-1, 25], [5, 6], [5, 24]]


func _result(bonus: int, dc: int, n: int, check: CheckData = CheckFixtures.check()) -> D20Result:
	return D20Check.resolve(check, bonus, dc, n, false)


# 21 pairs of the window plus the AC-04 pairs, as [bonus, DC].
func _pairs() -> Array[Array]:
	var pairs: Array[Array] = []
	for bonus: int in BONUSES:
		for dc: int in LEVELS:
			pairs.append([bonus, dc])
	pairs.append_array(PAIRS_AC04)
	return pairs


func _labelled_faces(bonus: int, dc: int) -> Array[int]:
	var faces: Array[int] = []
	for n: int in range(1, 21):
		if _result(bonus, dc, n).bonus_decided:
			faces.append(n)
	return faces


# --- Formulas 1-2 (AC-01, AC-02, AC-04) ---

func test_need_equals_smallest_success_face_for_21_pairs() -> void:
	for bonus: int in BONUSES:
		for dc: int in LEVELS:
			# Arrange / Act: the reference by enumeration of the faces
			var faces: Array[int] = []
			for n: int in range(1, 21):
				if D20Check.succeeds(n, bonus, dc):
					faces.append(n)
			# Assert: success is the unbroken run N…20, the chance is its share
			assert_int(faces[0]).is_equal(D20Check.need(dc, bonus))
			assert_int(faces.back()).is_equal(20)
			assert_int(faces.size()).is_equal(21 - faces[0])
			assert_int(faces.size() * 5).is_equal(D20Check.chance(dc, bonus))


func test_need_and_chance_match_formula_4_table() -> void:
	for row: Array in TABLE_4:
		for i: int in LEVELS.size():
			# Act
			var chance: int = D20Check.chance(LEVELS[i], row[0])
			var need: int = D20Check.need(LEVELS[i], row[0])
			# Assert
			assert_int(chance).is_equal(row[1 + i * 2])
			assert_int(need).is_equal(row[2 + i * 2])
			assert_int(chance % 5).is_equal(0)
			assert_int(chance).is_between(25, 75)
			assert_int(need).is_between(6, 16)


func test_resolve_matches_ac03_rows() -> void:
	for row: Array in ROWS_AC03:
		# Act
		var result: D20Result = _result(row[0], row[1], row[2])
		# Assert
		assert_int(result.roll).is_equal(row[2])
		assert_int(result.total).is_equal(row[3])
		assert_bool(result.success).is_equal(row[4])
		assert_int(result.crit).is_equal(row[5])


func test_out_of_window_edges_keep_5_and_95() -> void:
	# Act
	var low: D20Result = _result(-1, 25, 20)
	var high: D20Result = _result(5, 6, 1)
	var near: D20Result = _result(5, 24, 19)
	# Assert
	assert_bool(low.success).is_true()
	assert_int(low.crit).is_equal(CRIT.SUCCESS)
	assert_int(D20Check.need(25, -1)).is_equal(20)
	assert_int(D20Check.chance(25, -1)).is_equal(5)
	assert_bool(high.success).is_false()
	assert_int(high.crit).is_equal(CRIT.FAILURE)
	assert_int(D20Check.need(6, 5)).is_equal(2)
	assert_int(D20Check.chance(6, 5)).is_equal(95)
	assert_bool(near.success).is_true()
	assert_int(near.crit).is_equal(CRIT.NONE)
	for x: int in range(-5, 31):
		assert_int(D20Check.chance(x, 0)).is_equal(clampi((21 - x) * 5, 5, 95))
	var expected: Dictionary[int, int] = {1: 95, 2: 95, 9: 60, 16: 25, 20: 5, 21: 5}
	for x: int in expected:
		assert_int(D20Check.chance(x, 0)).is_equal(expected[x])


# --- Formula 6, crits (AC-05) ---

func test_crit_only_on_faces_20_and_1() -> void:
	for pair: Array in _pairs():
		for n: int in range(1, 21):
			# Act
			var result: D20Result = _result(pair[0], pair[1], n)
			# Assert
			var crit: int = CRIT.SUCCESS if n == 20 else CRIT.FAILURE if n == 1 else CRIT.NONE
			var line: String = CheckFixtures.CRIT_SUCCESS if n == 20 else CheckFixtures.CRIT_FAILURE if n == 1 else ""
			assert_int(result.crit).is_equal(crit)
			assert_str(result.crit_line).is_equal(line)
	assert_str(_result(4, 13, 20).outcome_id).is_equal(_result(4, 13, 15).outcome_id)
	assert_str(_result(4, 13, 1).outcome_id).is_equal(_result(4, 13, 5).outcome_id)
	for blank: String in ["", "   ", "\n\n"]:
		var check: CheckData = CheckFixtures.check()
		check.crit_success_line = blank
		assert_str(_result(4, 13, 20, check).crit_line).is_empty()


func test_success_and_failure_lead_to_different_outcomes() -> void:
	# Act / Assert
	assert_str(_result(4, 13, 20).outcome_id).is_equal(CheckFixtures.SUCCESS)
	assert_str(_result(4, 13, 15).outcome_id).is_equal(CheckFixtures.SUCCESS)
	assert_str(_result(4, 13, 5).outcome_id).is_equal(CheckFixtures.FAILURE)
	assert_str(_result(4, 13, 1).outcome_id).is_equal(CheckFixtures.FAILURE)


# --- Formula 5, the bonus label (AC-06) ---

func test_bonus_label_faces_match_formula_5() -> void:
	# Assert: the table of AC-06 on Medium 13
	assert_array(_labelled_faces(4, 13)).contains_exactly([9, 10, 11, 12])
	assert_array(_labelled_faces(2, 13)).contains_exactly([11, 12])
	assert_array(_labelled_faces(0, 13)).is_empty()
	assert_array(_labelled_faces(-1, 13)).contains_exactly([13])
	assert_bool(_result(-1, 13, 13).success).is_false()
	for bonus: int in BONUSES:
		for dc: int in LEVELS:
			var faces: Array[int] = _labelled_faces(bonus, dc)
			assert_int(faces.size()).is_equal(absi(bonus))
			assert_bool(faces.has(1) or faces.has(20)).is_false()
			for n: int in faces:
				assert_bool(_result(bonus, dc, n).success).is_equal(bonus > 0)
	assert_array(_labelled_faces(3, 22)).contains_exactly([19])
	assert_array(_labelled_faces(5, 6)).contains_exactly([2, 3, 4, 5])


# --- AC-19: the chance knows only the bonus and the DC ---

func test_chance_depends_only_on_bonus_and_dc() -> void:
	# Arrange
	var script: Script = load("res://src/core/checks/d20_check.gd")
	var args: Dictionary[String, int] = {}
	for method: Dictionary in script.get_script_method_list():
		args[method["name"]] = method["args"].size()
	# Assert
	assert_int(args["need"]).is_equal(2)
	assert_int(args["chance"]).is_equal(2)


func test_roll_takes_hero_bonus_config_dc_and_one_source_face() -> void:
	# Arrange
	var source: CountingD20Source = CountingD20Source.new(14)
	var d20: D20Check = D20Check.new(D20Config.new(), source)
	# Act
	var result: D20Result = d20.roll(CheckFixtures.check(), CheckFixtures.hero("strength", 4))
	# Assert
	assert_int(source.calls).is_equal(1)
	assert_int(result.roll).is_equal(14)
	assert_int(result.bonus).is_equal(4)
	assert_int(result.dc).is_equal(13)
	assert_int(result.total).is_equal(18)
	assert_bool(result.success).is_true()
	assert_bool(result.rerolled).is_false()
	assert_str(result.check_id).is_equal("bridge_strength")
	assert_str(result.stat_id).is_equal("strength")
	assert_int(D20Check.need(d20.dc_of(CheckFixtures.check()), 4)).is_equal(9)
