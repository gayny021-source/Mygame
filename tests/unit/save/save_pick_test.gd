extends GdUnitTestSuite
## Unit tests for SaveCodec.pick on slot bytes (save-system.md, rule 8 items 1-4, F2; ADR-0002 §1;
## story SV1): AC-26…AC-30 at the codec level; `null` stands for a missing file.

const SLOT_A: int = 0
const SLOT_B: int = 1
const OK_CODE := SaveCodec.Pick.Code.OK
const EMPTY := SaveCodec.Pick.Code.EMPTY
const CORRUPT := SaveCodec.Pick.Code.CORRUPT
const TOO_NEW := SaveCodec.Pick.Code.TOO_NEW


func _bytes(gen: int, version: int = 1) -> PackedByteArray:
	return SaveCodec.encode(version, gen, SaveFixtures.body().to_dict())


func _read(bytes: PackedByteArray, slot: int) -> SaveCodec.SlotRead:
	return SaveCodec.decode(bytes, slot, SaveFixtures.APP_VERSION, SaveFixtures.HERO)


func _slot(gen: int, version: int = 1) -> SaveCodec.SlotRead:
	return _read(_bytes(gen, version), SaveCodec.slot_of(gen))


## Cut in the middle of the body, as a write killed halfway.
func _cut(gen: int) -> SaveCodec.SlotRead:
	var bytes: PackedByteArray = _bytes(gen)
	return _read(bytes.slice(0, 48 + (bytes.size() - 48) / 2), SaveCodec.slot_of(gen))


func _empty_file(slot: int) -> SaveCodec.SlotRead:
	return _read(PackedByteArray(), slot)


func _assert_pick(pick: SaveCodec.Pick, code: SaveCodec.Pick.Code, slot: int, gen_max: int) -> void:
	assert_int(pick.code).is_equal(code)
	assert_int(pick.slot).is_equal(slot)
	assert_int(pick.gen_max).is_equal(gen_max)


func test_ac26_both_valid_takes_the_largest_gen() -> void:
	_assert_pick(SaveCodec.pick(_slot(14), _slot(15)), OK_CODE, SLOT_B, 15)


func test_ac27_newest_cut_takes_the_previous_and_next_gen_overwrites_the_cut() -> void:
	# Act
	var pick: SaveCodec.Pick = SaveCodec.pick(_slot(14), _cut(15))
	# Assert
	_assert_pick(pick, OK_CODE, SLOT_A, 14)
	assert_int(SaveCodec.slot_of(pick.gen_max + 1)).is_equal(SLOT_B)


func test_ac27_older_a_broken_takes_b_and_next_gen_goes_to_a() -> void:
	# Act
	var pick: SaveCodec.Pick = SaveCodec.pick(_cut(14), _slot(15))
	# Assert
	_assert_pick(pick, OK_CODE, SLOT_B, 15)
	assert_int(SaveCodec.slot_of(pick.gen_max + 1)).is_equal(SLOT_A)


func test_ac28_both_invalid_is_corrupt() -> void:
	_assert_pick(SaveCodec.pick(_cut(14), _cut(15)), CORRUPT, -1, 0)


func test_ac28_lone_empty_a_is_corrupt() -> void:
	_assert_pick(SaveCodec.pick(_empty_file(SLOT_A), null), CORRUPT, -1, 0)


func test_ac28_lone_invalid_b_is_empty() -> void:
	_assert_pick(SaveCodec.pick(null, _empty_file(SLOT_B)), EMPTY, -1, 0)
	_assert_pick(SaveCodec.pick(null, _cut(1)), EMPTY, -1, 0)


func test_ac29_no_files_is_empty() -> void:
	_assert_pick(SaveCodec.pick(null, null), EMPTY, -1, 0)


func test_ac29_one_valid_file_of_two_is_ok() -> void:
	_assert_pick(SaveCodec.pick(null, _slot(1)), OK_CODE, SLOT_B, 1)


func test_ac30_newest_of_newer_version_is_too_new_without_fallback() -> void:
	_assert_pick(SaveCodec.pick(_slot(14), _slot(15, 2)), TOO_NEW, SLOT_B, 15)


func test_newer_version_older_than_a_valid_slot_is_ok() -> void:
	# Arrange: a pair of transition 6 cut after its first write over a newer version slot
	_assert_pick(SaveCodec.pick(_slot(16), _slot(15, 2)), OK_CODE, SLOT_A, 16)


func test_newer_version_beside_invalid_counts_for_gen_max() -> void:
	_assert_pick(SaveCodec.pick(_cut(14), _slot(15, 2)), TOO_NEW, SLOT_B, 15)
