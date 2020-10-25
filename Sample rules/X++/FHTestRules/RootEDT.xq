(: Find the root EDT of the EDT given in $edtName :)

(: Recursive function to determine the name of the root EDT :)
declare function local:findRootEDTName($c, $edts)
{
  if ($c/@Extends != "") then
     (local:findRootEDTName($edts/Extend[@Name=$c/@Extends], $edts))
  else
     ($c/@Name)
};

(: Name of the EDT for which the root EDT is to be determined :)
let $edtName := "VendBank"

(: Build the EDT hierarchy. This is created to avoid having           :)
(: to pass the whole collection to the recursive method above and for :)
(: debugging convenience.                                             :)
let $edts := <Extends>
{
  for $c in /AxEdt
  return <Extend Name='{$c/Name}' Extends='{$c/Extends}'/>
}
</Extends>

(: Find the EDT with the given $edtName :)
let $edt := $edts/Extend[@Name=$edtName]
(: Get the name of the root of the $edt :)
let $rootEDTName := local:findRootEDTName($edt, $edts)
(: Return the name of the root EDT :)
return <Root Name='{$rootEDTName}' />

