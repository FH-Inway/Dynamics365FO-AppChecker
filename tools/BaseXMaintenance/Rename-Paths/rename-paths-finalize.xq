import module namespace db = 'http://basex.org/modules/db';
declare variable $db external;
declare variable $offset external := 1;
declare variable $batch-size external := 500;
declare variable $temp-prefix external := '__axedt_casefix__';

for $old in subsequence(
  (
    for $p in db:list($db)
    where starts-with($p, concat($temp-prefix, '/'))
    order by $p
    return $p
  ),
  $offset,
  $batch-size
)
let $new := concat('AxEDT/', substring-after($old, concat($temp-prefix, '/')))
return db:rename($db, $old, $new)