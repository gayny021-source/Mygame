extends GdUnitTestSuite
## Unit tests for BootServices (story RT1; DD-022: d20.json at start, DT-01/DT-02 in the log;
## graceful start without heroes; C5: broken captions, empty save config).

const BAD_D20 := "res://tests/fixtures/story/dt02_root_array.json"
const BROKEN := "res://tests/fixtures/story/dt01_broken.json"
const MISSING := "res://tests/fixtures/nope/d20.json"
const NO_HEROES := "res://tests/fixtures/nope"

var _lines: Array[String] = []


func before_test() -> void:
	_lines.clear()


func _log(line: String) -> void:
	_lines.append(line)


func _logged(prefix: String) -> bool:
	return _lines.any(func(line: String) -> bool: return line.begins_with(prefix))


func _writer() -> SaveWriter:
	return WriterRig.new().writer


func test_project_d20_config_loads_valid_at_start() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, NO_HEROES)
	# Assert
	assert_bool(services.d20_config.valid).is_true()
	assert_int(services.d20_config.dc_easy).is_equal(11)
	assert_object(services.captions).is_not_null()
	assert_object(services.d20).is_not_null()
	assert_bool(_logged("DT-")).is_false()


func test_invalid_d20_config_is_logged_and_kept_invalid() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, NO_HEROES, BAD_D20)
	# Assert
	assert_bool(services.d20_config.valid).is_false()
	assert_bool(_logged(services.d20_config.issue_code)).is_true()
	assert_bool(_logged("DT-0")).is_true()


func test_missing_d20_file_is_logged_dt01_and_does_not_crash() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, NO_HEROES, MISSING)
	# Assert
	assert_bool(services.d20_config.valid).is_false()
	assert_str(services.d20_config.issue_code).is_equal("DT-01")
	assert_bool(_logged("DT-01")).is_true()


func test_broken_captions_file_is_logged_and_boot_continues() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, NO_HEROES, D20Config.PATH, BROKEN)
	# Assert
	assert_bool(_logged("DT-")).is_true()
	assert_object(services.captions).is_not_null()
	assert_bool(services.d20_config.valid).is_true()


func test_missing_heroes_folder_gives_no_data_state_and_a_log_line() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, NO_HEROES)
	# Assert
	assert_dict(services.sessions).is_empty()
	assert_str(services.status).is_equal("Нет данных героев")
	assert_bool(_logged("RT-01")).is_true()


func test_heroes_folder_loads_valid_hero_and_logs_broken_ones() -> void:
	# Act
	var services: BootServices = BootServices.build(_writer(), _log, StoryFixtures.DIR)
	# Assert
	assert_object(services.sessions.get("hero_stub")).is_not_null()
	assert_str(services.status).is_empty()
	assert_bool(_logged("RT-01")).is_false()


func test_empty_save_config_keeps_default_wait_and_reports_an_issue() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var config: SaveConfig = SaveConfig.from_dict({}, "save.json", issues)
	# Assert
	assert_int(config.wait_ms).is_equal(SaveConfig.DEFAULT_WAIT_MS)
	assert_bool(issues.is_empty()).is_false()
