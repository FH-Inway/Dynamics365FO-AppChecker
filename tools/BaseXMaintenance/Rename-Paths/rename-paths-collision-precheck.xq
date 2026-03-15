import module namespace db = 'http://basex.org/modules/db';
declare variable $db external := 'D365ApplicationExtended';
declare variable $sample-limit external := 200;

(: Fast precheck mode: only inspect the first N resources under AxEdt/AxEDT. :)
let $paths :=
  for $p in db:list($db)
  where matches($p, '^(AxEdt|AxEDT)/')
  order by $p
  return $p
let $paths := subsequence($paths, 1, $sample-limit)
let $mapped :=
  for $p in $paths
  let $parts := tokenize($p, '/')
  let $head := $parts[1]
  let $tail := subsequence($parts, 2)
  let $normHead := if (lower-case($head) = 'axedt') then 'AxEDT' else $head
  let $normPath := string-join(($normHead, $tail), '/')
  return <m old='{$p}' new='{$normPath}'/>
let $collisions :=
  for $newPath in distinct-values($mapped/@new)
  let $sources := $mapped[@new = $newPath]/@old
  where count($sources) > 1
  order by $newPath
  return concat($newPath, ' | ', count($sources), ' | ', string-join($sources, '; '))
let $report := if (empty($collisions)) then 'NO_COLLISIONS' else $collisions
return string-join(
  (
    concat('SAMPLED_PATHS | ', count($paths)),
    $report
  ),
  codepoints-to-string(10)
)
