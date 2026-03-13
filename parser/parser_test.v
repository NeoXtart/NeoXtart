module parser

import ast
import source
import token.lexer

fn parse_text(text string) ast.Script {
	src := source.new('parser_test.kix', text)
	tokens := lexer.tokenize(src) or { panic(err.msg()) }
	return parse(src, tokens) or { panic(err.msg()) }
}

fn parse_error(text string) string {
	src := source.new('parser_test.kix', text)
	tokens := lexer.tokenize(src) or { panic(err.msg()) }
	_ := parse(src, tokens) or { return err.msg() }
	return ''
}

fn test_parser_handles_empty_call_args_and_multiline_expressions() {
	script := parse_text([
		'$' + 'result = Foo(1,,3)'
		'$' + 'text = "A" +'
		'  "B"'
		''
	].join('\n'))

	assert script.statements.len == 2

	stmt0 := script.statements[0]
	match stmt0 {
		ast.AssignStmt {
			assert stmt0.target == '$' + 'result'
			expr0 := stmt0.value
			match expr0 {
				ast.CallExpr {
					assert expr0.args.len == 3
					assert expr0.args[1] is ast.EmptyExpr
				}
				else {
					assert false
				}
			}
		}
		else {
			assert false
		}
	}

	stmt1 := script.statements[1]
	match stmt1 {
		ast.AssignStmt {
			assert stmt1.target == '$' + 'text'
			expr1 := stmt1.value
			match expr1 {
				ast.BinaryExpr {
					assert expr1.op == '+'
				}
				else {
					assert false
				}
			}
		}
		else {
			assert false
		}
	}
}

fn test_parser_keeps_question_as_newline_command_only() {
	script := parse_text([
		'?'
		'"Hello"'
		'if 1 = 1 goto done endif'
		':done'
		''
	].join('\n'))

	assert script.statements.len == 4
	assert script.statements[0] is ast.NewlineStmt
	assert script.statements[1] is ast.DisplayStmt
	assert script.statements[2] is ast.IfStmt
	assert script.statements[3] is ast.LabelStmt
}

fn test_parser_supports_result_and_rejects_return_value() {
	script := parse_text([
		'function Demo()'
		'result 42'
		'endfunction'
		''
	].join('\n'))

	assert script.statements.len == 1
	stmt0 := script.statements[0]
	match stmt0 {
		ast.FunctionDecl {
			assert stmt0.body.len == 1
			assert stmt0.body[0] is ast.ResultStmt
		}
		else {
			assert false
		}
	}

	errmsg := parse_error([
		'function Demo()'
		'return 42'
		'endfunction'
		''
	].join('\n'))
	assert errmsg.contains('NX0104')
}
