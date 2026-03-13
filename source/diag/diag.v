module diag

pub struct Pos {
pub:
	line   int
	col    int
	offset int
}

pub struct Span {
pub:
	start Pos
	end   Pos
}

pub struct Diagnostic {
pub:
	code      string
	message   string
	file_path string
	span      Span
	excerpt   string
	stack     []string
}

pub fn (d Diagnostic) str() string {
	mut parts := []string{}
	location := '${d.file_path}:${d.span.start.line}:${d.span.start.col}'
	parts << '${location}: ${d.code}: ${d.message}'
	if d.excerpt.len > 0 {
		parts << '> ${d.excerpt}'
	}
	if d.stack.len > 0 {
		parts << 'Call stack:'
		for entry in d.stack {
			parts << '  - ${entry}'
		}
	}
	return parts.join('\n')
}

pub fn single_pos(line int, col int, offset int) Span {
	pos := Pos{
		line:   line
		col:    col
		offset: offset
	}
	return Span{
		start: pos
		end:   pos
	}
}
