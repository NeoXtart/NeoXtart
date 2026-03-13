module samples_test

import os
import runtime
import tests.helpers

fn test_samples_from_plan_parse_and_fail_as_expected() {
	root := helpers.repo_root()
	samples := [
		helpers.sample_path('recur.kix'),
		helpers.sample_path('adsi01.kix'),
		helpers.sample_path('getip.kix'),
		helpers.sample_path('demo.kix'),
		helpers.sample_path('plt.kix'),
	]
	for sample in samples {
		runtime.check_file(sample) or { panic(err.msg()) }
	}

	fly := runtime.run_file(helpers.sample_path('fly.kix'), runtime.RunOptions{
		current_dir:  root
		emit_console: false
	}) or { panic(err.msg()) }
	assert fly.exit_code == 0
	assert fly.output.count('KIXTART') == 10

	failing := {
		'adsi01.kix': 'NX1001'
		'getip.kix':  'NX1001'
		'demo.kix':   'NX1001'
		'plt.kix':    'NX1001'
	}
	for name, expected in failing {
		_ := runtime.run_file(helpers.sample_path(name), runtime.RunOptions{
			current_dir:  root
			emit_console: false
		}) or {
			assert err.msg().contains(expected)
			continue
		}
		assert false
	}
}

fn test_helpers_are_shared_cleanly_across_test_subfolders() {
	assert os.exists(helpers.fixture_script_path('call_main.kix'))
	assert helpers.example_path('call_main.kix').ends_with('examples\\v1\\call_main.kix')
}
