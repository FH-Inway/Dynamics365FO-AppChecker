xquery version "3.1";

(:~
  Summarize attributes used anywhere inside AxEdt documents from the BaseX corpus.

  Behavior:
    - Reads EDT documents from both AxEDT and AxEdt roots.
    - Limits the number of EDTs examined via $limit (0 = all).
    - Groups attributes by parent element local name plus expanded attribute name.
    - For each attribute group:
      * if there are 10 or fewer distinct normalized values, list each value
        with its occurrence count and one sample EDT name
      * if there are more than 10 distinct values, list only the minimum and maximum
        value observed, each with one sample EDT name

  Notes:
    - Attribute names are rendered as local names when no namespace is present,
      else as {namespace-uri}local-name.
    - Values are normalized with normalize-space() for consistency with the
      scalar element summary reports.
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

declare function local:attribute-name-key($attr as attribute()) as xs:string {
  let $ns := namespace-uri($attr)
  let $local := local-name($attr)
  return if ($ns = "") then $local else concat("{", $ns, "}", $local)
};

declare function local:attribute-value-key($attr as attribute()) as xs:string {
  let $value := normalize-space(string($attr))
  return if ($value = "") then "[empty]" else $value
};

declare function local:edt-name($node as node()) as xs:string {
  let $name := normalize-space(string($node/ancestor-or-self::*[local-name() = "AxEdt"][1]/*[local-name() = "Name"][1]))
  return if ($name = "") then "[missing Name]" else $name
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

declare function local:sample-edt-name(
  $attrs as attribute()*,
  $value as xs:string
) as xs:string {
  let $attr := ($attrs[local:attribute-value-key(.) = $value])[1]
  return if (exists($attr)) then local:edt-name($attr) else "[no sample]"
};

declare function local:render-attribute-summary(
  $parent-name as xs:string,
  $attribute-name as xs:string,
  $attrs as attribute()*
) as xs:string* {
  let $values := for $attr in $attrs return local:attribute-value-key($attr)
  let $distinct-values := distinct-values($values)
  let $ordered-values := local:ordered-values($distinct-values)
  let $distinct-count := count($distinct-values)
  let $threshold := xs:integer($detail-threshold)
  return (
    concat(
      "ATTRIBUTE=", $attribute-name,
      " | PARENT=", $parent-name,
      " | OCCURRENCES=", count($attrs),
      " | DISTINCT_VALUES=", $distinct-count
    ),
    if ($distinct-count le $threshold) then
      for $value in $ordered-values
      let $count := count($values[. = $value])
      let $sample-edt := local:sample-edt-name($attrs, $value)
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
        " | MIN_SAMPLE_EDT=", local:sample-edt-name($attrs, $min-value),
        " | MAX=", $max-value,
        " | MAX_SAMPLE_EDT=", local:sample-edt-name($attrs, $max-value)
      )
  )
};

let $edts := local:edts()
let $sample :=
  if (xs:integer($limit) gt 0)
  then subsequence($edts, 1, xs:integer($limit))
  else $edts
let $all-attributes := $sample//@*
let $group-keys :=
  distinct-values(
    for $attr in $all-attributes
    return concat(local-name($attr/..), "|", local:attribute-name-key($attr))
  )
let $ordered-group-keys := sort($group-keys)
return (
  concat("CHECKED_EDTS=", count($sample)),
  concat("DETAIL_THRESHOLD=", $detail-threshold),
  concat("ATTRIBUTE_GROUPS_FOUND=", count($ordered-group-keys)),
  "ATTRIBUTE_VALUE_SUMMARY",
  for $group-key in $ordered-group-keys
  let $parent-name := substring-before($group-key, "|")
  let $attribute-name := substring-after($group-key, "|")
  let $attrs :=
    for $attr in $all-attributes
    where local-name($attr/..) = $parent-name
      and local:attribute-name-key($attr) = $attribute-name
    return $attr
  return local:render-attribute-summary($parent-name, $attribute-name, $attrs)
)
