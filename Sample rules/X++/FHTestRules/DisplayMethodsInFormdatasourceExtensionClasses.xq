declare variable $classes := /Class
  [
    ./AttributeList/Attribute[lower-case(@Name)="extensionof"]
    and
    ./AttributeList/Attribute/AttributeExpression/IntrinsicAttributeLiteral[lower-case(@FunctionName)="formdatasourcestr"]
    and
    ./Method[lower-case(@IsDisplay)="true"]
  ];

<Classes count="{count($classes)}" >
{
  for $class in $classes
  return 
    <Class>
      <Package>{data($class/@Package)}</Package>
      <Model>{data(/AxModelInfo[Id=$class/@ModelId]/DisplayName)}</Model>
      <ClassName>{data($class/@Name)}</ClassName>
    </Class>
}
</Classes>
