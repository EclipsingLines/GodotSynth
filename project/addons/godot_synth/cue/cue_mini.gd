class_name CueMini
extends RefCounted

## Parses a mini-notation string into its AST, or reports a syntax error.
## The input is the text between the quotes (no quotes). Cols are 0-based
## offsets inside that text.

## Returns {ok: bool, ast: Variant, error: Dictionary}.
## ok:  {ok = true,  ast = <mini AST root>, error = {}}
## err: {ok = false, ast = null, error = {message: String, col: int}}
static func parse(text: String) -> Dictionary:
	var parser := _Parser.new(text)
	var ast: Variant = parser.parse()
	if not parser.error.is_empty():
		return {"ok": false, "ast": null, "error": parser.error}
	return {"ok": true, "ast": ast, "error": {}}


class _Parser:
	var text: String
	var pos: int = 0
	var error: Dictionary = {}

	func _init(p_text: String) -> void:
		text = p_text

	func parse() -> Variant:
		_skip_spaces()
		var node: Variant = parse_stack()
		if node == null:
			return null
		_skip_spaces()
		if pos < text.length():
			_fail("unexpected '%s'" % text[pos], pos)
			return null
		return node

	func parse_stack() -> Variant:
		var first: Variant = parse_choice()
		if first == null:
			return null
		var items: Array = [first]
		while pos < text.length() and text[pos] == ",":
			pos += 1
			_skip_spaces()
			var next: Variant = parse_choice()
			if next == null:
				return null
			items.append(next)
		if items.size() == 1:
			return first
		return {"type": "stack", "items": items, "col": first["col"]}

	func parse_choice() -> Variant:
		var first: Variant = parse_seq()
		if first == null:
			return null
		var items: Array = [first]
		while pos < text.length() and text[pos] == "|":
			pos += 1
			_skip_spaces()
			var next: Variant = parse_seq()
			if next == null:
				return null
			items.append(next)
		if items.size() == 1:
			return first
		return {"type": "choice", "items": items, "col": first["col"]}

	func parse_seq() -> Variant:
		var first: Variant = parse_step()
		if first == null:
			return null
		var steps: Array = [first]
		while true:
			var spaces := 0
			while pos < text.length() and text[pos] == " ":
				pos += 1
				spaces += 1
			if pos >= text.length():
				break
			var c := text[pos]
			if c == "|" or c == "," or c == "]" or c == ">":
				break
			if spaces > 0 and _can_start_step(c):
				var next: Variant = parse_step()
				if next == null:
					return null
				steps.append(next)
			else:
				_fail("unexpected '%s'" % c, pos)
				return null
		return {"type": "seq", "steps": steps, "col": first["col"]}

	func parse_step() -> Variant:
		var start := pos
		if pos >= text.length():
			_fail("expected a step", pos)
			return null
		if text[pos] == "!":
			pos += 1
			return {"type": "repeat_prev", "col": start}
		var term: Variant = parse_term()
		if term == null:
			return null
		var mods: Array = []
		while pos < text.length():
			var c := text[pos]
			if c == "*" or c == "/" or c == "!" or c == "@" or c == "?" or c == "(":
				var mod: Variant = _parse_mod(c)
				if mod == null:
					return null
				mods.append(mod)
			else:
				break
		return {"type": "step", "term": term, "mods": mods, "col": term["col"]}

	func parse_term() -> Variant:
		var start := pos
		if pos >= text.length():
			_fail("expected a term", pos)
			return null
		var c := text[pos]
		if c == "~":
			pos += 1
			return {"type": "rest", "col": start}
		if c == "[":
			pos += 1
			_skip_spaces()
			var inner: Variant = parse_stack()
			if inner == null:
				return null
			_skip_spaces()
			if pos >= text.length() or text[pos] != "]":
				_fail("expected ']'", pos)
				return null
			pos += 1
			return {"type": "sub", "item": inner, "col": start}
		if c == "<":
			pos += 1
			_skip_spaces()
			var inner: Variant = parse_stack()
			if inner == null:
				return null
			_skip_spaces()
			if pos >= text.length() or text[pos] != ">":
				_fail("expected '>'", pos)
				return null
			pos += 1
			var items: Array = inner["items"] if inner["type"] == "stack" else [inner]
			return {"type": "cat", "items": items, "col": start}

		var word := _parse_word()
		if not error.is_empty():
			return null
		var suffix := ""
		if pos < text.length() and text[pos] == ":":
			pos += 1
			suffix = _parse_word()
			if not error.is_empty():
				return null
		return {"type": "atom", "text": word, "suffix": suffix, "col": start}

	func _parse_word() -> String:
		if pos >= text.length():
			_fail("expected a word", pos)
			return ""
		var c := text[pos]
		if _is_digit(c) or c == "-":
			var number := _scan_number()
			if not error.is_empty():
				return ""
			return number
		if _is_letter(c):
			var start := pos
			pos += 1
			while pos < text.length() and _is_name_char(text[pos]):
				pos += 1
			return text.substr(start, pos - start)
		_fail("unexpected '%s'" % c, pos)
		return ""

	func _parse_mod(op: String) -> Variant:
		var col := pos
		match op:
			"*":
				pos += 1
				var arg: Variant = _parse_factor()
				if arg == null:
					return null
				return {"type": "mod", "op": "fast", "arg": arg, "col": col}
			"/":
				pos += 1
				var arg: Variant = _parse_factor()
				if arg == null:
					return null
				return {"type": "mod", "op": "slow", "arg": arg, "col": col}
			"!":
				pos += 1
				var count := 2
				if _is_digit(_peek()):
					var parsed: Variant = _parse_mint()
					if parsed == null:
						return null
					count = parsed
				return {"type": "mod", "op": "rep", "count": count, "col": col}
			"@":
				pos += 1
				var value: Variant = _parse_number_node()
				if value == null:
					return null
				return {"type": "mod", "op": "weight", "value": value["value"], "col": col}
			"?":
				pos += 1
				var prob := 0.5
				var c := _peek()
				if _is_digit(c) or c == "-":
					var value: Variant = _parse_number_node()
					if value == null:
						return null
					prob = value["value"]
				return {"type": "mod", "op": "degrade", "prob": prob, "col": col}
			"(":
				return _parse_euclid(col)
		return null

	func _parse_factor() -> Variant:
		if _peek() == "<":
			var start := pos
			pos += 1
			_skip_spaces()
			var inner: Variant = parse_seq()
			if inner == null:
				return null
			_skip_spaces()
			if pos >= text.length() or text[pos] != ">":
				_fail("expected '>'", pos)
				return null
			pos += 1
			return {"type": "cat", "items": [inner], "col": start}
		return _parse_number_node()

	func _parse_euclid(col: int) -> Variant:
		pos += 1
		_skip_spaces()
		var k: Variant = _parse_mint()
		if k == null:
			return null
		_skip_spaces()
		if pos >= text.length() or text[pos] != ",":
			_fail("expected ','", pos)
			return null
		pos += 1
		_skip_spaces()
		var n: Variant = _parse_mint()
		if n == null:
			return null
		_skip_spaces()
		var rot := 0
		if pos < text.length() and text[pos] == ",":
			pos += 1
			_skip_spaces()
			var parsed: Variant = _parse_mint()
			if parsed == null:
				return null
			rot = parsed
			_skip_spaces()
		if pos >= text.length() or text[pos] != ")":
			_fail("expected ')'", pos)
			return null
		pos += 1
		return {"type": "mod", "op": "euclid", "k": k, "n": n, "rot": rot, "col": col}

	func _parse_number_node() -> Variant:
		var start := pos
		var c := _peek()
		if not (_is_digit(c) or c == "-"):
			_fail("expected a number", pos)
			return null
		var number := _scan_number()
		if not error.is_empty():
			return null
		return {"type": "number", "value": number.to_float(), "col": start}

	func _parse_mint() -> Variant:
		if not _is_digit(_peek()):
			_fail("expected a number", pos)
			return null
		var start := pos
		while pos < text.length() and _is_digit(text[pos]):
			pos += 1
		return int(text.substr(start, pos - start))

	func _scan_number() -> String:
		var start := pos
		if pos < text.length() and text[pos] == "-":
			pos += 1
			if not _is_digit(_peek()):
				_fail("expected a digit", pos)
				return ""
		while pos < text.length() and _is_digit(text[pos]):
			pos += 1
		if pos < text.length() and text[pos] == ".":
			pos += 1
			if not _is_digit(_peek()):
				_fail("expected a digit after '.'", pos)
				return ""
			while pos < text.length() and _is_digit(text[pos]):
				pos += 1
		return text.substr(start, pos - start)

	func _skip_spaces() -> void:
		while pos < text.length() and text[pos] == " ":
			pos += 1

	func _peek() -> String:
		if pos < text.length():
			return text[pos]
		return ""

	func _can_start_step(c: String) -> bool:
		return _is_letter(c) or _is_digit(c) or c == "-" or c == "~" or c == "[" or c == "<" or c == "!"

	func _is_digit(c: String) -> bool:
		return c >= "0" and c <= "9"

	func _is_letter(c: String) -> bool:
		return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")

	func _is_name_char(c: String) -> bool:
		return _is_letter(c) or _is_digit(c) or c == "#" or c == "_"

	func _fail(message: String, col: int) -> void:
		if error.is_empty():
			error = {"message": message, "col": col}
