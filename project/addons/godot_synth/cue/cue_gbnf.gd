class_name CueGbnf
extends RefCounted
## Recognizer for the llama.cpp GBNF grammar dialect.
##
## Compiles a grammar to a small BNF and runs an Earley recognizer over Unicode
## code points. It only answers whether a string is accepted; it builds no parse
## tree. `error_position()` reports the first character no live parse accepts.

var _names: Dictionary = {}
var _prods: Array = []
var _prods_of: Array = []
var _definitions: Array = []
var _refs: Dictionary = {}
var _load_error: String = ""
var _accept_error: String = ""
var _error_pos: int = -1

# Parser state for the rule body currently being compiled.
var _body: String = ""
var _body_lines: Array[int] = []
var _pos: int = 0


static func load_grammar(text: String) -> CueGbnf:
	var grammar := CueGbnf.new()
	grammar._load(text)
	return grammar


func get_error() -> String:
	if _load_error != "":
		return _load_error
	return _accept_error


func error_position() -> int:
	return _error_pos


func accepts(text: String, start_rule: String = "root") -> bool:
	_error_pos = -1
	if _load_error != "":
		return false
	_accept_error = ""
	if not _names.has(start_rule):
		_accept_error = "unknown start rule '" + start_rule + "'"
		return false

	var start: int = _names[start_rule]
	var p_count := _prods.size()
	if p_count == 0:
		_accept_error = "grammar has no productions"
		return false
	var max_rhs := 0
	for prod in _prods:
		max_rhs = maxi(max_rhs, (prod["rhs"] as Array).size())
	var d := max_rhs + 1

	var nullable := _compute_nullable()
	var sets: Array = []
	var first := _new_set()
	sets.append(first)
	for p in _prods_of[start]:
		_add_item(first, p, 0, 0, p_count, d)

	var n := text.length()
	var i := 0
	while i < n:
		_process_set(sets[i], i, nullable, p_count, d, sets)
		var next_set := _new_set()
		var cp := text.unicode_at(i)
		var items: Array = sets[i]["items"]
		var item_index := 0
		while item_index < items.size():
			var item: Array = items[item_index]
			item_index += 1
			var prod: int = item[0]
			var dot: int = item[1]
			var rhs: Array = _prods[prod]["rhs"]
			if dot < rhs.size():
				var sym = rhs[dot]
				if sym is Dictionary and _terminal_matches(sym, cp):
					_add_item(next_set, prod, dot + 1, item[2], p_count, d)
		if (next_set["items"] as Array).is_empty():
			_error_pos = i
			return false
		sets.append(next_set)
		i += 1

	_process_set(sets[n], n, nullable, p_count, d, sets)
	var last_items: Array = sets[n]["items"]
	for item in last_items:
		var prod: int = item[0]
		var rhs: Array = _prods[prod]["rhs"]
		if item[1] == rhs.size() and item[2] == 0 and _prods[prod]["lhs"] == start:
			return true
	_error_pos = n
	return false


func _load(text: String) -> void:
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	var lines := normalized.split("\n")
	var body := ""
	var body_lines: Array[int] = []
	var current_name := ""
	var current_lhs := -1
	var current_line := 0

	for i in range(lines.size()):
		var line_no := i + 1
		var stripped := _strip_comment(lines[i])
		if stripped.strip_edges() == "":
			continue
		var name := _rule_name(stripped)
		if name != "":
			if current_lhs >= 0 and not _parse_rule_body(current_name, body, body_lines, current_line):
				return
			var header := stripped
			var eq := header.find("::=")
			var rest := header.substr(eq + 3)
			current_name = name
			current_line = line_no
			if not _names.has(name):
				_names[name] = _new_nt()
			current_lhs = _names[name]
			_definitions.append({"name": name, "line": line_no})
			body = rest
			body_lines = []
			for k in range(rest.length()):
				body_lines.append(line_no)
		else:
			if current_lhs < 0:
				_load_error = "line %d: expected rule definition (missing '::=')" % line_no
				return
			if body != "":
				body += "\n"
				body_lines.append(line_no)
			body += stripped
			for k in range(stripped.length()):
				body_lines.append(line_no)

	if current_lhs >= 0 and not _parse_rule_body(current_name, body, body_lines, current_line):
		return
	_finish_load()


func _finish_load() -> void:
	var seen: Dictionary = {}
	for definition in _definitions:
		var name: String = definition["name"]
		if seen.has(name):
			_load_error = "line %d: rule '%s' defined twice" % [definition["line"], name]
			return
		seen[name] = true
	for name in _names.keys():
		if not seen.has(name):
			var line: int = _refs.get(name, 1)
			_load_error = "line %d: undefined rule '%s'" % [line, name]
			return


func _parse_rule_body(name: String, body: String, body_lines: Array[int], header_line: int) -> bool:
	if body.strip_edges() == "":
		_load_error = "line %d: rule '%s' has an empty body" % [header_line, name]
		return false
	_body = body
	_body_lines = body_lines
	_pos = 0
	var lhs: int = _names[name]
	if not _parse_alternatives(lhs):
		return false
	_skip_ws()
	if _pos < _body.length():
		_set_load_error(_pos, "unexpected character '%s'" % _body.substr(_pos, 1))
		return false
	return true


func _skip_ws() -> void:
	while _pos < _body.length():
		var c := _body.unicode_at(_pos)
		if c == 32 or c == 9 or c == 10 or c == 13:
			_pos += 1
		else:
			break


func _parse_alternatives(lhs: int) -> bool:
	var seq = _parse_sequence()
	if seq == null:
		return false
	_add_prod(lhs, seq)
	while true:
		_skip_ws()
		if _pos >= _body.length():
			return true
		if _body.unicode_at(_pos) == 124: # |
			_pos += 1
			seq = _parse_sequence()
			if seq == null:
				return false
			_add_prod(lhs, seq)
		else:
			return true
	return false


func _parse_sequence() -> Variant:
	var symbols: Array = []
	while true:
		_skip_ws()
		if _pos >= _body.length():
			break
		var c := _body.unicode_at(_pos)
		if c == 124 or c == 41: # | )
			break
		var atom = _parse_atom()
		if atom == null:
			return null
		var atom_symbols: Array = atom
		var postfix := -1
		if _pos < _body.length():
			postfix = _body.unicode_at(_pos)
		if postfix == 42 or postfix == 43 or postfix == 63: # * + ?
			_pos += 1
			var helper := _new_nt()
			if postfix == 42:
				_add_prod(helper, atom_symbols + [helper])
				_add_prod(helper, [])
			elif postfix == 43:
				_add_prod(helper, atom_symbols + [helper])
				_add_prod(helper, atom_symbols)
			else:
				_add_prod(helper, atom_symbols)
				_add_prod(helper, [])
			symbols.append(helper)
		else:
			for symbol in atom_symbols:
				symbols.append(symbol)
	return symbols


func _parse_atom() -> Variant:
	var c := _body.unicode_at(_pos)
	if c == 34: # "
		return _parse_literal()
	if c == 91: # [
		return _parse_class()
	if c == 40: # (
		return _parse_group()
	if _is_letter(c):
		return [_parse_name()]
	_set_load_error(_pos, "unexpected character '%s'" % _body.substr(_pos, 1))
	return null


func _parse_literal() -> Variant:
	_pos += 1
	var symbols: Array = []
	while true:
		if _pos >= _body.length():
			_set_load_error(_pos, "unterminated string literal")
			return null
		var c := _body.unicode_at(_pos)
		if c == 34: # "
			_pos += 1
			return symbols
		if c == 92: # backslash
			_pos += 1
			var cp := _parse_escape(false)
			if cp < 0:
				return null
			symbols.append(_terminal(cp))
		else:
			symbols.append(_terminal(c))
			_pos += 1
	return null


func _parse_class() -> Variant:
	_pos += 1
	var neg := false
	if _pos < _body.length() and _body.unicode_at(_pos) == 94: # ^
		neg = true
		_pos += 1
	var pairs: Array[int] = []
	var closed := false
	while _pos < _body.length():
		var c := _body.unicode_at(_pos)
		if c == 93: # ]
			_pos += 1
			closed = true
			break
		if c == 92: # backslash
			_pos += 1
			var cp := _parse_escape(true)
			if cp < 0:
				return null
			if _pos < _body.length() and _body.unicode_at(_pos) == 45 and _pos + 1 < _body.length() and _body.unicode_at(_pos + 1) != 93:
				_pos += 1
				var end_cp := _parse_class_item()
				if end_cp < 0:
					return null
				if cp > end_cp:
					_set_load_error(_pos, "invalid character range")
					return null
				pairs.append(cp)
				pairs.append(end_cp)
			else:
				pairs.append(cp)
				pairs.append(cp)
			continue
		if c == 45: # literal -
			pairs.append(45)
			pairs.append(45)
			_pos += 1
			continue
		_pos += 1
		if _pos < _body.length() and _body.unicode_at(_pos) == 45 and _pos + 1 < _body.length() and _body.unicode_at(_pos + 1) != 93:
			_pos += 1
			var end_cp := _parse_class_item()
			if end_cp < 0:
				return null
			if c > end_cp:
				_set_load_error(_pos, "invalid character range")
				return null
			pairs.append(c)
			pairs.append(end_cp)
		else:
			pairs.append(c)
			pairs.append(c)
	if not closed:
		_set_load_error(_pos, "unterminated character class")
		return null
	return [{"neg": neg, "set": PackedInt32Array(pairs)}]


func _parse_class_item() -> int:
	if _pos >= _body.length():
		_set_load_error(_pos, "unterminated character class")
		return -1
	var c := _body.unicode_at(_pos)
	if c == 92:
		_pos += 1
		return _parse_escape(true)
	_pos += 1
	return c


func _parse_escape(in_class: bool) -> int:
	if _pos >= _body.length():
		_set_load_error(_pos, "unterminated escape sequence")
		return -1
	var c := _body.unicode_at(_pos)
	_pos += 1
	if c == 110: # n
		return 10
	if c == 114: # r
		return 13
	if c == 116: # t
		return 9
	if c == 92: # backslash
		return 92
	if not in_class and c == 34: # "
		return 34
	if in_class:
		if c == 93: # ]
			return 93
		if c == 91: # [
			return 91
		if c == 94: # ^
			return 94
		if c == 45: # -
			return 45
	if c == 120: # x
		if _pos + 1 >= _body.length():
			_set_load_error(_pos, "expected two hex digits after '\\x'")
			return -1
		var hi := _hex_value(_body.unicode_at(_pos))
		var lo := _hex_value(_body.unicode_at(_pos + 1))
		if hi < 0 or lo < 0:
			_set_load_error(_pos, "expected two hex digits after '\\x'")
			return -1
		_pos += 2
		return hi * 16 + lo
	_set_load_error(_pos - 1, "invalid escape sequence '\\%s'" % _body.substr(_pos - 1, 1))
	return -1


func _parse_group() -> Variant:
	_pos += 1
	var helper := _new_nt()
	if not _parse_alternatives(helper):
		return null
	_skip_ws()
	if _pos >= _body.length() or _body.unicode_at(_pos) != 41: # )
		_set_load_error(_pos, "unbalanced parentheses: expected ')'")
		return null
	_pos += 1
	return [helper]


func _parse_name() -> int:
	var start := _pos
	_pos += 1
	while _pos < _body.length():
		var c := _body.unicode_at(_pos)
		if _is_letter(c) or _is_digit(c) or c == 95 or c == 45:
			_pos += 1
		else:
			break
	var name := _body.substr(start, _pos - start)
	if not _names.has(name):
		_names[name] = _new_nt()
	if not _refs.has(name):
		_refs[name] = _line_at(start)
	return _names[name]


func _rule_name(line: String) -> String:
	if line.length() == 0 or not _is_letter(line.unicode_at(0)):
		return ""
	var i := 0
	while i < line.length():
		var c := line.unicode_at(i)
		if _is_letter(c) or _is_digit(c) or c == 95 or c == 45:
			i += 1
		else:
			break
	var name := line.substr(0, i)
	while i < line.length() and (line.unicode_at(i) == 32 or line.unicode_at(i) == 9):
		i += 1
	if i + 3 <= line.length() and line.substr(i, 3) == "::=":
		return name
	return ""


func _strip_comment(line: String) -> String:
	var in_string := false
	var in_class := false
	var escaped := false
	for i in range(line.length()):
		var c := line.unicode_at(i)
		if escaped:
			escaped = false
			continue
		if c == 92: # backslash
			if in_string or in_class:
				escaped = true
			continue
		if in_string:
			if c == 34:
				in_string = false
			continue
		if in_class:
			if c == 93:
				in_class = false
			continue
		if c == 34:
			in_string = true
		elif c == 91:
			in_class = true
		elif c == 35: # #
			return line.substr(0, i)
	return line


func _new_nt() -> int:
	var id := _prods_of.size()
	_prods_of.append([])
	return id


func _add_prod(lhs: int, rhs: Array) -> int:
	var index := _prods.size()
	_prods.append({"lhs": lhs, "rhs": rhs})
	(_prods_of[lhs] as Array).append(index)
	return index


func _terminal(cp: int) -> Dictionary:
	return {"neg": false, "set": PackedInt32Array([cp, cp])}


func _compute_nullable() -> Array:
	var nullable: Array = []
	nullable.resize(_prods_of.size())
	for i in range(nullable.size()):
		nullable[i] = false
	var changed := true
	while changed:
		changed = false
		for prod in _prods:
			var lhs: int = prod["lhs"]
			if nullable[lhs]:
				continue
			var rhs: Array = prod["rhs"]
			var all_nullable := true
			for symbol in rhs:
				if not (symbol is int) or not nullable[symbol]:
					all_nullable = false
					break
			if all_nullable:
				nullable[lhs] = true
				changed = true
	return nullable


func _new_set() -> Dictionary:
	return {"items": [], "seen": {}, "waiting": {}}


func _add_item(current: Dictionary, prod: int, dot: int, origin: int, p_count: int, d: int) -> bool:
	var key := (origin * p_count + prod) * d + dot
	var seen: Dictionary = current["seen"]
	if seen.has(key):
		return false
	seen[key] = true
	var item: Array = [prod, dot, origin]
	(current["items"] as Array).append(item)
	var rhs: Array = _prods[prod]["rhs"]
	if dot < rhs.size():
		var symbol = rhs[dot]
		if symbol is int:
			var waiting: Dictionary = current["waiting"]
			if not waiting.has(symbol):
				waiting[symbol] = []
			(waiting[symbol] as Array).append(item)
	return true


func _process_set(current: Dictionary, position: int, nullable: Array, p_count: int, d: int, sets: Array) -> void:
	var items: Array = current["items"]
	var index := 0
	while index < items.size():
		var item: Array = items[index]
		index += 1
		var prod: int = item[0]
		var dot: int = item[1]
		var origin: int = item[2]
		var rhs: Array = _prods[prod]["rhs"]
		if dot >= rhs.size():
			var lhs: int = _prods[prod]["lhs"]
			var waiting: Dictionary = sets[origin]["waiting"]
			if waiting.has(lhs):
				var candidates: Array = waiting[lhs]
				var candidate_index := 0
				while candidate_index < candidates.size():
					var candidate: Array = candidates[candidate_index]
					candidate_index += 1
					_add_item(current, candidate[0], candidate[1] + 1, candidate[2], p_count, d)
		else:
			var symbol = rhs[dot]
			if symbol is int:
				for p in _prods_of[symbol]:
					_add_item(current, p, 0, position, p_count, d)
				if nullable[symbol]:
					_add_item(current, prod, dot + 1, origin, p_count, d)


func _terminal_matches(symbol: Dictionary, cp: int) -> bool:
	var set: PackedInt32Array = symbol["set"]
	var inside := false
	var i := 0
	while i + 1 < set.size():
		if cp >= set[i] and cp <= set[i + 1]:
			inside = true
			break
		i += 2
	return inside != bool(symbol["neg"])


func _is_letter(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57


func _hex_value(c: int) -> int:
	if c >= 48 and c <= 57:
		return c - 48
	if c >= 65 and c <= 70:
		return c - 55
	if c >= 97 and c <= 102:
		return c - 87
	return -1


func _line_at(position: int) -> int:
	if position >= 0 and position < _body_lines.size():
		return _body_lines[position]
	if _body_lines.size() > 0:
		return _body_lines[_body_lines.size() - 1]
	return 1


func _set_load_error(position: int, message: String) -> void:
	_load_error = "line %d: %s" % [_line_at(position), message]
