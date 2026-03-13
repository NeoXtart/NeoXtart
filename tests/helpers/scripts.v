module helpers

import os
import runtime

pub fn inline_script(lines []string) string {
	return lines.join('\n')
}

pub fn run_inline(text string) !runtime.RunResult {
	return runtime.run_text(text, runtime.RunOptions{
		current_dir:  repo_root()
		emit_console: false
	})
}

pub fn run_inline_lines(lines []string) !runtime.RunResult {
	return run_inline(inline_script(lines))
}

pub fn write_temp_script(name string, text string) !string {
	temp_dir := os.join_path(os.temp_dir(), 'neoxtart-tests')
	os.mkdir_all(temp_dir)!
	path := os.join_path(temp_dir, name)
	os.write_file(path, text)!
	return path
}
