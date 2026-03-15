module runtime

import os
import strings
import term
import time
import ast
import parser
import source
import source.diag
import token.lexer
import platform.windows
import platform.linux

pub struct RunOptions {
pub:
	current_dir  string
	emit_console bool
	stdin_lines  []string
	command_line []string
	vars         map[string]string
}

pub struct RunResult {
pub:
	output    string
	exit_code int
}

enum ControlKind {
	none
	script_return
	function_return
	goto_label
	gosub_label
	exit
}

struct Control {
	kind      ControlKind
	label     string
	value     Value
	exit_code int
}

enum FrameKind {
	script
	function
}

struct Frame {
	program Program
	kind    FrameKind
mut:
	result_slot  string
	return_addrs []int
}

struct DirState {
	items []string
mut:
	index int
}

struct Engine {
	start_dir    string
	command_line []string
	emit_console bool
mut:
	current_dir string
	options     EngineOptions
	globals     map[string]Binding
	scope_stack []map[string]Binding
	functions   map[string]ast.FunctionDecl
	scripts     map[string]Program
	stack       []string
	output      strings.Builder
	error_code  int
	error_text  string
	result_text string
	exit_code   int
	stdin_lines []string
	stdin_index int
	dir_handles map[int]DirState
	window_lib  windows.WindowsLib
	linux_lib   linux.LinuxLib
}

pub fn run_file(path string, options RunOptions) !RunResult {
	base_dir := if options.current_dir.len > 0 { options.current_dir } else { os.getwd() }
	resolved := source.resolve_script(path, base_dir)!
	if resolved.kind == .kx {
		return error('NX1001: tokenized .kx scripts are not supported yet')
	}
	mut engine := new_engine(base_dir, options)
	for key, value in options.vars {
		engine.globals[key.to_upper()] = Binding{
			value:     string_value(value)
			type_name: 'run'
		}
	}
	program := engine.load_cached_program(resolved.path)!
	engine.execute_program(program)!
	return RunResult{
		output:    engine.output.str()
		exit_code: engine.exit_code
	}
}

pub fn run_text(text string, options RunOptions) !RunResult {
	base_dir := if options.current_dir.len > 0 { options.current_dir } else { os.getwd() }
	mut engine := new_engine(base_dir, options)
	src := source.new('inline.kix', text)
	tokens := lexer.tokenize(src)!
	script := parser.parse(src, tokens)!
	program := Program{
		source: src
		script: script
		labels: build_label_index(script)
	}
	engine.register_functions(program)
	engine.execute_program(program)!
	return RunResult{
		output:    engine.output.str()
		exit_code: engine.exit_code
	}
}

fn new_engine(base_dir string, options RunOptions) Engine {
	return Engine{
		current_dir:  base_dir
		start_dir:    base_dir
		command_line: options.command_line.clone()
		emit_console: options.emit_console
		stdin_lines:  options.stdin_lines.clone()
		options:      EngineOptions{}
		globals:      map[string]Binding{}
		scope_stack:  []map[string]Binding{}
		functions:    map[string]ast.FunctionDecl{}
		scripts:      map[string]Program{}
		dir_handles:  map[int]DirState{}
		output:       strings.new_builder(1024)
	}
}

fn (mut e Engine) load_cached_program(path string) !Program {
	if existing := e.scripts[path] {
		return existing
	}
	program := load_program(path)!
	e.register_functions(program)
	e.scripts[path] = program
	return program
}

fn (mut e Engine) register_functions(program Program) {
	for stmt in program.script.statements {
		if stmt is ast.FunctionDecl {
			e.functions[stmt.name.to_upper()] = stmt
		}
	}
}

fn (mut e Engine) execute_program(program Program) ! {
	previous_dir := e.current_dir
	e.current_dir = os.dir(program.source.path)
	defer {
		e.current_dir = previous_dir
	}
	e.stack << os.base(program.source.path)
	defer {
		e.stack.delete(e.stack.len - 1)
	}
	e.push_scope()
	defer {
		e.pop_scope()
	}
	mut frame := Frame{
		program: program
		kind:    .script
	}
	control := e.execute_frame(mut frame)!
	if control.kind == .exit {
		e.exit_code = control.exit_code
	}
}

fn (mut e Engine) resolve_label(mut frame Frame, label string, span diag.Span) !int {
	normalized := label.to_upper()
	if normalized in frame.program.labels {
		return frame.program.labels[normalized]
	}
	return error(e.diag(frame.program.source, span, 'NX0301', 'label not found: ${label}'))
}

fn (mut e Engine) execute_block(stmts []ast.Stmt, mut frame Frame) !Control {
	e.push_scope()
	defer {
		e.pop_scope()
	}
	for stmt in stmts {
		control := e.execute_stmt(stmt, mut frame)!
		if control.kind != .none {
			return control
		}
	}
	return Control{}
}

fn (mut e Engine) execute_frame(mut frame Frame) !Control {
	mut index := 0
	for index < frame.program.script.statements.len {
		stmt := frame.program.script.statements[index]
		control := e.execute_stmt(stmt, mut frame)!
		match control.kind {
			.none {
				index++
			}
			.goto_label {
				index = e.resolve_label(mut frame, control.label, ast.span_of_stmt(stmt))!
			}
			.gosub_label {
				frame.return_addrs << index + 1
				index = e.resolve_label(mut frame, control.label, ast.span_of_stmt(stmt))!
			}
			.script_return {
				if frame.return_addrs.len == 0 {
					return control
				}
				index = frame.return_addrs.pop()
			}
			.function_return, .exit {
				return control
			}
		}
	}
	return Control{}
}

fn (mut e Engine) execute_stmt(stmt ast.Stmt, mut frame Frame) !Control {
	match stmt {
		ast.LabelStmt, ast.FunctionDecl {
			return Control{}
		}
		ast.NewlineStmt {
			e.write_output('\n')
			e.set_success('')
		}
		ast.DisplayStmt {
			value := e.eval_expr(stmt.expr, frame.program.source)!
			e.write_output(value.as_string())
			e.set_success('')
		}
		ast.ExprStmt {
			_ := e.eval_expr(stmt.expr, frame.program.source)!
			e.set_success('')
		}
		ast.AssignStmt {
			value := e.eval_expr(stmt.value, frame.program.source)!
			e.assign(stmt.target, stmt.type_name, stmt.index, value, frame.program.source,
				stmt.span)!
			e.set_success('')
		}
		ast.DimStmt {
			for decl in stmt.decls {
				e.declare_local(decl, frame.program.source)!
			}
			e.set_success('')
		}
		ast.GlobalStmt {
			for decl in stmt.decls {
				e.declare_global(decl, frame.program.source)!
			}
			e.set_success('')
		}
		ast.BreakStmt {
			e.set_success('')
		}
		ast.ClsStmt {
			if e.emit_console {
				term.erase_display('2')
				term.set_cursor_position(term.Coord{
					x: 1
					y: 1
				})
			}
			e.set_success('')
		}
		ast.BigStmt, ast.SmallStmt, ast.ColorStmt, ast.BoxStmt {
			e.set_success('')
		}
		ast.AtStmt {
			if e.emit_console {
				row_value := e.eval_expr(stmt.row, frame.program.source)!
				col_value := e.eval_expr(stmt.col, frame.program.source)!
				term.set_cursor_position(term.Coord{
					x: int(col_value.as_i64()!) + 1
					y: int(row_value.as_i64()!) + 1
				})
			}
			e.set_success('')
		}
		ast.GetStmt {
			input := e.read_input(stmt.line_mode)
			e.assign(stmt.var_name, '', ast.EmptyExpr{}, string_value(input), frame.program.source,
				stmt.span)!
			e.set_success('')
		}
		ast.IfStmt {
			condition := e.eval_expr(stmt.condition, frame.program.source)!
			if condition.truthy() {
				return e.execute_block(stmt.then_body, mut frame)
			}
			return e.execute_block(stmt.else_body, mut frame)
		}
		ast.SelectStmt {
			for case_clause in stmt.cases {
				if (e.eval_expr(case_clause.condition, frame.program.source)!).truthy() {
					return e.execute_block(case_clause.body, mut frame)
				}
			}
			e.set_success('')
		}
		ast.WhileStmt {
			for {
				if !(e.eval_expr(stmt.condition, frame.program.source)!).truthy() {
					break
				}
				control := e.execute_block(stmt.body, mut frame)!
				if control.kind != .none {
					return control
				}
			}
			e.set_success('')
		}
		ast.DoUntilStmt {
			for {
				control := e.execute_block(stmt.body, mut frame)!
				if control.kind != .none {
					return control
				}
				if (e.eval_expr(stmt.condition, frame.program.source)!).truthy() {
					break
				}
			}
			e.set_success('')
		}
		ast.ForStmt {
			start := (e.eval_expr(stmt.start, frame.program.source)!).as_i64()!
			finish := (e.eval_expr(stmt.finish, frame.program.source)!).as_i64()!
			step := if stmt.step is ast.EmptyExpr {
				i64(1)
			} else {
				(e.eval_expr(stmt.step, frame.program.source)!).as_i64()!
			}
			mut current := start
			for (step >= 0 && current <= finish) || (step < 0 && current >= finish) {
				e.assign(stmt.var_name, '', ast.EmptyExpr{}, int_value(current), frame.program.source,
					stmt.span)!
				control := e.execute_block(stmt.body, mut frame)!
				if control.kind != .none {
					return control
				}
				current += step
			}
			e.set_success('')
		}
		ast.ForEachStmt {
			iterable := e.eval_expr(stmt.iterable, frame.program.source)!
			if iterable.kind != .array {
				return error(e.diag(frame.program.source, stmt.span, 'NX0302', 'FOR EACH expects an array'))
			}
			for item in iterable.array_value {
				e.assign(stmt.var_name, '', ast.EmptyExpr{}, item, frame.program.source,
					stmt.span)!
				control := e.execute_block(stmt.body, mut frame)!
				if control.kind != .none {
					return control
				}
			}
			e.set_success('')
		}
		ast.GotoStmt {
			label := (e.eval_expr(stmt.label, frame.program.source)!).as_string()
			return Control{
				kind:  .goto_label
				label: label
			}
		}
		ast.GosubStmt {
			label := (e.eval_expr(stmt.label, frame.program.source)!).as_string()
			return Control{
				kind:  .gosub_label
				label: label
			}
		}
		ast.CallStmt {
			path_value := e.eval_expr(stmt.script, frame.program.source)!
			e.execute_call(path_value.as_string(), frame.program.source, stmt.span)!
		}
		ast.ResultStmt {
			mut value := empty_value()
			if stmt.value !is ast.EmptyExpr {
				value = e.eval_expr(stmt.value, frame.program.source)!
			} else if frame.result_slot.len > 0 {
				value = e.lookup(frame.result_slot) or { empty_value() }
			}
			if frame.kind != .function {
				return error(e.diag(frame.program.source, stmt.span, 'NX0307', 'RESULT can only be used inside FUNCTION'))
			}
			return Control{
				kind:  .function_return
				value: value
			}
		}
		ast.ReturnStmt {
			if frame.return_addrs.len == 0 {
				return error(e.diag(frame.program.source, stmt.span, 'NX0308', 'RETURN requires an active GOSUB'))
			}
			return Control{
				kind: .script_return
			}
		}
		ast.ExitStmt {
			code := if stmt.code is ast.EmptyExpr {
				0
			} else {
				int((e.eval_expr(stmt.code, frame.program.source)!).as_i64()!)
			}
			return Control{
				kind:      .exit
				exit_code: code
			}
		}
		ast.SleepStmt {
			duration := (e.eval_expr(stmt.duration, frame.program.source)!).as_f64()!
			time.sleep(time.Duration(i64(duration * f64(time.second))))
			e.set_success('')
		}
		ast.BeepStmt {
			println('emit_console=${e.emit_console}')
			$if windows {
				e.window_lib.beep(1000, 500)
			} $else {
				print('\a')
			}
			e.set_success('ok')
		}
		ast.RawCommandStmt {
			return error(e.diag(frame.program.source, stmt.span, 'NX1001', 'command `${stmt.name}` is not implemented yet'))
		}
	}
	return Control{}
}

fn (mut e Engine) execute_call(script_name string, caller source.Source, span diag.Span) ! {
	resolved := source.resolve_script(script_name, os.dir(caller.path))!
	if resolved.kind == .kx {
		return error(e.diag(caller, span, 'NX1001', 'tokenized .kx scripts are not supported yet'))
	}
	program := e.load_cached_program(resolved.path)!
	e.execute_program(program)!
}

fn (mut e Engine) declare_local(decl ast.VarDecl, src source.Source) ! {
	e.scope_stack[e.scope_stack.len - 1][decl.name.to_upper()] = e.build_decl_binding(decl,
		src)!
}

fn (mut e Engine) declare_global(decl ast.VarDecl, src source.Source) ! {
	e.globals[decl.name.to_upper()] = e.build_decl_binding(decl, src)!
}

fn (mut e Engine) build_decl_binding(decl ast.VarDecl, src source.Source) !Binding {
	if decl.dimensions.len > 0 && decl.value !is ast.EmptyExpr {
		return error(e.diag(src, decl.span, 'NX0504', 'array declarations do not support inline initializers yet'))
	}

	mut explicit_type := 'run'
	if decl.type_name.len > 0 {
		explicit_type = normalize_type_name(decl.type_name) or {
			return error(e.diag(src, decl.span, 'NX0501', err.msg()))
		}
	}

	if decl.dimensions.len > 0 {
		value := e.allocate_array(decl.dimensions, src)!
		return Binding{
			value:     value
			type_name: explicit_type
		}
	}

	if decl.value !is ast.EmptyExpr {
		initial := e.eval_expr(decl.value, src)!
		target_type := if explicit_type != 'run' { explicit_type } else { infer_type_name(initial) }
		coerced := if target_type == 'run' {
			initial
		} else {
			coerce_value_to_type(initial, target_type)!
		}
		return Binding{
			value:     coerced
			type_name: target_type
		}
	}

	if explicit_type == 'run' {
		return Binding{
			value:     empty_value()
			type_name: 'run'
		}
	}

	return Binding{
		value:     default_value_for_type(explicit_type)!
		type_name: explicit_type
	}
}

fn (mut e Engine) allocate_array(dimensions []ast.Expr, src source.Source) !Value {
	if dimensions.len == 0 {
		return array_value([]Value{})
	}
	size := int((e.eval_expr(dimensions[0], src)!).as_i64()!) + 1
	mut items := []Value{len: size}
	if dimensions.len > 1 {
		for index in 0 .. size {
			items[index] = e.allocate_array(dimensions[1..], src)!
		}
	}
	return array_value(items)
}

fn (mut e Engine) assign(name string, type_name string, index_expr ast.Expr, value Value, src source.Source, span diag.Span) ! {
	normalized := name.to_upper()
	if index_expr !is ast.EmptyExpr {
		existing := e.lookup_binding(normalized) or {
			return error(e.diag(src, ast.span_of_expr(index_expr), 'NX0303', 'array `${name}` is not declared'))
		}
		if existing.value.kind != .array {
			return error(e.diag(src, ast.span_of_expr(index_expr), 'NX0304', '`${name}` is not an array'))
		}
		index := int((e.eval_expr(index_expr, src)!).as_i64()!)
		mut updated := existing.value.array_value.clone()
		if index < 0 || index >= updated.len {
			return error(e.diag(src, ast.span_of_expr(index_expr), 'NX0305', 'array index out of range'))
		}
		updated[index] = value
		e.store_binding(normalized, Binding{
			value:     array_value(updated)
			type_name: existing.type_name
		})
		return
	}
	if e.options.explicit && !e.is_declared(normalized) {
		return error(e.diag(src, diag.Span{}, 'NX0306', 'variable `${name}` must be declared'))
	}
	if existing := e.lookup_binding(normalized) {
		if type_name.len > 0 {
			normalized_type := normalize_type_name(type_name) or {
				return error(e.diag(src, span, 'NX0501', err.msg()))
			}
			if existing.type_name != 'run' && existing.type_name != normalized_type {
				return error(e.diag(src, span, 'NX0502', 'variable `${name}` is already typed as `${existing.type_name}`'))
			}
			coerced := if normalized_type == 'run' {
				value
			} else {
				coerce_value_to_type(value, normalized_type)!
			}
			e.store_binding(normalized, Binding{
				value:     coerced
				type_name: normalized_type
			})
			return
		}
		target_type := if existing.type_name == 'run' && existing.value.is_empty() {
			infer_type_name(value)
		} else {
			existing.type_name
		}
		coerced := if target_type == 'run' {
			value
		} else {
			coerce_value_to_type(value, target_type)!
		}
		e.store_binding(normalized, Binding{
			value:     coerced
			type_name: target_type
		})
		return
	}
	target_type := if type_name.len > 0 {
		normalize_type_name(type_name) or { return error(e.diag(src, span, 'NX0501', err.msg())) }
	} else {
		infer_type_name(value)
	}
	coerced := if target_type == 'run' { value } else { coerce_value_to_type(value, target_type)! }
	e.store_binding(normalized, Binding{
		value:     coerced
		type_name: target_type
	})
}

fn (mut e Engine) store_binding(name string, binding Binding) {
	for index := e.scope_stack.len - 1; index >= 0; index-- {
		if name in e.scope_stack[index] {
			e.scope_stack[index][name] = binding
			return
		}
	}
	e.globals[name] = binding
}

fn (e Engine) lookup(name string) ?Value {
	if binding := e.lookup_binding(name) {
		return binding.value
	}
	return none
}

fn (e Engine) lookup_binding(name string) ?Binding {
	for index := e.scope_stack.len - 1; index >= 0; index-- {
		if name in e.scope_stack[index] {
			return e.scope_stack[index][name]
		}
	}
	if name in e.globals {
		return e.globals[name]
	}
	return none
}

fn (e Engine) is_declared(name string) bool {
	if name in e.globals {
		return true
	}
	for index := e.scope_stack.len - 1; index >= 0; index-- {
		if name in e.scope_stack[index] {
			return true
		}
	}
	return false
}

fn (mut e Engine) push_scope() {
	e.scope_stack << map[string]Binding{}
}

fn (mut e Engine) pop_scope() {
	if e.scope_stack.len > 0 {
		e.scope_stack.delete(e.scope_stack.len - 1)
	}
}

fn (mut e Engine) write_output(text string) {
	e.output.write_string(text)
	if e.emit_console {
		print(text)
	}
}

fn (mut e Engine) read_input(line_mode bool) string {
	if e.stdin_index < e.stdin_lines.len {
		line := e.stdin_lines[e.stdin_index]
		e.stdin_index++
		return if line_mode {
			line
		} else {
			if line.len > 0 {
				line[..1]
			} else {
				''
			}
		}
	}
	line := os.get_line()
	return if line_mode {
		line
	} else {
		if line.len > 0 {
			line[..1]
		} else {
			''
		}
	}
}

fn (mut e Engine) set_success(result string) {
	e.error_code = 0
	e.error_text = ''
	e.result_text = result
}

fn (e Engine) diag(src source.Source, span diag.Span, code string, message string) string {
	return src.diagnostic(code, message, span, e.stack).str()
}
