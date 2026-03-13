module runtime

import math

pub enum ValueKind {
	empty
	boolean
	integer
	double
	string
	array
	object
}

pub struct Value {
pub:
	kind         ValueKind
	type_name    string
	bool_value   bool
	int_value    i64
	double_value f64
	string_value string
	array_value  []Value
	object_name  string
}

pub fn empty_value() Value {
	return Value{
		kind:      .empty
		type_name: 'run'
	}
}

pub fn int_value(v i64) Value {
	return typed_int_value(v, 'i64')
}

pub fn typed_int_value(v i64, type_name string) Value {
	return Value{
		kind:      .integer
		type_name: type_name
		int_value: v
	}
}

pub fn double_value(v f64) Value {
	return typed_double_value(v, 'f64')
}

pub fn typed_double_value(v f64, type_name string) Value {
	return Value{
		kind:         .double
		type_name:    type_name
		double_value: v
	}
}

pub fn string_value(v string) Value {
	return Value{
		kind:         .string
		type_name:    'str'
		string_value: v
	}
}

pub fn bool_value(v bool) Value {
	return Value{
		kind:       .boolean
		type_name:  'bool'
		bool_value: v
	}
}

pub fn array_value(v []Value) Value {
	return Value{
		kind:        .array
		type_name:   'array'
		array_value: v.clone()
	}
}

pub fn object_placeholder(name string) Value {
	return Value{
		kind:        .object
		type_name:   'object'
		object_name: name
	}
}

pub fn (v Value) is_empty() bool {
	return v.kind == .empty
}

pub fn (v Value) is_numeric() bool {
	return v.kind in [.integer, .double]
}

pub fn (v Value) truthy() bool {
	return match v.kind {
		.empty { false }
		.boolean { v.bool_value }
		.integer { v.int_value != 0 }
		.double { math.abs(v.double_value) > 0.0000001 }
		.string { v.string_value.len > 0 }
		.array { v.array_value.len > 0 }
		.object { true }
	}
}

pub fn (v Value) as_i64() !i64 {
	return match v.kind {
		.empty {
			i64(0)
		}
		.boolean {
			if v.bool_value {
				i64(1)
			} else {
				i64(0)
			}
		}
		.integer {
			v.int_value
		}
		.double {
			i64(v.double_value)
		}
		.string {
			if v.string_value.len == 0 {
				i64(0)
			} else {
				i64(v.string_value.f64())
			}
		}
		.array {
			return error('array can not be used as integer')
		}
		.object {
			return error('object can not be used as integer')
		}
	}
}

pub fn (v Value) as_f64() !f64 {
	return match v.kind {
		.empty {
			f64(0.0)
		}
		.boolean {
			if v.bool_value {
				f64(1.0)
			} else {
				f64(0.0)
			}
		}
		.integer {
			f64(v.int_value)
		}
		.double {
			v.double_value
		}
		.string {
			if v.string_value.len == 0 {
				f64(0.0)
			} else {
				v.string_value.f64()
			}
		}
		.array {
			return error('array can not be used as double')
		}
		.object {
			return error('object can not be used as double')
		}
	}
}

pub fn (v Value) as_string() string {
	return match v.kind {
		.empty {
			''
		}
		.boolean {
			if v.bool_value {
				'1'
			} else {
				'0'
			}
		}
		.integer {
			v.int_value.str()
		}
		.double {
			mut text := v.double_value.str()
			if text.contains('.') {
				text = text.trim_right('0').trim_right('.')
			}
			text
		}
		.string {
			v.string_value
		}
		.array {
			v.array_value.map(it.as_string()).join(',')
		}
		.object {
			v.object_name
		}
	}
}

pub fn (v Value) vartype() int {
	return match v.kind {
		.empty { 0 }
		.boolean { 11 }
		.integer { 3 }
		.double { 5 }
		.string { 8 }
		.object { 9 }
		.array { 8204 }
	}
}

pub fn (v Value) vartype_name() string {
	return match v.kind {
		.empty { 'Empty' }
		.boolean { 'Boolean' }
		.integer { 'Long' }
		.double { 'Double' }
		.string { 'String' }
		.object { 'Object' }
		.array { 'Variant[]' }
	}
}

pub fn (v Value) neo_type_name() string {
	if v.type_name.len > 0 {
		return v.type_name
	}
	return match v.kind {
		.empty { 'run' }
		.boolean { 'bool' }
		.integer { 'i64' }
		.double { 'f64' }
		.string { 'str' }
		.array { 'array' }
		.object { 'object' }
	}
}
