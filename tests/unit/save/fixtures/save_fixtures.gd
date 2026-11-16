class_name SaveFixtures
extends RefCounted
## Fixtures of the save tests (save-system.md, rule 2; ADR-0002 §2, §3; story SV1): the hero
## `rovend`, its flags, a body with every v1 field and slot bytes built without SaveCodec.

const HERO := "rovend"
const APP_VERSION: int = 1
const HEADER_SIZE: int = 48


## One flag of rovend.
static func decl(id: String, category: String = "story", scope: String = FlagDecl.SCOPE_RUN, group: String = "") -> FlagDecl:
	var result: FlagDecl = FlagDecl.new()
	result.id = id
	result.category = category
	result.title = "Название " + id
	result.scope = scope
	result.group = group
	return result


## rovend's flags: a wound, a chapter item, two flags of the group `stance`.
static func decls() -> Array[FlagDecl]:
	var result: Array[FlagDecl] = [
		decl("leg_wound", "wound"),
		decl("torch", "item", FlagDecl.SCOPE_CHAPTER),
		decl("stance_bold", "story", FlagDecl.SCOPE_RUN, "stance"),
		decl("stance_calm", "story", FlagDecl.SCOPE_RUN, "stance"),
	]
	return result


## State after the first `outcomes` of three: wound and torch; bold; calm (the group drops bold).
static func state(outcomes: int = 3, log_error: Callable = Callable()) -> RunState:
	var run: RunState = RunState.new(decls(), log_error)
	if outcomes > 0:
		run.apply_outcome("s_gate", "o_fall", PackedStringArray(["leg_wound", "torch"]), PackedStringArray())
	if outcomes > 1:
		run.apply_outcome("s_bridge", "o_shout", PackedStringArray(["stance_bold"]), PackedStringArray())
	if outcomes > 2:
		run.apply_outcome("s_bridge", "o_breathe", PackedStringArray(["stance_calm"]), PackedStringArray())
	return run


## An applied roll record.
static func roll() -> RollRecord:
	var record: RollRecord = RollRecord.new()
	record.scene_id = "s_bridge"
	record.check_id = "c_jump"
	record.stat_id = "agility"
	record.roll = 14
	record.bonus = 2
	record.dc = 13
	record.rerolled = true
	record.applied = true
	return record


## A body with every v1 field: resume, three schema snapshots, an applied roll record.
static func body() -> RunBody:
	var run_body: RunBody = RunBody.new()
	run_body.run_id = "r_7f3a"
	run_body.hero = HERO
	run_body.resume = RunBody.Snapshot.new(state(), StoryPosition.new("ch_1", "s_bridge", "t_cross"))
	var scenes: Array[String] = ["s_gate", "s_bridge", "s_ford"]
	for i: int in scenes.size():
		run_body.schema.append(RunBody.Snapshot.new(state(i), StoryPosition.new("ch_1", scenes[i])))
	run_body.roll = roll()
	return run_body


## Slot bytes built by the test, not by SaveCodec: the header of ADR-0002 §2 over any payload.
static func raw_slot(version: int, gen: int, payload: PackedByteArray) -> PackedByteArray:
	var bytes: PackedByteArray = "KPSV".to_ascii_buffer()
	bytes.resize(HEADER_SIZE)
	bytes.encode_u32(4, version)
	bytes.encode_u64(8, gen)
	bytes.append_array(payload)
	var digest: PackedByteArray = sum(bytes)
	for i: int in digest.size():
		bytes[16 + i] = digest[i]
	return bytes


## SHA-256 of bytes 4…15 (format_version, gen) and of the body after the header.
static func sum(bytes: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes.slice(4, 16))
	context.update(bytes.slice(HEADER_SIZE))
	return context.finish()
