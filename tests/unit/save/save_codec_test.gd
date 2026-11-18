extends GdUnitTestSuite
## Unit tests for SaveCodec.encode and decode (save-system.md, rule 2, F1; ADR-0002 §2; story SV1):
## AC-01, AC-02, AC-03, AC-08, AC-61 on bytes, without the writer.

const SLOT_A: int = 0
const SLOT_B: int = 1
const VALID := SaveCodec.SlotRead.Status.VALID
const INVALID := SaveCodec.SlotRead.Status.INVALID
const TOO_NEW := SaveCodec.SlotRead.Status.TOO_NEW
## 2^53 − 1, the upper bound of gen (F1).
const GEN_MAX: int = 9007199254740991


func _body() -> Dictionary:
	return SaveFixtures.raw_body()


func _decode(bytes: PackedByteArray, slot: int) -> SaveCodec.SlotRead:
	return SaveCodec.decode(bytes, slot, SaveFixtures.APP_VERSION, SaveFixtures.HERO)


func _changed(bytes: PackedByteArray, index: int) -> PackedByteArray:
	var copy: PackedByteArray = bytes.duplicate()
	copy[index] = copy[index] ^ 0x02
	return copy


func test_ac01_header_has_magic_version_gen_and_sum_of_head_and_body() -> void:
	# Act
	var bytes: PackedByteArray = SaveCodec.encode(1, 1, _body())
	# Assert
	assert_str(bytes.slice(0, 4).get_string_from_ascii()).is_equal("KPSV")
	assert_int(bytes.decode_u32(4)).is_equal(1)
	assert_int(bytes.decode_u64(8)).is_equal(1)
	assert_str(bytes.slice(16, 48).hex_encode()).is_equal(SaveFixtures.sum(bytes).hex_encode())


func test_ac61_body_is_utf8_json_without_gen_and_version() -> void:
	# Act
	var bytes: PackedByteArray = SaveCodec.encode(1, 14, _body())
	# Assert
	var json: JSON = JSON.new()
	assert_int(json.parse(bytes.slice(48).get_string_from_utf8())).is_equal(OK)
	var body: Dictionary = json.data
	assert_str(body["hero"]).is_equal(SaveFixtures.HERO)
	assert_bool(body.has("gen")).is_false()
	assert_bool(body.has("format_version")).is_false()


func test_decode_valid_slot_gives_version_gen_and_body() -> void:
	# Arrange
	var body: Dictionary = _body()
	# Act
	var read: SaveCodec.SlotRead = _decode(SaveCodec.encode(1, 14, body), SLOT_A)
	# Assert
	assert_int(read.status).is_equal(VALID)
	assert_int(read.version).is_equal(1)
	assert_int(read.gen).is_equal(14)
	assert_str(read.body["run_id"]).is_equal(body["run_id"])


func test_ac02_one_byte_changed_in_magic_version_gen_sum_or_body_is_invalid() -> void:
	# Arrange: version 1 → 3 would be TOO_NEW and gen 14 → 16 keeps the parity: only the sum catches them
	var good: PackedByteArray = SaveCodec.encode(1, 14, _body())
	var gen_16: PackedByteArray = good.duplicate()
	gen_16.encode_u64(8, 16)
	var cases: Dictionary[String, PackedByteArray] = {
		"magic": _changed(good, 0), "version": _changed(good, 4), "gen 14→16": gen_16,
		"sum": _changed(good, 16), "body": _changed(good, 60),
	}
	assert_int(_decode(good, SLOT_A).status).is_equal(VALID)
	for part: String in cases:
		# Act
		var read: SaveCodec.SlotRead = _decode(cases[part], SLOT_A)
		# Assert
		assert_int(read.status).override_failure_message(part).is_equal(INVALID)
		assert_dict(read.body).override_failure_message(part).is_empty()


func test_ac03_odd_gen_in_slot_a_is_invalid() -> void:
	# Arrange
	var bytes: PackedByteArray = SaveCodec.encode(1, 15, _body())
	# Act + Assert
	assert_int(_decode(bytes, SLOT_A).status).is_equal(INVALID)
	assert_int(_decode(bytes, SLOT_B).status).is_equal(VALID)


func test_ac03_other_hero_in_body_is_invalid_and_gives_no_body() -> void:
	# Arrange: the sum is right, the hero is not the one of the file name
	var body: Dictionary = _body()
	body["hero"] = "other"
	# Act
	var read: SaveCodec.SlotRead = _decode(SaveCodec.encode(1, 14, body), SLOT_A)
	# Assert
	assert_int(read.status).is_equal(INVALID)
	assert_dict(read.body).is_empty()


func test_no_expected_hero_accepts_only_a_body_without_hero() -> void:
	# Act: Gallery and Settings bodies have no hero; a run body read without its hero fails closed (TD C4)
	var gallery: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 2, {"entries": []}), SLOT_A, 1)
	var run: SaveCodec.SlotRead = SaveCodec.decode(SaveCodec.encode(1, 2, _body()), SLOT_A, 1)
	# Assert
	assert_int(gallery.status).is_equal(VALID)
	assert_dict(gallery.body).contains_keys(["entries"])
	assert_int(run.status).is_equal(INVALID)


func test_newer_version_is_too_new_by_header_and_body_not_parsed() -> void:
	# Arrange: the body of a future version is not JSON at all, the sum is right
	var bytes: PackedByteArray = SaveFixtures.raw_slot(2, 15, "{future".to_utf8_buffer())
	# Act
	var read: SaveCodec.SlotRead = _decode(bytes, SLOT_B)
	# Assert
	assert_int(read.status).is_equal(TOO_NEW)
	assert_int(read.version).is_equal(2)
	assert_int(read.gen).is_equal(15)
	assert_dict(read.body).is_empty()


func test_newer_version_with_broken_sum_or_parity_is_invalid() -> void:
	# Arrange
	var bytes: PackedByteArray = SaveFixtures.raw_slot(2, 15, "{}".to_utf8_buffer())
	# Act + Assert
	assert_int(_decode(_changed(bytes, 20), SLOT_B).status).is_equal(INVALID)
	assert_int(_decode(bytes, SLOT_A).status).is_equal(INVALID)


func test_empty_or_cut_bytes_are_invalid() -> void:
	# Arrange
	var good: PackedByteArray = SaveCodec.encode(1, 14, _body())
	for size: int in [0, 3, 16, 47, 48, 48 + (good.size() - 48) / 2, good.size() - 1]:
		# Act
		var read: SaveCodec.SlotRead = _decode(good.slice(0, size), SLOT_A)
		# Assert
		assert_int(read.status).override_failure_message("size %d" % size).is_equal(INVALID)


func test_right_sum_over_broken_json_or_array_root_is_invalid() -> void:
	for payload: String in ["{bad", "[1, 2]", "\"rovend\""]:
		# Act
		var read: SaveCodec.SlotRead = _decode(SaveFixtures.raw_slot(1, 14, payload.to_utf8_buffer()), SLOT_A)
		# Assert
		assert_int(read.status).override_failure_message(payload).is_equal(INVALID)


func test_version_0_gen_0_or_gen_beyond_2_53_is_invalid() -> void:
	# Arrange
	var payload: PackedByteArray = JSON.stringify({"hero": SaveFixtures.HERO}).to_utf8_buffer()
	# Act + Assert
	assert_int(_decode(SaveFixtures.raw_slot(0, 14, payload), SLOT_A).status).is_equal(INVALID)
	assert_int(_decode(SaveFixtures.raw_slot(1, 0, payload), SLOT_A).status).is_equal(INVALID)
	assert_int(_decode(SaveFixtures.raw_slot(1, GEN_MAX + 2, payload), SLOT_B).status).is_equal(INVALID)
	assert_int(_decode(SaveFixtures.raw_slot(1, 14, payload), SLOT_A).status).is_equal(VALID)


func test_ac08_slot_of_gen() -> void:
	var expected: Dictionary[int, int] = {14: SLOT_A, 15: SLOT_B, 1: SLOT_B, 2: SLOT_A, GEN_MAX: SLOT_B}
	for gen: int in expected:
		assert_int(SaveCodec.slot_of(gen)).override_failure_message("gen %d" % gen).is_equal(expected[gen])


func test_largest_gen_round_trips() -> void:
	# Act
	var read: SaveCodec.SlotRead = _decode(SaveCodec.encode(1, GEN_MAX, _body()), SLOT_B)
	# Assert
	assert_int(read.status).is_equal(VALID)
	assert_int(read.gen).is_equal(GEN_MAX)
