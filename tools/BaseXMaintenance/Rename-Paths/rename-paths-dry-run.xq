import module namespace db = 'http://basex.org/modules/db';
declare variable $db external;
declare variable $offset external := 1;
declare variable $batch-size external := 500;

let $candidates :=
  for $p in db:list($db)
  where starts-with($p, 'AxEdt/')
  order by $p
  return $p
let $total := count($candidates)
let $batch := subsequence($candidates, $offset, $batch-size)
let $rows :=
  for $old in $batch
  let $new := concat('AxEDT/', substring-after($old, 'AxEdt/'))
  return concat($old, ' -> ', $new)
return string-join(
  (
    concat('TOTAL_AXEDT_SOURCE_PATHS | ', $total),
    concat('BATCH_OFFSET | ', $offset),
    concat('BATCH_SIZE | ', $batch-size),
    concat('BATCH_COUNT | ', count($batch)),
    if (empty($rows)) then 'NO_ROWS' else $rows
  ),
  codepoints-to-string(10)
)
