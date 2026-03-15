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
let $cnt := count($docs)
order by $cnt descending, $t
return concat($t, " | ", $cnt)
