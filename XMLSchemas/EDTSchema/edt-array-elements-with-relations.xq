xquery version "3.1";

(:~
  Find EDTs that have ArrayElements where at least one AxEdtArrayElement
  contains a non-empty Relations or TableReferences child element.

  Behavior:
    - Reads EDT documents from both AxEDT and AxEdt roots.
    - For each matching EDT, reports the EDT name and, for each qualifying
      AxEdtArrayElement, its index/name and which element(s) are non-empty.
:)

declare variable $db external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";

declare function local:edts() as element()* {
  (
    collection(concat($db, "/", $root1)),
    collection(concat($db, "/", $root2))
  )/*[local-name() = "AxEdt"]
};

for $edt in local:edts()
let $matching-array-elements :=
  $edt/ArrayElements/AxEdtArrayElement[
    Relations/* or TableReferences/*
  ]
where exists($matching-array-elements)
let $edt-name := string($edt/Name)
order by $edt-name
return (
  concat("EDT=", $edt-name),
  for $ae in $matching-array-elements
  let $ae-name  := string($ae/Name)
  let $ae-index := string($ae/Index)
  let $has-relations        := exists($ae/Relations/*)
  let $has-table-references := exists($ae/TableReferences/*)
  return concat(
    "  ARRAY_ELEMENT=", $ae-name,
    " | INDEX=", $ae-index,
    " | HAS_RELATIONS=", $has-relations,
    " | HAS_TABLE_REFERENCES=", $has-table-references
  )
)
