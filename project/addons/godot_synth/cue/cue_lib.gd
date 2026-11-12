## The cue function table and compiler: turns a parsed cue program into patterns.
##
## FUNCTIONS is the single source of truth for names, kinds and arities, and the
## validator reads it too. compile() evaluates program items in file order and
## returns the compiled lets, states, stingers, transitions, params and binds.
class_name CueLib extends RefCounted

const FUNCTIONS: Dictionary = {
	"s": {"kind": "constructor", "min_args": 1, "max_args": 1, "arg_kinds": ["string"], "also_method": true},
	"n": {"kind": "constructor", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"], "also_method": true},
	"note": {"kind": "constructor", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"], "also_method": true},
	"stack": {"kind": "constructor", "min_args": 1, "max_args": -1, "arg_kinds": ["pattern"]},
	"cat": {"kind": "constructor", "min_args": 1, "max_args": -1, "arg_kinds": ["pattern"]},
	"seq": {"kind": "constructor", "min_args": 1, "max_args": -1, "arg_kinds": ["pattern"]},
	"silence": {"kind": "constructor", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"run": {"kind": "constructor", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"game": {"kind": "constructor", "min_args": 1, "max_args": 1, "arg_kinds": ["string"]},
	"sine": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"saw": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"tri": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"square": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"rand": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"perlin": {"kind": "signal", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"irand": {"kind": "signal", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"fast": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"slow": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"early": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"late": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"ply": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"iter": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"segment": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"rev": {"kind": "method", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"palindrome": {"kind": "method", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"range": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "numeric"]},
	"struct": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"mask": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"euclid": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "numeric"]},
	"euclidRot": {"kind": "method", "min_args": 3, "max_args": 3, "arg_kinds": ["numeric", "numeric", "numeric"]},
	"degrade": {"kind": "method", "min_args": 0, "max_args": 0, "arg_kinds": []},
	"degradeBy": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"sometimesBy": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "transform"]},
	"someCyclesBy": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "transform"]},
	"sometimes": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"often": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"rarely": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"almostNever": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"almostAlways": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"someCycles": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"every": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "transform"]},
	"superimpose": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["transform"]},
	"off": {"kind": "method", "min_args": 2, "max_args": 2, "arg_kinds": ["numeric", "transform"]},
	"scale": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["string"]},
	"transpose": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"add": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"gain": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"velocity": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"legato": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"lpf": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"hpf": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"lpq": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"attack": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"decay": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"sustain": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"release": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"pan": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
	"detune": {"kind": "method", "min_args": 1, "max_args": 1, "arg_kinds": ["numeric"]},
}

const RANDOM_METHODS: Array[String] = [
	"degrade", "degradeBy", "sometimesBy", "someCyclesBy", "sometimes",
	"often", "rarely", "almostNever", "almostAlways", "someCycles",
	"every", "superimpose", "off",
]

const CONTROL_METHODS: Array[String] = [
	"gain", "velocity", "legato", "lpf", "hpf", "lpq", "attack", "decay",
	"sustain", "release", "pan", "detune",
]

static func has_function(name: String) -> bool:
	return FUNCTIONS.has(name)

static func compile(program_ast: Dictionary, seed: int) -> Dictionary:
	var items: Array = program_ast.get("items", [])
	var seed_value := seed
	for item: Variant in items:
		if item is Dictionary and String(item.get("type", "")) == "seed":
			seed_value = int(item.get("value", seed_value))

	var ctx := {"seed": seed_value, "site_counter": 0, "lets": {}, "errors": []}
	var lets: Dictionary = {}
	var states: Dictionary = {}
	var stingers: Dictionary = {}
	var transitions: Array = []
	var params: Dictionary = {}
	var binds: Array = []
	var tempo := {"bpm": 120.0, "beats": 4, "unit": 4}

	for item: Variant in items:
		if not (item is Dictionary):
			continue
		var node: Dictionary = item
		match String(node.get("type", "")):
			"seed":
				pass
			"tempo":
				tempo = {
					"bpm": _num(node.get("bpm"), 120.0),
					"beats": int(node.get("beats", 4)),
					"unit": int(node.get("unit", 4)),
				}
			"let":
				var name := String(node.get("name", ""))
				var value := _eval(node.get("expr", {}), ctx)
				ctx["lets"][name] = value
				lets[name] = value
			"param":
				var name := String(node.get("name", ""))
				var lo := _num(node.get("lo"), 0.0)
				var hi := _num(node.get("hi"), 1.0)
				var default_value := _num(node.get("default"), lo)
				params[name] = {"lo": lo, "hi": hi, "default": default_value}
			"state":
				var name := String(node.get("name", ""))
				var layers: Array[CuePattern] = []
				for layer: Variant in node.get("layers", []):
					var value := _eval(layer, ctx)
					if value is CuePattern:
						layers.append(value)
					else:
						_error(ctx, layer, "E_KIND", "state layer must be a pattern")
				states[name] = CuePattern.stack(layers)
			"stinger":
				var name := String(node.get("name", ""))
				var pattern := _eval(node.get("expr", {}), ctx)
				if not (pattern is CuePattern):
					_error(ctx, node.get("expr"), "E_KIND", "stinger must be a pattern")
					pattern = CuePattern.silence()
				stingers[name] = {
					"pattern": pattern,
					"quant": _quant(node.get("quant"), "beat", 1),
					"len": _num(node.get("len"), 1.0),
				}
			"transition":
				var fill: Variant = null
				var fill_node: Variant = node.get("fill")
				if fill_node != null:
					fill = _eval(fill_node, ctx)
					if not (fill is CuePattern):
						_error(ctx, fill_node, "E_KIND", "transition fill must be a pattern")
						fill = null
				transitions.append({
					"from": String(node.get("from", "*")),
					"to": String(node.get("to", "")),
					"quant": _quant(node.get("quant"), "bar", 1),
					"fade": _num(node.get("fade"), 0.0),
					"fill": fill,
				})
			"bind":
				binds.append({
					"inst": String(node.get("inst", "")),
					"control": String(node.get("control", "")),
					"param": String(node.get("param", "")),
					"lo": _nullable_float(node.get("lo")),
					"hi": _nullable_float(node.get("hi")),
				})

	return {
		"lets": lets,
		"states": states,
		"stingers": stingers,
		"transitions": transitions,
		"params": params,
		"binds": binds,
		"tempo": tempo,
		"seed": seed_value,
		"errors": ctx["errors"],
	}

static func _num(v: Variant, default_value: float) -> float:
	if v is Dictionary:
		return float((v as Dictionary).get("value", default_value))
	if v is int or v is float:
		return float(v)
	return default_value

static func _nullable_float(v: Variant) -> Variant:
	if v == null:
		return null
	return _num(v, 0.0)

static func _quant(v: Variant, default_kind: String, default_count: int) -> Dictionary:
	if v is Dictionary:
		var node: Dictionary = v
		return {"kind": String(node.get("kind", default_kind)), "count": int(node.get("count", default_count))}
	return {"kind": default_kind, "count": default_count}

static func _next_site(ctx: Dictionary) -> int:
	ctx["site_counter"] = int(ctx["site_counter"]) + 1
	return int(ctx["site_counter"])

static func _error(ctx: Dictionary, node: Variant, code: String, message: String) -> void:
	var line := 0
	var col := 0
	if node is Dictionary:
		line = int((node as Dictionary).get("line", 0))
		col = int((node as Dictionary).get("col", 0))
	ctx["errors"].append({"code": code, "message": message, "line": line, "col": col})

static func _eval(node: Variant, ctx: Dictionary) -> Variant:
	if not (node is Dictionary):
		_error(ctx, node, "E_KIND", "expected an expression")
		return CuePattern.silence()
	var expr: Dictionary = node
	match String(expr.get("type", "")):
		"number":
			return CuePattern.pure(float(expr.get("value", 0.0)))
		"string":
			var site := _next_site(ctx)
			return CueMiniCompiler.compile(expr.get("mini", {}), _default_atom, int(ctx["seed"]), site)
		"name":
			return _eval_name(expr, ctx)
		"call":
			return _eval_call(expr, ctx)
		_:
			_error(ctx, expr, "E_KIND", "unsupported expression")
			return CuePattern.silence()

static func _eval_name(node: Dictionary, ctx: Dictionary) -> Variant:
	var name := String(node.get("name", ""))
	var let_value: Dictionary = ctx["lets"]
	if let_value.has(name):
		return let_value[name]
	if not FUNCTIONS.has(name):
		_error(ctx, node, "E_UNKNOWN_FUNCTION", "unknown function '" + name + "'")
		return CuePattern.silence()
	var call := {
		"type": "call",
		"name": name,
		"args": [],
		"receiver": null,
		"line": int(node.get("line", 0)),
		"col": int(node.get("col", 0)),
	}
	return _eval_call(call, ctx)

static func _eval_call(node: Dictionary, ctx: Dictionary) -> Variant:
	var name := String(node.get("name", ""))
	if not FUNCTIONS.has(name):
		_error(ctx, node, "E_UNKNOWN_FUNCTION", "unknown function '" + name + "'")
		return CuePattern.silence()
	var entry: Dictionary = FUNCTIONS[name]
	var args: Array = node.get("args", [])
	var count := args.size()
	var min_args := int(entry.get("min_args", 0))
	var max_args := int(entry.get("max_args", 0))
	if count < min_args or (max_args != -1 and count > max_args):
		_error(ctx, node, "E_ARITY", "wrong number of arguments for '" + name + "'")
		return CuePattern.silence()

	var site := _next_site(ctx)
	var receiver: Variant = null
	if node.get("receiver") != null:
		receiver = _eval(node.get("receiver"), ctx)
	var argv := _eval_args(name, args, ctx)

	var kind := String(entry.get("kind", ""))
	if receiver == null:
		if kind == "method":
			var captured_name := name
			var captured_argv := argv
			var captured_ctx := ctx
			var captured_site := site
			return func(p: CuePattern) -> CuePattern:
				return _apply(captured_name, p, captured_argv, captured_ctx, captured_site)
		return _construct(name, argv, ctx, site)

	if receiver is CuePattern:
		if kind == "method" or bool(entry.get("also_method", false)):
			return _apply(name, receiver, argv, ctx, site)
		_error(ctx, node, "E_KIND", "'" + name + "' is not a method")
		return CuePattern.silence()

	if receiver is Callable:
		if kind == "method":
			var receiver_transform: Callable = receiver
			var captured_name := name
			var captured_argv := argv
			var captured_ctx := ctx
			var captured_site := site
			return func(p: CuePattern) -> CuePattern:
				return _apply(captured_name, receiver_transform.call(p), captured_argv, captured_ctx, captured_site)
		_error(ctx, node, "E_KIND", "'" + name + "' cannot follow a transform")
		return CuePattern.silence()

	_error(ctx, node, "E_KIND", "invalid receiver for '" + name + "'")
	return CuePattern.silence()

static func _eval_args(name: String, args: Array, ctx: Dictionary) -> Array:
	var entry: Dictionary = FUNCTIONS[name]
	var kinds: Array = entry.get("arg_kinds", [])
	var out: Array = []
	for i in args.size():
		var kind := "numeric"
		if not kinds.is_empty():
			kind = String(kinds[mini(i, kinds.size() - 1)])
		out.append(_eval_arg(name, args[i], kind, ctx))
	return out

static func _eval_arg(name: String, node: Variant, kind: String, ctx: Dictionary) -> Variant:
	if name == "s" or name == "n" or name == "note":
		return _control_arg_pattern(name, node, ctx)
	if CONTROL_METHODS.has(name):
		return _control_arg_pattern(name, node, ctx)
	if name == "struct" or name == "mask":
		return _bool_arg(node, ctx)
	if name == "game":
		_next_site(ctx)
		return _game_arg(node, ctx)
	if name == "scale":
		return _scale_arg(node, ctx)
	if kind == "numeric":
		return _numeric_arg(node, ctx)
	if kind == "pattern":
		return _eval_pattern(node, ctx)
	if kind == "transform":
		return _eval_transform(node, ctx)
	if node is Dictionary and String((node as Dictionary).get("type", "")) == "string":
		return _string_pattern(node, ctx, _default_atom)
	return _eval_pattern(node, ctx)

static func _eval_pattern(node: Variant, ctx: Dictionary) -> CuePattern:
	var value := _eval(node, ctx)
	if value is CuePattern:
		return value
	_error(ctx, node, "E_KIND", "expected a pattern")
	return CuePattern.silence()

static func _eval_transform(node: Variant, ctx: Dictionary) -> Callable:
	var value := _eval(node, ctx)
	if value is Callable:
		return value
	_error(ctx, node, "E_KIND", "expected a transform")
	return func(p: CuePattern) -> CuePattern: return p

static func _string_pattern(node: Variant, ctx: Dictionary, atom_fn: Callable) -> CuePattern:
	if not (node is Dictionary):
		_error(ctx, node, "E_KIND", "expected a string")
		return CuePattern.silence()
	var expr: Dictionary = node
	if String(expr.get("type", "")) != "string":
		return _eval_pattern(expr, ctx)
	var site := _next_site(ctx)
	return CueMiniCompiler.compile(expr.get("mini", {}), atom_fn, int(ctx["seed"]), site)

static func _numeric_arg(node: Variant, ctx: Dictionary) -> Variant:
	if node is Dictionary:
		var expr: Dictionary = node
		var node_type := String(expr.get("type", ""))
		if node_type == "number":
			return float(expr.get("value", 0.0))
		if node_type == "string":
			var atom := _single_atom(expr.get("mini", {}))
			if not atom.is_empty() and String(atom.get("text", "")).is_valid_float():
				_next_site(ctx)
				return float(String(atom.get("text", "")))
			var site := _next_site(ctx)
			return CueMiniCompiler.compile(expr.get("mini", {}), _numeric_atom, int(ctx["seed"]), site)
	var value := _eval(node, ctx)
	if value is CuePattern:
		return value
	_error(ctx, node, "E_KIND", "expected a number or pattern")
	return CuePattern.silence()

static func _bool_arg(node: Variant, ctx: Dictionary) -> CuePattern:
	if node is Dictionary and String((node as Dictionary).get("type", "")) == "string":
		return _string_pattern(node, ctx, _bool_atom)
	return _eval_pattern(node, ctx)

static func _control_arg_pattern(key: String, node: Variant, ctx: Dictionary) -> CuePattern:
	var value: Variant = null
	if node is Dictionary and String((node as Dictionary).get("type", "")) == "string":
		value = _string_pattern(node, ctx, _control_atom_fn(key))
	else:
		value = _eval(node, ctx)
	if not (value is CuePattern):
		_error(ctx, node, "E_KIND", "expected a value pattern for '" + key + "'")
		return CuePattern.silence()
	var inner: CuePattern = value
	return inner.fmap(func(v: Variant) -> Variant:
		if v is Dictionary:
			return v
		return {key: v})

static func _scale_arg(node: Variant, ctx: Dictionary) -> CuePattern:
	if node is Dictionary and String((node as Dictionary).get("type", "")) == "string":
		return _string_pattern(node, ctx, _scale_atom)
	return _eval_pattern(node, ctx)

static func _game_arg(node: Variant, ctx: Dictionary) -> String:
	if node is Dictionary:
		var expr: Dictionary = node
		if String(expr.get("type", "")) == "string":
			var atom := _single_atom(expr.get("mini", {}))
			return String(atom.get("text", ""))
		if String(expr.get("type", "")) == "name":
			return String(expr.get("name", ""))
	_error(ctx, node, "E_KIND", "game expects a parameter name")
	return ""

static func _control_atom_fn(key: String) -> Callable:
	match key:
		"s":
			return _s_atom
		"n":
			return _n_atom
		"note":
			return _note_atom
	return func(a: Dictionary) -> Variant: return _generic_control_atom(a, key)

static func _default_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	if text.is_valid_float():
		return text.to_float()
	return text

static func _numeric_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	if not text.is_valid_float():
		return null
	return text.to_float()

static func _bool_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	if text == "0" or text == "f" or text == "false":
		return false
	if text.is_valid_float():
		return text.to_float() != 0.0
	return true

static func _scale_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	var suffix := String(a.get("suffix", ""))
	if suffix.is_empty():
		return text
	return text + ":" + suffix

static func _s_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	var value := {"s": text}
	var suffix := String(a.get("suffix", ""))
	if suffix.is_valid_int():
		value["n"] = suffix.to_int()
	return value

static func _n_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	if not text.is_valid_float():
		return null
	return {"n": text.to_float()}

static func _note_atom(a: Dictionary) -> Variant:
	var text := String(a.get("text", ""))
	if text.is_valid_float():
		return {"note": text.to_float()}
	var midi := CueTheory.note_to_midi(text)
	if midi < 0:
		return null
	return {"note": midi}

static func _generic_control_atom(a: Dictionary, key: String) -> Variant:
	var text := String(a.get("text", ""))
	if not text.is_valid_float():
		return null
	return {key: text.to_float()}

static func _single_atom(mini_ast: Variant) -> Dictionary:
	var atoms: Array = []
	_collect_atoms(mini_ast, atoms)
	if atoms.size() != 1:
		return {}
	return atoms[0]

static func _collect_atoms(node: Variant, out: Array) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		if String(d.get("type", "")) == "atom":
			out.append(d)
		for key: Variant in d.keys():
			if String(key) == "col":
				continue
			_collect_atoms(d[key], out)
	elif node is Array:
		for item: Variant in node:
			_collect_atoms(item, out)

static func _construct(name: String, argv: Array, ctx: Dictionary, site: int) -> CuePattern:
	match name:
		"s", "n", "note":
			return _as_pattern(argv[0])
		"stack":
			return CuePattern.stack(_patterns(argv))
		"cat":
			return CuePattern.cat(_patterns(argv))
		"seq":
			return CuePattern.seq(_patterns(argv))
		"silence":
			return CuePattern.silence()
		"run":
			if argv[0] is CuePattern:
				var count_pat: CuePattern = argv[0]
				return CuePattern.patternify_inner(count_pat, func(v: Variant) -> CuePattern:
					return _run_pattern(floori(float(v))))
			return _run_pattern(floori(float(argv[0])))
		"game":
			return _game_pattern(String(argv[0]))
		"sine":
			return CueSignals.sine()
		"saw":
			return CueSignals.saw()
		"tri":
			return CueSignals.tri()
		"square":
			return CueSignals.square()
		"rand":
			return CueSignals.rand(int(ctx["seed"]), site)
		"perlin":
			return CueSignals.perlin(int(ctx["seed"]), site)
		"irand":
			if argv[0] is CuePattern:
				var k_pat: CuePattern = argv[0]
				var seed := int(ctx["seed"])
				return CuePattern.patternify_inner(k_pat, func(v: Variant) -> CuePattern:
					return CueSignals.irand(floori(float(v)), seed, site))
			return CueSignals.irand(floori(float(argv[0])), int(ctx["seed"]), site)
	_error(ctx, null, "E_UNKNOWN_FUNCTION", "cannot construct '" + name + "'")
	return CuePattern.silence()

static func _patterns(argv: Array) -> Array[CuePattern]:
	var out: Array[CuePattern] = []
	for v: Variant in argv:
		if v is CuePattern:
			out.append(v)
	return out

static func _as_pattern(v: Variant) -> CuePattern:
	if v is CuePattern:
		return v
	return CuePattern.silence()

static func _run_pattern(k: int) -> CuePattern:
	if k <= 0:
		return CuePattern.silence()
	var pats: Array[CuePattern] = []
	for i in k:
		pats.append(CuePattern.pure(float(i)))
	return CuePattern.seq(pats)

static func _game_pattern(param_name: String) -> CuePattern:
	var q := func(state: Dictionary) -> Array[CueHap]:
		var controls: Dictionary = state.get("controls", {})
		var params: Dictionary = controls.get("params", {})
		var value := float(params.get(param_name, 0.0))
		var span: CueSpan = state["span"]
		var out: Array[CueHap] = []
		out.append(CueHap.make(null, span, value))
		return out
	return CuePattern.new(q)

static func _apply(name: String, recv: CuePattern, argv: Array, ctx: Dictionary, site: int) -> CuePattern:
	if RANDOM_METHODS.has(name):
		return _apply_random(name, recv, argv, ctx, site)
	match name:
		"fast":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern: return r.fast(f))
		"slow":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern: return r.slow(f))
		"early":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern: return r.early(f))
		"late":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern: return r.late(f))
		"segment":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern: return r.segment(f))
		"ply":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern:
				return r.ply(floori(f.to_float())))
		"iter":
			return _time(recv, argv[0], func(r: CuePattern, f: CueFrac) -> CuePattern:
				return r.iter(floori(f.to_float())))
		"rev":
			return recv.rev()
		"palindrome":
			return recv.palindrome()
		"struct":
			return recv.struct(_as_pattern(argv[0]))
		"mask":
			return recv.mask(_as_pattern(argv[0]))
		"euclid":
			return _euclid_apply(recv, argv[0], argv[1], 0.0)
		"euclidRot":
			return _euclid_apply(recv, argv[0], argv[1], argv[2])
		"range":
			return _range_apply(recv, argv[0], argv[1])
		"s", "n", "note":
			return _apply_control(recv, argv[0], name)
		"scale":
			return _scale_apply(recv, _as_pattern(argv[0]))
		"transpose":
			return _transpose_apply(recv, argv[0], false)
		"add":
			return _transpose_apply(recv, argv[0], true)
	if CONTROL_METHODS.has(name):
		return _apply_control(recv, argv[0], name)
	_error(ctx, null, "E_UNKNOWN_FUNCTION", "unsupported method '" + name + "'")
	return recv

static func _apply_random(name: String, recv: CuePattern, _argv: Array, ctx: Dictionary, _site: int) -> CuePattern:
	_error(ctx, null, "E_UNKNOWN_FUNCTION", "not implemented: " + name)
	return recv

static func _time(recv: CuePattern, arg: Variant, build: Callable) -> CuePattern:
	if arg is CuePattern:
		var arg_pat: CuePattern = arg
		return CuePattern.patternify_inner(arg_pat, func(v: Variant) -> CuePattern:
			return build.call(recv, CuePattern.to_frac(v)))
	if arg is float or arg is int:
		return build.call(recv, CueFrac.from_float(float(arg)))
	return CuePattern.silence()

static func _euclid_apply(recv: CuePattern, k: Variant, n: Variant, r: Variant) -> CuePattern:
	if k is CuePattern:
		var k_pat: CuePattern = k
		var n_outer := n
		var r_outer := r
		return CuePattern.patternify_inner(k_pat, func(v: Variant) -> CuePattern:
			return _euclid_apply(recv, floori(float(v)), n_outer, r_outer))
	if n is CuePattern:
		var n_pat: CuePattern = n
		var k_outer := k
		var r_outer := r
		return CuePattern.patternify_inner(n_pat, func(v: Variant) -> CuePattern:
			return _euclid_apply(recv, k_outer, floori(float(v)), r_outer))
	if r is CuePattern:
		var r_pat: CuePattern = r
		var k_outer := k
		var n_outer := n
		return CuePattern.patternify_inner(r_pat, func(v: Variant) -> CuePattern:
			return _euclid_apply(recv, k_outer, n_outer, floori(float(v))))
	return recv.euclid(floori(float(k)), floori(float(n)), floori(float(r)))

static func _range_apply(recv: CuePattern, lo: Variant, hi: Variant) -> CuePattern:
	if (lo is float or lo is int) and (hi is float or hi is int):
		return recv.range(float(lo), float(hi))
	return recv.range_pat(_to_pattern(lo), _to_pattern(hi))

static func _to_pattern(v: Variant) -> CuePattern:
	if v is CuePattern:
		return v
	if v is float or v is int:
		return CuePattern.pure(float(v))
	return CuePattern.silence()

static func _apply_control(recv: CuePattern, arg: Variant, key: String) -> CuePattern:
	var arg_pat := _to_pattern(arg)
	return recv.app_left(arg_pat, func(l: Variant, r: Variant) -> Variant:
		var d: Dictionary = {}
		if l is Dictionary:
			d = (l as Dictionary).duplicate()
		if r is Dictionary:
			d.merge(r, true)
		else:
			d[key] = r
		return d)

static func _scale_apply(recv: CuePattern, scale_pat: CuePattern) -> CuePattern:
	return recv.app_left(scale_pat, func(l: Variant, sc: Variant) -> Variant:
		if not (sc is String):
			return null
		var parsed := CueTheory.parse_scale(sc)
		if not bool(parsed.get("ok", false)):
			return null
		if not (l is Dictionary):
			return l
		var d: Dictionary = (l as Dictionary).duplicate()
		if not d.has("n"):
			return d
		var midi := CueTheory.degree_to_midi(floori(float(d["n"])), parsed)
		d.erase("n")
		d["note"] = midi
		return d)

static func _transpose_apply(recv: CuePattern, amount: Variant, add_mode: bool) -> CuePattern:
	var amount_pat := _to_pattern(amount)
	return recv.app_left(amount_pat, func(l: Variant, x: Variant) -> Variant:
		var d: Dictionary = {}
		if l is Dictionary:
			d = (l as Dictionary).duplicate()
		var delta := float(x)
		if add_mode:
			if d.has("n"):
				d["n"] = float(d["n"]) + delta
			elif d.has("note"):
				d["note"] = float(d["note"]) + delta
		else:
			if d.has("note"):
				d["note"] = float(d["note"]) + delta
			elif d.has("n"):
				d["n"] = float(d["n"]) + delta
		return d)
