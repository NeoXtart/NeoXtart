module token

import source.diag

pub enum Kind {
	eof
	newline
	name
	number
	string
	var_ref
	macro_ref
	env_ref
	label
	question
	comma
	dot
	colon
	lpar
	rpar
	lsbr
	rsbr
	plus
	minus
	star
	slash
	assign
	eq
	ne
	lt
	gt
	le
	ge
	amp
	pipe
	caret
	tilde
}

pub struct Token {
pub:
	kind   Kind
	lexeme string
	upper  string
	span   diag.Span
}

pub fn (tok Token) str() string {
	return '${tok.kind}(${tok.lexeme})'
}

pub fn (tok Token) is_name(value string) bool {
	return tok.kind == .name && tok.upper == value
}

pub fn (tok Token) is_one_of(values []string) bool {
	if tok.kind != .name {
		return false
	}
	return tok.upper in values
}
