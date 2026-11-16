extends GdUnitTestSuite
## Unit tests for the argument check of the CLI tools/validate_data.gd (TD S5 round 1, C3): an argument the CLI
## does not know makes it stop with exit 2. The exit code itself needs a process run and is checked by hand.

const Cli := preload("res://tools/validate_data.gd")


func test_known_arguments_pass() -> void:
	# Arrange / Act / Assert
	assert_array(Cli.unknown_args(PackedStringArray(["--freeze", "--root=res://tests/fixtures/story"]))).is_empty()


func test_misspelled_argument_is_unknown() -> void:
	# Arrange / Act / Assert
	assert_array(Cli.unknown_args(PackedStringArray(["--frezee"]))).is_equal(PackedStringArray(["--frezee"]))


func test_root_without_a_folder_is_unknown() -> void:
	# Arrange / Act / Assert
	assert_int(Cli.unknown_args(PackedStringArray(["--root=", "--root"])).size()).is_equal(2)
