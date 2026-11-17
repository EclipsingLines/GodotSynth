class_name CueGenMatrix
extends RefCounted
## Expands the cue dataset prompt matrix into deterministic generation requests.

## Axis names in canonical order. The last axis varies fastest when a combination index is decoded.
const AXES: Array[String] = ["mood", "biome", "intensity", "instrumentation", "form"]
## The instruments of the real catalog (D-239). Every token of an instrumentation value must be one of them.
const INSTRUMENTS: Array[String] = ["bass", "lead", "pad", "kick", "snare", "hat", "arp"]

## Returns human-readable errors, empty when the matrix is valid. Checks: "axes" is a Dictionary with
## exactly the five AXES keys, each a non-empty Array of non-empty unique Strings; every instrumentation
## value splits on single spaces into >= 1 tokens that are all in INSTRUMENTS; "templates" is a non-empty
## Array of Strings and every template contains all five placeholders "{mood}" "{biome}" "{intensity}"
## "{instrumentation}" "{form}" (so a request always carries every axis value).
static func validate(matrix: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var axes_value: Variant = matrix.get("axes", null)
	if not axes_value is Dictionary:
		errors.append("axes: missing or not a Dictionary")
	else:
		var axes: Dictionary = axes_value
		for axis_name: String in AXES:
			if not axes.has(axis_name):
				errors.append("axes.%s: missing" % axis_name)
		for axis_key: Variant in axes.keys():
			if not AXES.has(String(axis_key)):
				errors.append("axes.%s: unknown axis" % String(axis_key))
		for axis_name: String in AXES:
			if not axes.has(axis_name):
				continue
			var values: Variant = axes[axis_name]
			if not values is Array:
				errors.append("axes.%s: not an Array" % axis_name)
				continue
			var value_list: Array = values
			if value_list.is_empty():
				errors.append("axes.%s: empty" % axis_name)
				continue
			var seen: Dictionary = {}
			for value: Variant in value_list:
				if not value is String:
					errors.append("axes.%s: value is not a String" % axis_name)
					continue
				var text: String = value
				if text.is_empty():
					errors.append("axes.%s: empty value" % axis_name)
				elif seen.has(text):
					errors.append("axes.%s: duplicate value '%s'" % [axis_name, text])
				seen[text] = true
				if axis_name == "instrumentation":
					var tokens: PackedStringArray = text.split(" ")
					if tokens.is_empty():
						errors.append("axes.%s: value has no instruments" % axis_name)
					for token: String in tokens:
						if not INSTRUMENTS.has(token):
							errors.append("axes.%s: unknown instrument '%s'" % [axis_name, token])

	var templates_value: Variant = matrix.get("templates", null)
	if not templates_value is Array:
		errors.append("templates: missing or not an Array")
	elif (templates_value as Array).is_empty():
		errors.append("templates: empty")
	else:
		var template_list: Array = templates_value
		for index: int in range(template_list.size()):
			var template: Variant = template_list[index]
			if not template is String:
				errors.append("templates[%d]: not a String" % index)
				continue
			var template_text: String = template
			for axis_name: String in AXES:
				var placeholder: String = "{%s}" % axis_name
				if not template_text.contains(placeholder):
					errors.append("templates[%d]: missing %s" % [index, placeholder])

	return errors

## Number of combinations (product of the axis list sizes). 0 when the matrix is invalid.
static func combination_count(matrix: Dictionary) -> int:
	if not validate(matrix).is_empty():
		return 0
	var axes: Dictionary = matrix["axes"]
	var product: int = 1
	for axis_name: String in AXES:
		product *= (axes[axis_name] as Array).size()
	return product

## Deterministic expansion into `count` items, each {id: String, axes: Dictionary (axis -> value), request: String}.
static func expand(matrix: Dictionary, seed: int, count: int) -> Array[Dictionary]:
	var errors: Array[String] = validate(matrix)
	if not errors.is_empty():
		push_error("CueGenMatrix.expand: " + errors[0])
		return []
	if count <= 0:
		return []
	var product: int = combination_count(matrix)
	var order: Array[int] = []
	for combo_index: int in range(product):
		order.append(combo_index)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in range(product - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp

	var axes: Dictionary = matrix["axes"]
	var templates: Array = matrix["templates"]
	var items: Array[Dictionary] = []
	for item_index: int in range(count):
		var combo: int = order[item_index % product]
		var decoded: Dictionary = {}
		var remaining: int = combo
		for k: int in range(AXES.size() - 1, -1, -1):
			var axis_name: String = AXES[k]
			var values: Array = axes[axis_name]
			decoded[axis_name] = values[remaining % values.size()]
			remaining = remaining / values.size()

		var item_axes: Dictionary = {}
		var canonical_parts: PackedStringArray = PackedStringArray()
		for axis_name: String in AXES:
			var axis_value: String = String(decoded[axis_name])
			item_axes[axis_name] = axis_value
			canonical_parts.append("%s=%s" % [axis_name, axis_value])
		canonical_parts.append("#%d" % item_index)
		var canonical: String = "|".join(canonical_parts)
		var id: String = canonical.sha256_text().substr(0, 12)
		var n: int = ("0x" + id.substr(0, 8)).hex_to_int()
		var template: String = templates[n % templates.size()]
		var request: String = template
		for axis_name: String in AXES:
			request = request.replace("{%s}" % axis_name, String(item_axes[axis_name]))
		items.append({"id": id, "axes": item_axes, "request": request})
	return items
