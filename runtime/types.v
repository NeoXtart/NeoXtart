module runtime

const supported_type_names = ['BOOL', 'F32', 'F64', 'I8', 'I16', 'I32', 'I64', 'INT', 'RUN', 'STR',
	'STRING']

struct Binding {
mut:
	value     Value
	type_name string
}

fn normalize_type_name(name string) !string {
	if name.len == 0 {
		return 'run'
	}
	return match name.to_upper() {
		'BOOL' { 'bool' }
		'F32' { 'f32' }
		'F64' { 'f64' }
		'I8' { 'i8' }
		'I16' { 'i16' }
		'I32' { 'i32' }
		'I64' { 'i64' }
		'INT' { 'int' }
		'RUN' { 'run' }
		'STR', 'STRING' { 'str' }
		else { return error('unsupported type `${name}`') }
	}
}

fn infer_type_name(value Value) string {
	return match value.kind {
		.boolean {
			'bool'
		}
		.double {
			'f64'
		}
		.integer {
			if value.type_name.len > 0 {
				value.type_name
			} else {
				'i64'
			}
		}
		.string {
			'str'
		}
		.array {
			'run'
		}
		.object {
			'run'
		}
		.empty {
			'run'
		}
	}
}

fn default_value_for_type(type_name string) !Value {
	normalized := normalize_type_name(type_name)!
	return match normalized {
		'bool' { bool_value(false) }
		'f32' { typed_double_value(0.0, 'f32') }
		'f64' { double_value(0.0) }
		'i8' { typed_int_value(0, 'i8') }
		'i16' { typed_int_value(0, 'i16') }
		'i32' { typed_int_value(0, 'i32') }
		'i64' { int_value(0) }
		'int' { typed_int_value(0, 'int') }
		'str' { string_value('') }
		'run' { empty_value() }
		else { return error('unsupported type `${type_name}`') }
	}
}

fn coerce_value_to_type(value Value, type_name string) !Value {
	normalized := normalize_type_name(type_name)!
	return match normalized {
		'bool' { bool_value(value.truthy()) }
		'f32' { typed_double_value(value.as_f64()!, 'f32') }
		'f64' { double_value(value.as_f64()!) }
		'i8' { typed_int_value(value.as_i64()!, 'i8') }
		'i16' { typed_int_value(value.as_i64()!, 'i16') }
		'i32' { typed_int_value(value.as_i64()!, 'i32') }
		'i64' { int_value(value.as_i64()!) }
		'int' { typed_int_value(value.as_i64()!, 'int') }
		'str' { string_value(value.as_string()) }
		'run' { value }
		else { return error('unsupported type `${type_name}`') }
	}
}

fn binding_from_value(type_name string, value Value) !Binding {
	normalized := normalize_type_name(type_name)!
	return Binding{
		value:     if normalized == 'run' { value } else { coerce_value_to_type(value, normalized)! }
		type_name: normalized
	}
}
