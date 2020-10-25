(: Copyright (c) Microsoft Corporation.
   Licensed under the MIT license. :)

(: Create the sequence of inherited classes up the tree from the given class :)
(: The classes arg is the document that describes the inheritance hierarchy. :)
(: @Category Informational :)
(: @Language Xpp :)

declare function local:f($c, $classes)
{
  if ($c/@Extends != "") then
     ($c/@Extends, local:f($classes/Extend[@Name=$c/@Extends], $classes))
  else
     ()
};

(: Build the extension hierarchy document. This is created to avoid having   :)
(: to pass the whole collection to the recursive method above and for        :)
(: debugging convenience.                                                    :)
let $classes := <Extends>
{
  for $c in /Class
  return <Extend Name='{$c/@Name}' Extends='{$c/@Extends}'/>
}
</Extends>

(: Create the document where each class has the classes it inherites from as :)
(: subnodes. This document is useful in itself, for generating diagrams etc. :)
  for $c in $classes/Extend
     return <Result Name='{$c/@Name}'>
     {
       let $list := local:f($c, $classes)
       for $le in $list
       return <Inherits Name='{$le}' />
   } </Result>

