module runtime

import math
import os
import rand
import strings
import time
import ast
import platform.windows
import source
import source.diag

const month_names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
	'September', 'October', 'November', 'December']

fn (mut e Engine) eval_expr(expr ast.Expr, src source.Source) !Value {
	return match expr {
		ast.EmptyExpr {
			empty_value()
		}
		ast.NumberLiteralExpr {
			e.eval_number_literal(expr)
		}
		ast.StringLiteralExpr {
			string_value(e.resolve_string(expr.value, src)!)
		}
		ast.VarRefExpr {
			e.eval_var(expr, src)
		}
		ast.MacroRefExpr {
			e.eval_macro(expr, src)
		}
		ast.EnvRefExpr {
			string_value(os.getenv(expr.name.trim('%')))
		}
		ast.NameExpr {
			match expr.name.to_upper() {
				'TRUE' { bool_value(true) }
				'FALSE' { bool_value(false) }
				else { string_value(expr.name) }
			}
		}
		ast.UnaryExpr {
			e.eval_unary(expr, src)
		}
		ast.BinaryExpr {
			e.eval_binary(expr, src)
		}
		ast.CallExpr {
			e.eval_call(expr, src)
		}
		ast.MemberExpr {
			e.eval_member(expr, src)
		}
		ast.IndexExpr {
			e.eval_index(expr, src)
		}
		ast.ArrayLiteralExpr {
			mut items := []Value{}
			for item in expr.items {
				items << e.eval_expr(item, src)!
			}
			array_value(items)
		}
	}
}

fn (mut e Engine) eval_number_literal(expr ast.NumberLiteralExpr) Value {
	if expr.raw.starts_with('&') {
		return int_value(i64(expr.raw[1..].int()))
	}
	if expr.raw.contains('.') || expr.raw.contains('E') || expr.raw.contains('e') {
		return double_value(expr.raw.f64())
	}
	return int_value(expr.raw.i64())
}

fn (mut e Engine) eval_var(expr ast.VarRefExpr, src source.Source) !Value {
	if value := e.lookup(expr.name.to_upper()) {
		return value
	}
	if e.options.explicit {
		return error(e.diag(src, expr.span, 'NX0401', 'variable `${expr.name}` is not declared'))
	}
	return empty_value()
}

fn (mut e Engine) eval_macro(expr ast.MacroRefExpr, src source.Source) !Value {
	name := expr.name.to_upper()
	now := time.now()
	mut script_name := ''
	if e.stack.len > 0 {
		script_name = e.stack[e.stack.len - 1]
	}
	match name {
		'@ERROR' { return int_value(e.error_code) }
		'@SERROR' { return string_value(e.error_text) }
		'@RESULT' { return string_value(e.result_text) }
		'@DATE' { return string_value('${now.year:04}/${now.month:02}/${now.day:02}') }
		'@TIME' { return string_value('${now.hour:02}:${now.minute:02}:${now.second:02}') }
		'@MSECS' { return string_value('${now.nanosecond / 1_000_000:03}') }
		'@DAY' { return string_value(now.long_weekday_str()) }
		'@MDAYNO' { return int_value(now.day) }
		'@WDAYNO' { return int_value(now.day_of_week()) }
		'@YDAYNO' { return int_value(now.year_day()) }
		'@MONTH' { return string_value(month_names[now.month - 1]) }
		'@MONTHNO' { return int_value(now.month) }
		'@YEAR' { return int_value(now.year) }
		'@CURDIR' { return string_value(e.current_dir) }
		'@STARTDIR' { return string_value(e.start_dir) }
		'@SCRIPTDIR' { return string_value(e.current_dir) }
		'@SCRIPTNAME' { return string_value(script_name) }
		'@SCRIPTEXE' { return string_value('neoxtart') }
		'@KIX' { return string_value('NeoXtart 0.0.1') }
		'@PID' { return int_value(os.getpid()) }
		'@PRODUCTTYPE' { return string_value(windows.product_type()) }
		'@INWIN' { return int_value(1) }
		else { return error(e.diag(src, expr.span, 'NX1001', 'macro `${expr.name}` is not implemented yet')) }
	}
}

fn (mut e Engine) eval_unary(expr ast.UnaryExpr, src source.Source) !Value {
	right := e.eval_expr(expr.right, src)!
	match expr.op.to_upper() {
		'NOT' {
			return int_value(if right.truthy() { 0 } else { 1 })
		}
		'+' {
			if right.kind == .double {
				return double_value(right.double_value)
			}
			return int_value(right.as_i64()!)
		}
		'-' {
			if right.kind == .double {
				return double_value(-right.double_value)
			}
			return int_value(-right.as_i64()!)
		}
		'~' {
			return int_value(~right.as_i64()!)
		}
		else {
			return error(e.diag(src, expr.span, 'NX0402', 'unsupported unary operator `${expr.op}`'))
		}
	}
}

fn (mut e Engine) eval_binary(expr ast.BinaryExpr, src source.Source) !Value {
	left := e.eval_expr(expr.left, src)!
	right := e.eval_expr(expr.right, src)!
	op := expr.op.to_upper()
	match op {
		'+' {
			return e.binary_plus(left, right)!
		}
		'-', '*' {
			return e.binary_numeric(left, right, op)!
		}
		'/' {
			return int_value(i64(left.as_f64()! / right.as_f64()!))
		}
		'MOD' {
			return int_value(left.as_i64()! % right.as_i64()!)
		}
		'&' {
			return int_value(left.as_i64()! & right.as_i64()!)
		}
		'|' {
			return int_value(left.as_i64()! | right.as_i64()!)
		}
		'^' {
			return int_value(left.as_i64()! ^ right.as_i64()!)
		}
		'<' {
			return int_value(if e.compare(left, right, false) < 0 { 1 } else { 0 })
		}
		'>' {
			return int_value(if e.compare(left, right, false) > 0 { 1 } else { 0 })
		}
		'<=' {
			return int_value(if e.compare(left, right, false) <= 0 { 1 } else { 0 })
		}
		'>=' {
			return int_value(if e.compare(left, right, false) >= 0 { 1 } else { 0 })
		}
		'=' {
			return int_value(if e.equal(left, right, false) { 1 } else { 0 })
		}
		'==' {
			return int_value(if e.equal(left, right, true) { 1 } else { 0 })
		}
		'<>' {
			return int_value(if !e.equal(left, right, false) { 1 } else { 0 })
		}
		'AND' {
			return int_value(if left.truthy() && right.truthy() { 1 } else { 0 })
		}
		'OR' {
			return int_value(if left.truthy() || right.truthy() { 1 } else { 0 })
		}
		'IS' {
			left_type := if left.kind == .string { left.as_string() } else { left.neo_type_name() }
			return int_value(if left_type.to_lower() == right.as_string().to_lower() { 1 } else { 0 })
		}
		else {
			return error(e.diag(src, expr.span, 'NX0404', 'unsupported binary operator `${expr.op}`'))
		}
	}
}

fn (mut e Engine) binary_plus(left Value, right Value) !Value {
	if left.kind == .string {
		return string_value(left.as_string() + right.as_string())
	}
	if left.kind == .double || right.kind == .double {
		return double_value(left.as_f64()! + right.as_f64()!)
	}
	return int_value(left.as_i64()! + right.as_i64()!)
}

fn (mut e Engine) binary_numeric(left Value, right Value, op string) !Value {
	if left.kind == .double || right.kind == .double {
		return match op {
			'-' { double_value(left.as_f64()! - right.as_f64()!) }
			'*' { double_value(left.as_f64()! * right.as_f64()!) }
			else { error('unsupported numeric operator') }
		}
	}
	return match op {
		'-' { int_value(left.as_i64()! - right.as_i64()!) }
		'*' { int_value(left.as_i64()! * right.as_i64()!) }
		else { error('unsupported numeric operator') }
	}
}

fn (e Engine) compare(left Value, right Value, force_case_sensitive bool) int {
	if left.kind == .string || right.kind == .string {
		mut left_text := left.as_string()
		mut right_text := right.as_string()
		if !(force_case_sensitive || e.options.case_sensitivity) {
			left_text = left_text.to_lower()
			right_text = right_text.to_lower()
		}
		if left_text < right_text {
			return -1
		}
		if left_text > right_text {
			return 1
		}
		return 0
	}
	left_number := left.as_f64() or { 0.0 }
	right_number := right.as_f64() or { 0.0 }
	if left_number < right_number {
		return -1
	}
	if left_number > right_number {
		return 1
	}
	return 0
}

fn (e Engine) equal(left Value, right Value, force_case_sensitive bool) bool {
	if left.kind == .string || right.kind == .string {
		mut left_text := left.as_string()
		mut right_text := right.as_string()
		if !(force_case_sensitive || e.options.case_sensitivity) {
			left_text = left_text.to_lower()
			right_text = right_text.to_lower()
		}
		return left_text == right_text
	}
	return math.abs((left.as_f64() or { 0.0 }) - (right.as_f64() or { 0.0 })) < 0.0000001
}

fn (mut e Engine) eval_call(expr ast.CallExpr, src source.Source) !Value {
	match expr.callee {
		ast.NameExpr {
			name := expr.callee.name.to_upper()
			mut args := []Value{}
			for arg in expr.args {
				args << e.eval_expr(arg, src)!
			}
			if name in e.functions {
				return e.call_user_function(name, e.functions[name], args, src, expr.span)
			}
			return e.call_builtin(name, args, src, expr.span)
		}
		ast.MemberExpr {
			return error(e.diag(src, expr.span, 'NX1001', 'object method calls are not implemented yet'))
		}
		else {
			return error(e.diag(src, expr.span, 'NX0405', 'invalid call target'))
		}
	}
}

fn (mut e Engine) eval_member(expr ast.MemberExpr, src source.Source) !Value {
	object := e.eval_expr(expr.object, src)!
	if object.kind == .string {
		return string_value(object.as_string() + '.' + expr.name)
	}
	return error(e.diag(src, expr.span, 'NX1001', 'object member access is not implemented yet'))
}

fn (mut e Engine) eval_index(expr ast.IndexExpr, src source.Source) !Value {
	object := e.eval_expr(expr.object, src)!
	index := int((e.eval_expr(expr.index, src)!).as_i64()!)
	if object.kind != .array {
		return error(e.diag(src, expr.span, 'NX0406', 'indexing requires an array'))
	}
	if index < 0 || index >= object.array_value.len {
		return error(e.diag(src, expr.span, 'NX0407', 'array index out of range'))
	}
	return object.array_value[index]
}

fn (mut e Engine) call_user_function(name string, decl ast.FunctionDecl, args []Value, src source.Source, span diag.Span) !Value {
	e.stack << decl.name
	defer {
		e.stack.delete(e.stack.len - 1)
	}
	e.push_scope()
	defer {
		e.pop_scope()
	}
	return_slot := '$' + name
	e.scope_stack[e.scope_stack.len - 1][return_slot] = Binding{
		value:     empty_value()
		type_name: 'run'
	}
	for index, param in decl.params {
		param_type := normalize_type_name(param.type_name) or { 'run' }
		param_value := if index < args.len { args[index] } else { default_value_for_type(param_type) or {
				empty_value()} }
		e.scope_stack[e.scope_stack.len - 1][param.name.to_upper()] = binding_from_value(param_type,
			param_value) or {
			return error(e.diag(src, span, 'NX0503', 'failed to bind parameter `${param.name}` as `${param_type}`'))
		}
	}
	mut frame := Frame{
		program:     Program{
			source: src
			script: ast.Script{
				path:       src.path
				statements: decl.body
			}
			labels: build_label_index(ast.Script{
				path:       src.path
				statements: decl.body
			})
		}
		kind:        .function
		result_slot: return_slot
	}
	control := e.execute_frame(mut frame)!
	if control.kind == .function_return && !control.value.is_empty() {
		return control.value
	}
	if value := e.lookup(return_slot) {
		return value
	}
	return empty_value()
}

fn (mut e Engine) call_builtin(name string, args []Value, src source.Source, span diag.Span) !Value {
	mut result := empty_value()
	match name {
		'ABS' {
			e.require_arg_count(name, args, 1, src, span)!
			result = if args[0].kind == .double {
				double_value(math.abs(args[0].double_value))
			} else {
				int_value(i64(math.abs(f64(args[0].as_i64()!))))
			}
		}
		'ASC' {
			e.require_arg_count(name, args, 1, src, span)!
			text := args[0].as_string()
			result = int_value(if text.len > 0 { text[0] } else { 0 })
		}
		'CHR' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(rune(args[0].as_i64()!).str())
		}
		'CDBL' {
			e.require_arg_count(name, args, 1, src, span)!
			result = double_value(args[0].as_f64()!)
		}
		'CINT', 'FIX', 'INT' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(args[0].as_i64()!)
		}
		'CSTR' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string())
		}
		'VAL' {
			e.require_arg_count(name, args, 1, src, span)!
			result = double_value(args[0].as_f64()!)
		}
		'LEN' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(args[0].as_string().len)
		}
		'LEFT' {
			e.require_arg_count(name, args, 2, src, span)!
			result = string_value(left(args[0].as_string(), int(args[1].as_i64()!)))
		}
		'RIGHT' {
			e.require_arg_count(name, args, 2, src, span)!
			result = string_value(right(args[0].as_string(), int(args[1].as_i64()!)))
		}
		'SUBSTR' {
			e.require_arg_count(name, args, 3, src, span)!
			result = string_value(substr(args[0].as_string(), int(args[1].as_i64()!),
				int(args[2].as_i64()!)))
		}
		'LTRIM' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string().trim_left(' '))
		}
		'RTRIM' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string().trim_right(' '))
		}
		'TRIM' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string().trim_space())
		}
		'LCASE' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string().to_lower())
		}
		'UCASE' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].as_string().to_upper())
		}
		'INSTR' {
			e.require_arg_count(name, args, 2, src, span)!
			result = int_value(instr(args[0].as_string(), args[1].as_string()))
		}
		'INSTRREV' {
			e.require_arg_count(name, args, 2, src, span)!
			result = int_value(instrrev(args[0].as_string(), args[1].as_string()))
		}
		'REPLACE' {
			e.require_arg_count(name, args, 3, src, span)!
			result = string_value(replace_impl(args))
		}
		'IIF' {
			e.require_arg_count(name, args, 3, src, span)!
			result = if args[0].truthy() { args[1] } else { args[2] }
		}
		'SPLIT' {
			e.require_arg_count(name, args, 1, src, span)!
			result = split_impl(args)
		}
		'JOIN' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(join_impl(args))
		}
		'UBOUND' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(if args[0].kind == .array { args[0].array_value.len - 1 } else { -1 })
		}
		'VARTYPE' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(args[0].vartype())
		}
		'VARTYPENAME' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].vartype_name())
		}
		'RND' {
			result = int_value(rnd_impl(args))
		}
		'SRND' {
			e.require_arg_count(name, args, 1, src, span)!
			rand.seed([u32(args[0].as_i64()! % 1024), 777])
			result = args[0]
		}
		'EXIST' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(if exist_impl(args[0].as_string()) { 1 } else { 0 })
		}
		'DIR' {
			result = e.dir_impl(args)
		}
		'GETCOMMANDLINE' {
			result = get_command_line_impl(e.command_line, args)
		}
		'ISDECLARED' {
			e.require_arg_count(name, args, 1, src, span)!
			result = int_value(if e.is_declared(args[0].as_string().to_upper()) { 1 } else { 0 })
		}
		'SETOPTION' {
			e.require_arg_count(name, args, 2, src, span)!
			result = string_value(e.set_option_impl(args, src, span)!)
		}
		'TYPEOF' {
			e.require_arg_count(name, args, 1, src, span)!
			result = string_value(args[0].neo_type_name())
		}
		else {
			return error(e.diag(src, span, 'NX1001', 'function `${name}` is not implemented yet'))
		}
	}
	e.set_success(result.as_string())
	return result
}

fn (e Engine) require_arg_count(name string, args []Value, count int, src source.Source, span diag.Span) ! {
	if args.len < count {
		return error(e.diag(src, span, 'NX0408', 'function `${name}` expects at least ${count} argument(s)'))
	}
}

fn (mut e Engine) set_option_impl(args []Value, src source.Source, span diag.Span) !string {
	option := args[0].as_string()
	value := args[1].as_string()
	previous := e.options.set_option(option, value) or {
		return error(e.diag(src, span, 'NX1001', 'option `${option}` is not implemented yet'))
	}
	return previous
}

fn (mut e Engine) dir_impl(args []Value) Value {
	path := if args.len > 0 { args[0].as_string() } else { '' }
	index := if args.len > 1 { int(args[1].as_i64() or { 0 }) } else { 0 }
	if path.len > 0 {
		items := os.glob(path) or { []string{} }
		e.dir_handles[index] = DirState{
			items: items.map(os.file_name(it))
		}
	}
	if index !in e.dir_handles {
		return string_value('')
	}
	mut handle := e.dir_handles[index]
	if handle.index >= handle.items.len {
		e.dir_handles[index] = handle
		return string_value('')
	}
	item := handle.items[handle.index]
	handle.index++
	e.dir_handles[index] = handle
	return string_value(item)
}

fn (mut e Engine) resolve_string(value string, src source.Source) !string {
	mut out := strings.new_builder(value.len + 16)
	mut i := 0
	for i < value.len {
		ch := value[i]
		if ch == `$` {
			if i + 1 < value.len && value[i + 1] == `$` {
				out.write_u8(`$`)
				i += 2
				continue
			}
			if !e.options.no_vars_in_strings {
				name, consumed := read_inline_name(value, i + 1)
				if consumed > 0 {
					inline_name := '$' + name
					out.write_string((e.lookup(inline_name.to_upper()) or { empty_value() }).as_string())
					i += consumed + 1
					continue
				}
			}
		}
		if ch == `@` {
			if i + 1 < value.len && value[i + 1] == `@` {
				out.write_u8(`@`)
				i += 2
				continue
			}
			if !e.options.no_macros_in_strings {
				name, consumed := read_inline_name(value, i + 1)
				if consumed > 0 {
					out.write_string((e.eval_macro(ast.MacroRefExpr{
						name: '@' + name
					}, src)!).as_string())
					i += consumed + 1
					continue
				}
			}
		}
		if ch == `%` {
			if i + 1 < value.len && value[i + 1] == `%` {
				out.write_u8(`%`)
				i += 2
				continue
			}
			mut end := i + 1
			for end < value.len && value[end] != `%` {
				end++
			}
			if end < value.len && end > i + 1 {
				out.write_string(os.getenv(value[i + 1..end]))
				i = end + 1
				continue
			}
		}
		out.write_u8(ch)
		i++
	}
	return out.str()
}

fn read_inline_name(text string, start int) (string, int) {
	mut end := start
	for end < text.len && ((text[end] >= `A` && text[end] <= `Z`)
		|| (text[end] >= `a` && text[end] <= `z`)
		|| (text[end] >= `0` && text[end] <= `9`) || text[end] == `_`) {
		end++
	}
	if end == start {
		return '', 0
	}
	return text[start..end], end - start
}

fn left(text string, length int) string {
	if length == 0 {
		return ''
	}
	if length < 0 {
		end := text.len + length
		if end <= 0 {
			return ''
		}
		return text[..end]
	}
	if length >= text.len {
		return text
	}
	return text[..length]
}

fn right(text string, length int) string {
	if length == 0 {
		return ''
	}
	if length < 0 {
		start := -length
		if start >= text.len {
			return ''
		}
		return text[start..]
	}
	if length >= text.len {
		return text
	}
	return text[text.len - length..]
}

fn substr(text string, offset int, length int) string {
	mut start := offset - 1
	if start < 0 {
		start = 0
	}
	if start >= text.len {
		return ''
	}
	mut end := text.len
	if length > 0 && start + length < end {
		end = start + length
	}
	return text[start..end]
}

fn instr(source_text string, needle string) i64 {
	index := source_text.to_lower().index(needle.to_lower()) or { return 0 }
	return index + 1
}

fn instrrev(source_text string, needle string) i64 {
	index := source_text.to_lower().last_index(needle.to_lower()) or { return 0 }
	return index + 1
}

fn replace_impl(args []Value) string {
	source_text := args[0].as_string()
	old := args[1].as_string()
	new := args[2].as_string()
	return source_text.replace(old, new)
}

fn split_impl(args []Value) Value {
	delimiter := if args.len > 1 { args[1].as_string() } else { ' ' }
	parts := args[0].as_string().split(delimiter)
	mut items := []Value{}
	for part in parts {
		items << string_value(part)
	}
	return array_value(items)
}

fn join_impl(args []Value) string {
	if args[0].kind != .array {
		return ''
	}
	delimiter := if args.len > 1 { args[1].as_string() } else { ' ' }
	mut count := args[0].array_value.len
	if args.len > 2 {
		requested := int(args[2].as_i64() or { i64(args[0].array_value.len) })
		if requested < count {
			count = requested
		}
	}
	if count < 0 {
		count = 0
	}
	mut pieces := []string{}
	for item in args[0].array_value[..count] {
		pieces << item.as_string()
	}
	return pieces.join(delimiter)
}

fn rnd_impl(args []Value) i64 {
	maximum := if args.len > 0 { int(args[0].as_i64() or { 32767 }) } else { 32767 }
	return rand.intn(maximum + 1) or { 0 }
}

fn exist_impl(path string) bool {
	if path.contains('*') || path.contains('?') {
		return (os.glob(path) or { []string{} }).len > 0
	}
	return os.exists(path)
}

fn get_command_line_impl(argv []string, args []Value) Value {
	mode := if args.len > 0 { args[0].as_i64() or { 0 } } else { 0 }
	if mode == 1 {
		mut items := []Value{}
		for arg in argv {
			items << string_value(arg)
		}
		return array_value(items)
	}
	return string_value(argv.join(' '))
}
