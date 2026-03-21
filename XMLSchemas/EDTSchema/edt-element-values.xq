xquery version "3.1";

declare variable $db external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";
declare variable $element external := "TimeSeconds";

declare function local:edts() as element()* {
  (
    collection(concat($db, "/", $root1)),
    collection(concat($db, "/", $root2))
  )/*[local-name() = "AxEdt"]
};

declare function local:value-key($node as element()) as xs:string {
  let $value := normalize-space(string($node))
  return if ($value = "") then "[empty]" else $value
};

let $matches := local:edts()/*[local-name() = $element]
return (
  concat("ELEMENT=", $element),
  concat("TOTAL_OCCURRENCES=", count($matches)),
  for $value in distinct-values(for $match in $matches return local:value-key($match))
  let $count := count($matches[local:value-key(.) = $value])
  order by $count descending, $value
  return concat($value, " | ", $count)
)