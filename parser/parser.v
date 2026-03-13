module parser

import ast
import source
import source.diag
import token

const block_terminators = ['ELSE', 'ENDIF', 'CASE', 'ENDSELECT', 'LOOP', 'UNTIL', 'NEXT',
	'ENDFUNCTION']
const raw_command_names = ['DISPLAY', 'INCLUDE', 'RUN', 'SHELL', 'USE', 'PLAY', 'PASSWORD', 'SET',
	'SETL', 'SETM', 'SETTIME']
const statement_names = ['AT', 'BIG', 'BOX', 'BREAK', 'CALL', 'CLS', 'COLOR', 'DIM', 'DO', 'EXIT',
	'FOR', 'FUNCTION', 'GET', 'GETS', 'GLOBAL', 'GOSUB', 'GOTO', 'IF', 'RESULT', 'RETURN', 'SELECT',
	'SLEEP', 'SMALL', 'WHILE']
const prefix_operators = ['NOT']
const infix_operators = ['AND', 'OR', 'MOD', 'IS']
const type_names = ['BOOL', 'F32', 'F64', 'I8', 'I16', 'I32', 'I64', 'INT', 'RUN', 'STR', 'STRING']

pub struct Parser {
	source source.Source
	tokens []token.Token
mut:
	index int
}

pub fn parse(src source.Source, tokens []token.Token) !ast.Script {
	mut p := Parser{
		source: src
		tokens: tokens
	}
	return p.parse_script()
}

fn (mut p Parser) parse_script() !ast.Script {
	start := p.current().span
	statements := p.parse_statement_list([]string{})!
	end_span := if statements.len > 0 {
		ast.span_of_stmt(statements[statements.len - 1])
	} else {
		start
	}
	return ast.Script{
		path:       p.source.path
		statements: statements
		span:       diag.Span{
			start: start.start
			end:   end_span.end
		}
	}
}

fn (mut p Parser) parse_statement_list(terminators []string) ![]ast.Stmt {
	mut statements := []ast.Stmt{}
	for !p.at_eof() {
		if p.current().kind == .newline {
			p.advance()
			continue
		}
		if p.current().kind == .name && p.current().upper in terminators {
			break
		}
		statements << p.parse_statement()!
	}
	return statements
}

fn (mut p Parser) parse_statement() !ast.Stmt {
	current := p.current()
	match current.kind {
		.label {
			p.advance()
			return ast.LabelStmt{
				name: current.lexeme
				span: current.span
			}
		}
		.question {
			p.advance()
			return ast.NewlineStmt{
				span: current.span
			}
		}
		.var_ref {
			if p.looks_like_assignment() {
				return p.parse_assignment()
			}
			return p.parse_display_stmt()
		}
		.name {
			return p.parse_name_statement()
		}
		.string, .number, .macro_ref, .env_ref, .lpar, .plus, .minus, .tilde {
			return p.parse_display_stmt()
		}
		else {
			return error(p.diag('NX0100', 'unexpected token `${current.lexeme}`', current.span))
		}
	}
}

fn (mut p Parser) parse_name_statement() !ast.Stmt {
	name := p.current().upper
	match name {
		'IF' {
			return p.parse_if_stmt()
		}
		'SELECT' {
			return p.parse_select_stmt()
		}
		'WHILE' {
			return p.parse_while_stmt()
		}
		'DO' {
			return p.parse_do_until_stmt()
		}
		'FOR' {
			return p.parse_for_stmt()
		}
		'FUNCTION' {
			return p.parse_function_decl()
		}
		'DIM' {
			return p.parse_decl_stmt(false)
		}
		'GLOBAL' {
			return p.parse_decl_stmt(true)
		}
		'BREAK' {
			return p.parse_break_stmt()
		}
		'CALL' {
			return p.parse_call_stmt()
		}
		'CLS' {
			return p.parse_unit_stmt(ast.ClsStmt{ span: p.current().span })
		}
		'BIG' {
			return p.parse_unit_stmt(ast.BigStmt{ span: p.current().span })
		}
		'SMALL' {
			return p.parse_unit_stmt(ast.SmallStmt{ span: p.current().span })
		}
		'COLOR' {
			return p.parse_color_stmt()
		}
		'AT' {
			return p.parse_at_stmt()
		}
		'BOX' {
			return p.parse_box_stmt()
		}
		'GET' {
			return p.parse_get_stmt(false)
		}
		'GETS' {
			return p.parse_get_stmt(true)
		}
		'GOTO' {
			return p.parse_jump_stmt(false)
		}
		'GOSUB' {
			return p.parse_jump_stmt(true)
		}
		'RESULT' {
			return p.parse_result_stmt()
		}
		'RETURN' {
			return p.parse_return_stmt()
		}
		'EXIT' {
			return p.parse_exit_stmt()
		}
		'SLEEP' {
			return p.parse_sleep_stmt()
		}
		else {
			if name in raw_command_names {
				return p.parse_raw_command()
			}
			if p.peek().kind == .lpar {
				return p.parse_display_stmt()
			}
			return p.parse_raw_command()
		}
	}
}

fn (mut p Parser) parse_assignment() !ast.Stmt {
	start := p.current().span
	target := p.expect(.var_ref)!.lexeme
	mut index_expr := ast.Expr(ast.NameExpr{
		name: ''
		span: start
	})
	mut has_index := false
	if p.match_kind(.lsbr) {
		has_index = true
		index_expr = p.parse_expression()!
		p.expect(.rsbr)!
	}
	mut type_name := ''
	if p.current().kind == .name && p.is_type_name_token(p.current()) {
		type_name = p.current().lexeme
		p.advance()
	}
	p.expect(.assign)!
	value := p.parse_assignment_value()!
	return ast.AssignStmt{
		target:    target
		type_name: type_name
		index:     if has_index { index_expr } else { ast.EmptyExpr{} }
		value:     value
		span:      diag.Span{
			start: start.start
			end:   ast.span_of_expr(value).end
		}
	}
}

fn (mut p Parser) parse_display_stmt() !ast.Stmt {
	expr := p.parse_expression()!
	return ast.DisplayStmt{
		expr: expr
		span: ast.span_of_expr(expr)
	}
}

fn (mut p Parser) parse_decl_stmt(is_global bool) !ast.Stmt {
	start := p.current().span
	p.advance()
	p.skip_newlines()
	mut decls := []ast.VarDecl{}
	for {
		p.skip_newlines()
		decls << p.parse_var_decl()!
		p.skip_newlines()
		if !p.match_kind(.comma) {
			break
		}
	}
	span := diag.Span{
		start: start.start
		end:   decls[decls.len - 1].span.end
	}
	if is_global {
		return ast.GlobalStmt{
			decls: decls
			span:  span
		}
	}
	return ast.DimStmt{
		decls: decls
		span:  span
	}
}

fn (mut p Parser) parse_var_decl() !ast.VarDecl {
	name_tok := p.expect(.var_ref)!
	mut dimensions := []ast.Expr{}
	if p.match_kind(.lsbr) {
		if !p.match_kind(.rsbr) {
			dimensions << p.parse_expression()!
			for p.match_kind(.comma) {
				dimensions << p.parse_expression()!
			}
			p.expect(.rsbr)!
		}
	}
	mut type_name := ''
	if p.current().kind == .name && p.is_type_name_token(p.current()) {
		type_name = p.current().lexeme
		p.advance()
	}
	mut value := ast.Expr(ast.EmptyExpr{})
	if p.match_kind(.assign) {
		value = p.parse_expression()!
	}
	return ast.VarDecl{
		name:       name_tok.lexeme
		type_name:  type_name
		value:      value
		dimensions: dimensions
		span:       diag.Span{
			start: name_tok.span.start
			end:   if value !is ast.EmptyExpr {
				ast.span_of_expr(value).end
			} else if dimensions.len > 0 {
				ast.span_of_expr(dimensions[dimensions.len - 1]).end
			} else if type_name.len > 0 {
				p.previous().span.end
			} else {
				name_tok.span.end
			}
		}
	}
}

fn (mut p Parser) parse_break_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	mode_tok := p.expect(.name)!
	return ast.BreakStmt{
		enabled: mode_tok.upper == 'ON'
		span:    diag.Span{
			start: start.start
			end:   mode_tok.span.end
		}
	}
}

fn (mut p Parser) parse_call_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	script_expr := p.parse_expression()!
	return ast.CallStmt{
		script: script_expr
		span:   diag.Span{
			start: start.start
			end:   ast.span_of_expr(script_expr).end
		}
	}
}

fn (mut p Parser) parse_unit_stmt(stmt ast.Stmt) !ast.Stmt {
	p.advance()
	return stmt
}

fn (mut p Parser) parse_color_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	mut parts := []string{}
	if p.current().kind in [.name, .var_ref, .string, .macro_ref, .env_ref] {
		parts << p.current().lexeme
		p.advance()
		if p.match_kind(.plus) {
			parts << '+'
		}
		if p.match_kind(.slash) {
			parts << '/'
			if p.current().kind in [.name, .var_ref, .string, .macro_ref, .env_ref] {
				parts << p.current().lexeme
				p.advance()
				if p.match_kind(.plus) {
					parts << '+'
				}
			}
		}
	}
	return ast.ColorStmt{
		raw:  parts.join('')
		span: diag.Span{
			start: start.start
			end:   p.previous().span.end
		}
	}
}

fn (mut p Parser) parse_at_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	p.expect(.lpar)!
	row := p.parse_expression()!
	p.expect(.comma)!
	col := p.parse_expression()!
	p.expect(.rpar)!
	return ast.AtStmt{
		row:  row
		col:  col
		span: diag.Span{
			start: start.start
			end:   p.previous().span.end
		}
	}
}

fn (mut p Parser) parse_box_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	p.expect(.lpar)!
	top := p.parse_expression()!
	p.expect(.comma)!
	left := p.parse_expression()!
	p.expect(.comma)!
	bottom := p.parse_expression()!
	p.expect(.comma)!
	right := p.parse_expression()!
	p.expect(.comma)!
	style := p.parse_expression()!
	p.expect(.rpar)!
	return ast.BoxStmt{
		top:    top
		left:   left
		bottom: bottom
		right:  right
		style:  style
		span:   diag.Span{
			start: start.start
			end:   p.previous().span.end
		}
	}
}

fn (mut p Parser) parse_get_stmt(line_mode bool) !ast.Stmt {
	start := p.current().span
	p.advance()
	name_tok := p.expect(.var_ref)!
	return ast.GetStmt{
		var_name:  name_tok.lexeme
		line_mode: line_mode
		span:      diag.Span{
			start: start.start
			end:   name_tok.span.end
		}
	}
}

fn (mut p Parser) parse_jump_stmt(is_gosub bool) !ast.Stmt {
	start := p.current().span
	p.advance()
	label_expr := p.parse_expression()!
	span := diag.Span{
		start: start.start
		end:   ast.span_of_expr(label_expr).end
	}
	if is_gosub {
		return ast.GosubStmt{
			label: label_expr
			span:  span
		}
	}
	return ast.GotoStmt{
		label: label_expr
		span:  span
	}
}

fn (mut p Parser) parse_return_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	if !p.should_end_statement() {
		return error(p.diag('NX0104', 'RETURN does not accept a value; use RESULT [value] for function returns',
			p.current().span))
	}
	return ast.ReturnStmt{
		span: start
	}
}

fn (mut p Parser) parse_result_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	if p.should_end_statement() {
		return ast.ResultStmt{
			span: start
		}
	}
	value := p.parse_expression()!
	return ast.ResultStmt{
		value: value
		span:  diag.Span{
			start: start.start
			end:   ast.span_of_expr(value).end
		}
	}
}

fn (mut p Parser) parse_exit_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	if p.should_end_statement() {
		return ast.ExitStmt{
			span: start
		}
	}
	code_expr := p.parse_expression()!
	return ast.ExitStmt{
		code: code_expr
		span: diag.Span{
			start: start.start
			end:   ast.span_of_expr(code_expr).end
		}
	}
}

fn (mut p Parser) parse_sleep_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	duration := p.parse_expression()!
	return ast.SleepStmt{
		duration: duration
		span:     diag.Span{
			start: start.start
			end:   ast.span_of_expr(duration).end
		}
	}
}

fn (mut p Parser) parse_if_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	condition := p.parse_expression()!
	then_body := p.parse_statement_list(['ELSE', 'ENDIF'])!
	mut else_body := []ast.Stmt{}
	if p.current().is_name('ELSE') {
		p.advance()
		if p.current().is_name('IF') {
			else_body << p.parse_else_if_stmt()!
		} else {
			else_body = p.parse_statement_list(['ENDIF'])!
		}
	}
	end_tok := p.expect_name('ENDIF')!
	return ast.IfStmt{
		condition: condition
		then_body: then_body
		else_body: else_body
		span:      diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_else_if_stmt() !ast.Stmt {
	start := p.current().span
	p.expect_name('IF')!
	condition := p.parse_expression()!
	then_body := p.parse_statement_list(['ELSE', 'ENDIF'])!
	mut else_body := []ast.Stmt{}
	if p.current().is_name('ELSE') {
		p.advance()
		if p.current().is_name('IF') {
			else_body << p.parse_else_if_stmt()!
		} else {
			else_body = p.parse_statement_list(['ENDIF'])!
		}
	}
	end_pos := if else_body.len > 0 {
		ast.span_of_stmt(else_body[else_body.len - 1]).end
	} else if then_body.len > 0 {
		ast.span_of_stmt(then_body[then_body.len - 1]).end
	} else {
		ast.span_of_expr(condition).end
	}
	return ast.IfStmt{
		condition: condition
		then_body: then_body
		else_body: else_body
		span:      diag.Span{
			start: start.start
			end:   end_pos
		}
	}
}

fn (mut p Parser) parse_select_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	mut cases := []ast.SelectCase{}
	for p.current().is_name('CASE') {
		case_tok := p.current()
		p.advance()
		condition := p.parse_expression()!
		body := p.parse_statement_list(['CASE', 'ENDSELECT'])!
		cases << ast.SelectCase{
			condition: condition
			body:      body
			span:      diag.Span{
				start: case_tok.span.start
				end:   if body.len > 0 {
					ast.span_of_stmt(body[body.len - 1]).end
				} else {
					ast.span_of_expr(condition).end
				}
			}
		}
	}
	end_tok := p.expect_name('ENDSELECT')!
	return ast.SelectStmt{
		cases: cases
		span:  diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_while_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	condition := p.parse_expression()!
	body := p.parse_statement_list(['LOOP'])!
	end_tok := p.expect_name('LOOP')!
	return ast.WhileStmt{
		condition: condition
		body:      body
		span:      diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_do_until_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	body := p.parse_statement_list(['UNTIL'])!
	p.expect_name('UNTIL')!
	condition := p.parse_expression()!
	return ast.DoUntilStmt{
		body:      body
		condition: condition
		span:      diag.Span{
			start: start.start
			end:   ast.span_of_expr(condition).end
		}
	}
}

fn (mut p Parser) parse_for_stmt() !ast.Stmt {
	start := p.current().span
	p.advance()
	if p.current().is_name('EACH') {
		return p.parse_for_each_stmt(start)
	}
	var_tok := p.expect(.var_ref)!
	p.expect(.assign)!
	start_expr := p.parse_expression()!
	p.expect_name('TO')!
	finish_expr := p.parse_expression()!
	mut step_expr := ast.Expr(ast.EmptyExpr{})
	if p.current().is_name('STEP') {
		p.advance()
		step_expr = p.parse_expression()!
	}
	body := p.parse_statement_list(['NEXT'])!
	end_tok := p.expect_name('NEXT')!
	return ast.ForStmt{
		var_name: var_tok.lexeme
		start:    start_expr
		finish:   finish_expr
		step:     step_expr
		body:     body
		span:     diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_for_each_stmt(start diag.Span) !ast.Stmt {
	p.expect_name('EACH')!
	var_tok := p.expect(.var_ref)!
	p.expect_name('IN')!
	iterable := p.parse_expression()!
	body := p.parse_statement_list(['NEXT'])!
	end_tok := p.expect_name('NEXT')!
	return ast.ForEachStmt{
		var_name: var_tok.lexeme
		iterable: iterable
		body:     body
		span:     diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_function_decl() !ast.Stmt {
	start := p.current().span
	p.advance()
	name_tok := p.expect(.name)!
	mut params := []ast.Parameter{}
	if p.match_kind(.lpar) {
		if !p.match_kind(.rpar) {
			for {
				optional := if p.current().is_name('OPTIONAL') {
					p.advance()
					true
				} else {
					false
				}
				param_tok := p.expect(.var_ref)!
				mut type_name := ''
				if p.current().kind == .name && p.is_type_name_token(p.current()) {
					type_name = p.current().lexeme
					p.advance()
				}
				params << ast.Parameter{
					name:      param_tok.lexeme
					type_name: type_name
					optional:  optional
					span:      param_tok.span
				}
				if p.match_kind(.comma) {
					continue
				}
				p.expect(.rpar)!
				break
			}
		}
	}
	body := p.parse_statement_list(['ENDFUNCTION'])!
	end_tok := p.expect_name('ENDFUNCTION')!
	return ast.FunctionDecl{
		name:   name_tok.lexeme
		params: params
		body:   body
		span:   diag.Span{
			start: start.start
			end:   end_tok.span.end
		}
	}
}

fn (mut p Parser) parse_raw_command() !ast.Stmt {
	start_tok := p.current()
	p.advance()
	mut raw_parts := []string{}
	for !p.at_eof() && p.current().kind != .newline {
		if p.current().kind == .name && p.current().upper in block_terminators {
			break
		}
		raw_parts << p.current().lexeme
		p.advance()
	}
	return ast.RawCommandStmt{
		name: start_tok.lexeme
		raw:  raw_parts.join(' ')
		span: diag.Span{
			start: start_tok.span.start
			end:   p.previous().span.end
		}
	}
}

fn (mut p Parser) parse_assignment_value() !ast.Expr {
	first := p.parse_expression()!
	if p.match_kind(.comma) {
		mut items := [first]
		items << p.parse_expression()!
		for p.match_kind(.comma) {
			items << p.parse_expression()!
		}
		return ast.ArrayLiteralExpr{
			items: items
			span:  diag.Span{
				start: ast.span_of_expr(items[0]).start
				end:   ast.span_of_expr(items[items.len - 1]).end
			}
		}
	}
	return first
}

fn (mut p Parser) parse_expression() !ast.Expr {
	return p.parse_precedence(0)
}

fn (mut p Parser) parse_precedence(min_prec int) !ast.Expr {
	p.skip_expression_newlines()
	mut left := p.parse_prefix()!
	for {
		p.skip_expression_newlines()
		if p.at_eof() || p.should_end_expression() {
			break
		}
		prec := p.current_precedence()
		if prec < min_prec {
			break
		}
		left = p.parse_infix(left, prec)!
	}
	return left
}

fn (mut p Parser) parse_prefix() !ast.Expr {
	current := p.current()
	match current.kind {
		.number {
			p.advance()
			return ast.NumberLiteralExpr{
				raw:  current.lexeme
				span: current.span
			}
		}
		.string {
			p.advance()
			return ast.StringLiteralExpr{
				value: current.lexeme
				span:  current.span
			}
		}
		.var_ref {
			p.advance()
			mut expr := ast.Expr(ast.VarRefExpr{
				name: current.lexeme
				span: current.span
			})
			return p.parse_postfix(mut expr)
		}
		.macro_ref {
			p.advance()
			return ast.MacroRefExpr{
				name: current.lexeme
				span: current.span
			}
		}
		.env_ref {
			p.advance()
			return ast.EnvRefExpr{
				name: current.lexeme
				span: current.span
			}
		}
		.name {
			if current.upper in prefix_operators {
				p.advance()
				right := p.parse_precedence(7)!
				return ast.UnaryExpr{
					op:    current.upper
					right: right
					span:  diag.Span{
						start: current.span.start
						end:   ast.span_of_expr(right).end
					}
				}
			}
			p.advance()
			mut expr := ast.Expr(ast.NameExpr{
				name: current.lexeme
				span: current.span
			})
			return p.parse_postfix(mut expr)
		}
		.plus, .minus, .tilde {
			p.advance()
			right := p.parse_precedence(7)!
			return ast.UnaryExpr{
				op:    current.lexeme
				right: right
				span:  diag.Span{
					start: current.span.start
					end:   ast.span_of_expr(right).end
				}
			}
		}
		.lpar {
			p.advance()
			mut expr := p.parse_expression()!
			p.expect(.rpar)!
			return p.parse_postfix(mut expr)
		}
		else {
			return error(p.diag('NX0101', 'expected expression, found `${current.lexeme}`',
				current.span))
		}
	}
}

fn (mut p Parser) parse_postfix(mut expr ast.Expr) !ast.Expr {
	for !p.at_eof() {
		match p.current().kind {
			.lpar {
				p.advance()
				mut args := []ast.Expr{}
				if !p.match_kind(.rpar) {
					for {
						if p.current().kind == .comma {
							args << ast.EmptyExpr{}
						} else {
							args << p.parse_expression()!
						}
						if !p.match_kind(.comma) {
							break
						}
						if p.current().kind == .rpar {
							args << ast.EmptyExpr{}
							break
						}
					}
					p.expect(.rpar)!
				}
				expr = ast.CallExpr{
					callee: expr
					args:   args
					span:   diag.Span{
						start: ast.span_of_expr(expr).start
						end:   p.previous().span.end
					}
				}
				continue
			}
			.dot {
				p.advance()
				name_tok := p.expect(.name)!
				expr = ast.MemberExpr{
					object: expr
					name:   name_tok.lexeme
					span:   diag.Span{
						start: ast.span_of_expr(expr).start
						end:   name_tok.span.end
					}
				}
				continue
			}
			.lsbr {
				p.advance()
				index_expr := p.parse_expression()!
				p.expect(.rsbr)!
				expr = ast.IndexExpr{
					object: expr
					index:  index_expr
					span:   diag.Span{
						start: ast.span_of_expr(expr).start
						end:   p.previous().span.end
					}
				}
				continue
			}
			else {}
		}
		break
	}
	return expr
}

fn (mut p Parser) parse_infix(left ast.Expr, prec int) !ast.Expr {
	op_tok := p.current()
	op := if op_tok.kind == .name { op_tok.upper } else { op_tok.lexeme }
	p.advance()
	right := p.parse_precedence(prec + 1)!
	return ast.BinaryExpr{
		left:  left
		op:    op
		right: right
		span:  diag.Span{
			start: ast.span_of_expr(left).start
			end:   ast.span_of_expr(right).end
		}
	}
}

fn (p Parser) current_precedence() int {
	tok := p.current()
	if tok.kind == .name {
		return match tok.upper {
			'OR' { 1 }
			'AND' { 2 }
			'IS' { 4 }
			'MOD' { 5 }
			else { -1 }
		}
	}
	return match tok.kind {
		.assign, .eq, .ne { 3 }
		.lt, .gt, .le, .ge { 4 }
		.plus, .minus, .caret { 5 }
		.star, .slash, .amp, .pipe { 6 }
		else { -1 }
	}
}

fn (p Parser) should_end_expression() bool {
	current := p.current()
	if current.kind in [.eof, .newline, .comma, .rpar, .rsbr] {
		return true
	}
	if current.kind == .name && current.upper in block_terminators {
		return true
	}
	if current.kind == .name && current.upper in statement_names
		&& !current.upper.starts_with('AND') {
		return true
	}
	return false
}

fn (p Parser) should_end_statement() bool {
	current := p.current()
	if current.kind in [.eof, .newline] {
		return true
	}
	return current.kind == .name && current.upper in block_terminators
}

fn (p Parser) looks_like_assignment() bool {
	next := p.peek()
	if next.kind in [.assign, .lsbr] {
		return true
	}
	return next.kind == .name && p.is_type_name_token(next)
}

fn (mut p Parser) skip_expression_newlines() {
	for p.current().kind == .newline {
		previous := p.previous()
		next := p.peek()
		if p.is_expression_joiner(previous) || p.is_expression_joiner(next) {
			p.advance()
			continue
		}
		break
	}
}

fn (p Parser) is_expression_joiner(tok token.Token) bool {
	if tok.kind in [.plus, .minus, .star, .slash, .assign, .eq, .ne, .lt, .gt, .le, .ge, .amp,
		.pipe, .caret, .comma, .lpar, .lsbr] {
		return true
	}
	if tok.kind == .name && tok.upper in infix_operators {
		return true
	}
	return false
}

fn (mut p Parser) skip_newlines() {
	for p.current().kind == .newline {
		p.advance()
	}
}

fn (p Parser) is_type_name_token(tok token.Token) bool {
	return tok.kind == .name && tok.upper in type_names
}

fn (mut p Parser) expect(kind token.Kind) !token.Token {
	current := p.current()
	if current.kind != kind {
		return error(p.diag('NX0102', 'expected ${kind}, found `${current.lexeme}`', current.span))
	}
	p.advance()
	return current
}

fn (mut p Parser) expect_name(name string) !token.Token {
	current := p.current()
	if !current.is_name(name) {
		return error(p.diag('NX0103', 'expected `${name}`, found `${current.lexeme}`',
			current.span))
	}
	p.advance()
	return current
}

fn (mut p Parser) match_kind(kind token.Kind) bool {
	if p.current().kind == kind {
		p.advance()
		return true
	}
	return false
}

fn (p Parser) current() token.Token {
	if p.index >= p.tokens.len {
		return p.tokens[p.tokens.len - 1]
	}
	return p.tokens[p.index]
}

fn (p Parser) peek() token.Token {
	if p.index + 1 >= p.tokens.len {
		return p.tokens[p.tokens.len - 1]
	}
	return p.tokens[p.index + 1]
}

fn (p Parser) previous() token.Token {
	if p.index == 0 {
		return p.tokens[0]
	}
	return p.tokens[p.index - 1]
}

fn (mut p Parser) advance() {
	if p.index < p.tokens.len {
		p.index++
	}
}

fn (p Parser) at_eof() bool {
	return p.current().kind == .eof
}

fn (p Parser) diag(code string, message string, span diag.Span) string {
	return p.source.diagnostic(code, message, span, []).str()
}
