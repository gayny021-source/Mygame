extends GdUnitTestSuite
## Unit tests for ThemeScale and the reading theme fonts (story RT1; reading-screen.md: 200 % = font size multiplier).

const THEME := "res://src/ui/reading_theme.tres"


func test_theme_uses_literata_regular_as_default_font() -> void:
	# Arrange
	var theme: Theme = load(THEME)
	# Assert
	assert_str(theme.default_font.resource_path).is_equal("res://assets/fonts/Literata-Regular.ttf")


func test_rich_text_bold_and_italic_and_title_variation_fonts_are_wired() -> void:
	# Arrange
	var theme: Theme = load(THEME)
	# Assert
	assert_str(theme.get_font(&"bold_font", &"RichTextLabel").resource_path).contains("Literata-Bold")
	assert_str(theme.get_font(&"italics_font", &"RichTextLabel").resource_path).contains("Literata-Italic")
	assert_str(theme.get_font(&"font", &"TitleLabel").resource_path).contains("YesevaOne")
	assert_str(theme.get_type_variation_base(&"TitleLabel")).is_equal("Label")


func test_scale_200_doubles_every_font_size_and_keeps_the_base() -> void:
	# Arrange
	var base: Theme = load(THEME)
	# Act
	var big: Theme = ThemeScale.scaled(base, 2.0)
	# Assert
	assert_int(big.default_font_size).is_equal(96)
	assert_int(big.get_font_size(&"font_size", &"Button")).is_equal(96)
	assert_int(big.get_font_size(&"font_size", &"CaptionLabel")).is_equal(84)
	assert_int(base.get_font_size(&"font_size", &"Button")).is_equal(48)


func test_scale_is_clamped_to_one_and_two() -> void:
	# Arrange
	var base: Theme = load(THEME)
	# Act / Assert
	assert_int(ThemeScale.scaled(base, 0.5).default_font_size).is_equal(48)
	assert_int(ThemeScale.scaled(base, 5.0).default_font_size).is_equal(96)
