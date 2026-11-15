extends GdUnitTestSuite
## Pins the Godot 4.7.2 file behaviour that ADR-0001 lists as NOT SOURCEABLE (Engine
## Compatibility) and that the story loaders rely on. A red test here means the
## engine changed under the loader, not that the loader is wrong. The probes that
## need no file are in tests/unit/story/story_json_engine_test.gd.


func test_file_access_reads_fixture_from_res_in_headless() -> void:
	# Act
	var file: FileAccess = FileAccess.open(StoryFixtures.DT02_ROOT_ARRAY, FileAccess.READ)
	# Assert
	assert_object(file).is_not_null()
	assert_str(file.get_as_text()).starts_with("[\"корень файла")


func test_file_access_open_missing_file_returns_null_and_open_error() -> void:
	# Act
	var file: FileAccess = FileAccess.open(StoryFixtures.MISSING_FILE, FileAccess.READ)
	# Assert
	assert_object(file).is_null()
	assert_int(FileAccess.get_open_error()).is_equal(ERR_FILE_NOT_FOUND)


func test_file_access_file_exists_tells_fixture_from_missing_file() -> void:
	# Act: why HeroLoader can tell a chapter without a file (BS-01) from a broken one (DT-01)
	var present: bool = FileAccess.file_exists(StoryFixtures.DT02_ROOT_ARRAY)
	var absent: bool = FileAccess.file_exists(StoryFixtures.MISSING_FILE)
	# Assert
	assert_bool(present).is_true()
	assert_bool(absent).is_false()
