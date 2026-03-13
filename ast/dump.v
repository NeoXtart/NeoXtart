module ast

fn indent(level int) string {
	return '  '.repeat(level)
}

pub fn dump_script(script Script) string {
	mut lines := ['Script(${script.path})']
	for stmt in script.statements {
		lines << dump_stmt(stmt, 1)
	}
	return lines.join('\n')
}

pub fn dump_stmt(stmt Stmt, level int) string {
	pad := indent(level)
	return match stmt {
		LabelStmt { '${pad}Label(${stmt.name})' }
		NewlineStmt { '${pad}Newline' }
		DisplayStmt { '${pad}Display(${dump_expr(stmt.expr)})' }
		ExprStmt { '${pad}Expr(${dump_expr(stmt.expr)})' }
		AssignStmt {
			mut left := stmt.target
			if stmt.index !is EmptyExpr {
				left += '[${dump_expr(stmt.index)}]'
			}
			if stmt.type_name.len > 0 {
				left += ' ${stmt.type_name}'
			}
			'${pad}Assign(${left} = ${dump_expr(stmt.value)})'
		}
		DimStmt { '${pad}Dim(${stmt.decls.map(format_decl(it)).join(", ")})' }
		GlobalStmt { '${pad}Global(${stmt.decls.map(format_decl(it)).join(", ")})' }
		BreakStmt { '${pad}Break(${stmt.enabled})' }
		ClsStmt { '${pad}Cls' }
		BigStmt { '${pad}Big' }
		SmallStmt { '${pad}Small' }
		ColorStmt { '${pad}Color(${stmt.raw})' }
		AtStmt { '${pad}At(${dump_expr(stmt.row)}, ${dump_expr(stmt.col)})' }
		BoxStmt {
			'${pad}Box(${dump_expr(stmt.top)}, ${dump_expr(stmt.left)}, ${dump_expr(stmt.bottom)}, ${dump_expr(stmt.right)}, ${dump_expr(stmt.style)})'
		}
		GetStmt { '${pad}${if stmt.line_mode { "Gets" } else { "Get" }}(${stmt.var_name})' }
		IfStmt {
			mut lines := ['${pad}If(${dump_expr(stmt.condition)})']
			for child in stmt.then_body {
				lines << dump_stmt(child, level + 1)
			}
			if stmt.else_body.len > 0 {
				lines << '${pad}Else'
				for child in stmt.else_body {
					lines << dump_stmt(child, level + 1)
				}
			}
			lines.join('\n')
		}
		SelectStmt {
			mut lines := ['${pad}Select']
			for case_clause in stmt.cases {
				lines << '${pad}  Case(${dump_expr(case_clause.condition)})'
				for child in case_clause.body {
					lines << dump_stmt(child, level + 2)
				}
			}
			lines.join('\n')
		}
		WhileStmt {
			mut lines := ['${pad}While(${dump_expr(stmt.condition)})']
			for child in stmt.body {
				lines << dump_stmt(child, level + 1)
			}
			lines.join('\n')
		}
		DoUntilStmt {
			mut lines := ['${pad}Do']
			for child in stmt.body {
				lines << dump_stmt(child, level + 1)
			}
			lines << '${pad}Until(${dump_expr(stmt.condition)})'
			lines.join('\n')
		}
		ForStmt {
			mut header := '${pad}For(${stmt.var_name} = ${dump_expr(stmt.start)} TO ${dump_expr(stmt.finish)}'
			if stmt.step !is EmptyExpr {
				header += ' STEP ${dump_expr(stmt.step)}'
			}
			header += ')'
			mut lines := [header]
			for child in stmt.body {
				lines << dump_stmt(child, level + 1)
			}
			lines.join('\n')
		}
		ForEachStmt {
			mut lines := ['${pad}ForEach(${stmt.var_name} IN ${dump_expr(stmt.iterable)})']
			for child in stmt.body {
				lines << dump_stmt(child, level + 1)
			}
			lines.join('\n')
		}
		GotoStmt { '${pad}Goto(${dump_expr(stmt.label)})' }
		GosubStmt { '${pad}Gosub(${dump_expr(stmt.label)})' }
		CallStmt { '${pad}Call(${dump_expr(stmt.script)})' }
		FunctionDecl {
			mut lines := ['${pad}Function(${stmt.name}(${stmt.params.map(format_param(it)).join(", ")}))']
			for child in stmt.body {
				lines << dump_stmt(child, level + 1)
			}
			lines.join('\n')
		}
		ResultStmt {
			if stmt.value is EmptyExpr {
				'${pad}Result'
			} else {
				'${pad}Result(${dump_expr(stmt.value)})'
			}
		}
		ReturnStmt { '${pad}Return' }
		ExitStmt {
			if stmt.code is EmptyExpr {
				'${pad}Exit'
			} else {
				'${pad}Exit(${dump_expr(stmt.code)})'
			}
		}
		SleepStmt { '${pad}Sleep(${dump_expr(stmt.duration)})' }
		RawCommandStmt { '${pad}RawCommand(${stmt.name}: ${stmt.raw})' }
	}
}

pub fn dump_expr(expr Expr) string {
	return match expr {
		ArrayLiteralExpr { '[' + expr.items.map(dump_expr(it)).join(', ') + ']' }
		BinaryExpr { '(' + dump_expr(expr.left) + ' ' + expr.op + ' ' + dump_expr(expr.right) + ')' }
		CallExpr { dump_expr(expr.callee) + '(' + expr.args.map(dump_expr(it)).join(', ') + ')' }
		EmptyExpr { '<empty>' }
		EnvRefExpr { expr.name }
		IndexExpr { dump_expr(expr.object) + '[' + dump_expr(expr.index) + ']' }
		MacroRefExpr { expr.name }
		MemberExpr { dump_expr(expr.object) + '.' + expr.name }
		NameExpr { expr.name }
		NumberLiteralExpr { expr.raw }
		StringLiteralExpr { '"' + expr.value + '"' }
		UnaryExpr { '(' + expr.op + ' ' + dump_expr(expr.right) + ')' }
		VarRefExpr { expr.name }
	}
}

fn format_decl(decl VarDecl) string {
	mut text := decl.name
	if decl.type_name.len > 0 {
		text += ' ${decl.type_name}'
	}
	if decl.value !is EmptyExpr {
		text += ' = ${dump_expr(decl.value)}'
	}
	return text
}

fn format_param(param Parameter) string {
	if param.type_name.len > 0 {
		return '${param.name} ${param.type_name}'
	}
	return param.name
}
