xquery version "3.1";

declare variable $db external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";

declare function local:edts() as element()* {
  (
    collection(concat($db, "/", $root1)),
    collection(concat($db, "/", $root2))
  )/*[local-name() = "AxEdt"]
};

for $t in distinct-values(local:edts()/@*[local-name() = "type"])
let $docs := local:edts()[@*[local-name() = "type"] = $t]
let $docCount := count($docs)
order by $docCount descending, $t
return (
  concat("TYPE | ", $t, " | DOCS | ", $docCount),
  for $n in distinct-values(for $c in $docs/* return local-name($c))
  let $cnt := count($docs/*[local-name() = $n])
  order by $cnt descending, $n
  return concat("  ", $n, " | ", $cnt),
  "---"
)
