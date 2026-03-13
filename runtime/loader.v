module runtime

import os
import ast
import parser
import source
import token.lexer

struct Program {
	source source.Source
	script ast.Script
	labels map[string]int
}

fn load_program(path string) !Program {
	src := source.load_file(path)!
	tokens := lexer.tokenize(src)!
	script := parser.parse(src, tokens)!
	return Program{
		source: src
		script: script
		labels: build_label_index(script)
	}
}

fn build_label_index(script ast.Script) map[string]int {
	mut labels := map[string]int{}
	for index, stmt in script.statements {
		if stmt is ast.LabelStmt {
			labels[stmt.name.to_upper()] = index
		}
	}
	return labels
}

pub fn tokenize_file(path string) !string {
	resolved := source.resolve_script(path, os.getwd())!
	if resolved.kind == .kx {
		return error('.kx tokenized scripts are not supported yet')
	}
	src := source.load_file(resolved.path)!
	tokens := lexer.tokenize(src)!
	mut lines := []string{}
	for tok in tokens {
		lines << '${tok.span.start.line}:${tok.span.start.col} ${tok.kind} ${tok.lexeme}'
	}
	return lines.join('\n')
}

pub fn dump_ast_file(path string) !string {
	resolved := source.resolve_script(path, os.getwd())!
	if resolved.kind == .kx {
		return error('.kx tokenized scripts are not supported yet')
	}
	program := load_program(resolved.path)!
	return ast.dump_script(program.script)
}

pub fn check_file(path string) ! {
	resolved := source.resolve_script(path, os.getwd())!
	if resolved.kind == .kx {
		return error('.kx tokenized scripts are not supported yet')
	}
	_ := load_program(resolved.path)!
}
