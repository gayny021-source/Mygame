extends GdUnitTestSuite
## Headless probe of ThreadSaveIo on the real `user://` (ADR-0002 §4, Risks: WorkerThreadPool and FileAccess
## are NOT SOURCEABLE in docs/engine-reference, so this test is their proof; story SV4): write twice ->
## a new writer over a new ThreadSaveIo loads the newest -> the slot files are byte-for-byte the same
## after the load (rule 8, AC-38). The files are removed after each test.

const HERO := "disk_probe"
const KEY := "run_disk_probe"
const LIMIT_FRAMES: int = 5000

var _lines: PackedStringArray = []


func after_test() -> void:
	for slot: int in 2:
		var path: String = ProjectSettings.globalize_path(SaveWriter.path_of(KEY, slot))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _writer() -> SaveWriter:
	return SaveWriter.new(ThreadSaveIo.new(), SaveFixtures.APP_VERSION, func(line: String) -> void: _lines.append(line), 2000)


# Pumps with the real clock until `done` is true; false when the frames ran out.
func _until(writer: SaveWriter, done: Callable) -> bool:
	for frame: int in LIMIT_FRAMES:
		writer.pump(Time.get_ticks_msec())
		if done.call():
			return true
		OS.delay_msec(1)
	return false


func _hashes() -> PackedStringArray:
	var result: PackedStringArray = []
	for slot: int in 2:
		result.append(FileAccess.get_sha256(SaveWriter.path_of(KEY, slot)))
	return result


func test_two_writes_then_a_load_by_a_new_instance_return_the_newest_body_and_change_no_file() -> void:
	# Arrange
	var outcomes: Array[int] = []
	var writer: SaveWriter = _writer()
	writer.write_finished.connect(func(_ticket: int, outcome: int) -> void: outcomes.append(outcome))
	var issues: Array[DataIssue] = []
	writer.commit(1, HERO, WriterRig.run("R1", HERO), issues)
	assert_bool(_until(writer, func() -> bool: return outcomes.size() == 1)).is_true()
	writer.commit(1, HERO, WriterRig.run("R2", HERO), issues)
	assert_bool(_until(writer, func() -> bool: return outcomes.size() == 2)).is_true()
	var hashes: PackedStringArray = _hashes()
	var codes: Array[int] = []
	var bodies: Array[Dictionary] = []
	var fresh: SaveWriter = _writer()
	fresh.load_finished.connect(func(_token: int, code: int, body: Dictionary) -> void:
		codes.append(code)
		bodies.append(body))
	# Act
	fresh.load_run(HERO)
	assert_bool(_until(fresh, func() -> bool: return not codes.is_empty())).is_true()
	# Assert
	assert_array(outcomes).contains_exactly([SaveWriter.Outcome.OK, SaveWriter.Outcome.OK])
	assert_int(codes[0]).is_equal(SaveWriter.LoadCode.OK)
	assert_str(bodies[0]["run_id"]).is_equal("R2")
	assert_array(_hashes()).is_equal(hashes)
	assert_bool(hashes[0].is_empty() or hashes[1].is_empty()).is_false()


func test_load_of_a_hero_with_no_files_is_empty() -> void:
	# Arrange
	var codes: Array[int] = []
	var writer: SaveWriter = _writer()
	writer.load_finished.connect(func(_token: int, code: int, _body: Dictionary) -> void: codes.append(code))
	# Act
	writer.load_run(HERO)
	assert_bool(_until(writer, func() -> bool: return not codes.is_empty())).is_true()
	# Assert
	assert_int(codes[0]).is_equal(SaveWriter.LoadCode.EMPTY)


func test_a_start_while_a_task_runs_is_refused_and_the_running_one_finishes() -> void:
	# Arrange
	var io: ThreadSaveIo = ThreadSaveIo.new()
	var bytes: PackedByteArray = "x".to_ascii_buffer()
	# Act
	var first: bool = io.start_write(SaveWriter.path_of(KEY, 0), bytes)
	var second: bool = io.start_write(SaveWriter.path_of(KEY, 1), bytes)
	var read: bool = io.start_read(PackedStringArray([SaveWriter.path_of(KEY, 0)]))
	var done: SaveIo.IoDone = null
	for frame: int in LIMIT_FRAMES:
		done = io.poll()
		if done != null:
			break
		OS.delay_msec(1)
	# Assert (TD C5, round 2: the refusal is reported)
	assert_bool(first).is_true()
	assert_bool(second).is_false()
	assert_bool(read).is_false()
	assert_object(done).is_not_null()
	assert_bool(done.ok).is_true()
	assert_bool(FileAccess.file_exists(SaveWriter.path_of(KEY, 0))).is_true()
	assert_bool(FileAccess.file_exists(SaveWriter.path_of(KEY, 1))).is_false()
