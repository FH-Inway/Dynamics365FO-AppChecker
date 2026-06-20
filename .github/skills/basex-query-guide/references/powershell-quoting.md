# PowerShell Quoting and Output Handling for BaseX

## Goals

Reliable command execution and result extraction for BaseX in Windows PowerShell.

## Quoting Rules

- For inline XQuery containing `$` variables, use single-quoted outer command strings.
- Inside those strings, escape literal single quotes as doubled single quotes.
- If quoting becomes complex, move logic into a `.xq` file and use `-b` bindings.

Example:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; count(db:list(''D365ApplicationExtended''))'
```

## External Variable Bindings

Use bare `key=value` tokens with `-b`; do not wrap the entire token in single quotes.

```powershell
# Incorrect: binding may be ignored
basex -b 'limit=500' '.\file.xq'

# Correct
basex -b limit=500 '.\file.xq'
```

If a script declares a default external variable, you can omit `-b` to use that default.

## Robust Output Patterns

### A) Scalar Count with Label

```powershell
$count = basex -q 'import module namespace db = ''http://basex.org/modules/db''; count(for $p in db:list(''D365ApplicationExtended'') where starts-with($p, ''AxEDT/'') return $p)'
Write-Host "AXEDT_PATHS=$count"
```

### B) Label Output in XQuery

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; concat(''AXEDT_PATHS | '', count(for $p in db:list(''D365ApplicationExtended'') where starts-with($p, ''AxEDT/'') return $p))'
```

### C) Capture Report Lines and Filter

```powershell
$lines = basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $c in distinct-values(for $x in $p return tokenize($x, ''/'')[1]) let $n := count($p[starts-with(., concat($c, ''/''))]) order by $n descending return concat($c, '' | '', $n)'
$axedt = $lines | Where-Object { $_ -like 'AxEDT | *' }
Write-Host $axedt
```

### D) Persist Long Output to File

```powershell
$lines = basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $r in subsequence(for $x in db:list-details(''D365ApplicationExtended'') order by xs:integer($x/@size) descending return $x, 1, 20) return concat($r/text(), '' | '', $r/@size)'
Set-Content -Path .\largest-resources.txt -Value $lines -Encoding UTF8
Get-Content .\largest-resources.txt
```

### E) Extract Specific INFO DB Fields

```powershell
$info = basex -c "OPEN D365ApplicationExtended; INFO DB"
($info | Select-String '^ DOCUMENTS:').Line
($info | Select-String '^ SIZE:').Line
```

## Critical Pipeline Rule (`2>&1`)

When piping `.xq` script output through PowerShell cmdlets, merge stderr into stdout first.

```powershell
# Avoid: can produce empty output in some terminal configurations
basex '.\XMLSchemas\EDTSchema\edt-verify-order-conflicts.xq' | Select-Object -First 20

# Correct
basex '.\XMLSchemas\EDTSchema\edt-verify-order-conflicts.xq' 2>&1 | Select-Object -First 20
```

Capturing first is also safe:

```powershell
$out = basex '.\XMLSchemas\EDTSchema\edt-verify-order-conflicts.xq' 2>&1
$out | Select-Object -First 20
```

## Troubleshooting

- Parser errors in PowerShell: move query to `.xq` and pass `-b` variables.
- Empty output after piping: ensure `2>&1` is present before the pipe.
- `-b` override ineffective: remove single quotes around `key=value`.
