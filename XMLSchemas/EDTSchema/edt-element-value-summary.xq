xquery version "3.1";

(:~
  Summarize values for each direct AxEdt child element from the BaseX corpus.

  Behavior:
    - Reads EDT documents from both AxEDT and AxEdt roots.
    - Limits the number of EDTs examined via $limit (0 = all).
    - For each direct child element name:
      * if there are 10 or fewer distinct normalized string values, list each value
        with its occurrence count and one sample EDT name
      * if there are more than 10 distinct values, list only the minimum and maximum
        value observed, each with one sample EDT name

  Notes:
    - Values are based on the normalized string-value of the direct child element.
      For complex elements such as Relations or TableReferences, this means descendant
      text is collapsed into a single normalized string.
    - Min/max are lexical for general strings and numeric when all distinct values are
      decimal-castable.
:)

declare variable $db external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";
declare variable $limit external := "20";
declare variable $detail-threshold external := "10";

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

declare function local:edt-name($node as element()) as xs:string {
  let $name := normalize-space(string($node/parent::*/*[local-name() = "Name"][1]))
  return if ($name = "") then "[missing Name]" else $name
};

declare function local:sample-edt-name(
  $matches as element()*,
  $value as xs:string
) as xs:string {
  let $match := ($matches[local:value-key(.) = $value])[1]
  return if (exists($match)) then local:edt-name($match) else "[no sample]"
};

declare function local:ordered-values($values as xs:string*) as xs:string* {
  if (empty($values)) then
    ()
  else if (every $value in $values satisfies $value castable as xs:decimal) then
    for $value in $values
    order by xs:decimal($value), $value
    return $value
  else
    sort($values)
};

declare function local:render-element-summary(
  $name as xs:string,
  $matches as element()*
) as xs:string* {
  let $values := for $match in $matches return local:value-key($match)
  let $distinct-values := distinct-values($values)
  let $ordered-values := local:ordered-values($distinct-values)
  let $distinct-count := count($distinct-values)
  let $threshold := xs:integer($detail-threshold)
  return (
    concat(
      "ELEMENT=", $name,
      " | OCCURRENCES=", count($matches),
      " | DISTINCT_VALUES=", $distinct-count
    ),
    if ($distinct-count le $threshold) then
      for $value in $ordered-values
      let $count := count($values[. = $value])
      let $sample-edt := local:sample-edt-name($matches, $value)
      return concat(
        "  VALUE=", $value,
        " | COUNT=", $count,
        " | SAMPLE_EDT=", $sample-edt
      )
    else
      let $min-value := $ordered-values[1]
      let $max-value := $ordered-values[last()]
      return concat(
        "  MIN=", $min-value,
        " | MIN_SAMPLE_EDT=", local:sample-edt-name($matches, $min-value),
        " | MAX=", $max-value,
        " | MAX_SAMPLE_EDT=", local:sample-edt-name($matches, $max-value)
      )
  )
};

let $edts := local:edts()
let $sample :=
  if (xs:integer($limit) gt 0)
  then subsequence($edts, 1, xs:integer($limit))
  else $edts
let $element-names :=
  distinct-values(
    for $edt in $sample
    return $edt/*/local-name()
  )
let $ordered-element-names := sort($element-names)
return (
  concat("CHECKED_EDTS=", count($sample)),
  concat("DETAIL_THRESHOLD=", $detail-threshold),
  concat("ELEMENTS_FOUND=", count($ordered-element-names)),
  "ELEMENT_VALUE_SUMMARY",
  for $name in $ordered-element-names
  let $matches :=
    for $edt in $sample
    return $edt/*[local-name() = $name]
  return local:render-element-summary($name, $matches)
)