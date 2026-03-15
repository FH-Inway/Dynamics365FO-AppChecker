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

for $n in distinct-values(for $c in local:edts()/* return local-name($c))
let $cnt := count(local:edts()/*[local-name() = $n])
order by $cnt descending, $n
return concat($n, " | ", $cnt)
