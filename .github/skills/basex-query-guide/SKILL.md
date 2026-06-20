---
name: basex-query-guide
description: 'BaseX query operations for Dynamics 365 FO metadata databases. Use when writing or troubleshooting BaseX CLI commands, counting resources, listing object types, handling PowerShell quoting, external variable bindings, stderr/stdout piping with 2>&1, and compatibility issues such as unavailable db:open().'
argument-hint: 'Describe the BaseX task, database name, and desired output format (count, report, or file output).'
user-invocable: true
---

# BaseX Query Guide for D365 FO

## When to Use
- You need operational BaseX CLI queries against D365 metadata databases (for example `D365ApplicationExtended`).
- You need robust Windows PowerShell patterns for quoting, output capture, and filtering.
- You are troubleshooting BaseX behavior in this environment, including function compatibility.

## Environment Assumptions
- BaseX CLI is available as `basex`.
- `db:list(...)`, `db:list-details(...)`, and `collection(...)` patterns are supported.
- `db:open(...)` is not assumed to be available.
- For Windows PowerShell inline XQuery: use single-quoted outer strings and double single quotes inside XQuery string literals.

## Procedure
1. Confirm scope and inputs.
2. Pick a command pattern from `references/basex-commands.md`.
3. Apply Windows PowerShell-safe quoting and pipeline rules from `references/powershell-quoting.md`.
4. Run the command, then validate counts and sample paths.
5. If behavior is unexpected, use the troubleshooting map in both reference files.

## References
- `references/basex-commands.md`
- `references/powershell-quoting.md`

## Core Rules
- Prefer `db:list(...)` plus `collection(...)`/`doc(...)` in this environment.
- For `.xq` pipelines in PowerShell, use `2>&1` before piping.
- Use bare `-b key=value` bindings.

## Troubleshooting Quick Map
- Parser errors in PowerShell: move inline query to a `.xq` file and pass `-b` bindings.
- Empty pipeline output: add `2>&1` before the PowerShell pipeline.
- `-b` override ignored: remove quotes around `key=value`.
- Unknown `db:open(...)`: use `db:list(...)` with `collection(...)` or `doc(...)`.
- Lock errors (`[db:lock]`): close other BaseX processes and retry.

## Expected Inputs
- Database name (for example `D365ApplicationExtended`).
- Query intent: metadata check, count, report, or path rename validation.
- Output preference: terminal, filtered lines, or file output.

## Expected Outputs
- Reproducible BaseX command lines.
- Quoting-safe PowerShell invocations.
- Diagnostics-first troubleshooting steps for common failures.