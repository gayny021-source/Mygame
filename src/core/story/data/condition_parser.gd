class_name ConditionParser
extends RefCounted
## Parses the text of an `if` key into a Condition tree (ADR-0001 §5). Data is a
## trust boundary: a syntax error is one DT-08 finding, a name the hero does not
## declare is BS-01 (once per name), never a crash. A finding's message starts with
## the 1-based position in the text; `path` and `object_id` are left empty for the
## loader to fill.
##
## Usage: [code]var parsed := ConditionParser.parse("f_a and not f_b", known)[/code],
## then [code]parsed.condition.evaluate(ctx)[/code] when [code]parsed.issues[/code] is empty.

## Deepest nesting of brackets and `not` together. Keeps the recursion of the
## parser and of Condition.evaluate far below the GDScript call stack limit.
const MAX_DEPTH: int = 32
## Longest condition text, in symbols; a longer one is DT-08 and is not read.
const MAX_LENGTH: int = 1000
## Words of the language; none of them can be a flag, category or group id.
const RESERVED: PackedStringArray = ["and", "or", "not", "any", "cat", "group"]
const WHITESPACE: PackedStringArray = [" ", "\t", "\r", "\n"]
const END := ""

var _tokens: PackedStringArray = []
var _positions: PackedInt32Array = []
var _index: int = 0
var _depth: int = 0
var _known: ConditionVocabulary
var _issues: Array[DataIssue] = []
# Сообщения BS-01 без позиции: повтор того же имени не даёт второй находки.
var _unknown: PackedStringArray = []


## Result of `parse`: `condition` is the tree, or null when `issues` is not empty.
class ParseResult extends RefCounted:
	var condition: Condition
	var issues: Array[DataIssue] = []


## Parses `text`. Names are checked against `known`; with `known` null only the
## syntax is checked. Empty text is DT-08: no condition means no `if` key.
static func parse(text: String, known: ConditionVocabulary) -> ParseResult:
	var parser: ConditionParser = ConditionParser.new()
	parser._known = known
	var result: ParseResult = ParseResult.new()
	result.issues = parser._issues
	var root: Condition = parser._root(text)
	if result.issues.is_empty():
		result.condition = root
	return result


func _root(text: String) -> Condition:
	if text.length() > MAX_LENGTH:
		_issue("DT-08", MAX_LENGTH + 1, "условие длиннее %d символов" % MAX_LENGTH)
		return null
	if not _tokenize(text):
		return null
	if _peek() == END:
		_fail("пустое условие; если условия нет, уберите ключ if")
		return null
	var root: Condition = _chain()
	if root != null and _peek() != END:
		_fail("ожидалась связка and / or или конец условия, получено %s" % _shown())
		return null
	return root


func _tokenize(text: String) -> bool:
	var length: int = text.length()
	var i: int = 0
	while i < length:
		var symbol: String = text[i]
		if WHITESPACE.has(symbol):
			i += 1
			continue
		var start: int = i
		if symbol == "(" or symbol == ")" or symbol == ",":
			i += 1
		elif text.substr(i, 2) == "==":
			i += 2
		elif _is_lower(symbol):
			i = _word_end(text, i)
		else:
			# Код символа — чтобы сценарист увидел невидимое (U+00A0 и т. п.).
			var shown: String = "«%s» (U+%04X)" % [symbol, symbol.unicode_at(0)]
			_issue("DT-08", start + 1, "недопустимый символ %s; имена — по ^[a-z][a-z0-9_]*$" % shown)
			return false
		_tokens.append(text.substr(start, i - start))
		_positions.append(start + 1)
	_tokens.append(END)
	_positions.append(length + 1)
	return true


static func _is_lower(symbol: String) -> bool:
	return symbol >= "a" and symbol <= "z"


static func _word_end(text: String, start: int) -> int:
	var i: int = start + 1
	while i < text.length():
		var symbol: String = text[i]
		var is_digit: bool = symbol >= "0" and symbol <= "9"
		if not _is_lower(symbol) and not is_digit and symbol != "_":
			break
		i += 1
	return i


# Цепочка только из and или только из or: смешение без скобок — DT-08 (ADR-0001 §5).
func _chain() -> Condition:
	var first: Condition = _unary()
	if first == null:
		return null
	var connective: String = _peek()
	if connective != "and" and connective != "or":
		return first
	var node: Condition = Condition.new(Condition.Kind.AND if connective == "and" else Condition.Kind.OR)
	node.children.append(first)
	while _peek() == connective:
		_index += 1
		var operand: Condition = _unary()
		if operand == null:
			return null
		node.children.append(operand)
	if _peek() == "and" or _peek() == "or":
		_fail("and и or в одной цепочке без скобок; напишите (a and b) or c")
		return null
	return node


func _unary() -> Condition:
	if _peek() != "not":
		return _atom()
	if not _descend():
		return null
	var operand: Condition = _unary()
	_depth -= 1
	if operand == null:
		return null
	var node: Condition = Condition.new(Condition.Kind.NOT)
	node.children.append(operand)
	return node


func _atom() -> Condition:
	match _peek():
		"(":
			return _brackets()
		"any":
			return _any()
		"cat":
			return _category()
		"group":
			return _group()
	var node: Condition = Condition.new(Condition.Kind.FLAG)
	if not _flag(node):
		return null
	return node


func _brackets() -> Condition:
	if not _descend():
		return null
	var inner: Condition = _chain()
	_depth -= 1
	if inner == null:
		return null
	if not _expect(")"):
		return null
	return inner


func _any() -> Condition:
	_index += 1
	if not _expect("("):
		return null
	var node: Condition = Condition.new(Condition.Kind.ANY)
	if not _flag(node):
		return null
	while _peek() == ",":
		_index += 1
		if not _flag(node):
			return null
	if not _expect(")"):
		return null
	return node


func _category() -> Condition:
	_index += 1
	var node: Condition = Condition.new(Condition.Kind.CATEGORY)
	if not _expect("("):
		return null
	var position: int = _positions[_index]
	node.name = _name("категории")
	if node.name.is_empty():
		return null
	if not _expect(")"):
		return null
	if _known != null and not _known.categories.has(node.name):
		_report_unknown(position, "категория «%s» не объявлена у героя" % node.name)
	return node


func _group() -> Condition:
	_index += 1
	var node: Condition = Condition.new(Condition.Kind.GROUP)
	if not _expect("("):
		return null
	var position: int = _positions[_index]
	node.name = _name("группы")
	if node.name.is_empty():
		return null
	if not _expect(")"):
		return null
	if not _expect("=="):
		return null
	if _known != null and not _known.groups.has(node.name):
		_report_unknown(position, "группа «%s» не объявлена у героя" % node.name)
	if not _flag(node):
		return null
	return node


# Читает id флага в `node.flags`; необъявленный флаг — BS-01, разбор идёт дальше.
func _flag(node: Condition) -> bool:
	var position: int = _positions[_index]
	var id: String = _name("флага")
	if id.is_empty():
		return false
	node.flags.append(id)
	if _known != null and not _known.flags.has(id):
		_report_unknown(position, "флаг «%s» не объявлен у героя" % id)
	return true


# Имя либо пустая строка с находкой DT-08: слова языка именами не бывают.
func _name(what: String) -> String:
	var token: String = _peek()
	if token == END or not _is_lower(token[0]) or RESERVED.has(token):
		_fail("ожидался id %s, получено %s" % [what, _shown()])
		return ""
	_index += 1
	return token


# Шаг вглубь через `(` или `not`; глубже MAX_DEPTH — DT-08 вместо переполнения стека.
func _descend() -> bool:
	if _depth >= MAX_DEPTH:
		_fail("вложенность скобок и not глубже %d" % MAX_DEPTH)
		return false
	_index += 1
	_depth += 1
	return true


func _expect(token: String) -> bool:
	if _peek() != token:
		_fail("ожидалось «%s», получено %s" % [token, _shown()])
		return false
	_index += 1
	return true


func _peek() -> String:
	return _tokens[_index]


func _shown() -> String:
	return "конец условия" if _peek() == END else "«%s»" % _peek()


# DT-08 на текущем токене.
func _fail(message: String) -> void:
	_issue("DT-08", _positions[_index], message)


# BS-01 один раз на имя, с позицией первого вхождения.
func _report_unknown(position: int, message: String) -> void:
	if _unknown.has(message):
		return
	_unknown.append(message)
	_issue("BS-01", position, message)


func _issue(code: String, position: int, message: String) -> void:
	_issues.append(DataIssue.new(code, "", "", "позиция %d: %s" % [position, message]))
