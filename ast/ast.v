module ast

import source.diag

pub type Stmt = AssignStmt
	| AtStmt
	| BigStmt
	| BoxStmt
	| BreakStmt
	| CallStmt
	| ClsStmt
	| ColorStmt
	| DimStmt
	| DisplayStmt
	| DoUntilStmt
	| ExitStmt
	| ExprStmt
	| ForEachStmt
	| ForStmt
	| FunctionDecl
	| GetStmt
	| GlobalStmt
	| GosubStmt
	| GotoStmt
	| IfStmt
	| LabelStmt
	| NewlineStmt
	| RawCommandStmt
	| ResultStmt
	| ReturnStmt
	| SelectStmt
	| SleepStmt
	| SmallStmt
	| WhileStmt

pub type Expr = ArrayLiteralExpr
	| BinaryExpr
	| CallExpr
	| EmptyExpr
	| EnvRefExpr
	| IndexExpr
	| MacroRefExpr
	| MemberExpr
	| NameExpr
	| NumberLiteralExpr
	| StringLiteralExpr
	| UnaryExpr
	| VarRefExpr

pub struct Script {
pub:
	path       string
	statements []Stmt
	span       diag.Span
}

pub struct VarDecl {
pub:
	name       string
	dimensions []Expr
	span       diag.Span
}

pub struct Parameter {
pub:
	name     string
	optional bool
	span     diag.Span
}

pub struct LabelStmt {
pub:
	name string
	span diag.Span
}

pub struct NewlineStmt {
pub:
	span diag.Span
}

pub struct DisplayStmt {
pub:
	expr Expr
	span diag.Span
}

pub struct ExprStmt {
pub:
	expr Expr
	span diag.Span
}

pub struct AssignStmt {
pub:
	target string
	index  Expr = EmptyExpr{}
	value  Expr
	span   diag.Span
}

pub struct DimStmt {
pub:
	decls []VarDecl
	span  diag.Span
}

pub struct GlobalStmt {
pub:
	decls []VarDecl
	span  diag.Span
}

pub struct BreakStmt {
pub:
	enabled bool
	span    diag.Span
}

pub struct ClsStmt {
pub:
	span diag.Span
}

pub struct BigStmt {
pub:
	span diag.Span
}

pub struct SmallStmt {
pub:
	span diag.Span
}

pub struct ColorStmt {
pub:
	raw  string
	span diag.Span
}

pub struct AtStmt {
pub:
	row  Expr
	col  Expr
	span diag.Span
}

pub struct BoxStmt {
pub:
	top    Expr
	left   Expr
	bottom Expr
	right  Expr
	style  Expr
	span   diag.Span
}

pub struct GetStmt {
pub:
	var_name string
	line_mode bool
	span      diag.Span
}

pub struct IfStmt {
pub:
	condition Expr
	then_body []Stmt
	else_body []Stmt
	span      diag.Span
}

pub struct SelectCase {
pub:
	condition Expr
	body      []Stmt
	span      diag.Span
}

pub struct SelectStmt {
pub:
	cases []SelectCase
	span  diag.Span
}

pub struct WhileStmt {
pub:
	condition Expr
	body      []Stmt
	span      diag.Span
}

pub struct DoUntilStmt {
pub:
	body      []Stmt
	condition Expr
	span      diag.Span
}

pub struct ForStmt {
pub:
	var_name string
	start    Expr
	finish   Expr
	step     Expr = EmptyExpr{}
	body     []Stmt
	span     diag.Span
}

pub struct ForEachStmt {
pub:
	var_name string
	iterable Expr
	body     []Stmt
	span     diag.Span
}

pub struct GotoStmt {
pub:
	label Expr
	span  diag.Span
}

pub struct GosubStmt {
pub:
	label Expr
	span  diag.Span
}

pub struct CallStmt {
pub:
	script Expr
	span   diag.Span
}

pub struct FunctionDecl {
pub:
	name   string
	params []Parameter
	body   []Stmt
	span   diag.Span
}

pub struct ReturnStmt {
pub:
	span diag.Span
}

pub struct ResultStmt {
pub:
	value Expr = EmptyExpr{}
	span  diag.Span
}

pub struct ExitStmt {
pub:
	code Expr = EmptyExpr{}
	span diag.Span
}

pub struct SleepStmt {
pub:
	duration Expr
	span     diag.Span
}

pub struct RawCommandStmt {
pub:
	name string
	raw  string
	span diag.Span
}

pub struct EmptyExpr {}

pub struct NumberLiteralExpr {
pub:
	raw  string
	span diag.Span
}

pub struct StringLiteralExpr {
pub:
	value string
	span  diag.Span
}

pub struct VarRefExpr {
pub:
	name string
	span diag.Span
}

pub struct MacroRefExpr {
pub:
	name string
	span diag.Span
}

pub struct EnvRefExpr {
pub:
	name string
	span diag.Span
}

pub struct NameExpr {
pub:
	name string
	span diag.Span
}

pub struct UnaryExpr {
pub:
	op    string
	right Expr
	span  diag.Span
}

pub struct BinaryExpr {
pub:
	left  Expr
	op    string
	right Expr
	span  diag.Span
}

pub struct CallExpr {
pub:
	callee Expr
	args   []Expr
	span   diag.Span
}

pub struct MemberExpr {
pub:
	object Expr
	name   string
	span   diag.Span
}

pub struct IndexExpr {
pub:
	object Expr
	index  Expr
	span   diag.Span
}

pub struct ArrayLiteralExpr {
pub:
	items []Expr
	span  diag.Span
}

pub fn span_of_stmt(stmt Stmt) diag.Span {
	return match stmt {
		AssignStmt { stmt.span }
		AtStmt { stmt.span }
		BigStmt { stmt.span }
		BoxStmt { stmt.span }
		BreakStmt { stmt.span }
		CallStmt { stmt.span }
		ClsStmt { stmt.span }
		ColorStmt { stmt.span }
		DimStmt { stmt.span }
		DisplayStmt { stmt.span }
		DoUntilStmt { stmt.span }
		ExitStmt { stmt.span }
		ExprStmt { stmt.span }
		ForEachStmt { stmt.span }
		ForStmt { stmt.span }
		FunctionDecl { stmt.span }
		GetStmt { stmt.span }
		GlobalStmt { stmt.span }
		GosubStmt { stmt.span }
		GotoStmt { stmt.span }
		IfStmt { stmt.span }
		LabelStmt { stmt.span }
		NewlineStmt { stmt.span }
		RawCommandStmt { stmt.span }
		ResultStmt { stmt.span }
		ReturnStmt { stmt.span }
		SelectStmt { stmt.span }
		SleepStmt { stmt.span }
		SmallStmt { stmt.span }
		WhileStmt { stmt.span }
	}
}

pub fn span_of_expr(expr Expr) diag.Span {
	return match expr {
		ArrayLiteralExpr { expr.span }
		BinaryExpr { expr.span }
		CallExpr { expr.span }
		EmptyExpr { diag.Span{} }
		EnvRefExpr { expr.span }
		IndexExpr { expr.span }
		MacroRefExpr { expr.span }
		MemberExpr { expr.span }
		NameExpr { expr.span }
		NumberLiteralExpr { expr.span }
		StringLiteralExpr { expr.span }
		UnaryExpr { expr.span }
		VarRefExpr { expr.span }
	}
}
