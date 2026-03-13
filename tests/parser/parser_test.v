module parser_test

import runtime
import tests.helpers

fn dump_ast(text string) string {
	path := helpers.write_temp_script('parser_test.kix', text) or { panic(err.msg()) }
	return runtime.dump_ast_file(path) or { panic(err.msg()) }
}

fn parse_error(text string) string {
	path := helpers.write_temp_script('parser_error.kix', text) or { panic(err.msg()) }
	runtime.check_file(path) or { return err.msg() }
	return ''
}

fn test_parser_handles_empty_call_args_and_multiline_expressions() {
	dump_output := dump_ast(helpers.inline_script([
		'$' + 'result = Foo(1,,3)',
		'$' + 'text = "A" +',
		'  "B"',
		'',
	]))

	assert dump_output.contains('Assign($' + 'result = Foo(1, <empty>, 3))')
	assert dump_output.contains('Assign($' + 'text = ("A" + "B"))')
}

fn test_parser_keeps_question_as_newline_command_only() {
	dump_output := dump_ast(helpers.inline_script([
		'?',
		'"Hello"',
		'if 1 = 1 goto done endif',
		':done',
		'',
	]))

	assert dump_output.contains('\n  Newline')
	assert dump_output.contains('\n  Display("Hello")')
	assert dump_output.contains('\n  If((1 = 1))')
	assert dump_output.contains('\n    Goto(done)')
	assert dump_output.contains('\n  Label(done)')
}

fn test_parser_supports_result_and_rejects_return_value() {
	dump_output := dump_ast(helpers.inline_script([
		'function Demo()',
		'result 42',
		'endfunction',
		'',
	]))

	assert dump_output.contains('Function(Demo())')
	assert dump_output.contains('\n    Result(42)')

	errmsg := parse_error(helpers.inline_script([
		'function Demo()',
		'return 42',
		'endfunction',
		'',
	]))
	assert errmsg.contains('NX0104')
}

fn test_parser_supports_typed_variables_parameters_and_else_if() {
	dump_output := dump_ast(helpers.inline_script([
		'$' + 'value i16 = 33',
		'function hello(' + '$' + 'arg run)',
		'dim',
		'    ' + '$' + 'local1 str,',
		'    ' + '$' + 'local2 bool',
		'if typeof(' + '$' + 'arg) is bool',
		'    "bool"',
		'else if typeof(' + '$' + 'arg) is f64',
		'    "float"',
		'endif',
		'endfunction',
		'',
	]))

	assert dump_output.contains('Assign($' + 'value i16 = 33)')
	assert dump_output.contains('Function(hello($' + 'arg run))')
	assert dump_output.contains('Dim($' + 'local1 str, $' + 'local2 bool)')
	assert dump_output.contains('If((typeof($' + 'arg) IS bool))')
	assert dump_output.contains('\n    Else')
}

fn test_parser_supports_decl_initializers() {
	dump_output := dump_ast(helpers.inline_script([
		'dim',
		'    ' + '$' + 'value1 run = 33.4,',
		'    ' + '$' + 'value2 str = "Hello, World!",',
		'    ' + '$' + 'value3 bool,',
		'    ' + '$' + 'value4',
		'',
	]))

	assert dump_output.contains('Dim($' + 'value1 run = 33.4, $' +
		'value2 str = "Hello, World!", $' + 'value3 bool, $' + 'value4)')
}

fn test_parser_helpers_fixture_path_is_available() {
	assert helpers.fixture_script_path('call_main.kix').ends_with('call_main.kix')
}
