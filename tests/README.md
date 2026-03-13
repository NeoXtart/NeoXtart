# Tests

This directory is the canonical home for NeoXtart language tests.

## Layout

- `tests/helpers`: shared helpers for repository paths, fixtures, and inline scripts.
- `tests/fixtures/scripts`: test-only `.kix` and `.neo` script fixtures.
- `tests/lexer`: lexer-focused tests.
- `tests/parser`: parser-focused tests.
- `tests/runtime`: runtime-focused tests.
- `tests/samples`: compatibility checks against the KiXtart sample set and other larger scenarios.

## Commands

Run the full language test suite with:

```powershell
v test tests
```

List the test files:

```powershell
rg --files tests -g "*_test.v"
```

## Conventions

- Prefer public APIs (`token.lexer`, `parser`, `runtime`, `source`, `ast`) over same-module internals.
- Keep human-facing examples under `examples/v1`.
- Keep test-only fixtures under `tests/fixtures/scripts`.
- When adding a new language feature, finish with at least one parser test and one runtime test.

## Recommended First Solo Feature

`BEEP` is a good first feature to implement end-to-end because it is small and touches the full interpreter path.

Acceptance tests to add when implementing it:

- Parser: `BEEP` becomes a dedicated AST statement.
- Runtime: `run_text("BEEP", emit_console: false)` succeeds without output and without error.
- CLI: `neoxtart check` accepts a script containing `BEEP`.
