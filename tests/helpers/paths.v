module helpers

import os

pub fn repo_root() string {
	return os.dir(os.dir(os.dir(@FILE)))
}

pub fn fixture_scripts_dir() string {
	return os.join_path(repo_root(), 'tests', 'fixtures', 'scripts')
}

pub fn fixture_script_path(name string) string {
	return os.join_path(fixture_scripts_dir(), name)
}

pub fn example_path(name string) string {
	return os.join_path(repo_root(), 'examples', 'v1', name)
}

pub fn sample_path(name string) string {
	return os.join_path(repo_root(), 'KiX4.70', 'Samples', name)
}
