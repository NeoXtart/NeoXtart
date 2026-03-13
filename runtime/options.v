module runtime

pub struct EngineOptions {
pub mut:
	explicit             bool
	case_sensitivity     bool
	no_vars_in_strings   bool
	no_macros_in_strings bool
	wrap_at_eol          bool
}

pub fn (mut opts EngineOptions) set_option(name string, value string) !string {
	normalized_name := name.to_upper()
	normalized_value := value.to_upper()
	state := normalized_value == 'ON'
	return match normalized_name {
		'EXPLICIT' {
			previous := on_off(opts.explicit)
			opts.explicit = state
			previous
		}
		'CASESENSITIVITY' {
			previous := on_off(opts.case_sensitivity)
			opts.case_sensitivity = state
			previous
		}
		'NOVARSINSTRINGS' {
			previous := on_off(opts.no_vars_in_strings)
			opts.no_vars_in_strings = state
			previous
		}
		'NOMACROSINSTRINGS' {
			previous := on_off(opts.no_macros_in_strings)
			opts.no_macros_in_strings = state
			previous
		}
		'WRAPATEOL' {
			previous := on_off(opts.wrap_at_eol)
			opts.wrap_at_eol = state
			previous
		}
		else {
			return error('NX1001')
		}
	}
}

fn on_off(value bool) string {
	return if value { 'ON' } else { 'OFF' }
}
