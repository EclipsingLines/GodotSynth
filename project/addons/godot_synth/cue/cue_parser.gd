class_name CueParser
extends RefCounted

## Parses a .cue file into its AST, or reports the first syntax error.
##
## Every AST node is a Dictionary with a 1-based `line` and `col`.
## Syntax errors use the diagnostic shape
## {code, message, line, col, severity} and parsing stops at the first one.
##
## Returns {ok: bool, ast: Variant, diagnostics: Array[Dictionary]}.
## ok:  {ok = true,  ast = <program Dictionary>, diagnostics = []}
## err: {ok = false, ast = null, diagnostics = [<one E_SYNTAX diagnostic>]}
static func parse(source: String) -> Dictionary:
	var text := source.replace("\r", "")
	if text != "" and not text.ends_with("\n"):
		text += "\n"
	var parser := _Parser.new(text)
	var ast: Variant = parser.parse_program()
	if not parser.error.is_empty():
		var diagnostics: Array[Dictionary] = [parser.error]
		return {"ok": false, "ast": null, "diagnostics": diagnostics}
	var none: Array[Dictionary] = []
	return {"ok": true, "ast": ast, "diagnostics": none}


class _Parser:
	var text: String
	var pos: int = 0
	var error: Dictionary = {}
	var _line_starts: PackedInt32Array = []

	func _init(p_text: String) -> void:
		text = p_text
		_line_starts.append(0)
		for i in range(text.length()):
			if text.unicode_at(i) == 10:
				_line_starts.append(i + 1)

	func parse_program() -> Variant:
		var program: Dictionary = _make_node("program", 0, {"items": []})
		while pos < text.length():
			var c := _peek()
			if c == "\n":
				pos += 1
				continue
			if c == " " or c == "\t":
				_sp()
				if _peek() == "/" and _peek(1) == "/":
					_skip_comment()
					if not _consume_newline():
						return null
					continue
				if _peek() == "\n":
					pos += 1
					continue
				_fail(pos, "unexpected indentation")
				return null
			if c == "/":
				_expect("//")
				if not error.is_empty():
					return null
				_skip_comment_after_marker()
				if not _consume_newline():
					return null
				continue
			var statement: Variant = _parse_statement()
			if statement == null:
				return null
			(program["items"] as Array).append(statement)
		return program

	func _parse_statement() -> Variant:
		var keyword := _match_word(["tempo", "seed", "let", "param", "transition", "stinger", "bind", "state"])
		if keyword == "":
			return null
		var keyword_pos := pos - keyword.length()
		_sp1()
		if not error.is_empty():
			return null
		match keyword:
			"tempo":
				return _parse_tempo(keyword_pos)
			"seed":
				return _parse_seed(keyword_pos)
			"let":
				return _parse_let(keyword_pos)
			"param":
				return _parse_param(keyword_pos)
			"transition":
				return _parse_transition(keyword_pos)
			"stinger":
				return _parse_stinger(keyword_pos)
			"bind":
				return _parse_bind(keyword_pos)
			"state":
				return _parse_state(keyword_pos)
		return null

	func _parse_tempo(keyword_pos: int) -> Variant:
		var bpm := _number(true)
		if not error.is_empty():
			return null
		var beats := 4
		var unit := 4
		var had := _sp()
		if had > 0 and _is_digit(_peek()):
			beats = _int()
			if not error.is_empty():
				return null
			_expect("/")
			if not error.is_empty():
				return null
			unit = _int()
			if not error.is_empty():
				return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("tempo", keyword_pos, {
			"bpm": bpm["value"],
			"beats": beats,
			"unit": unit,
		})

	func _parse_seed(keyword_pos: int) -> Variant:
		var value := _int()
		if not error.is_empty():
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("seed", keyword_pos, {"value": value})

	func _parse_let(keyword_pos: int) -> Variant:
		var name_pos := pos
		var name := _ident()
		if not error.is_empty():
			return null
		_sp()
		_expect("=")
		if not error.is_empty():
			return null
		_sp()
		var expr: Variant = parse_expr()
		if expr == null:
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("let", keyword_pos, {
			"name": name,
			"name_col": _col_at(name_pos),
			"expr": expr,
		})

	func _parse_param(keyword_pos: int) -> Variant:
		var name_pos := pos
		var name := _ident()
		if not error.is_empty():
			return null
		var lo := 0.0
		var hi := 1.0
		if _sp() > 0 and (_is_digit(_peek()) or _peek() == "-"):
			var first := _number(true)
			if not error.is_empty():
				return null
			_expect("..")
			if not error.is_empty():
				return null
			var second := _number(true)
			if not error.is_empty():
				return null
			lo = first["value"]
			hi = second["value"]
		_sp()
		_expect("=")
		if not error.is_empty():
			return null
		_sp()
		var default_pos := pos
		var default_value := _number(true)
		if not error.is_empty():
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("param", keyword_pos, {
			"name": name,
			"name_col": _col_at(name_pos),
			"lo": lo,
			"hi": hi,
			"default": default_value["value"],
			"default_col": _col_at(default_pos),
		})

	func _parse_transition(keyword_pos: int) -> Variant:
		var from_pos := pos
		var from := "*"
		if _peek() == "*":
			pos += 1
		else:
			from = _ident()
			if not error.is_empty():
				return null
		_sp()
		_expect("->")
		if not error.is_empty():
			return null
		_sp()
		var to_pos := pos
		var to := _ident()
		if not error.is_empty():
			return null
		var quant_node: Variant = null
		var fade: Variant = null
		var fill: Variant = null
		if _try_clause("on"):
			quant_node = _parse_quant()
			if quant_node == null:
				return null
		if _try_clause("fade"):
			var fade_number := _number(true)
			if not error.is_empty():
				return null
			fade = fade_number["value"]
		if _try_clause("fill"):
			fill = parse_expr()
			if fill == null:
				return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("transition", keyword_pos, {
			"from": from,
			"from_col": _col_at(from_pos),
			"to": to,
			"to_col": _col_at(to_pos),
			"quant": quant_node,
			"fade": fade,
			"fill": fill,
		})

	func _parse_stinger(keyword_pos: int) -> Variant:
		var name_pos := pos
		var name := _ident()
		if not error.is_empty():
			return null
		var quant_node: Variant = null
		var length := 1.0
		if _try_clause("on"):
			quant_node = _parse_quant()
			if quant_node == null:
				return null
		if _try_clause("len"):
			var length_number := _number(true)
			if not error.is_empty():
				return null
			length = length_number["value"]
		_sp()
		_expect(":")
		if not error.is_empty():
			return null
		_sp()
		var expr: Variant = parse_expr()
		if expr == null:
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("stinger", keyword_pos, {
			"name": name,
			"name_col": _col_at(name_pos),
			"quant": quant_node,
			"len": length,
			"expr": expr,
		})

	func _parse_bind(keyword_pos: int) -> Variant:
		var inst_pos := pos
		var inst := _ident()
		if not error.is_empty():
			return null
		_expect(".")
		if not error.is_empty():
			return null
		var control_pos := pos
		var control := _ident()
		if not error.is_empty():
			return null
		_sp()
		_expect("<-")
		if not error.is_empty():
			return null
		_sp()
		var param_pos := pos
		var param := _ident()
		if not error.is_empty():
			return null
		var lo: Variant = null
		var hi: Variant = null
		if _sp() > 0 and (_is_digit(_peek()) or _peek() == "-"):
			var first := _number(true)
			if not error.is_empty():
				return null
			_expect("..")
			if not error.is_empty():
				return null
			var second := _number(true)
			if not error.is_empty():
				return null
			lo = first["value"]
			hi = second["value"]
		_end_of_line()
		if not error.is_empty():
			return null
		return _make_node("bind", keyword_pos, {
			"inst": inst,
			"inst_col": _col_at(inst_pos),
			"control": control,
			"control_col": _col_at(control_pos),
			"param": param,
			"param_col": _col_at(param_pos),
			"lo": lo,
			"hi": hi,
		})

	func _parse_state(keyword_pos: int) -> Variant:
		var name_pos := pos
		var name := _ident()
		if not error.is_empty():
			return null
		_sp()
		_expect(":")
		if not error.is_empty():
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		var layers: Array = []
		# The first layer must follow the header directly.
		_expect("  ")
		if not error.is_empty():
			return null
		var first: Variant = parse_expr()
		if first == null:
			return null
		_end_of_line()
		if not error.is_empty():
			return null
		layers.append(first)
		while pos < text.length():
			var line_pos := pos
			var i := pos
			while i < text.length() and (text.unicode_at(i) == 32 or text.unicode_at(i) == 9):
				i += 1
			if i < text.length() and text.unicode_at(i) == 10:
				pos = i + 1
				continue
			if i + 1 < text.length() and text.unicode_at(i) == 47 and text.unicode_at(i + 1) == 47:
				while i < text.length() and text.unicode_at(i) != 10:
					i += 1
				pos = i + 1
				continue
			if i == line_pos + 2 and _can_start_expr(text.unicode_at(i)):
				_expect("  ")
				if not error.is_empty():
					return null
				var layer: Variant = parse_expr()
				if layer == null:
					return null
				_end_of_line()
				if not error.is_empty():
					return null
				layers.append(layer)
				continue
			break
		return _make_node("state", keyword_pos, {
			"name": name,
			"name_col": _col_at(name_pos),
			"layers": layers,
		})

	func _parse_quant() -> Variant:
		if _is_digit(_peek()):
			var start := pos
			var count := _int()
			if not error.is_empty():
				return null
			_sp1()
			if not error.is_empty():
				return null
			var kind := _match_word(["bars", "beats"])
			if kind == "":
				return null
			return _make_node("quant", start, {"kind": kind, "count": count})
		var word_pos := pos
		var kind := _match_word(["now", "beat", "bar"])
		if kind == "":
			return null
		return _make_node("quant", word_pos, {"kind": kind, "count": 1})

	func parse_expr() -> Variant:
		var node: Variant = _parse_primary()
		if node == null:
			return null
		while true:
			var c := _peek()
			if c == ".":
				pass
			elif c == "\n":
				var i := pos + 1
				var skipped := 0
				while i < text.length() and (text.unicode_at(i) == 32 or text.unicode_at(i) == 9):
					i += 1
					skipped += 1
				if skipped > 0 and i < text.length() and text.unicode_at(i) == 46:
					pos = i
				else:
					break
			else:
				break
			node = _parse_link(node)
			if node == null:
				return null
		return node

	func _parse_primary() -> Variant:
		if pos >= text.length():
			_fail(pos, "expected an expression")
			return null
		var c := _peek()
		if _is_ident_start(c):
			var start := pos
			var name := _ident()
			if not error.is_empty():
				return null
			if _peek() == "(":
				var args: Variant = _parse_args()
				if args == null:
					return null
				return _make_node("call", start, {
					"name": name,
					"args": args,
					"receiver": null,
				})
			return _make_node("name", start, {"name": name})
		if c == "\"":
			return _parse_string()
		if _is_digit(c) or c == "-":
			var value := _number(false)
			if not error.is_empty():
				return null
			return _make_node("number", value["start"], {"value": value["value"]})
		if c == "(":
			pos += 1
			_ws()
			var inner: Variant = parse_expr()
			if inner == null:
				return null
			_ws()
			_expect(")")
			if not error.is_empty():
				return null
			return inner
		_fail(pos, "expected an expression")
		return null

	func _parse_link(receiver: Dictionary) -> Variant:
		pos += 1 # the dot
		var name_pos := pos
		var name := _ident()
		if not error.is_empty():
			return null
		if _peek() != "(":
			_fail(pos, "expected '('")
			return null
		var args: Variant = _parse_args()
		if args == null:
			return null
		return _make_node("call", name_pos, {
			"name": name,
			"args": args,
			"receiver": receiver,
		})

	func _parse_args() -> Variant:
		pos += 1 # (
		var args: Array = []
		if _peek() == ")":
			pos += 1
			return args
		_ws()
		var first: Variant = parse_expr()
		if first == null:
			return null
		args.append(first)
		while true:
			_ws()
			var c := _peek()
			if c == ",":
				pos += 1
				_ws()
				var next: Variant = parse_expr()
				if next == null:
					return null
				args.append(next)
			elif c == ")":
				pos += 1
				return args
			else:
				_fail(pos, "expected ',' or ')'")
				return null
		return null

	func _parse_string() -> Variant:
		var quote_pos := pos
		pos += 1
		var start := pos
		while pos < text.length() and text.unicode_at(pos) != 34 and text.unicode_at(pos) != 10:
			pos += 1
		var content := text.substr(start, pos - start)
		var mini_result := CueMini.parse(content)
		if not mini_result["ok"]:
			var quote_lc := _line_col(quote_pos)
			var mini_error: Dictionary = mini_result["error"]
			_fail_at(quote_lc.x, quote_lc.y + 1 + int(mini_error["col"]), str(mini_error["message"]))
			return null
		if pos >= text.length() or text.unicode_at(pos) != 34:
			_fail(pos, "unterminated string")
			return null
		pos += 1
		return _make_node("string", quote_pos, {
			"text": content,
			"mini": mini_result["ast"],
		})

	func _sp() -> int:
		var start := pos
		while pos < text.length():
			var c := text.unicode_at(pos)
			if c == 32 or c == 9:
				pos += 1
			else:
				break
		return pos - start

	func _sp1() -> int:
		var count := _sp()
		if count == 0:
			_fail(pos, "expected whitespace")
		return count

	func _ws() -> void:
		while pos < text.length():
			var c := text.unicode_at(pos)
			if c == 32 or c == 9 or c == 10:
				pos += 1
			else:
				break

	func _ident() -> String:
		if not _is_ident_start(_peek_char()):
			_fail(pos, "expected an identifier")
			return ""
		var start := pos
		pos += 1
		while _is_ident_char(_peek_char()):
			pos += 1
		return text.substr(start, pos - start)

	func _number(strict: bool) -> Dictionary:
		var start := pos
		if _peek() == "-":
			pos += 1
			if not _is_digit(_peek()):
				_fail(pos, "expected a digit")
				return {}
		if not _is_digit(_peek()):
			_fail(pos, "expected a number")
			return {}
		while _is_digit(_peek()):
			pos += 1
		if _peek() == ".":
			if _is_digit(_peek(1)):
				pos += 1
				while _is_digit(_peek()):
					pos += 1
			elif _peek(1) == ".":
				pass
			elif strict:
				pos += 1
				_fail(pos, "expected a digit after '.'")
				return {}
		return {"value": text.substr(start, pos - start).to_float(), "start": start}

	func _int() -> int:
		if not _is_digit(_peek()):
			_fail(pos, "expected an integer")
			return 0
		var start := pos
		while _is_digit(_peek()):
			pos += 1
		return int(text.substr(start, pos - start))

	func _expect(literal: String) -> void:
		for i in range(literal.length()):
			if pos + i >= text.length() or text.unicode_at(pos + i) != literal.unicode_at(i):
				_fail(pos + i, "expected '%s'" % literal)
				return
		pos += literal.length()

	func _end_of_line() -> void:
		_sp()
		if _peek() == "/" and _peek(1) == "/":
			_skip_comment()
		if not _consume_newline():
			return

	func _try_clause(keyword: String) -> bool:
		var save := pos
		if _sp() <= 0:
			pos = save
			return false
		if pos + keyword.length() > text.length() or text.substr(pos, keyword.length()) != keyword:
			pos = save
			return false
		pos += keyword.length()
		_sp1()
		if not error.is_empty():
			return false
		return true

	func _match_word(candidates: Array) -> String:
		var best := ""
		var best_len := -1
		for candidate: String in candidates:
			var matched := 0
			while matched < candidate.length() and pos + matched < text.length() \
					and text.unicode_at(pos + matched) == candidate.unicode_at(matched):
				matched += 1
			if matched > best_len:
				best_len = matched
				best = candidate
		if best_len < best.length():
			_fail(pos + best_len, "unexpected input")
			return ""
		pos += best.length()
		return best

	func _skip_comment() -> void:
		# At the "//" marker.
		pos += 2
		_skip_comment_after_marker()

	func _skip_comment_after_marker() -> void:
		while pos < text.length() and text.unicode_at(pos) != 10:
			pos += 1

	func _consume_newline() -> bool:
		if _peek() != "\n":
			_fail(pos, "expected end of line")
			return false
		pos += 1
		return true

	func _col_at(offset: int) -> int:
		return _line_col(offset).y

	func _line_col(offset: int) -> Vector2i:
		var lo := 0
		var hi := _line_starts.size() - 1
		while lo < hi:
			var mid := (lo + hi + 1) >> 1
			if _line_starts[mid] <= offset:
				lo = mid
			else:
				hi = mid - 1
		return Vector2i(lo + 1, offset - _line_starts[lo] + 1)

	func _fail(offset: int, message: String) -> void:
		if not error.is_empty():
			return
		var lc := _line_col(offset)
		error = {
			"code": "E_SYNTAX",
			"message": message,
			"line": lc.x,
			"col": lc.y,
			"severity": "error",
		}

	func _fail_at(line: int, col: int, message: String) -> void:
		if not error.is_empty():
			return
		error = {
			"code": "E_SYNTAX",
			"message": message,
			"line": line,
			"col": col,
			"severity": "error",
		}

	func _make_node(node_type: String, offset: int, extra: Dictionary) -> Dictionary:
		var lc := _line_col(offset)
		var node: Dictionary = {"type": node_type, "line": lc.x, "col": lc.y}
		node.merge(extra)
		return node

	func _peek(offset: int = 0) -> String:
		var index := pos + offset
		if index >= 0 and index < text.length():
			return text[index]
		return ""

	func _peek_char() -> String:
		return _peek()

	func _is_digit(c: String) -> bool:
		return c >= "0" and c <= "9"

	func _is_letter(c: String) -> bool:
		return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")

	func _is_ident_start(c: String) -> bool:
		return _is_letter(c) or c == "_"

	func _is_ident_char(c: String) -> bool:
		return _is_letter(c) or _is_digit(c) or c == "_"

	func _can_start_expr(c: int) -> bool:
		return _is_ident_start(String.chr(c)) or c == 34 or (c >= 48 and c <= 57) or c == 45 or c == 40
