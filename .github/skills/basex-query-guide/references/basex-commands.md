# BaseX Command Cookbook

## Scope

Operational BaseX CLI commands for D365 FO metadata databases (for example `D365ApplicationExtended`).

## Prerequisites

- BaseX CLI is available as `basex`.
- Target database exists.
- In this environment, prefer `db:list(...)` and `collection(...)` patterns.

## 1) Database Metadata

Quick health and size snapshot:

```powershell
basex -c "OPEN D365ApplicationExtended; INFO DB"
```

Useful fields:

- `SIZE`
- `DOCUMENTS`
- `NODES`
- `UPTODATE`
- index flags such as `TEXTINDEX`, `ATTRINDEX`

## 2) Sample Resource Paths

List an initial sample before expensive scans:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $p in subsequence(db:list(''D365ApplicationExtended''), 1, 40) return $p'
```

## 3) Count by Top-Level Object Type

Groups by first path segment (`Classes`, `Tables`, `AxEDT`, ...):

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $c in distinct-values(for $x in $p return tokenize($x, ''/'')[1]) let $n := count($p[starts-with(., concat($c, ''/''))]) order by $n descending return concat($c, '' | '', $n)'
```

## 4) Case-Normalized Type Counts

Treat case variants as one category:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') let $cats := for $x in $p return tokenize($x, ''/'')[1] for $k in distinct-values(for $c in $cats return lower-case($c)) let $n := count($cats[lower-case(.) = $k]) order by $n descending return concat($k, '' | '', $n)'
```

Force canonical name `AxEDT`:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; let $p := db:list(''D365ApplicationExtended'') for $x in $p let $raw := tokenize($x, ''/'')[1] let $canon := if(lower-case($raw) = ''axedt'') then ''AxEDT'' else $raw group by $canon order by count($x) descending return concat($canon, '' | '', count($x))'
```

## 5) Count Only EDT Paths

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; count(for $p in db:list(''D365ApplicationExtended'') where matches($p, ''^(AxEdt|AxEDT)/'') return $p)'
```

## 6) Largest Resources by Stored Size

Use `db:list-details()` metadata:

```powershell
basex -q 'import module namespace db = ''http://basex.org/modules/db''; for $r in subsequence(for $x in db:list-details(''D365ApplicationExtended'') order by xs:integer($x/@size) descending return $x, 1, 20) return concat($r/text(), '' | '', $r/@size)'
```

## 7) Reusable `.xq` with External Bindings

```powershell
basex -bdb=D365ApplicationExtended -bsample-limit=500 ./tools/BaseXMaintenance/Rename-Paths/rename-paths-collision-precheck.xq
```

## Compatibility Notes

- `db:open(...)` is not assumed to be available in this environment.
- Rewrite incompatible examples with `db:list(...)` plus `collection(...)` or `doc(...)`.

## Troubleshooting

- Unknown function errors for `db:open(...)`: switch to `db:list(...)` traversal.
- Case-only rename issues on Windows: use two-phase rename flow.
- Lock errors (`[db:lock]`): close other BaseX clients/processes and retry.
