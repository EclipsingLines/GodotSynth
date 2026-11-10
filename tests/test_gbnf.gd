extends SceneTree
# Tests for the GBNF recognizer utility: grammar parsing errors and Earley
# recognition against toy grammars.
# Run: bash tests/verify.sh --no-build tests/test_gbnf.gd
# Exits with code 0 when every check passes, 1 otherwise.

const GbnfScript = preload("res://addons/godot_synth/cue/cue_gbnf.gd")

var failures: Array[String] = []


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS " + name)
	else:
		print("FAIL " + name + ": " + detail)
		failures.append(name)


func load_ok(name: String, text: String) -> RefCounted:
	var grammar = GbnfScript.load_grammar(text)
	check(name + " loads", grammar.get_error() == "", grammar.get_error())
	return grammar


func expect_accept(name: String, grammar: RefCounted, text: String, start_rule: String = "root") -> void:
	var accepted: bool = grammar.accepts(text, start_rule)
	check(name, accepted and grammar.error_position() == -1,
		"expected accept, got accepted=%s position=%d error=%s" % [str(accepted), grammar.error_position(), grammar.get_error()])


func expect_reject(name: String, grammar: RefCounted, text: String, position: int, start_rule: String = "root") -> void:
	var accepted: bool = grammar.accepts(text, start_rule)
	check(name, not accepted and grammar.error_position() == position,
		"expected reject at %d, got accepted=%s position=%d error=%s" % [position, str(accepted), grammar.error_position(), grammar.get_error()])


func _initialize() -> void:
	var arithmetic := """root ::= expr nl
expr ::= expr "+" term | term
term ::= term "*" factor | factor
factor ::= num | "(" expr ")"
num ::= [0-9]+
nl ::= "\\n"
"""
	var arith := load_ok("arithmetic", arithmetic)
	expect_accept("arithmetic 42", arith, "42\n")
	expect_accept("arithmetic precedence", arith, "1+2*3\n")
	expect_accept("arithmetic parentheses", arith, "(1+2)*3\n")
	expect_reject("arithmetic missing term", arith, "1+\n", 2)
	expect_reject("arithmetic missing close", arith, "(1+2\n", 4)
	expect_reject("arithmetic leading close", arith, ")\n", 0)
	expect_reject("arithmetic missing newline", arith, "1+2", 3)

	var classes := load_ok("classes", "root ::= [a-c] [^a-c0-9]+\n")
	expect_accept("class range and negated", classes, "axyz")
	expect_accept("class punctuation", classes, "b-!")
	expect_reject("class first mismatch", classes, "d", 0)
	expect_reject("class negated excludes b", classes, "ab", 1)
	expect_reject("class needs one more", classes, "a", 1)

	var escapes := load_ok("class escapes", "root ::= \"x\" [\\]\\\\]\n")
	expect_accept("class escaped close", escapes, "x]")
	expect_accept("class escaped backslash", escapes, "x\\")
	var whitespace := load_ok("whitespace class", "root ::= [ \\t\\n]* \"z\"\n")
	expect_accept("whitespace class with tabs", whitespace, " \t\n z")
	expect_accept("whitespace class empty", whitespace, "z")

	var repeat := load_ok("repeat", "root ::= \"a\"* \"b\"+ \"c\"?\n")
	expect_accept("repeat single b", repeat, "b")
	expect_accept("repeat all parts", repeat, "aabbc")
	expect_accept("repeat many b", repeat, "bbb")
	expect_reject("repeat empty", repeat, "", 0)
	expect_reject("repeat missing b", repeat, "aac", 2)
	expect_reject("repeat extra c", repeat, "abcc", 3)

	var groups := load_ok("groups", "root ::= (\"ab\" | \"cd\")+\n")
	expect_accept("group repeated", groups, "abcdab")
	expect_reject("group partial", groups, "abc", 3)
	expect_reject("group bad start", groups, "abd", 2)

	var ambiguous := load_ok("ambiguous", "root ::= s\ns ::= s s | \"a\"\n")
	expect_accept("ambiguous single", ambiguous, "a")
	expect_accept("ambiguous 40 a", ambiguous, "a".repeat(40))
	expect_reject("ambiguous empty", ambiguous, "", 0)
	expect_reject("ambiguous ab", ambiguous, "ab", 1)

	var nullable := load_ok("nullable ambiguity", "root ::= a a\na ::= \"x\"?\n")
	expect_accept("nullable empty", nullable, "")
	expect_accept("nullable one", nullable, "x")
	expect_accept("nullable two", nullable, "xx")
	expect_reject("nullable three", nullable, "xxx", 2)

	var syntax := load_ok("syntax", """# a comment line
root ::= a-b suffix   # trailing comment
a-b ::= "x" "\\\"" "\\x41"
suffix ::= [^\\n]*
      | "y"
""")
	expect_accept("syntax features", syntax, "x\"Ahello")
	expect_reject("syntax hex literal", syntax, "x\"Bhello", 2)

	expect_accept("start rule num", arith, "12", "num")
	expect_reject("start rule num rejects", arith, "1+2", 1, "num")
	var unknown_ok: bool = arith.accepts("12", "missing")
	check("unknown start rule", not unknown_ok and arith.get_error() != "",
		"expected false and an error, got accepted=%s error='%s'" % [str(unknown_ok), arith.get_error()])

	var empty_alt := load_ok("empty alternative", "root ::= | \"x\"\n")
	expect_accept("empty alternative empty", empty_alt, "")
	expect_accept("empty alternative x", empty_alt, "x")

	var malformed: Array = [
		["missing rule header", "@root ::= \"x\"\n"],
		["missing ::=", "root \"x\"\n"],
		["unterminated literal", "root ::= \"abc\n"],
		["unterminated class", "root ::= [a-z\n"],
		["unbalanced open paren", "root ::= (\"a\"\n"],
		["unbalanced close paren", "root ::= \"a\")\n"],
		["bad literal escape", "root ::= \"\\q\"\n"],
		["bad class escape", "root ::= [\\q]\n"],
		["empty rule body", "root ::=\n"],
		["duplicate rule", "root ::= \"x\"\nroot ::= \"y\"\n"],
		["undefined rule", "root ::= foo\n"],
		["invalid continuation", "root ::= \"x\"\n@\n"],
	]
	for case in malformed:
		var name: String = case[0]
		var grammar = GbnfScript.load_grammar(case[1])
		check("malformed " + name + " reports", grammar.get_error() != "", "expected a load error")
		var accepted: bool = grammar.accepts("x")
		check("malformed " + name + " accepts false", not accepted and grammar.get_error() != "",
			"expected false without clobbering the load error, got accepted=%s error='%s'" % [str(accepted), grammar.get_error()])

	var undefined_grammar = GbnfScript.load_grammar("root ::= foo\n")
	check("undefined rule names foo", undefined_grammar.get_error().contains("foo"),
		"error was '" + undefined_grammar.get_error() + "'")

	var first = GbnfScript.load_grammar("root ::= \"a\"\n")
	var second = GbnfScript.load_grammar("root ::= \"b\"\n")
	check("instances do not share rules",
		first.accepts("a") and second.accepts("b") and not first.accepts("b") and not second.accepts("a"),
		"loaded grammars interfere with each other")

	if failures.is_empty():
		print("PASS all gbnf checks")
		quit(0)
	else:
		print("FAILURES: " + ", ".join(failures))
		quit(1)
