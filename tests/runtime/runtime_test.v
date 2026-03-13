module runtime_test

import runtime
import tests.helpers

fn test_runtime_handles_scope_recursion_and_for_each() {
	result := helpers.run_inline(helpers.inline_script([
		'$' + 'Global = "g"',
		'$' + 'Items = "a","b","c"',
		'',
		'function Fact(' + '$' + 'n)',
		'if ' + '$' + 'n <= 1',
		'$' + 'Fact = 1',
		'else',
		'$' + 'Fact = ' + '$' + 'n * Fact(' + '$' + 'n - 1)',
		'endif',
		'endfunction',
		'',
		'function Shadow()',
		'dim ' + '$' + 'Global',
		'$' + 'Global = "l"',
		'result ' + '$' + 'Global',
		'endfunction',
		'',
		'Shadow()',
		'Fact(5)',
		'for each ' + '$' + 'Item in ' + '$' + 'Items',
		'$' + 'Item',
		'next',
		'$' + 'Global',
		'',
	])) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == 'l120abcg'
}

fn test_runtime_supports_gosub_return_and_result_keyword() {
	result := helpers.run_inline(helpers.inline_script([
		'gosub "Demo"',
		'function Twice(' + '$' + 'n)',
		'result ' + '$' + 'n * 2',
		'endfunction',
		'Twice(21)',
		'exit 0',
		':Demo',
		'"sub"',
		'return',
		'',
	])) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == 'sub42'
}

fn test_runtime_string_interpolation_and_options() {
	result := helpers.run_inline(helpers.inline_script([
		'$' + 'Name = "NeoXtart"',
		'"Hello ' + '$' + 'Name"',
		'$' + 'Old = SetOption("NoVarsInStrings", "ON")',
		'"Hello ' + '$' + 'Name"',
		'',
	])) or { panic(err.msg()) }

	assert result.output == 'Hello NeoXtartHello ' + '$' + 'Name'
}

fn test_runtime_explicit_rejects_implicit_variable() {
	_ := runtime.run_text(helpers.inline_script([
		'dim ' + '$' + 'Old',
		'$' + 'Old = SetOption("Explicit", "ON")',
		'$' + 'Missing',
		'',
	]), runtime.RunOptions{
		current_dir:  helpers.repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0401')
		return
	}
	assert false
}

fn test_runtime_return_without_gosub_fails() {
	_ := runtime.run_text(helpers.inline_script([
		'return',
		'',
	]), runtime.RunOptions{
		current_dir:  helpers.repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0308')
		return
	}
	assert false
}

fn test_runtime_call_shares_globals() {
	fixtures_dir := helpers.fixture_scripts_dir()
	result := runtime.run_file(helpers.fixture_script_path('call_main.kix'), runtime.RunOptions{
		current_dir:  fixtures_dir
		emit_console: false
	}) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == 'root-child'
}

fn test_runtime_supports_static_types_run_and_typeof() {
	result := helpers.run_inline(helpers.inline_script([
		'$' + 'var_i16 i16 = 33',
		'$' + 'var_f64 f64 = 3.14',
		'$' + 'var_bool bool = 0',
		'$' + 'var_infer = "ola"',
		'$' + 'var_runtime run = "opa"',
		'',
		'function hello(' + '$' + 'value run)',
		'    dim',
		'        ' + '$' + 'value1 run,',
		'        ' + '$' + 'value2 str,',
		'        ' + '$' + 'value3 bool',
		'    if typeof(' + '$' + 'value) is bool',
		'        "Value is boolean ' + '$' + 'value"',
		'    else if typeof(' + '$' + 'value) is f64',
		'        "Value is float64 ' + '$' + 'value"',
		'    endif',
		'endfunction',
		'',
		'hello(' + '$' + 'var_bool)',
		'hello(' + '$' + 'var_f64)',
		'$' + 'var_i16',
		'$' + 'var_infer',
		'$' + 'var_runtime i16 = 7',
		'$' + 'var_runtime',
		'',
	])) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == 'Value is boolean 0Value is float64 3.1433ola7'
}

fn test_runtime_rejects_conflicting_explicit_type_annotation() {
	_ := runtime.run_text(helpers.inline_script([
		'$' + 'value i16 = 1',
		'$' + 'value str = "oops"',
		'',
	]), runtime.RunOptions{
		current_dir:  helpers.repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0502')
		return
	}
	assert false
}

fn test_runtime_dim_initializers_and_defaults() {
	result := helpers.run_inline(helpers.inline_script([
		'function demo()',
		'    dim',
		'        ' + '$' + 'value1 run = 33.4,',
		'        ' + '$' + 'value2 str = "Hello, World!",',
		'        ' + '$' + 'value3 bool,',
		'        ' + '$' + 'value4',
		'    ? "value1 = ' + '$' + 'value1"',
		'    ? "value2 = ' + '$' + 'value2"',
		'    ? "value3 = ' + '$' + 'value3"',
		'    ? "value4 = ' + '$' + 'value4"',
		'endfunction',
		'demo()',
		'',
	])) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == '\nvalue1 = 33.4\nvalue2 = Hello, World!\nvalue3 = 0\nvalue4 = '
}
