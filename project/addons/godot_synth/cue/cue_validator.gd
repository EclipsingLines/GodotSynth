class_name CueValidator
extends RefCounted

## Semantic checks for a parsed cue program.
##
## The parser only guarantees syntax. This walks its AST and reports every
## unknown name, wrong arity or kind, out-of-range value, duplicate declaration,
## bind conflict and invalid mini-notation modifier as a diagnostic with a stable
## code and a 1-based file position.

## Returns diagnostics sorted by (line, col, code). Empty when the file is clean.
static func validate(ast: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
	var run := _Run.new(catalog)
	run.run(ast)
	var sorted: Array[Dictionary] = []
	for diagnostic: Dictionary in run.diags:
		sorted.append(diagnostic)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["line"]) != int(b["line"]):
			return int(a["line"]) < int(b["line"])
		if int(a["col"]) != int(b["col"]):
			return int(a["col"]) < int(b["col"])
		return String(a["code"]) < String(b["code"])
	)
	return sorted


class _Run:
	const KEYWORDS: Array[String] = [
		"tempo", "seed", "let", "param", "state", "transition", "stinger",
		"bind", "on", "fade", "fill", "len", "now", "beat", "bar", "bars",
		"beats",
	]

	const SCALES: Array[String] = [
		"major", "minor", "dorian", "phrygian", "lydian", "mixolydian",
		"locrian", "harmonicMinor", "melodicMinor", "majPent", "minPent",
		"blues", "chromatic",
	]

	var diags: Array[Dictionary] = []
	var lets: Dictionary = {}
	var let_nodes: Dictionary = {}
	var let_uses: Dictionary = {}
	var let_cols: Dictionary = {}
	var let_lines: Dictionary = {}
	var states: Dictionary = {}
	var params: Dictionary = {}
	var stingers: Dictionary = {}
	var catalog: Dictionary = {}
	var control_names: Dictionary = {}
	var _scale_root_re: RegEx

	func _init(p_catalog: Dictionary) -> void:
		catalog = p_catalog
		_scale_root_re = RegEx.new()
		_scale_root_re.compile("^[A-Ga-g][#bs]*[0-9]*$")
		for inst: Variant in catalog.keys():
			var entry: Variant = catalog[inst]
			if not (entry is Dictionary):
				continue
			var controls: Variant = (entry as Dictionary).get("controls", [])
			if controls is Array:
				for control: Variant in controls:
					control_names[String(control)] = true

	func run(ast: Dictionary) -> void:
		var items: Array = ast.get("items", [])

		# Pass 1: declarations. Names are global, so states and params declared
		# later are still visible to earlier references.
		var has_state := false
		var seen_tempo := false
		var seen_seed := false
		var seen_states: Dictionary = {}
		var seen_params: Dictionary = {}
		var seen_stingers: Dictionary = {}
		var seen_lets: Dictionary = {}
		for item: Variant in items:
			if not (item is Dictionary):
				continue
			var node: Dictionary = item
			match String(node.get("type", "")):
				"state":
					has_state = true
					_declare(node, seen_states, states)
				"param":
					_declare(node, seen_params, params)
				"stinger":
					_declare(node, seen_stingers, stingers)
				"let":
					_declare(node, seen_lets, {})
				"tempo":
					if seen_tempo:
						_err("E_DUPLICATE", "tempo is declared more than once",
							_node_line(node), _node_col(node))
					seen_tempo = true
				"seed":
					if seen_seed:
						_err("E_DUPLICATE", "seed is declared more than once",
							_node_line(node), _node_col(node))
					seen_seed = true
		if not has_state:
			_err("E_NO_STATE", "program has no state", 1, 1)

		# Pass 2: walk in file order, resolving lets only after their own value.
		var playing: Array[Dictionary] = []
		var binds: Array[Dictionary] = []
		for item: Variant in items:
			if not (item is Dictionary):
				continue
			var node: Dictionary = item
			match String(node.get("type", "")):
				"tempo":
					var bpm := float(node.get("bpm", 0.0))
					var beats := int(node.get("beats", 0))
					var unit := int(node.get("unit", 0))
					if bpm <= 0.0 or beats < 1 or unit < 1:
						_err("E_RANGE", "tempo must have a positive bpm, beats and unit",
							_node_line(node), _node_col(node))
				"param":
					_check_param(node)
				"let":
					_check_let(node)
				"state":
					var layers: Array = node.get("layers", [])
					for layer: Variant in layers:
						_check_playing_expr(layer, playing)
				"transition":
					_check_transition(node, playing)
				"stinger":
					var expr: Variant = node.get("expr")
					if expr is Dictionary:
						_check_playing_expr(expr, playing)
				"bind":
					_check_bind(node)
					binds.append(node)

		_check_bind_conflicts(playing, binds)

		for name: Variant in lets.keys():
			if int(let_uses.get(name, 0)) == 0:
				_warn("W_UNUSED_LET", "let '%s' is never used" % String(name),
					int(let_lines.get(name, 1)), int(let_cols.get(name, 1)))

	func _declare(node: Dictionary, seen: Dictionary, target: Dictionary) -> void:
		var name := String(node.get("name", ""))
		var line := _node_line(node)
		var col := int(node.get("name_col", _node_col(node)))
		if not _valid_user_name(name):
			_err("E_RESERVED", "'%s' is reserved and cannot be a user name" % name, line, col)
			target[name] = node
			return
		if seen.has(name):
			_err("E_DUPLICATE", "'%s' is declared more than once" % name, line, col)
			return
		seen[name] = true
		target[name] = node

	func _check_param(node: Dictionary) -> void:
		var lo := float(node.get("lo", 0.0))
		var hi := float(node.get("hi", 1.0))
		var line := _node_line(node)
		var name_col := int(node.get("name_col", _node_col(node)))
		if lo >= hi:
			_err("E_RANGE", "param range must be increasing", line, name_col)
			return
		var default_value := float(node.get("default", 0.0))
		if default_value < lo or default_value > hi:
			_err("E_RANGE", "param default is outside its range", line,
				int(node.get("default_col", name_col)))

	func _check_let(node: Dictionary) -> void:
		var name := String(node.get("name", ""))
		var expr: Variant = node.get("expr", {})
		var kind := _expr(expr)
		lets[name] = kind
		let_nodes[name] = expr
		let_uses[name] = 0
		let_cols[name] = int(node.get("name_col", _node_col(node)))
		let_lines[name] = _node_line(node)
		_warn_n_without_scale(expr)

	func _check_playing_expr(node: Variant, playing: Array[Dictionary]) -> void:
		if not (node is Dictionary):
			return
		var expr: Dictionary = node
		var kind := _expr(expr)
		if kind == "transform":
			var start := _start(expr)
			_err("E_KIND", "expected a pattern, got a transform", start.x, start.y)
		_warn_n_without_scale(expr)
		playing.append(expr)

	func _check_transition(node: Dictionary, playing: Array[Dictionary]) -> void:
		var line := _node_line(node)
		var from := String(node.get("from", "*"))
		if from != "*" and not states.has(from):
			_err("E_UNKNOWN_STATE", "unknown state '%s'" % from, line,
				int(node.get("from_col", _node_col(node))))
		var to := String(node.get("to", ""))
		if not states.has(to):
			_err("E_UNKNOWN_STATE", "unknown state '%s'" % to, line,
				int(node.get("to_col", _node_col(node))))
		var fill: Variant = node.get("fill")
		if fill is Dictionary:
			_check_playing_expr(fill, playing)

	func _check_bind(node: Dictionary) -> void:
		var inst := String(node.get("inst", ""))
		var control := String(node.get("control", ""))
		var param := String(node.get("param", ""))
		var line := _node_line(node)
		if not catalog.has(inst):
			_err("E_UNKNOWN_INSTRUMENT", "unknown instrument '%s'" % inst, line,
				int(node.get("inst_col", _node_col(node))))
		else:
			var entry: Variant = catalog.get(inst)
			var controls: Variant = {}
			if entry is Dictionary:
				controls = (entry as Dictionary).get("controls", [])
			var known := controls is Array and (controls as Array).has(control)
			if not known:
				_err("E_UNKNOWN_CONTROL", "unknown control '%s' on '%s'" % [control, inst],
					line, int(node.get("control_col", _node_col(node))))
		if not params.has(param):
			_err("E_UNKNOWN_PARAM", "unknown param '%s'" % param, line,
				int(node.get("param_col", _node_col(node))))

	func _expr(node: Variant) -> String:
		if not (node is Dictionary):
			return "unknown"
		var expr: Dictionary = node
		match String(expr.get("type", "")):
			"number":
				return "number"
			"string":
				_mini_checks(expr)
				return "pattern"
			"name":
				return _expr_name(expr)
			"call":
				return _expr_call(expr)
		return "unknown"

	func _expr_name(node: Dictionary) -> String:
		var name := String(node.get("name", ""))
		if lets.has(name):
			let_uses[name] = int(let_uses.get(name, 0)) + 1
			return String(lets[name])
		if CueLib.FUNCTIONS.has(name):
			var entry: Dictionary = CueLib.FUNCTIONS[name]
			if int(entry.get("min_args", 0)) == 0:
				var kind := String(entry.get("kind", ""))
				if kind == "constructor" or kind == "signal":
					return "pattern"
				if kind == "method":
					return "transform"
			_err("E_ARITY", "'%s' needs arguments" % name,
				_node_line(node), _node_col(node))
			return "unknown"
		_err("E_UNKNOWN_IDENT", "unknown name '%s'" % name,
			_node_line(node), _node_col(node))
		return "unknown"

	func _expr_call(node: Dictionary) -> String:
		var name := String(node.get("name", ""))
		var args: Array = node.get("args", [])
		var receiver: Variant = node.get("receiver")
		var line := _node_line(node)
		var col := _node_col(node)

		if not CueLib.FUNCTIONS.has(name):
			_err("E_UNKNOWN_FUNCTION", "unknown function '%s'" % name, line, col)
			if receiver is Dictionary:
				_expr(receiver)
			for arg: Variant in args:
				_expr(arg)
			return "unknown"

		var entry: Dictionary = CueLib.FUNCTIONS[name]
		var function_kind := String(entry.get("kind", ""))
		var has_receiver := receiver is Dictionary
		var receiver_kind := ""
		if has_receiver:
			receiver_kind = _expr(receiver)

		var also_method := bool(entry.get("also_method", false))
		if has_receiver and not also_method \
				and (function_kind == "constructor" or function_kind == "signal"):
			_err("E_KIND", "'%s' cannot be used as a chain link" % name, line, col)
			return "unknown"

		var min_args := int(entry.get("min_args", 0))
		var max_args := int(entry.get("max_args", 0))
		if args.size() < min_args or (max_args >= 0 and args.size() > max_args):
			_err("E_ARITY", "'%s' takes %s argument(s), got %d" % [
				name,
				str(max_args) if max_args >= 0 else "at least %d" % min_args,
				args.size(),
			], line, col)

		var arg_kinds: Array = entry.get("arg_kinds", [])
		for i: int in range(args.size()):
			var arg: Variant = args[i]
			var actual := _expr(arg)
			if arg_kinds.is_empty():
				continue
			var expected := String(arg_kinds[min(i, arg_kinds.size() - 1)])
			var start := _start(arg)
			if expected == "string":
				var is_string := arg is Dictionary \
						and String((arg as Dictionary).get("type", "")) == "string"
				if not is_string and actual != "unknown":
					_err("E_ARG_TYPE", "expected a string", start.x, start.y)
			elif expected == "numeric" or expected == "pattern":
				if actual == "transform":
					_err("E_KIND", "expected a pattern or number, got a transform",
						start.x, start.y)
			elif expected == "transform":
				if actual == "pattern":
					_err("E_KIND", "expected a transform, got a pattern", start.x, start.y)
				elif actual == "number":
					_err("E_ARG_TYPE", "expected a transform, got a number", start.x, start.y)

		_check_string_call(name, args)

		if not has_receiver:
			if function_kind == "constructor" or function_kind == "signal":
				return "pattern"
			return "transform"

		if function_kind == "constructor" or function_kind == "signal" or function_kind == "method":
			if receiver_kind == "number":
				var start := _start(receiver)
				_err("E_KIND", "cannot call '%s' on a number" % name, start.x, start.y)
				return "unknown"
			return receiver_kind
		return "unknown"

	func _check_string_call(name: String, args: Array) -> void:
		if name != "s" and name != "scale" and name != "game":
			return
		for arg: Variant in args:
			if not (arg is Dictionary):
				continue
			var string_node: Dictionary = arg
			if String(string_node.get("type", "")) != "string":
				continue
			var atoms: Array[Dictionary] = []
			_pattern_atoms(string_node.get("mini"), atoms)
			for atom: Dictionary in atoms:
				var text := String(atom.get("text", ""))
				var line := _node_line(string_node)
				var col := _node_col(string_node) + 1 + int(atom.get("col", 0))
				if name == "s":
					if not catalog.has(text):
						_err("E_UNKNOWN_INSTRUMENT", "unknown instrument '%s'" % text,
							line, col)
				elif name == "scale":
					var suffix := String(atom.get("suffix", ""))
					if not _valid_scale(text, suffix):
						_err("E_UNKNOWN_SCALE", "unknown scale '%s:%s'" % [text, suffix],
							line, col)
				elif name == "game":
					if not params.has(text):
						_err("E_UNKNOWN_PARAM", "unknown param '%s'" % text, line, col)

	func _mini_checks(string_node: Dictionary) -> void:
		_walk_mini(string_node.get("mini"), string_node)

	func _walk_mini(node: Variant, string_node: Dictionary) -> void:
		if not (node is Dictionary):
			return
		var mini: Dictionary = node
		match String(mini.get("type", "")):
			"seq":
				var steps: Array = mini.get("steps", [])
				for step: Variant in steps:
					_walk_mini(step, string_node)
			"choice", "stack":
				var items: Array = mini.get("items", [])
				for item: Variant in items:
					_walk_mini(item, string_node)
			"step":
				_walk_mini(mini.get("term"), string_node)
				var mods: Array = mini.get("mods", [])
				for mod: Variant in mods:
					_walk_mini(mod, string_node)
			"sub":
				_walk_mini(mini.get("item"), string_node)
			"cat":
				var cat_items: Array = mini.get("items", [])
				for item: Variant in cat_items:
					_walk_mini(item, string_node)
			"mod":
				_check_mod(mini, string_node)
				var op := String(mini.get("op", ""))
				var arg: Variant = mini.get("arg")
				if (op == "fast" or op == "slow") and arg is Dictionary \
						and String((arg as Dictionary).get("type", "")) == "cat":
					_walk_mini(arg, string_node)

	func _check_mod(mod: Dictionary, string_node: Dictionary) -> void:
		var bad := false
		match String(mod.get("op", "")):
			"euclid":
				bad = int(mod.get("n", 0)) == 0
			"weight":
				bad = float(mod.get("value", 0.0)) <= 0.0
			"rep":
				bad = int(mod.get("count", 0)) < 1
			"fast", "slow":
				var arg: Variant = mod.get("arg")
				bad = arg is Dictionary and String((arg as Dictionary).get("type", "")) == "number" \
						and float((arg as Dictionary).get("value", 0.0)) <= 0.0
			"degrade":
				var prob := float(mod.get("prob", 0.0))
				bad = prob < 0.0 or prob > 1.0
		if bad:
			_err("E_MINI", "invalid mini-notation modifier '%s'" % String(mod.get("op", "")),
				_node_line(string_node),
				_node_col(string_node) + 1 + int(mod.get("col", 0)))

	func _pattern_atoms(node: Variant, out: Array[Dictionary]) -> void:
		if not (node is Dictionary):
			return
		var mini: Dictionary = node
		match String(mini.get("type", "")):
			"seq":
				var steps: Array = mini.get("steps", [])
				for step: Variant in steps:
					_pattern_atoms(step, out)
			"choice", "stack", "cat":
				var items: Array = mini.get("items", [])
				for item: Variant in items:
					_pattern_atoms(item, out)
			"step":
				_pattern_atoms(mini.get("term"), out)
			"sub":
				_pattern_atoms(mini.get("item"), out)
			"atom":
				out.append(mini)

	func _warn_n_without_scale(node: Variant) -> void:
		var scan := {"first": {}, "scale": false}
		_scan_n_scale(node, scan)
		var first: Dictionary = scan["first"]
		if not first.is_empty() and not bool(scan["scale"]):
			_warn("W_N_WITHOUT_SCALE", "n() is used without scale()",
				_node_line(first), _node_col(first))

	func _scan_n_scale(node: Variant, scan: Dictionary) -> void:
		if not (node is Dictionary):
			return
		var expr: Dictionary = node
		if String(expr.get("type", "")) != "call":
			return
		var name := String(expr.get("name", ""))
		if name == "scale":
			scan["scale"] = true
		if name == "n" and (scan["first"] as Dictionary).is_empty():
			scan["first"] = expr
		var receiver: Variant = expr.get("receiver")
		if receiver is Dictionary:
			_scan_n_scale(receiver, scan)
		var args: Array = expr.get("args", [])
		for arg: Variant in args:
			_scan_n_scale(arg, scan)

	func _check_bind_conflicts(playing: Array[Dictionary], binds: Array[Dictionary]) -> void:
		if playing.is_empty() or binds.is_empty():
			return
		var infos: Array[Dictionary] = []
		for expr: Dictionary in playing:
			infos.append(_info(expr, {}))
		for bind: Dictionary in binds:
			var inst := String(bind.get("inst", ""))
			var control := String(bind.get("control", ""))
			var conflict := false
			for info: Dictionary in infos:
				var insts: Dictionary = info["insts"]
				var controls: Dictionary = info["controls"]
				if insts.has(inst) and controls.has(control):
					conflict = true
					break
			if conflict:
				_err("E_BIND_CONFLICT", "bind '%s.%s' conflicts with a played control" % [
					inst, control,
				], _node_line(bind), _node_col(bind))

	func _info(node: Variant, seen_lets: Dictionary) -> Dictionary:
		var info := {"insts": {}, "controls": {}}
		if not (node is Dictionary):
			return info
		var expr: Dictionary = node
		match String(expr.get("type", "")):
			"name":
				var name := String(expr.get("name", ""))
				if let_nodes.has(name) and not seen_lets.has(name):
					var next_seen := seen_lets.duplicate()
					next_seen[name] = true
					return _info(let_nodes[name], next_seen)
				return info
			"call":
				var call_name := String(expr.get("name", ""))
				var args: Array = expr.get("args", [])
				if call_name == "s":
					for arg: Variant in args:
						if arg is Dictionary \
								and String((arg as Dictionary).get("type", "")) == "string":
							var atoms: Array[Dictionary] = []
							_pattern_atoms((arg as Dictionary).get("mini"), atoms)
							for atom: Dictionary in atoms:
								(info["insts"] as Dictionary)[String(atom.get("text", ""))] = true
					return info
				if call_name == "stack" or call_name == "cat" or call_name == "seq":
					for arg: Variant in args:
						_merge_info(info, _info(arg, seen_lets))
					return info
				var receiver: Variant = expr.get("receiver")
				if receiver is Dictionary:
					_merge_info(info, _info(receiver, seen_lets))
				if control_names.has(call_name):
					(info["controls"] as Dictionary)[call_name] = true
				if CueLib.FUNCTIONS.has(call_name):
					var entry: Dictionary = CueLib.FUNCTIONS[call_name]
					var arg_kinds: Array = entry.get("arg_kinds", [])
					for i: int in range(args.size()):
						if arg_kinds.is_empty():
							break
						if String(arg_kinds[min(i, arg_kinds.size() - 1)]) == "transform":
							var transform_info := _info(args[i], seen_lets)
							_merge_controls(info, transform_info)
				return info
		return info

	func _merge_info(target: Dictionary, source: Dictionary) -> void:
		for name: Variant in (source["insts"] as Dictionary).keys():
			(target["insts"] as Dictionary)[name] = true
		_merge_controls(target, source)

	func _merge_controls(target: Dictionary, source: Dictionary) -> void:
		for name: Variant in (source["controls"] as Dictionary).keys():
			(target["controls"] as Dictionary)[name] = true

	func _start(node: Variant) -> Vector2i:
		var current: Variant = node
		while current is Dictionary:
			var current_node: Dictionary = current
			var receiver: Variant = current_node.get("receiver")
			if receiver is Dictionary:
				current = receiver
			else:
				return Vector2i(_node_line(current_node), _node_col(current_node))
		return Vector2i(1, 1)

	func _valid_user_name(name: String) -> bool:
		if name.is_empty():
			return false
		var first := name.unicode_at(0)
		if not ((first >= 97 and first <= 122) or first == 95):
			return false
		for i: int in range(1, name.length()):
			var c := name.unicode_at(i)
			var lower := c >= 97 and c <= 122
			var digit := c >= 48 and c <= 57
			if not (lower or digit or c == 95):
				return false
		return not KEYWORDS.has(name) and not CueLib.FUNCTIONS.has(name)

	func _valid_scale(root: String, suffix: String) -> bool:
		if not SCALES.has(suffix):
			return false
		return _scale_root_re.search(root) != null

	func _node_line(node: Dictionary) -> int:
		return max(1, int(node.get("line", 1)))

	func _node_col(node: Dictionary) -> int:
		return max(1, int(node.get("col", 1)))

	func _err(code: String, message: String, line: int, col: int) -> void:
		diags.append({
			"code": code,
			"message": message,
			"line": line,
			"col": col,
			"severity": "error",
		})

	func _warn(code: String, message: String, line: int, col: int) -> void:
		diags.append({
			"code": code,
			"message": message,
			"line": line,
			"col": col,
			"severity": "warning",
		})
