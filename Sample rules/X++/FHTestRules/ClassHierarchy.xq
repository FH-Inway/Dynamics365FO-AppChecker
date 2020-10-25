(: Copyright (c) Microsoft Corporation.
   Licensed under the MIT license. :)

(: List of classes that extend SysAttribute :)
(: @Category Informational :)
(: @Language Xpp :)

declare function local:f($c, $classes)
{
  if ($c/@Extends != "") then
     ($c/@Extends, local:f($classes/Extend[@Name=$c/@Extends], $classes))
  else
     ()
};

  declare function local:getChildClasses($childClasses, $classes)
  {
    if ($childClasses != ())
    then (
      for $childClass in $childClasses/Extend
      return ($childClass, local:getChildClasses($classes/Extend[@Extends=$childClass/@Name], $classes))
    )
    else ()
  };

  let $baseClassName := 'RunBaseBatch'
  
(: Build the extension hierarchy document. This is created to avoid having   :)
(: to pass the whole collection to the recursive method above and for        :)
(: debugging convenience.                                                    :)
let $classes := <Extends>
{
  for $c in /Class
  return <Extend Name='{$c/@Name}' Extends='{$c/@Extends}'/>
}
</Extends>

  return local:getChildClasses($classes/Extend[@Extends=$baseClassName], $classes)
  