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

fn test_parser_supports_typed_variables_parameters_and_else_if() {
	script := parse_text([
		'$' + 'value i16 = 33'
		'function hello(' + '$' + 'arg run)'
		'dim'
		'    ' + '$' + 'local1 str,'
		'    ' + '$' + 'local2 bool'
		'if typeof(' + '$' + 'arg) is bool'
		'    "bool"'
		'else if typeof(' + '$' + 'arg) is f64'
		'    "float"'
		'endif'
		'endfunction'
		''
	].join('\n'))

	assert script.statements.len == 2

	stmt0 := script.statements[0]
	match stmt0 {
		ast.AssignStmt {
			assert stmt0.target == '$' + 'value'
			assert stmt0.type_name == 'i16'
		}
		else {
			assert false
		}
	}

	stmt1 := script.statements[1]
	match stmt1 {
		ast.FunctionDecl {
			assert stmt1.params.len == 1
			assert stmt1.params[0].type_name == 'run'
			assert stmt1.body.len == 2
			dim_stmt := stmt1.body[0]
			match dim_stmt {
				ast.DimStmt {
					assert dim_stmt.decls.len == 2
					assert dim_stmt.decls[0].type_name == 'str'
					assert dim_stmt.decls[1].type_name == 'bool'
				}
				else {
					assert false
				}
			}
			assert stmt1.body[1] is ast.IfStmt
		}
		else {
			assert false
		}
	}
}

fn test_parser_supports_decl_initializers() {
	script := parse_text([
		'dim'
		'    ' + '$' + 'value1 run = 33.4,'
		'    ' + '$' + 'value2 str = "Hello, World!",'
		'    ' + '$' + 'value3 bool,'
		'    ' + '$' + 'value4'
		''
	].join('\n'))

	assert script.statements.len == 1
	stmt0 := script.statements[0]
	match stmt0 {
		ast.DimStmt {
			assert stmt0.decls.len == 4
			assert stmt0.decls[0].type_name == 'run'
			assert stmt0.decls[0].value is ast.NumberLiteralExpr
			assert stmt0.decls[1].type_name == 'str'
			assert stmt0.decls[1].value is ast.StringLiteralExpr
			assert stmt0.decls[2].type_name == 'bool'
			assert stmt0.decls[2].value is ast.EmptyExpr
			assert stmt0.decls[3].type_name == ''
			assert stmt0.decls[3].value is ast.EmptyExpr
		}
		else {
			assert false
		}
	}
}
