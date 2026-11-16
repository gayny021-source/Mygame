extends GdUnitTestSuite
## Unit tests for the d20 sources (d20-checks.md, rule 10; AC-09, AC-10; story S7).

## χ² critical values at p = 0.001: 19 degrees of freedom (AC-10), and 399 by the Wilson–Hilferty
## approximation (492.05), rounded down so the bound is not looser than the GDD's.
const CHI2_19 := 43.82
const CHI2_399 := 492.0
const SEED := 20261116


func _scripted(tokens: PackedStringArray, fallback: D20Source, errors: Array[String]) -> ScriptedD20Source:
	return ScriptedD20Source.new(tokens, fallback, func(message: String) -> void: errors.append(message))


func _rolls(source: D20Source, count: int) -> Array[int]:
	var faces: Array[int] = []
	for i: int in count:
		faces.append(source.roll())
	return faces


func _chi2(counts: Array[int], expected: float) -> float:
	var sum: float = 0.0
	for count: int in counts:
		sum += (count - expected) * (count - expected) / expected
	return sum


func test_scripted_then_fallback() -> void:
	# Arrange
	var fallback: CountingD20Source = CountingD20Source.new()
	var errors: Array[String] = []
	var source: ScriptedD20Source = _scripted(["14", "3"], fallback, errors)
	# Act / Assert
	assert_array(_rolls(source, 3)).contains_exactly([14, 3, 7])
	assert_int(fallback.calls).is_equal(1)
	assert_array(errors).is_empty()


func test_out_of_range_values_use_fallback_and_log() -> void:
	# Arrange
	var errors: Array[String] = []
	var source: ScriptedD20Source = _scripted(["0", "21", "14"], CountingD20Source.new(), errors)
	# Act / Assert
	assert_array(_rolls(source, 3)).contains_exactly([7, 7, 14])
	assert_int(errors.size()).is_equal(2)
	assert_str(errors[0]).contains("«0»")
	assert_str(errors[1]).contains("«21»")


func test_text_tokens() -> void:
	# Arrange
	var errors: Array[String] = []
	var source: ScriptedD20Source = _scripted("14,abc,12.5, 3".split(","), CountingD20Source.new(), errors)
	# Act / Assert
	assert_array(_rolls(source, 4)).contains_exactly([14, 7, 7, 3])
	assert_int(errors.size()).is_equal(2)


func test_new_instance_restarts_sequence() -> void:
	# Arrange
	var errors: Array[String] = []
	var first: ScriptedD20Source = _scripted(["14", "3"], CountingD20Source.new(), errors)
	var played: Array[int] = _rolls(first, 2)
	# Act: a chapter replayed in the same process, then a new process
	var replay: int = first.roll()
	var fresh: ScriptedD20Source = _scripted(["14", "3"], CountingD20Source.new(), errors)
	# Assert
	assert_array(played).contains_exactly([14, 3])
	assert_int(replay).is_equal(7)
	assert_int(fresh.roll()).is_equal(14)


func test_engine_source_bounds_and_chi_square() -> void:
	# Arrange: a fixed seed only here (AC-10)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var faces: Array[int] = _rolls(EngineD20Source.new(rng), 40000)
	var counts: Array[int] = []
	counts.resize(20)
	var pairs: Array[int] = []
	pairs.resize(400)
	# Act
	for face: int in faces:
		assert_int(face).is_between(1, 20)
		counts[face - 1] += 1
	for i: int in range(0, faces.size(), 2):
		pairs[(faces[i] - 1) * 20 + faces[i + 1] - 1] += 1
	# Assert
	assert_bool(counts.has(0)).is_false()
	assert_float(_chi2(counts, 2000.0)).is_less(CHI2_19)
	assert_float(_chi2(pairs, 50.0)).is_less(CHI2_399)
