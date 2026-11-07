extends SceneTree
## Load-checks Godot scenes (.tscn) and resources (.tres) the way the game loads them.
##
## Usage, from the project root, after `godot --headless --path . --import`:
##
##   godot --headless --path . -s res://.claude/scripts/godot-scene-check.gd -- res://ui/a.tscn res://ui/theme.tres
##
## Prints `ok: <path> ...` or `LOAD FAIL: <path>` per file, with Godot's own
## parse errors above each failure. For a scene it also prints the node tree
## and the connection count, so a reader can compare them with what was meant
## to be written. Exit 0 when every file loads (and every scene instantiates),
## 1 when any does not, 2 when no file was given.
##
## Observations only: a scene that loads can still be laid out wrongly. Layout
## and touch problems are mobile-ux-validator's job, and the look needs a
## screenshot (.claude/docs/run-and-observe.md).


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("godot-scene-check: no files given. Pass res:// paths after `--`.")
		quit(2)
		return
	var failed := 0
	for path in paths:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			printerr("LOAD FAIL: ", path)
			failed += 1
			continue
		if not (res is PackedScene):
			print("ok: ", path, " (", res.get_class(), ")")
			continue
		var ps := res as PackedScene
		var inst: Node = ps.instantiate() if ps.can_instantiate() else null
		if inst == null:
			printerr("LOAD FAIL: ", path, " (cannot instantiate)")
			failed += 1
			continue
		var st := ps.get_state()
		print("ok: ", path, " nodes=", st.get_node_count(), " connections=", st.get_connection_count())
		for i in st.get_node_count():
			print("    ", st.get_node_path(i), " (", st.get_node_type(i), ")")
		inst.free()
	quit(1 if failed > 0 else 0)
