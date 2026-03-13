# NeoXtart

## Overview

NeoXtart is a KiXtart-like interpreter written in V, with an initial Windows-only target and an intentionally simple codebase.
The goal at this stage is to prioritize implementation readability, incremental compatibility, and explicit errors for anything that is not implemented yet.

## Architecture

- `cmd/neoxtart`: project CLI (`run`, `check`, `dump-tokens`, `dump-ast`).
- `source`: script loading, path resolution, and diagnostics.
- `token/token.v`: token types.
- `token/lexer`: hand-written lexer, case-insensitive for keywords.
- `ast`: AST nodes and dump helpers.
- `parser`: hand-written parser using recursive descent for statements and precedence parsing for expressions.
- `runtime`: loader, options, values, builtins, and tree-walk execution.
- `platform/windows`: Windows-specific integrations.
- `examples/v1`: small and stable examples for the current supported subset.

## Execution Flow

1. `source.resolve_script` resolves the target script path.
2. `token.lexer.tokenize` transforms source text into tokens.
3. `parser.parse` builds the AST.
4. `runtime.load_program` indexes labels and registers functions.
5. `runtime.run_file` or `runtime.run_text` executes the program.

## Useful Commands

- `v run .\cmd\neoxtart check .\examples\v1\factorial.kix`
- `v run .\cmd\neoxtart dump-tokens .\examples\v1\factorial.kix`
- `v run .\cmd\neoxtart dump-ast .\examples\v1\factorial.kix`
- `v run .\cmd\neoxtart run .\examples\v1\call_main.kix`
- `v test .`

## Contribution Rules

- Preserve the main goal of this stage: code that is easy to read and continue.
- Before introducing a new abstraction, confirm that it reduces real complexity in the parser or runtime.
- Do not hide missing behavior. Use structured `NX1001` errors when a feature does not exist yet.
- When adding new syntax or semantics, update examples and tests in the same commit.
- Any future change to the language or runtime must update, in the same commit, the `NeoXtart vs KiXtart Differences` and `How To Do Things In NeoXtart` sections.

## NeoXtart vs KiXtart Differences

### Intentional Differences

- NeoXtart adds the `RESULT [value]` keyword for explicit function returns.
- Inside functions, the KiXtart-compatible style remains valid: assign the result to `$FunctionName`.
- `RETURN` is reserved for `GOSUB` flow control.
- NeoXtart supports optional static type annotations such as `i16`, `f64`, `bool`, `str`, and `run`.
- `run` is the dynamic compatibility type: the value is resolved at runtime instead of being fixed ahead of time.
- `typeof(...) is <type>` is supported as the preferred type-check syntax in `.neo` code.

### Temporary Implementation Gaps

- The current public interface uses the `neoxtart run/check/dump-tokens/dump-ast` CLI.
- Tokenized `.kx` scripts are not supported yet.
- COM, WMI, registry, printers, networking, and domain/user-dependent macros are not implemented yet.
- `INCLUDE`, `RUN`, `SHELL`, `USE`, `PLAY`, and other commands outside the current subset still return `NX1001`.
- Real object execution exists only in the parser for now; runtime still fails with `NX1001` for object members and methods.

## How To Do Things In NeoXtart

### Run a Script

Use:

```powershell
v run .\cmd\neoxtart run .\examples\v1\factorial.kix
```

### Validate Syntax

Use:

```powershell
v run .\cmd\neoxtart check .\KiX4.70\Samples\fly.kix
```

### Inspect Tokens

Use:

```powershell
v run .\cmd\neoxtart dump-tokens .\examples\v1\factorial.kix
```

### Inspect the AST

Use:

```powershell
v run .\cmd\neoxtart dump-ast .\examples\v1\factorial.kix
```

### Pass Variables Through the Command Line

Use:

```powershell
v run .\cmd\neoxtart run .\script.kix --var '$Name=Neo'
```

### Declare Typed Variables

Use the type after the variable name:

```vb
$count i16 = 33
$price f64 = 3.14
$flag bool = 0
$message str = "hello"
$dynamic run = "compatible"
```

If no type is provided, NeoXtart infers one from the first assigned value.
The same pattern also works inside `DIM` and `GLOBAL` blocks, and typed declarations without an initializer receive a type-specific default value such as `0`, `0.0`, `""`, or `false`.

### Return a Function Value

For KiXtart compatibility:

```vb
function Fact($n)
    $Fact = 1
endfunction
```

Or using the NeoXtart extension:

```vb
function Double($n)
    result $n * 2
endfunction
```

### Type-check a Runtime Value

Use `typeof(...) is <type>`:

```vb
if typeof($value) is bool
    "boolean"
else if typeof($value) is f64
    "float64"
endif
```

### Add a New Builtin

1. Implement the logic in `runtime/builtins.v`.
2. Register the name in the `call_builtin` match.
3. If the builtin changes global state, prefer a small helper that is easy to test.
4. Add a test in `runtime/runtime_test.v`.
5. If it changes compatibility with KiXtart, update the `NeoXtart vs KiXtart Differences` section.

### Register a New Compatibility Divergence

1. Document the divergence in `NeoXtart vs KiXtart Differences`.
2. Add a test covering the behavior.
3. If there is a recommended way to do the same thing with the current project state, document it in `How To Do Things In NeoXtart`.
