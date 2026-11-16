class_name SaveCodec
extends RefCounted
## Slot codec (save-system.md, rule 2, rule 8 items 1-4, F1, F2; ADR-0002 §1, §2; story SV1). A slot
## is a 48-byte header — `KPSV`, format_version u32 LE, gen u64 LE, SHA-256 of bytes 4…15 and of the
## body — then the body as UTF-8 JSON. Pure: no files, no threads; the writer hands the bytes to SaveIo.
##
## Usage: [code]var read := SaveCodec.decode(bytes, SaveCodec.slot_of(gen), 1, "rovend")[/code]

const MAGIC := "KPSV"
const HEADER_SIZE: int = 48
## End of the hashed head: format_version and gen (bytes 4…15) are hashed with the body.
const HEAD_END: int = 16
## 2^53 − 1, the largest whole number JSON keeps exactly (F1).
const MAX_GEN: int = 9007199254740991


## One slot read and checked by rule 2.
class SlotRead extends RefCounted:
	enum Status { VALID, INVALID, TOO_NEW }

	var status: Status = Status.INVALID
	## Header values; meaningful only when the slot is not INVALID.
	var version: int
	var gen: int
	## Parsed body; empty unless VALID (a TOO_NEW body is not parsed).
	var body: Dictionary = {}


## Choice between the two slots of one file (F2; rule 8 items 2-4).
class Pick extends RefCounted:
	enum Code { OK, EMPTY, CORRUPT, TOO_NEW }

	var code: Code
	## Chosen slot: 0 is `_a`, 1 is `_b`; -1 when none.
	var slot: int = -1
	## Largest gen among the valid slots, a TOO_NEW slot included (AC-43); 0 when none.
	var gen_max: int


## Slot of a generation: 0 (`_a`) for an even gen, 1 (`_b`) for an odd one (F1).
static func slot_of(gen: int) -> int:
	return gen % 2


## Slot bytes of `body` with the header of `version` and `gen`. The body is serialized now (AC-15).
static func encode(version: int, gen: int, body: Dictionary) -> PackedByteArray:
	var payload: PackedByteArray = JSON.stringify(body).to_utf8_buffer()
	var bytes: PackedByteArray = MAGIC.to_ascii_buffer()
	bytes.resize(HEAD_END)
	bytes.encode_u32(4, version)
	bytes.encode_u64(8, gen)
	var digest: PackedByteArray = _sum(bytes, payload)
	bytes.append_array(digest)
	bytes.append_array(payload)
	return bytes


## Reads the bytes of slot `slot` (0 `_a`, 1 `_b`). VALID: magic, version 1…`app_version`, gen
## 1…2^53 − 1 of the slot's parity, the sum, a JSON object, and its `hero` equal to `expect_hero`
## (not checked when empty: Gallery, Settings). A newer version with a valid header is TOO_NEW and its
## body is not parsed. Anything else, a cut or empty file included, is INVALID.
static func decode(bytes: PackedByteArray, slot: int, app_version: int, expect_hero: String = "") -> SlotRead:
	var read: SlotRead = SlotRead.new()
	if bytes.size() <= HEADER_SIZE or bytes.slice(0, 4) != MAGIC.to_ascii_buffer():
		return read
	read.version = bytes.decode_u32(4)
	read.gen = bytes.decode_u64(8)
	if read.version < 1 or read.gen < 1 or read.gen > MAX_GEN or slot_of(read.gen) != slot:
		return read
	var payload: PackedByteArray = bytes.slice(HEADER_SIZE)
	if _sum(bytes, payload) != bytes.slice(HEAD_END, HEADER_SIZE):
		return read
	if read.version > app_version:
		read.status = SlotRead.Status.TOO_NEW
		return read
	# JSON.parse_string печатает ERROR на битом тексте; экземпляр JSON молчит.
	var json: JSON = JSON.new()
	if json.parse(payload.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return read
	var body: Dictionary = json.data
	var hero: Variant = body.get("hero")
	if not expect_hero.is_empty() and not (hero is String and hero == expect_hero):
		return read
	read.body = body
	read.status = SlotRead.Status.VALID
	return read


## F2 and rule 8 items 2-4 over the two slots of a file; `null` is a missing file. The valid slot
## (TOO_NEW counts) with the largest gen is chosen; a chosen TOO_NEW slot is TOO_NEW, no fallback.
## No valid slot: no file or a lone invalid `_b` (killed inside the first write) is EMPTY, else CORRUPT.
static func pick(a: SlotRead, b: SlotRead) -> Pick:
	var result: Pick = Pick.new()
	var reads: Array[SlotRead] = [a, b]
	for slot: int in reads.size():
		var read: SlotRead = reads[slot]
		if read != null and read.status != SlotRead.Status.INVALID and read.gen > result.gen_max:
			result.gen_max = read.gen
			result.slot = slot
	if result.slot >= 0 and reads[result.slot].status == SlotRead.Status.TOO_NEW:
		result.code = Pick.Code.TOO_NEW
	elif result.slot >= 0:
		result.code = Pick.Code.OK
	elif a == null:
		result.code = Pick.Code.EMPTY
	else:
		result.code = Pick.Code.CORRUPT
	return result


static func _sum(head: PackedByteArray, payload: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(head.slice(4, HEAD_END))
	context.update(payload)
	return context.finish()
