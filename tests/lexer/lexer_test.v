module lexer_test

import source
import tests.helpers
import token
import token.lexer

fn compact_tokens(tokens []token.Token) []token.Token {
	mut out := []token.Token{}
	for tok in tokens {
		if tok.kind in [.newline, .eof] {
			continue
		}
		out << tok
	}
	return out
}

fn test_tokenize_refs_comments_and_keywords() {
	script := helpers.inline_script([
		'; comment',
		':Start',
		'DiM ' + '$' + 'Name',
		'$' + 'Name = "neo" + @DATE + %PATH%',
		'/* block */',
		'',
	])
	src := source.new('lexer_test.kix', script)
	tokens := compact_tokens(lexer.tokenize(src) or { panic(err.msg()) })

	assert tokens.len == 10
	assert tokens[0].kind == .label
	assert tokens[0].lexeme == 'Start'
	assert tokens[1].kind == .name
	assert tokens[1].upper == 'DIM'
	assert tokens[2].kind == .var_ref
	assert tokens[2].lexeme == '$' + 'Name'
	assert tokens[3].kind == .var_ref
	assert tokens[4].kind == .assign
	assert tokens[5].kind == .string
	assert tokens[5].lexeme == 'neo'
	assert tokens[6].kind == .plus
	assert tokens[7].kind == .macro_ref
	assert tokens[7].lexeme == '@DATE'
	assert tokens[8].kind == .plus
	assert tokens[9].kind == .env_ref
	assert tokens[9].lexeme == '%PATH%'
}

fn test_lexer_helpers_inline_script_is_shared() {
	assert helpers.inline_script(['a', 'b']) == 'a\nb'
}
