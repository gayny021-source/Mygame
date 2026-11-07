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
## A scene whose script fails to parse still loads in Godot 4.7.2 (checked):
## the node simply runs without its script. So every script the file depends
## on — directly or through nested scenes and resources, followed recursively —
## is loaded too, and a script that cannot instantiate fails the file
## (`SCRIPT FAIL: <script> (in <path>)`). Shaders are NOT judged here: a broken
## shader still loads as a Shader; its errors only show as engine
## `SHADER ERROR` lines above the result.
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
		if not _scripts_ok(path):
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


## Loads every script `path` depends on, following nested .tscn/.tres files;
## false if any script fails to parse.
func _scripts_ok(path: String) -> bool:
	var ok := true
	var visited := {}
	var queue: Array[String] = [path]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		for dep in ResourceLoader.get_dependencies(current):
			var dep_path: String = dep.get_slice("::", dep.get_slice_count("::") - 1)
			if dep_path.ends_with(".tscn") or dep_path.ends_with(".tres"):
				queue.append(dep_path)
				continue
			if not dep_path.ends_with(".gd"):
				continue
			var script_res := ResourceLoader.load(dep_path, "", ResourceLoader.CACHE_MODE_IGNORE)
			var broken := script_res == null
			if script_res is Script:
				broken = not (script_res as Script).can_instantiate()
			if broken:
				printerr("SCRIPT FAIL: ", dep_path, " (in ", current, ", checked for ", path, ")")
				ok = false
	return ok
