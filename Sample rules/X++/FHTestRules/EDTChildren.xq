(: Output the hierarchy of the given root EDT :)

(: Name of the root EDT :)
let $rootEDTName := "BankAccountID"

(: Build the EDT hierarchy. This is created to avoid having           :)
(: to pass the whole collection to the recursive method above and for :)
(: debugging convenience.                                             :)
let $edts := <Extends>
{
  for $c in /AxEdt[Extends!=""]
  return <Extend Name='{$c/Name}' Extends='{$c/Extends}'/>
}
</Extends>

(: Create list of children of root EDT (the first generation) :)
let $Gen1 := <Gen1>{$edts/Extend[@Extends=$rootEDTName]}</Gen1>

(: Create lists of generations 2 to 7.                             :)
(: There are no EDTs that have more than 7 generations of children :)
let $Gen2 := <Gen2>
{
  for $c in $Gen1/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen2>

let $Gen3 := <Gen3>
{
  for $c in $Gen2/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen3>

let $Gen4 := <Gen4>
{
  for $c in $Gen3/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen4>


let $Gen5 := <Gen5>
{
  for $c in $Gen4/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen5>

let $Gen6 := <Gen6>
{
  for $c in $Gen5/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen6>

let $Gen7 := <Gen7>
{
  for $c in $Gen6/Extend
  return $edts/Extend[@Extends=$c/@Name]
}
</Gen7>

(: Combine lists of generations :)
let $list := (
  $Gen1/Extend, 
  $Gen2/Extend, 
  $Gen3/Extend, 
  $Gen4/Extend, 
  $Gen5/Extend, 
  $Gen6/Extend, 
  $Gen7/Extend
)

(: Output all generations :)
for $c in $list
return $c