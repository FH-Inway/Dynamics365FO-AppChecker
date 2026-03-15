# BaseX Query Guide for D365ApplicationExtended

This guide captures the practical BaseX query patterns used during maintenance of the `D365ApplicationExtended` database.

## Prerequisites

- BaseX CLI is installed and available as `basex`.
- Database exists, for example `D365ApplicationExtended`.
- On Windows PowerShell, prefer single-quoted outer command text and doubled single quotes inside XQuery string literals when needed.

### BaseX Function Compatibility (Current Environment)

- Verified on this workstation with BaseX 12.2 CLI.
- `db:list(...)` and `collection(...)` patterns are working and preferred for database/resource traversal.
- `db:open(...)` was not available in this environment; avoid depending on it for operational scripts.
- If a query example relies on unavailable functions, rewrite it using `db:list(...)` + `collection(...)` (or `doc(...)` with explicit database/resource paths).

## 1) Get Database Metadata

Use this when you need a quick health/size check:

```powershell
basex -c "OPEN D365ApplicationExtended; INFO DB"
```

Useful fields:
- `SIZE`
- `DOCUMENTS`
- `NODES`
- `UPTODATE`
- index flags (`TEXTINDEX`, `ATTRINDEX`, ...)

## 2) List Sample Resource Paths

Use the `db` module and sample output before running expensive queries:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $p in subsequence(db:list(''D365ApplicationExtended''), 1, 40) return $p'
```

## 3) Count Resources by Top-Level Object Type

This groups by the first path segment (Classes, Tables, AxEDT, ...):

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $c in distinct-values(for $x in $p return tokenize($x, ''/'')[1]) let $n := count($p[starts-with(., concat($c, ''/''))]) order by $n descending return concat($c, '' | '', $n)'
```

## 4) Case-Normalized Type Counts (e.g. AxEdt + AxEDT)

If you need to treat case variants as one type:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') let $cats := for $x in $p return tokenize($x, ''/'')[1] for $k in distinct-values(for $c in $cats return lower-case($c)) let $n := count($cats[lower-case(.) = $k]) order by $n descending return concat($k, '' | '', $n)'
```

To force canonical name `AxEDT`:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $x in $p let $raw := tokenize($x, ''/'')[1] let $canon := if(lower-case($raw) = ''axedt'') then ''AxEDT'' else $raw group by $canon order by count($x) descending return concat($canon, '' | '', count($x))'
```

## 5) Count Only EDT Paths

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; count(for $p in db:list(''D365ApplicationExtended'') where matches($p, ''^(AxEdt|AxEDT)/'') return $p)'
```

## 6) Largest Resources by Stored Size

`db:list-details()` exposes size metadata per resource:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $r in subsequence(for $x in db:list-details(''D365ApplicationExtended'') order by xs:integer($x/@size) descending return $x, 1, 20) return concat($r/text(), '' | '', $r/@size)'
```

## 9) Common Windows PowerShell Quoting Notes

- If a query contains `$` variables, use single-quoted command strings around XQuery.
- Inside those single-quoted strings, escape literal single quotes as doubled single quotes.
- If quoting gets too complex, put the query in an `.xq` file and execute the file with external variable bindings.

Example external variable binding with query file:

```powershell
basex -bdb=D365ApplicationExtended -bsample-limit=500 ./tools/BaseXMaintenance/Rename-Paths/rename-paths-collision-precheck.xq
```

## 10) Robust Extraction of Query Results

BaseX output in Windows PowerShell can be awkward to consume directly:

- single-value results may appear without obvious labels
- multi-line output may be truncated in the terminal renderer
- parser errors can be mixed into command output

Prefer one of these patterns when you need reliable extraction.

### A) Wrap the result in a PowerShell variable and print a labeled line

Good for scalar values such as counts.

```powershell
$count = basex -q 'import module namespace db = ''http://basex.org/modules/db''; count(for $p in db:list(''D365ApplicationExtended'') where starts-with($p, ''AxEDT/'') return $p)'
Write-Host "AXEDT_PATHS=$count"
```

### B) Return labeled output from XQuery itself

This makes the result self-describing before it reaches PowerShell.

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; concat(''AXEDT_PATHS | '', count(for $p in db:list(''D365ApplicationExtended'') where starts-with($p, ''AxEDT/'') return $p))'
```

### C) Capture multi-line output and filter it in PowerShell

Good for reports such as top-level object type counts.

```powershell
$lines = basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $c in distinct-values(for $x in $p return tokenize($x, ''/'')[1]) let $n := count($p[starts-with(., concat($c, ''/''))]) order by $n descending return concat($c, '' | '', $n)'
$axedt = $lines | Where-Object { $_ -like 'AxEDT | *' }
Write-Host $axedt
```

### D) Write results to a file when terminal rendering is unreliable

Good for long outputs or when the terminal drops lines.

```powershell
$lines = basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $r in subsequence(for $x in db:list-details(''D365ApplicationExtended'') order by xs:integer($x/@size) descending return $x, 1, 20) return concat($r/text(), '' | '', $r/@size)'
Set-Content -Path .\largest-resources.txt -Value $lines -Encoding UTF8
```

Then inspect the saved output:

```powershell
Get-Content .\largest-resources.txt
```

### E) Extract metadata fields from `INFO DB`

Useful when you want one specific field from the database metadata block.

```powershell
$info = basex -c "OPEN D365ApplicationExtended; INFO DB"
($info | Select-String '^ DOCUMENTS:').Line
($info | Select-String '^ SIZE:').Line
```

### F) Prefer `.xq` files plus external bindings for reusable queries

This is the most robust option when the query is long or contains many `$` variables.

```powershell
basex -bdb=D365ApplicationExtended -bsample-limit=50 ./tools/BaseXMaintenance/Rename-Paths/rename-paths-collision-precheck.xq
```

### Recommended practice

- For one number: capture to a variable and print a labeled line.
- For reports: return one line per item and filter in PowerShell.
- For long output: write to a file first, then inspect the file.
- For repeatable operational queries: keep them in `.xq` files and pass parameters with `-b...`.

## 11) Troubleshooting

### Symptom: query returns parser errors in PowerShell

Likely cause: shell quoting around XQuery.

Fix: move query to `.xq` file and call `basex` with `-b` variable bindings.

### Symptom: unknown function errors for `db:open(...)`

Likely cause: function/module compatibility differences in the installed BaseX build.

Fix: use `db:list(...)` to enumerate resource paths and `collection(...)` (or `doc(...)`) to read content instead of `db:open(...)`.

### Symptom: case-only rename appears to do nothing on Windows

Likely cause: path case change is not reliably applied in one update pass.

Fix: use the two-phase rename flow already implemented:
1. `AxEdt/...` -> temporary prefix path
2. temporary prefix path -> `AxEDT/...`

### Symptom: lock errors (`[db:lock] Database is opened by another process`)

Fix: close other BaseX clients/processes and rerun.
