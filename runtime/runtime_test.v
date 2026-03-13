module runtime

import os

fn repo_root() string {
	return os.dir(os.dir(@FILE))
}

fn run_inline(text string) RunResult {
	return run_text(text, RunOptions{
		current_dir: repo_root()
		emit_console: false
	}) or { panic(err.msg()) }
}

fn test_runtime_handles_scope_recursion_and_for_each() {
	result := run_inline([
		'$' + 'Global = "g"'
		'$' + 'Items = "a","b","c"'
		''
		'function Fact(' + '$' + 'n)'
		'if ' + '$' + 'n <= 1'
		'$' + 'Fact = 1'
		'else'
		'$' + 'Fact = ' + '$' + 'n * Fact(' + '$' + 'n - 1)'
		'endif'
		'endfunction'
		''
		'function Shadow()'
		'dim ' + '$' + 'Global'
		'$' + 'Global = "l"'
		'result ' + '$' + 'Global'
		'endfunction'
		''
		'Shadow()'
		'Fact(5)'
		'for each ' + '$' + 'Item in ' + '$' + 'Items'
		'$' + 'Item'
		'next'
		'$' + 'Global'
		''
	].join('\n'))

	assert result.exit_code == 0
	assert result.output == 'l120abcg'
}

fn test_runtime_supports_gosub_return_and_result_keyword() {
	result := run_inline([
		'gosub "Demo"'
		'function Twice(' + '$' + 'n)'
		'result ' + '$' + 'n * 2'
		'endfunction'
		'Twice(21)'
		'exit 0'
		':Demo'
		'"sub"'
		'return'
		''
	].join('\n'))

	assert result.exit_code == 0
	assert result.output == 'sub42'
}

fn test_runtime_string_interpolation_and_options() {
	result := run_inline([
		'$' + 'Name = "NeoXtart"'
		'"Hello ' + '$' + 'Name"'
		'$' + 'Old = SetOption("NoVarsInStrings", "ON")'
		'"Hello ' + '$' + 'Name"'
		''
	].join('\n'))

	assert result.output == 'Hello NeoXtartHello ' + '$' + 'Name'
}

fn test_runtime_explicit_rejects_implicit_variable() {
	_ := run_text([
		'dim ' + '$' + 'Old'
		'$' + 'Old = SetOption("Explicit", "ON")'
		'$' + 'Missing'
		''
	].join('\n'), RunOptions{
		current_dir: repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0401')
		return
	}
	assert false
}

fn test_runtime_return_without_gosub_fails() {
	_ := run_text([
		'return'
		''
	].join('\n'), RunOptions{
		current_dir: repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0308')
		return
	}
	assert false
}

fn test_runtime_call_shares_globals() {
	examples_dir := os.join_path(repo_root(), 'examples', 'v1')
	result := run_file(os.join_path(examples_dir, 'call_main.kix'), RunOptions{
		current_dir: examples_dir
		emit_console: false
	}) or { panic(err.msg()) }

	assert result.exit_code == 0
	assert result.output == 'root-child'
}

fn test_runtime_supports_static_types_run_and_typeof() {
	result := run_inline([
		'$' + 'var_i16 i16 = 33'
		'$' + 'var_f64 f64 = 3.14'
		'$' + 'var_bool bool = 0'
		'$' + 'var_infer = "ola"'
		'$' + 'var_runtime run = "opa"'
		''
		'function hello(' + '$' + 'value run)'
		'    dim'
		'        ' + '$' + 'value1 run,'
		'        ' + '$' + 'value2 str,'
		'        ' + '$' + 'value3 bool'
		'    if typeof(' + '$' + 'value) is bool'
		'        "Value is boolean ' + '$' + 'value"'
		'    else if typeof(' + '$' + 'value) is f64'
		'        "Value is float64 ' + '$' + 'value"'
		'    endif'
		'endfunction'
		''
		'hello(' + '$' + 'var_bool)'
		'hello(' + '$' + 'var_f64)'
		'$' + 'var_i16'
		'$' + 'var_infer'
		'$' + 'var_runtime i16 = 7'
		'$' + 'var_runtime'
		''
	].join('\n'))

	assert result.exit_code == 0
	assert result.output == 'Value is boolean 0Value is float64 3.1433ola7'
}

fn test_runtime_rejects_conflicting_explicit_type_annotation() {
	_ := run_text([
		'$' + 'value i16 = 1'
		'$' + 'value str = "oops"'
		''
	].join('\n'), RunOptions{
		current_dir: repo_root()
		emit_console: false
	}) or {
		assert err.msg().contains('NX0502')
		return
	}
	assert false
}

fn test_runtime_dim_initializers_and_defaults() {
	result := run_inline([
		'function demo()'
		'    dim'
		'        ' + '$' + 'value1 run = 33.4,'
		'        ' + '$' + 'value2 str = "Hello, World!",'
		'        ' + '$' + 'value3 bool,'
		'        ' + '$' + 'value4'
		'    ? "value1 = ' + '$' + 'value1"'
		'    ? "value2 = ' + '$' + 'value2"'
		'    ? "value3 = ' + '$' + 'value3"'
		'    ? "value4 = ' + '$' + 'value4"'
		'endfunction'
		'demo()'
		''
	].join('\n'))

	assert result.exit_code == 0
	assert result.output == '\nvalue1 = 33.4\nvalue2 = Hello, World!\nvalue3 = 0\nvalue4 = '
}

fn test_samples_from_plan_parse_and_fail_as_expected() {
	root := repo_root()
	samples := [
		os.join_path(root, 'KiX4.70', 'Samples', 'recur.kix'),
		os.join_path(root, 'KiX4.70', 'Samples', 'adsi01.kix'),
		os.join_path(root, 'KiX4.70', 'Samples', 'getip.kix'),
		os.join_path(root, 'KiX4.70', 'Samples', 'demo.kix'),
		os.join_path(root, 'KiX4.70', 'Samples', 'plt.kix'),
	]
	for sample in samples {
		check_file(sample) or { panic(err.msg()) }
	}

	fly := run_file(os.join_path(root, 'KiX4.70', 'Samples', 'fly.kix'), RunOptions{
		current_dir: root
		emit_console: false
	}) or { panic(err.msg()) }
	assert fly.exit_code == 0
	assert fly.output.count('KIXTART') == 10

	failing := {
		'KiX4.70\\Samples\\adsi01.kix': 'NX1001'
		'KiX4.70\\Samples\\getip.kix': 'NX1001'
		'KiX4.70\\Samples\\demo.kix': 'NX1001'
		'KiX4.70\\Samples\\plt.kix': 'NX1001'
	}
	for relative, expected in failing {
		_ := run_file(os.join_path(root, relative), RunOptions{
			current_dir: root
			emit_console: false
		}) or {
			assert err.msg().contains(expected)
			continue
		}
		assert false
	}
}
