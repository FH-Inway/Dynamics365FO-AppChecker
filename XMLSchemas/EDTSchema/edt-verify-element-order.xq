xquery version "3.1";
(:~
  Verify that every AxEdt document in the BaseX database conforms to the
  expected element ordering established in AxEdt.1.0.xsd / AxEdt.1.1.xsd.

  Expected structure (simplified):
    Name
    DisplayLength?   \
    Extends?          > zero or more of these, in any relative order, before collections
    Label?           /
    ArrayElements         \
    Relations              > always present, always in this order
    TableReferences       /
    <type-specific optional fields>

  The script flags any AxEdt where:
    (a) ArrayElements, Relations, or TableReferences are absent, or
    (b) any element other than {Name, DisplayLength, Extends, Label}
        appears before ArrayElements, or
    (c) Relations appears before ArrayElements, or
    (d) TableReferences appears before Relations.

  For each violation, the script also reports:
    - the full ordered prefix before ArrayElements
    - the observed collection block order
    - the full ordered child sequence

  Run with a small limit for spot-checking (set $limit to a larger value
  or 0 to check all documents).
:)

declare variable $db    external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";
(: Set to 0 to check all; any positive integer caps the number of EDTs examined :)
declare variable $limit external := "20";

declare function local:edts() as element()* {
  (
    collection(concat($db, "/", $root1)),
    collection(concat($db, "/", $root2))
  )/*[local-name() = "AxEdt"]
};

(: Elements that are allowed to appear before ArrayElements :)
declare variable $local:pre-collection-allowed :=
  ("Name", "DisplayLength", "Extends", "Label");

(: Core collection block — must appear in this order :)
declare variable $local:collections :=
  ("ArrayElements", "Relations", "TableReferences");

declare function local:join-or-empty($items as xs:string*) as xs:string {
  if (exists($items)) then string-join($items, ",") else "<empty>"
};

declare function local:prefix-before-array($edt as element()) as xs:string* {
  let $children := $edt/*/local-name()
  let $arr-idx := index-of($children, "ArrayElements")[1]
  return
    if (exists($arr-idx)) then subsequence($children, 1, $arr-idx - 1) else $children
};

declare function local:collection-block($edt as element()) as xs:string* {
  for $elem in $edt/*/local-name()
  where $elem = $local:collections
  return $elem
};

declare function local:check-edt($edt as element()) as xs:string* {
  let $name     := string($edt/Name)
  let $type     := string($edt/@*[local-name() = "type"])
  let $children := $edt/*/local-name()

  (: Position of the first collection element :)
  let $arr-idx := index-of($children, "ArrayElements")[1]
  let $rel-idx := index-of($children, "Relations")[1]
  let $tab-idx := index-of($children, "TableReferences")[1]
  let $prefix-before-array := local:prefix-before-array($edt)
  let $collection-block := local:collection-block($edt)

  (: (a) Missing required collection elements :)
  let $missing :=
    for $c in $local:collections
    where not($c = $children)
    return concat("MISSING:", $c)

  (: (b) Unexpected element before ArrayElements :)
  let $bad-pre :=
    if (exists($arr-idx)) then
      for $pos in 1 to ($arr-idx - 1)
      let $elem := $children[$pos]
      where not($elem = $local:pre-collection-allowed)
      return concat("UNEXPECTED_BEFORE_ARRAYELEMENTS:", $elem, "@pos", $pos)
    else ()

  (: (c) Relations before ArrayElements :)
  let $bad-rel-order :=
    if (exists($arr-idx) and exists($rel-idx) and $rel-idx lt $arr-idx)
    then ("ORDER:Relations_before_ArrayElements")
    else ()

  (: (d) TableReferences before Relations :)
  let $bad-tab-order :=
    if (exists($rel-idx) and exists($tab-idx) and $tab-idx lt $rel-idx)
    then ("ORDER:TableReferences_before_Relations")
    else ()

  let $violations := ($missing, $bad-pre, $bad-rel-order, $bad-tab-order)

  where exists($violations)
  return
    concat(
      "EDT=", $name, " | TYPE=", $type, " | ",
      "PREFIX=", local:join-or-empty($prefix-before-array), " | ",
      "COLLECTIONS=", local:join-or-empty($collection-block), " | ",
      "CHILDREN=", local:join-or-empty($children), " | ",
      string-join($violations, "; ")
    )
};

let $edts  := local:edts()
let $sample :=
  if (xs:integer($limit) gt 0)
  then subsequence($edts, 1, xs:integer($limit))
  else $edts
let $total  := count($sample)
let $issues := for $e in $sample return local:check-edt($e)
let $prefix-elements :=
  distinct-values(
    for $e in $sample
    return local:prefix-before-array($e)[. != "Name"]
  )
let $prefix-element-summary :=
  for $elem in $prefix-elements
  let $docs :=
    for $e in $sample
    where local:prefix-before-array($e) = $elem
    return $e
  let $types := distinct-values(for $e in $docs return string($e/@*[local-name() = "type"]))
  order by count($types) descending, count($docs) descending, $elem
  return concat(
    "PREFIX_ELEMENT=", $elem,
    " | DOCS=", count($docs),
    " | TYPE_COUNT=", count($types),
    " | TYPES=", string-join($types, ",")
  )
return (
  concat("CHECKED=", $total, " | VIOLATIONS=", count($issues)),
  "PREFIX_ELEMENT_TYPE_SPREAD",
  $prefix-element-summary,
  "VIOLATIONS",
  $issues
)
