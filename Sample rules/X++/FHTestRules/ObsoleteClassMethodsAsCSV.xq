declare variable $obsoleteClassMethods := /Class
  [@Name=("TaxEngineIntegrationAxContract", "AppConsistencyCheckRule", "AssetDepBookCheckPost")]
  [./Method/AttributeList/Attribute[@Name="SysObsolete"]];
  
let $options := map { 'lax': false(), 'header': true() }
let $records := <Records>{
for $class in $obsoleteClassMethods
let $obsoleteMethods := $class/Method[./AttributeList/Attribute[@Name="SysObsolete"]]
  for $method in $obsoleteMethods
  let $methodObsoleteAttribute := $method/AttributeList/Attribute[@Name="SysObsolete"]
  let $obsoleteReason := $methodObsoleteAttribute/AttributeExpression/StringAttributeLiteral/@Value
  let $obsoleteError := $methodObsoleteAttribute/AttributeExpression/BooleanAttributeLiteral/@Value
  let $obsoleteSince := $methodObsoleteAttribute/AttributeExpression/DateAttributeLiteral/@Value
  return <Record>
    <Package>{data($class/@Package)}</Package>
    <Model>{data(/AxModelInfo[Id=$class/@ModelId]/DisplayName)}</Model>
    <ClassName>{data($class/@Name)}</ClassName>
    <MethodName>{data($method/@Name)}</MethodName>
    <ObsoleteReason>{data($obsoleteReason)}</ObsoleteReason>
    <ObsoleteError>{data($obsoleteError)}</ObsoleteError>
    <ObsoleteSince>{data($obsoleteSince)}</ObsoleteSince>
  </Record>
}</Records>

return csv:serialize($records, $options)