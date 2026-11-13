extends GdUnitTestSuite
## Unit tests for the pure static functions SafeAreaMargins.insets_for() and margin_for().
## Source of the phone numbers: .claude/skills/tscn-handcrafter/SKILL.md (1080x2400,
## cutout 110, gesture bar 60 -> insets [0, 110, 0, 60]).

const BASE_LEFT := 48
const BASE_TOP := 96
const BASE_RIGHT := 48
const BASE_BOTTOM := 72
const AIR := 24

const PHONE_VIEW := Vector2(1080, 2400)
const PHONE_WIN := Vector2i(1080, 2400)
const CUTOUT := 110
const GESTURE_BAR := 60


func _phone_safe() -> Rect2i:
	return Rect2i(0, CUTOUT, PHONE_WIN.x, PHONE_WIN.y - CUTOUT - GESTURE_BAR)


func _insets(safe: Rect2i, win_pos: Vector2i, win_size: Vector2i, view: Vector2) -> Array:
	return Array(SafeAreaMargins.insets_for(safe, win_pos, win_size, view))


# --- insets_for: empty / invalid input ---

func test_insets_for_empty_safe_area_returns_zeros() -> void:
	# Arrange: headless DisplayServer reports an empty rect
	var safe := Rect2i()
	# Act
	var insets := _insets(safe, Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_zero_window_size_returns_zeros() -> void:
	# Arrange
	var win := Vector2i.ZERO
	# Act
	var insets := _insets(_phone_safe(), Vector2i.ZERO, win, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_zero_window_width_only_returns_zeros() -> void:
	# Arrange
	var win := Vector2i(0, PHONE_WIN.y)
	# Act
	var insets := _insets(_phone_safe(), Vector2i.ZERO, win, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_negative_window_size_returns_zeros() -> void:
	# Arrange
	var win := -PHONE_WIN
	# Act
	var insets := _insets(_phone_safe(), Vector2i.ZERO, win, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_negative_safe_size_returns_zeros() -> void:
	# Arrange
	var safe := Rect2i(0, CUTOUT, -PHONE_WIN.x, -PHONE_WIN.y)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_zero_viewport_returns_zeros() -> void:
	# Arrange: scale factor 0 collapses every inset
	var view := Vector2.ZERO
	# Act
	var insets := _insets(_phone_safe(), Vector2i.ZERO, PHONE_WIN, view)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_negative_viewport_clamps_to_zeros() -> void:
	# Arrange: negative scale gives negative insets, which must clamp at 0
	var view := -PHONE_VIEW
	# Act
	var insets := _insets(_phone_safe(), Vector2i.ZERO, PHONE_WIN, view)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


# --- insets_for: real phone numbers ---

func test_insets_for_phone_cutout_and_gesture_bar_returns_top_and_bottom() -> void:
	# Arrange
	var safe := _phone_safe()
	# Act
	var insets := _insets(safe, Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, CUTOUT, 0, GESTURE_BAR])


func test_insets_for_full_screen_safe_area_returns_zeros() -> void:
	# Arrange
	var safe := Rect2i(Vector2i.ZERO, PHONE_WIN)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_side_cutout_returns_left_and_right() -> void:
	# Arrange: landscape-style side insets
	var left := 40
	var right := 30
	var safe := Rect2i(left, 0, PHONE_WIN.x - left - right, PHONE_WIN.y)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([left, 0, right, 0])


func test_insets_for_qhd_screen_scales_to_viewport_pixels() -> void:
	# Arrange: window 1440x3200 shown as a 1080x2400 viewport, k = 0.75
	var win := Vector2i(1440, 3200)
	var top_px := 120
	var bottom_px := 80
	var safe := Rect2i(0, top_px, win.x, win.y - top_px - bottom_px)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, win, PHONE_VIEW)
	# Assert
	assert_array(insets).is_equal([0, 90, 0, 60])


func test_insets_for_fractional_scale_rounds_up() -> void:
	# Arrange: 1000 px window, 1080 viewport, k = 1.08; left 10 px -> 10.8 -> 11
	var win := Vector2i(1000, 2000)
	var view := Vector2(1080, 2160)
	var safe := Rect2i(10, 0, 990, 2000)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, win, view)
	# Assert
	assert_array(insets).is_equal([11, 0, 0, 0])


# --- insets_for: window not full screen / offset ---

func test_insets_for_offset_window_measures_from_window_edge() -> void:
	# Arrange: window at (100, 200); cutout 100 and bar 50 inside the window
	var pos := Vector2i(100, 200)
	var win := Vector2i(1080, 1920)
	var safe := Rect2i(pos.x, pos.y + 100, win.x, win.y - 100 - 50)
	# Act
	var insets := _insets(safe, pos, win, Vector2(win))
	# Assert
	assert_array(insets).is_equal([0, 100, 0, 50])


func test_insets_for_window_inside_safe_area_returns_zeros() -> void:
	# Arrange: windowed mode, safe area bigger than the window -> negative raw insets
	var win := Vector2i(1080, 1920)
	var safe := Rect2i(-50, -50, 2000, 3000)
	# Act
	var insets := _insets(safe, Vector2i.ZERO, win, Vector2(win))
	# Assert
	assert_array(insets).is_equal([0, 0, 0, 0])


func test_insets_for_window_partly_under_cutout_returns_only_overlap() -> void:
	# Arrange: window starts 60 px below the top of the screen; cutout ends at 110
	var pos := Vector2i(0, 60)
	var win := Vector2i(1080, 1920)
	var safe := Rect2i(0, CUTOUT, win.x, 3000)
	# Act
	var insets := _insets(safe, pos, win, Vector2(win))
	# Assert: only 110 - 60 = 50 px of the window is covered at the top
	assert_array(insets).is_equal([0, 50, 0, 0])


# --- margin_for ---

func test_margin_for_zero_inset_returns_base() -> void:
	# Arrange / Act
	var result := SafeAreaMargins.margin_for(BASE_TOP, 0, AIR)
	# Assert
	assert_int(result).is_equal(BASE_TOP)


func test_margin_for_negative_inset_returns_base() -> void:
	# Arrange / Act
	var result := SafeAreaMargins.margin_for(BASE_TOP, -5, AIR)
	# Assert
	assert_int(result).is_equal(BASE_TOP)


func test_margin_for_small_inset_keeps_base() -> void:
	# Arrange: 10 + 24 = 34 < 48
	# Act
	var result := SafeAreaMargins.margin_for(BASE_LEFT, 10, AIR)
	# Assert
	assert_int(result).is_equal(BASE_LEFT)


func test_margin_for_inset_plus_air_equal_to_base_returns_base() -> void:
	# Arrange: boundary, 24 + 24 == 48
	# Act
	var result := SafeAreaMargins.margin_for(BASE_LEFT, BASE_LEFT - AIR, AIR)
	# Assert
	assert_int(result).is_equal(BASE_LEFT)


func test_margin_for_cutout_above_base_returns_inset_plus_air() -> void:
	# Arrange: 110 + 24 = 134 > 96
	# Act
	var result := SafeAreaMargins.margin_for(BASE_TOP, CUTOUT, AIR)
	# Assert
	assert_int(result).is_equal(CUTOUT + AIR)


func test_margin_for_gesture_bar_above_base_returns_inset_plus_air() -> void:
	# Arrange: 60 + 24 = 84 > 72
	# Act
	var result := SafeAreaMargins.margin_for(BASE_BOTTOM, GESTURE_BAR, AIR)
	# Assert
	assert_int(result).is_equal(GESTURE_BAR + AIR)


func test_margin_for_zero_air_with_positive_inset_returns_max_of_base_and_inset() -> void:
	# Arrange
	var inset := 200
	# Act
	var result := SafeAreaMargins.margin_for(BASE_TOP, inset, 0)
	# Assert
	assert_int(result).is_equal(inset)


# --- combined: headless and phone pipelines ---

func test_margins_headless_empty_safe_area_gives_base_fields() -> void:
	# Arrange
	var insets := SafeAreaMargins.insets_for(Rect2i(), Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Act
	var margins := [
		SafeAreaMargins.margin_for(BASE_LEFT, insets[0], AIR),
		SafeAreaMargins.margin_for(BASE_TOP, insets[1], AIR),
		SafeAreaMargins.margin_for(BASE_RIGHT, insets[2], AIR),
		SafeAreaMargins.margin_for(BASE_BOTTOM, insets[3], AIR),
	]
	# Assert: 48 / 96 / 48 / 72
	assert_array(margins).is_equal([BASE_LEFT, BASE_TOP, BASE_RIGHT, BASE_BOTTOM])


func test_margins_phone_1080x2400_gives_expected_fields() -> void:
	# Arrange
	var insets := SafeAreaMargins.insets_for(_phone_safe(), Vector2i.ZERO, PHONE_WIN, PHONE_VIEW)
	# Act
	var margins := [
		SafeAreaMargins.margin_for(BASE_LEFT, insets[0], AIR),
		SafeAreaMargins.margin_for(BASE_TOP, insets[1], AIR),
		SafeAreaMargins.margin_for(BASE_RIGHT, insets[2], AIR),
		SafeAreaMargins.margin_for(BASE_BOTTOM, insets[3], AIR),
	]
	# Assert: left/right keep base; top 110+24; bottom 60+24
	assert_array(margins).is_equal([BASE_LEFT, CUTOUT + AIR, BASE_RIGHT, GESTURE_BAR + AIR])
