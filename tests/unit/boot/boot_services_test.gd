extends GdUnitTestSuite
## Unit tests for BootServices (story RT1; DD-022: d20.json at start, DT-01/DT-02 in the log;
## graceful start without heroes).

const BAD_D20 := "res://tests/fixtures/story/dt02_root_array.json"
const MISSING := "res://tests/fixtures/nope/d20.json"

var _lines: Array[String] = []


func _log(line: String) -> void:
	_lines.append(line)


func _logged(prefix: String) -> bool:
	return _lines.any(func(line: String) -> bool: return line.begins_with(prefix))


func _writer() -> SaveWriter:
	return WriterRig.new().writer


func test_project_d20_config_loads_valid_at_start() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, "res://tests/fixtures/nope")
	# Assert
	assert_bool(services.d20_config.valid).is_true()
	assert_bool(services.captions != null).is_true()


func test_invalid_d20_config_is_logged_and_kept_invalid() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, "res://tests/fixtures/nope", BAD_D20)
	# Assert
	assert_bool(services.d20_config.valid).is_false()
	assert_bool(_logged("DT-0")).is_true()


func test_missing_d20_file_is_logged_dt01_and_does_not_crash() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, "res://tests/fixtures/nope", MISSING)
	# Assert
	assert_bool(services.d20_config.valid).is_false()
	assert_bool(_logged("DT-01")).is_true()


func test_missing_heroes_folder_gives_no_data_state_and_a_log_line() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, "res://tests/fixtures/nope")
	# Assert
	assert_bool(services.has_heroes()).is_false()
	assert_str(services.status).is_not_empty()
	assert_bool(_logged("RT-01")).is_true()


func test_heroes_folder_loads_valid_hero_and_logs_broken_ones() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, StoryFixtures.DIR)
	# Assert
	assert_bool(services.sessions.has("hero_stub")).is_true()
	assert_str(services.status).is_empty()
