module source

import os
import source.diag

pub enum ScriptKind {
	kix
	kx
}

pub struct ResolvedScript {
pub:
	path string
	kind ScriptKind
}

pub struct Source {
pub:
	path  string
	text  string
	lines []string
}

pub fn new(path string, text string) Source {
	return Source{
		path:  path
		text:  text
		lines: text.split_into_lines()
	}
}

pub fn load_file(path string) !Source {
	text := os.read_file(path)!
	return new(path, text)
}

pub fn (src Source) line_text(line int) string {
	if line <= 0 || line > src.lines.len {
		return ''
	}
	return src.lines[line - 1]
}

pub fn (src Source) diagnostic(code string, message string, span diag.Span, stack []string) diag.Diagnostic {
	return diag.Diagnostic{
		code:      code
		message:   message
		file_path: src.path
		span:      span
		excerpt:   src.line_text(span.start.line)
		stack:     stack
	}
}

pub fn resolve_script(input string, current_dir string) !ResolvedScript {
	base_dir := if current_dir.len > 0 { current_dir } else { os.getwd() }
	mut candidates := []string{}
	if os.is_abs_path(input) {
		candidates << input
	} else {
		candidates << os.join_path(base_dir, input)
	}
	if os.file_ext(input).len == 0 {
		if os.is_abs_path(input) {
			candidates << input + '.kix'
			candidates << input + '.kx'
		} else {
			candidates << os.join_path(base_dir, input + '.kix')
			candidates << os.join_path(base_dir, input + '.kx')
		}
	}
	for candidate in candidates {
		if os.exists(candidate) {
			ext := os.file_ext(candidate).to_lower()
			kind := if ext == '.kx' { ScriptKind.kx } else { ScriptKind.kix }
			return ResolvedScript{
				path: os.real_path(candidate)
				kind: kind
			}
		}
	}
	return error('script not found: ${input}')
}
