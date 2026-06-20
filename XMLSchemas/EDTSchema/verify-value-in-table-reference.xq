xquery version "3.1";

(:~
  Verify that <Value> elements only appear inside AxEdtTableReference elements
  if they have the AxEdtTableReferenceFilter type.

  Returns violations where:
    - An AxEdtTableReference without AxEdtTableReferenceFilter type contains a <Value> element
:)

declare namespace i = "http://www.w3.org/2001/XMLSchema-instance";

declare variable $db external := "D365ApplicationExtended";

(: Find all AxEdtTableReference elements :)
let $all-refs := 
  (
    collection(concat($db, "/AxEDT")),
    collection(concat($db, "/AxEdt"))
  )//AxEdtTableReference

(: Find violations: refs without AxEdtTableReferenceFilter type that have a Value element :)
let $violations :=
  for $ref in $all-refs
  let $type := data($ref/@i:type)
  let $has-value := exists($ref/Value)
  where $has-value and (not($type) or $type != "AxEdtTableReferenceFilter")
  return $ref

(: Generate report :)
return (
  concat("TOTAL_TABLE_REFERENCES=", count($all-refs)),
  concat("VIOLATIONS_FOUND=", count($violations)),
  if (count($violations) > 0) then (
    "VIOLATION_DETAILS",
    for $violation at $i in $violations
    let $edt-name := normalize-space($violation/ancestor::*[contains(local-name(), 'AxEdt')][1]/Name[1])
    let $type := data($violation/@i:type)
    let $value := normalize-space($violation/Value)
    let $table := normalize-space($violation/Table)
    let $field := normalize-space($violation/RelatedField)
    return concat(
      "  #", $i,
      " | EDT=", $edt-name,
      " | TYPE=", (if ($type) then $type else "[no type]"),
      " | TABLE=", $table,
      " | FIELD=", $field,
      " | VALUE=", $value
    )
  ) else
    "NO_VIOLATIONS: All Value elements appear only in AxEdtTableReferenceFilter references"
)
