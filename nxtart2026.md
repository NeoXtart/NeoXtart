# NeoXtart 2026

This document describes what NeoXtart actually executes today.
It reflects the current interpreter implementation in this repository, not the long-term language plan.

## Scope

NeoXtart currently provides:

- A Windows-first interpreter written in V.
- A KiXtart-like execution model with a practical subset of syntax and runtime behavior.
- Optional static type annotations with a dynamic `run` type for compatibility-oriented code.
- A CLI for running scripts, checking syntax, and dumping tokens or AST.

It does not yet aim for full KiXtart compatibility.

## CLI

The current CLI supports:

```powershell
neoxtart run <script> [--var '$Name=Value']...
neoxtart check <script>
neoxtart dump-tokens <script>
neoxtart dump-ast <script>
```

Notes:

- Exact paths work for `.kix`, `.neo`, or any existing script path.
- Extensionless resolution currently tries `.kix` and `.kx`.
- `.kx` tokenized scripts are explicitly rejected.

## File and Runtime Model

- Execution is script-based.
- `CALL` loads another script and shares global state and registered functions.
- Labels are indexed per script/function body.
- Runtime diagnostics include file, line, column, excerpt, and call stack.

## Current Language Syntax

### Statements

The interpreter currently parses and executes these statement forms:

- Assignment: `$name = expr`
- Typed assignment: `$name i16 = 33`
- Array indexing assignment: `$arr[0] = expr`
- Label: `:start`
- New line command: `?`
- Expression display: bare expression or string on its own line
- `DIM`
- `GLOBAL`
- `IF / ELSE / ENDIF`
- `SELECT / CASE / ENDSELECT`
- `WHILE / LOOP`
- `DO / UNTIL`
- `FOR / NEXT`
- `FOR EACH / NEXT`
- `GOTO`
- `GOSUB`
- `CALL`
- `FUNCTION / ENDFUNCTION`
- `RESULT [value]`
- `RETURN`
- `EXIT [code]`
- `SLEEP`
- `CLS`
- `AT`
- `GET`
- `GETS`
- `BIG`
- `SMALL`
- `COLOR`
- `BOX`
- `BREAK`

### Expression Features

The parser currently supports:

- Numbers
- Strings
- Variables: `$name`
- Macros: `@DATE`
- Environment references: `%PATH%`
- Function calls: `foo(a, b)`
- Calls with omitted arguments: `foo(1,,3)`
- Member access parsing: `obj.name`
- Index access: `$arr[0]`
- Unary operators: `NOT`, `+`, `-`, `~`
- Binary operators: `+`, `-`, `*`, `/`, `MOD`, `AND`, `OR`, `IS`, `<`, `>`, `<=`, `>=`, `=`, `==`, `<>`, `&`, `|`, `^`
- Multi-line expressions with operator continuation
- `else if` chains

### Type Syntax

NeoXtart currently accepts these types:

- `bool`
- `i8`
- `i16`
- `i32`
- `i64`
- `int`
- `f32`
- `f64`
- `str`
- `string`
- `run`

Supported typed forms:

```vb
$count i16 = 33
$price f64 = 3.14
$flag bool = true
$text str = "hello"
$dynamic run = "compatible"
```

Inside declarations:

```vb
dim
    $value1 run = 33.4,
    $value2 str = "Hello, World!",
    $value3 bool,
    $value4
```

Current typing behavior:

- If a type is explicitly declared, assignments are coerced to that type.
- If no type is declared, the first assigned value infers the stored type.
- `run` stays dynamic and stores the runtime value without locking a fixed type ahead of time.
- Typed declarations without an initializer receive a default value.
- Untyped declarations without an initializer start as empty `run`.

Current defaults:

- `bool` -> `false` / `0`
- integer types -> `0`
- float types -> `0.0`
- `str` -> `""`
- `run` -> empty runtime value

### Function Return Rules

NeoXtart currently supports two function return styles:

1. KiXtart-compatible style:

```vb
function Fact($n)
    $Fact = 1
endfunction
```

2. NeoXtart explicit style:

```vb
function Double($n)
    result $n * 2
endfunction
```

Current flow control rule:

- `RETURN` is reserved for `GOSUB`.
- `RESULT` is used for function return values.
- `RETURN <value>` is rejected.

## Commands That Execute Today

### Fully or Meaningfully Implemented

- `DIM`
- `GLOBAL`
- `IF / ELSE / ENDIF`
- `SELECT / CASE / ENDSELECT`
- `WHILE / LOOP`
- `DO / UNTIL`
- `FOR / NEXT`
- `FOR EACH / NEXT`
- `GOTO`
- `GOSUB`
- `CALL`
- `FUNCTION / ENDFUNCTION`
- `RESULT`
- `RETURN` for `GOSUB`
- `EXIT`
- `SLEEP`
- `GET`
- `GETS`
- `CLS`
- `AT`
- bare display expressions
- `?`

### Accepted but Currently Minimal or No-op

- `BIG`
- `SMALL`
- `COLOR`
- `BOX`
- `BREAK`

Notes:

- `CLS` clears the terminal when console output is enabled.
- `AT` moves the terminal cursor when console output is enabled.
- `GET` reads a single character.
- `GETS` reads a full line.
- `BIG`, `SMALL`, `COLOR`, `BOX`, and `BREAK` are accepted but do not yet implement full KiXtart behavior.

## Builtin Functions Implemented Today

These builtins currently execute:

- `ABS`
- `ASC`
- `CHR`
- `CDBL`
- `CINT`
- `CSTR`
- `FIX`
- `INT`
- `VAL`
- `LEN`
- `LEFT`
- `RIGHT`
- `SUBSTR`
- `LTRIM`
- `RTRIM`
- `TRIM`
- `LCASE`
- `UCASE`
- `INSTR`
- `INSTRREV`
- `REPLACE`
- `IIF`
- `SPLIT`
- `JOIN`
- `UBOUND`
- `VARTYPE`
- `VARTYPENAME`
- `RND`
- `SRND`
- `EXIST`
- `DIR`
- `GETCOMMANDLINE`
- `ISDECLARED`
- `SETOPTION`
- `TYPEOF`

## Macros Implemented Today

These macros currently execute:

- `@ERROR`
- `@SERROR`
- `@RESULT`
- `@DATE`
- `@TIME`
- `@MSECS`
- `@DAY`
- `@MDAYNO`
- `@WDAYNO`
- `@YDAYNO`
- `@MONTH`
- `@MONTHNO`
- `@YEAR`
- `@CURDIR`
- `@STARTDIR`
- `@SCRIPTDIR`
- `@SCRIPTNAME`
- `@SCRIPTEXE`
- `@KIX`
- `@PID`
- `@PRODUCTTYPE`
- `@INWIN`

Environment expansion using `%NAME%` is also supported.

## Type Introspection

NeoXtart currently supports:

```vb
if typeof($value) is bool
    "boolean"
else if typeof($value) is f64
    "float64"
endif
```

Current behavior:

- `typeof(x)` returns the NeoXtart runtime type name such as `bool`, `f64`, `str`, `run`, or an integer subtype.
- `is` compares the type name text in this context.

## Runtime Values Supported Today

The runtime currently stores these value categories:

- empty
- boolean
- integer
- double
- string
- array
- object placeholder

Object support is still incomplete. Member access and method call syntax may parse, but runtime execution is not fully implemented.

## Compatibility Notes

### What Is Deliberately Different

- `RESULT` exists as a NeoXtart extension.
- `RETURN` is not used for function values.
- Static type annotations are part of NeoXtart syntax.
- `run` is the dynamic bridge type for compatibility-oriented code.

### What Still Fails with `NX1001`

These areas are still intentionally unsupported or partial:

- tokenized `.kx` execution
- `INCLUDE`
- `RUN`
- `SHELL`
- `USE`
- `PLAY`
- registry operations
- COM and WMI execution
- printer features
- networking features
- domain/user-dependent macros
- real object member/method execution

## Current Examples

The repository already includes working examples for the current subset:

- `examples/v1/factorial.kix`
- `examples/v1/result.kix`
- `examples/v1/call_main.kix`
- `examples/v1/type_var.neo`

## Current Test Coverage

The current automated tests cover:

- the `tests/` directory as the canonical home for language tests
- lexer behavior
- parser behavior
- function return rules
- typed declarations and inference
- `DIM` declaration initializers
- `CALL` global sharing
- runtime compatibility checks for selected KiXtart samples

Run them with:

```powershell
v test tests
```

## Summary

NeoXtart today is best described as:

- a working subset interpreter
- KiXtart-inspired, not fully KiXtart-complete
- capable of running real scripts in the implemented subset
- already supporting the new NeoXtart type syntax
- still missing heavy Windows integration features and object-based runtime behavior
