class_name CueMiniCompiler
extends RefCounted

## Compiles a mini-notation AST (from CueMini.parse) into a CuePattern.
## Atoms are typed by the caller's atom_fn; returning null makes an atom silent.
## Random choices and degradation are keyed on (seed, sub-site, time) so a
## string compiles to the same pattern offline and live.

## Compiles the AST root, drawing randomness from seed and the string's site.
static func compile(mini_ast: Dictionary, atom_fn: Callable, seed: int, site: int) -> CuePattern:
	var ctx := {"atom_fn": atom_fn, "seed": seed, "site": site, "n": 0}
	if mini_ast.is_empty():
		return CuePattern.silence()
	return _node(mini_ast, ctx)

# Every `?` and every `|` draws from its own sub-site, so two of them in one
# string are independent and a different site gives different decisions.
static func _next_site(ctx: Dictionary) -> int:
	var s: int = int(ctx["site"]) * 1024 + int(ctx["n"])
	ctx["n"] = int(ctx["n"]) + 1
	return s

static func _node(node: Variant, ctx: Dictionary) -> CuePattern:
	if not (node is Dictionary):
		return CuePattern.silence()
	match String(node.get("type", "")):
		"seq":
			return _sequence(node.get("steps", []), ctx)
		"stack":
			return _stack(node.get("items", []), ctx)
		"choice":
			return _choice(node.get("items", []), ctx)
		"cat":
			return _cat(node.get("items", []), ctx)
		"sub":
			return _node(node.get("item", {}), ctx)
		"atom":
			return _atom(node, ctx)
		"rest":
			return CuePattern.silence()
		"step":
			return _step_pattern(node, ctx)
		"repeat_prev":
			return CuePattern.silence()
		_:
			return CuePattern.silence()

static func _stack(items: Array, ctx: Dictionary) -> CuePattern:
	if items.is_empty():
		return CuePattern.silence()
	var pats: Array[CuePattern] = []
	for item: Variant in items:
		pats.append(_node(item, ctx))
	if pats.size() == 1:
		return pats[0]
	return CuePattern.stack(pats)

static func _choice(items: Array, ctx: Dictionary) -> CuePattern:
	if items.is_empty():
		return CuePattern.silence()
	var pats: Array[CuePattern] = []
	for item: Variant in items:
		pats.append(_node(item, ctx))
	if pats.size() == 1:
		return pats[0]
	var n := pats.size()
	var s := _next_site(ctx)
	var seed := int(ctx["seed"])
	var q := func(state: Dictionary) -> Array[CueHap]:
		var out: Array[CueHap] = []
		var span: CueSpan = state["span"]
		var controls: Dictionary = state["controls"]
		for sub: CueSpan in span.span_cycles():
			var c := sub.begin.cycle()
			var r := CueSignals.hash01(seed, s, CueFrac.make(c))
			var i := mini(floori(r * float(n)), n - 1)
			out.append_array(pats[i].query.call(CuePattern.make_state(sub, controls)))
		return out
	return CuePattern.new(q)

# Cat items are the rows of a `<...>`: a comma makes several rows to stack, and
# each row is a sequence of steps that plays one step per cycle.
static func _cat(items: Array, ctx: Dictionary) -> CuePattern:
	if items.is_empty():
		return CuePattern.silence()
	var rows: Array[CuePattern] = []
	for item: Variant in items:
		var steps: Array = []
		if item is Dictionary and String(item.get("type", "")) == "seq":
			steps = item.get("steps", [])
		else:
			steps = [item]
		var entries := _entries(steps, ctx, true)
		var pats: Array[CuePattern] = []
		for entry: Array in entries:
			var builder: Callable = entry[1]
			pats.append(builder.call())
		rows.append(CuePattern.cat(pats))
	if rows.size() == 1:
		return rows[0]
	return CuePattern.stack(rows)

static func _atom(node: Dictionary, ctx: Dictionary) -> CuePattern:
	var fn: Callable = ctx["atom_fn"]
	var v: Variant = fn.call({"text": node.get("text", ""), "suffix": node.get("suffix", "")})
	if typeof(v) == TYPE_NIL:
		return CuePattern.silence()
	return CuePattern.pure(v)

# The entries of a step list: [weight, builder] in order. Builders (not compiled
# patterns) are kept so `!` and a bare `!` can recompile a step with fresh
# random sub-sites for every replica.
static func _entries(steps: Array, ctx: Dictionary, ignore_weights: bool) -> Array:
	var out: Array = []
	for step: Variant in steps:
		if not (step is Dictionary):
			continue
		match String(step.get("type", "")):
			"repeat_prev":
				if not out.is_empty():
					out.append(out[out.size() - 1])
			"step":
				_append_step_entries(step, ctx, out, ignore_weights)
			_:
				out.append([CueFrac.one(), _make_builder(step, ctx)])
	return out

static func _append_step_entries(step: Dictionary, ctx: Dictionary, out: Array, ignore_weights: bool) -> void:
	var term: Variant = step.get("term", {})
	var rep := 1
	var weight := CueFrac.one()
	for mod: Variant in step.get("mods", []):
		if not (mod is Dictionary):
			continue
		match String(mod.get("op", "")):
			"rep":
				rep = int(mod.get("count", 2))
			"weight":
				if not ignore_weights:
					weight = CueFrac.from_float(float(mod.get("value", 1.0)))
	var builder := _make_step_builder(term, step, ctx)
	for i in rep:
		out.append([weight, builder])

static func _make_builder(node: Variant, ctx: Dictionary) -> Callable:
	return func() -> CuePattern: return _node(node, ctx)

static func _make_step_builder(term: Variant, step: Dictionary, ctx: Dictionary) -> Callable:
	var wrapper := {"type": "step", "term": term, "mods": step.get("mods", [])}
	return func() -> CuePattern: return _step_pattern(wrapper, ctx)

static func _sequence(steps: Array, ctx: Dictionary) -> CuePattern:
	var entries := _entries(steps, ctx, false)
	if entries.is_empty():
		return CuePattern.silence()
	var weighted: Array = []
	var all_one := true
	for entry: Array in entries:
		var w: CueFrac = entry[0]
		var builder: Callable = entry[1]
		weighted.append([w, builder.call()])
		if not w.eq(CueFrac.one()):
			all_one = false
	if weighted.size() == 1:
		return weighted[0][1]
	if all_one:
		var pats: Array[CuePattern] = []
		for entry: Array in weighted:
			pats.append(entry[1])
		return CuePattern.seq(pats)
	return CuePattern.timecat(weighted)

static func _step_pattern(step: Dictionary, ctx: Dictionary) -> CuePattern:
	var p := _node(step.get("term", {}), ctx)
	for mod: Variant in step.get("mods", []):
		if not (mod is Dictionary):
			continue
		match String(mod.get("op", "")):
			"fast", "slow":
				p = _apply_factor(p, mod, ctx)
			"degrade":
				var prob := float(mod.get("prob", 0.5))
				p = p.degrade_by(prob, int(ctx["seed"]), _next_site(ctx))
			"euclid":
				var rot := 0
				if mod.get("rot") != null:
					rot = int(mod.get("rot"))
				p = p.euclid(int(mod.get("k", 0)), int(mod.get("n", 0)), rot)
	return p

static func _apply_factor(p: CuePattern, mod: Dictionary, ctx: Dictionary) -> CuePattern:
	var op := String(mod.get("op", ""))
	var arg: Variant = mod.get("arg", null)
	if not (arg is Dictionary):
		return p
	var atype := String(arg.get("type", ""))
	if atype == "number":
		var k := CueFrac.from_float(float(arg.get("value", 0.0)))
		return p.fast(k) if op == "fast" else p.slow(k)
	if atype == "atom":
		var text := String(arg.get("text", ""))
		if not text.is_valid_float():
			return p
		var k := CueFrac.from_float(text.to_float())
		return p.fast(k) if op == "fast" else p.slow(k)
	if atype == "cat":
		var number_atom := func(a: Dictionary) -> Variant:
			var text := String(a.get("text", ""))
			if not text.is_valid_float():
				return null
			return text.to_float()
		var factor_ctx: Dictionary = ctx.duplicate()
		factor_ctx["atom_fn"] = number_atom
		var factor_pat := _node(arg, factor_ctx)
		var p0 := p
		if op == "fast":
			return CuePattern.patternify_inner(factor_pat, func(v: Variant) -> CuePattern:
				return p0.fast(CuePattern.to_frac(v)))
		return CuePattern.patternify_inner(factor_pat, func(v: Variant) -> CuePattern:
			return p0.slow(CuePattern.to_frac(v)))
	return p
