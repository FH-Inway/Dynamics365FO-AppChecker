xquery version "3.1";
(:~
  Find pairs of EDTs whose pre-collection prefix sequences are mutually
  incompatible: EDT A has field X before field Y, EDT B has field Y before
  field X.  A strict sequence in the schema cannot satisfy both at once.

  Reports, for each conflicting field pair:
  - the pair (X, Y)
  - one EDT where X precedes Y
  - one EDT where Y precedes X

  Set $limit to 0 to scan the full database.
:)

declare variable $db    external := "D365ApplicationExtended";
declare variable $root1 external := "AxEDT";
declare variable $root2 external := "AxEdt";
declare variable $limit external := "0";

(: Fields known to appear before the ArrayElements collection block :)
declare variable $local:pre-fields :=
  ("DisplayLength","Extends","Label","ConfigurationKey","CountryRegionCodes",
   "HelpText","ReferenceTable","ButtonImage","IsObsolete","EnforceHierarchy",
   "FormHelp","Alignment");

declare function local:edts() as element()* {
  (
    collection(concat($db, "/", $root1)),
    collection(concat($db, "/", $root2))
  )/*[local-name() = "AxEdt"]
};

(: Returns the pre-collection prefix element names in document order :)
declare function local:prefix($edt as element()) as xs:string* {
  let $children := $edt/*/local-name()
  let $arr-idx  := index-of($children, "ArrayElements")[1]
  return
    if (exists($arr-idx)) then
      subsequence($children, 1, $arr-idx - 1)[. = $local:pre-fields]
    else ()
};

let $all  := local:edts()
let $sample :=
  if (xs:integer($limit) gt 0)
  then subsequence($all, 1, xs:integer($limit))
  else $all

(: Build a flat list of (edt-name, field-a, field-b) for every ordered pair
   of pre-collection fields that co-occur in the same prefix :)
let $pairs :=
  for $e in $sample
  let $name   := string($e/Name)
  let $prefix := local:prefix($e)
  where count($prefix) ge 2
  for $i in 1 to (count($prefix) - 1)
  for $j in ($i + 1) to count($prefix)
  return map {
    "edt"  : $name,
    "first": $prefix[$i],
    "second": $prefix[$j]
  }

(: For each (field-a, field-b) canonical pair (alphabetic), find whether
   both orderings are observed :)
let $canonical-pairs :=
  distinct-values(
    for $p in $pairs
    let $a := $p("first")
    let $b := $p("second")
    return
      if ($a lt $b) then concat($a, "|", $b)
      else concat($b, "|", $a)
  )

for $cp in $canonical-pairs
let $parts := tokenize($cp, "\|")
let $fa := $parts[1]
let $fb := $parts[2]

(: EDTs where $fa appears before $fb in the prefix :)
let $fa-first :=
  for $p in $pairs
  where $p("first") = $fa and $p("second") = $fb
  return $p("edt")

(: EDTs where $fb appears before $fa in the prefix :)
let $fb-first :=
  for $p in $pairs
  where $p("first") = $fb and $p("second") = $fa
  return $p("edt")

where exists($fa-first) and exists($fb-first)
order by count($fa-first) + count($fb-first) descending
return concat(
  "FIELD_PAIR=(", $fa, ",", $fb, ")",
  " | ", $fa, "_FIRST_EXAMPLE=", $fa-first[1],
  " | ", $fb, "_FIRST_EXAMPLE=", $fb-first[1],
  " | ", $fa, "_FIRST_COUNT=", count($fa-first),
  " | ", $fb, "_FIRST_COUNT=", count($fb-first)
)
