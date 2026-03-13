module lexer

import source
import source.diag
import token

pub struct Lexer {
	source source.Source
mut:
	text  string
	index int
	line  int = 1
	col   int = 1
}

pub fn tokenize(src source.Source) ![]token.Token {
	mut lexer := Lexer{
		source: src
		text:   src.text
	}
	return lexer.run()
}

fn (mut l Lexer) run() ![]token.Token {
	mut tokens := []token.Token{}
	for !l.is_eof() {
		if tok := l.next_token() {
			tokens << tok
		}
	}
	eof_span := diag.single_pos(l.line, l.col, l.index)
	tokens << token.Token{
		kind:   .eof
		lexeme: ''
		upper:  ''
		span:   eof_span
	}
	return tokens
}

fn (mut l Lexer) next_token() ?token.Token {
	for {
		if l.is_eof() {
			return none
		}
		ch := l.current()
		if ch == ` ` || ch == `\t` || ch == `\r` {
			l.advance()
			continue
		}
		if ch == `\n` {
			return l.simple_token(.newline, '\n')
		}
		if ch == `;` {
			l.skip_line_comment()
			continue
		}
		if ch == `/` && l.peek(1) == `*` {
			l.skip_block_comment() or { panic(err.msg()) }
			continue
		}
		break
	}
	start := l.mark()
	ch := l.current()
	match ch {
		`?` {
			return l.simple_token(.question, '?')
		}
		`,` {
			return l.simple_token(.comma, ',')
		}
		`.` {
			return l.simple_token(.dot, '.')
		}
		`:` {
			return l.scan_label_or_colon()
		}
		`(` {
			return l.simple_token(.lpar, '(')
		}
		`)` {
			return l.simple_token(.rpar, ')')
		}
		`[` {
			return l.simple_token(.lsbr, '[')
		}
		`]` {
			return l.simple_token(.rsbr, ']')
		}
		`+` {
			return l.simple_token(.plus, '+')
		}
		`-` {
			return l.simple_token(.minus, '-')
		}
		`*` {
			return l.simple_token(.star, '*')
		}
		`/` {
			return l.simple_token(.slash, '/')
		}
		`~` {
			return l.simple_token(.tilde, '~')
		}
		`^` {
			return l.simple_token(.caret, '^')
		}
		`|` {
			return l.simple_token(.pipe, '|')
		}
		`&` {
			if is_hex_digit(l.peek(1)) {
				return l.scan_hex_number()
			}
			return l.simple_token(.amp, '&')
		}
		`<` {
			if l.peek(1) == `=` {
				return l.double_token(.le, '<=')
			}
			if l.peek(1) == `>` {
				return l.double_token(.ne, '<>')
			}
			return l.simple_token(.lt, '<')
		}
		`>` {
			if l.peek(1) == `=` {
				return l.double_token(.ge, '>=')
			}
			return l.simple_token(.gt, '>')
		}
		`=` {
			if l.peek(1) == `=` {
				return l.double_token(.eq, '==')
			}
			return l.simple_token(.assign, '=')
		}
		`"`, `'` {
			return l.scan_string()
		}
		`$` {
			return l.scan_var_ref()
		}
		`@` {
			return l.scan_macro_ref()
		}
		`%` {
			if l.can_scan_env_ref() {
				return l.scan_env_ref()
			}
		}
		else {}
	}
	if is_digit(ch) {
		return l.scan_number()
	}
	if is_name_start(ch) {
		return l.scan_name()
	}
	span := diag.single_pos(start.line, start.col, start.offset)
	panic(l.source.diagnostic('NX0001', 'unexpected character `${rune(ch)}`', span, []).str())
}

struct Mark {
	line   int
	col    int
	offset int
}

fn (l Lexer) mark() Mark {
	return Mark{
		line:   l.line
		col:    l.col
		offset: l.index
	}
}

fn (mut l Lexer) simple_token(kind token.Kind, value string) token.Token {
	start := l.mark()
	l.advance()
	return token.Token{
		kind:   kind
		lexeme: value
		upper:  value.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) double_token(kind token.Kind, value string) token.Token {
	start := l.mark()
	l.advance()
	l.advance()
	return token.Token{
		kind:   kind
		lexeme: value
		upper:  value.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_label_or_colon() token.Token {
	start := l.mark()
	l.advance()
	if !is_name_start(l.current()) {
		return token.Token{
			kind:   .colon
			lexeme: ':'
			upper:  ':'
			span:   span_from_mark(start, l.line, l.col, l.index)
		}
	}
	name := l.read_while(is_name_part)
	return token.Token{
		kind:   .label
		lexeme: name
		upper:  name.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_string() token.Token {
	start := l.mark()
	quote := l.current()
	l.advance()
	mut literal := []u8{}
	for !l.is_eof() {
		ch := l.current()
		if ch == quote {
			l.advance()
			return token.Token{
				kind:   .string
				lexeme: literal.bytestr()
				upper:  literal.bytestr()
				span:   span_from_mark(start, l.line, l.col, l.index)
			}
		}
		literal << ch
		l.advance()
	}
	panic(l.source.diagnostic('NX0002', 'unterminated string literal', span_from_mark(start,
		l.line, l.col, l.index), []).str())
}

fn (mut l Lexer) scan_var_ref() token.Token {
	start := l.mark()
	l.advance()
	name := if is_name_start(l.current()) {
		l.read_while(is_name_part)
	} else {
		''
	}
	lexeme := '$' + name
	return token.Token{
		kind:   .var_ref
		lexeme: lexeme
		upper:  lexeme.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_macro_ref() token.Token {
	start := l.mark()
	l.advance()
	name := l.read_while(is_name_part)
	lexeme := '@' + name
	return token.Token{
		kind:   .macro_ref
		lexeme: lexeme
		upper:  lexeme.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (l Lexer) can_scan_env_ref() bool {
	if l.current() != `%` {
		return false
	}
	mut offset := 1
	for !l.is_eof_at(offset) {
		ch := l.peek(offset)
		if ch == `%` {
			return offset > 1
		}
		if ch == `\n` || ch == `\r` {
			return false
		}
		offset++
	}
	return false
}

fn (mut l Lexer) scan_env_ref() token.Token {
	start := l.mark()
	l.advance()
	mut name := []u8{}
	for !l.is_eof() && l.current() != `%` {
		name << l.current()
		l.advance()
	}
	if l.current() == `%` {
		l.advance()
	}
	lexeme := '%' + name.bytestr() + '%'
	return token.Token{
		kind:   .env_ref
		lexeme: lexeme
		upper:  lexeme.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_hex_number() token.Token {
	start := l.mark()
	mut value := []u8{}
	value << l.current()
	l.advance()
	for !l.is_eof() && is_hex_digit(l.current()) {
		value << l.current()
		l.advance()
	}
	text := value.bytestr()
	return token.Token{
		kind:   .number
		lexeme: text
		upper:  text.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_number() token.Token {
	start := l.mark()
	mut value := []u8{}
	mut seen_dot := false
	mut seen_exp := false
	for !l.is_eof() {
		ch := l.current()
		if is_digit(ch) {
			value << ch
			l.advance()
			continue
		}
		if ch == `.` && !seen_dot && !seen_exp && is_digit(l.peek(1)) {
			seen_dot = true
			value << ch
			l.advance()
			continue
		}
		if (ch == `e` || ch == `E`) && !seen_exp {
			seen_exp = true
			value << ch
			l.advance()
			if l.current() == `+` || l.current() == `-` {
				value << l.current()
				l.advance()
			}
			continue
		}
		break
	}
	text := value.bytestr()
	return token.Token{
		kind:   .number
		lexeme: text
		upper:  text.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) scan_name() token.Token {
	start := l.mark()
	text := l.read_while(is_name_part)
	return token.Token{
		kind:   .name
		lexeme: text
		upper:  text.to_upper()
		span:   span_from_mark(start, l.line, l.col, l.index)
	}
}

fn (mut l Lexer) skip_line_comment() {
	for !l.is_eof() && l.current() != `\n` {
		l.advance()
	}
}

fn (mut l Lexer) skip_block_comment() ! {
	l.advance()
	l.advance()
	for !l.is_eof() {
		if l.current() == `*` && l.peek(1) == `/` {
			l.advance()
			l.advance()
			return
		}
		l.advance()
	}
	return error('unterminated block comment')
}

fn (mut l Lexer) read_while(predicate fn (u8) bool) string {
	mut value := []u8{}
	for !l.is_eof() && predicate(l.current()) {
		value << l.current()
		l.advance()
	}
	return value.bytestr()
}

fn (mut l Lexer) advance() {
	if l.is_eof() {
		return
	}
	ch := l.current()
	l.index++
	if ch == `\n` {
		l.line++
		l.col = 1
	} else {
		l.col++
	}
}

fn (l Lexer) current() u8 {
	if l.is_eof() {
		return 0
	}
	return l.text[l.index]
}

fn (l Lexer) peek(offset int) u8 {
	idx := l.index + offset
	if idx < 0 || idx >= l.text.len {
		return 0
	}
	return l.text[idx]
}

fn (l Lexer) is_eof() bool {
	return l.index >= l.text.len
}

fn (l Lexer) is_eof_at(offset int) bool {
	return l.index + offset >= l.text.len
}

fn span_from_mark(start Mark, end_line int, end_col int, end_offset int) diag.Span {
	return diag.Span{
		start: diag.Pos{
			line:   start.line
			col:    start.col
			offset: start.offset
		}
		end:   diag.Pos{
			line:   end_line
			col:    end_col
			offset: end_offset
		}
	}
}

fn is_digit(ch u8) bool {
	return ch >= `0` && ch <= `9`
}

fn is_hex_digit(ch u8) bool {
	return is_digit(ch) || (ch >= `A` && ch <= `F`) || (ch >= `a` && ch <= `f`)
}

fn is_name_start(ch u8) bool {
	return (ch >= `A` && ch <= `Z`) || (ch >= `a` && ch <= `z`) || ch == `_`
}

fn is_name_part(ch u8) bool {
	return is_name_start(ch) || is_digit(ch)
}
