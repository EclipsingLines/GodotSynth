class_name CueScan
extends RefCounted
## Which instruments each group of a cue uses (design: M3, CueScan).

## ast: the program Dictionary from CueParser.parse.
## Returns {group: PackedStringArray (sorted)}. One group per state, plus
## "transitions" and "stingers" when those use an instrument.
static func instruments(ast: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var trans: Dictionary = {}
	var sting: Dictionary = {}
	var run := _Run.new()
	var items: Array = ast.get("items", [])
	for item: Variant in items:
		if not (item is Dictionary):
			continue
		var node: Dictionary = item
		match String(node.get("type", "")):
			"let":
				var s: Dictionary = {}
				run.walk(node.get("expr"), s)
				run.lets[String(node.get("name", ""))] = s
			"state":
				var s: Dictionary = {}
				var layers: Array = node.get("layers", [])
				for layer: Variant in layers:
					run.walk(layer, s)
				result[String(node.get("name", ""))] = _sorted(s)
			"transition":
				var fill: Variant = node.get("fill")
				if fill != null:
					run.walk(fill, trans)
			"stinger":
				run.walk(node.get("expr"), sting)
	if not trans.is_empty():
		result["transitions"] = _sorted(trans)
	if not sting.is_empty():
		result["stingers"] = _sorted(sting)
	return result


static func _sorted(set: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in set.keys():
		out.append(String(key))
	out.sort()
	return out


class _Run:
	extends RefCounted

	var lets: Dictionary = {}

	func walk(node: Variant, out: Dictionary) -> void:
		if not (node is Dictionary):
			return
		var entry: Dictionary = node
		match String(entry.get("type", "")):
			"name":
				var name := String(entry.get("name", ""))
				if lets.has(name):
					for key: Variant in (lets[name] as Dictionary).keys():
						out[key] = true
			"call":
				walk(entry.get("receiver"), out)
				var args: Array = entry.get("args", [])
				for arg: Variant in args:
					walk(arg, out)
				if String(entry.get("name", "")) == "s" and args.size() >= 1:
					var first: Variant = args[0]
					if first is Dictionary and String((first as Dictionary).get("type", "")) == "string":
						_atoms((first as Dictionary).get("mini"), out)

	func _atoms(mini: Variant, out: Dictionary) -> void:
		if not (mini is Dictionary):
			return
		var node: Dictionary = mini
		match String(node.get("type", "")):
			"seq":
				var steps: Array = node.get("steps", [])
				for step: Variant in steps:
					_atoms(step, out)
			"choice", "stack", "cat":
				var items: Array = node.get("items", [])
				for item: Variant in items:
					_atoms(item, out)
			"step":
				_atoms(node.get("term"), out)
			"sub":
				_atoms(node.get("item"), out)
			"atom":
				out[String(node.get("text", ""))] = true
