declare variable $classesWithObsoleteAttribute := /Class
  (: [@Name=("TaxEngineIntegrationAxContract", "AppConsistencyCheckRule", "AssetDepBookCheckPost")] :)
  [
    ./AttributeList/Attribute[@Name="SysObsolete"]
    or
    ./Method/AttributeList/Attribute[@Name="SysObsolete"]
  ];

<ObsoleteClasses count="{count($classesWithObsoleteAttribute)}">
{
  for $class in $classesWithObsoleteAttribute
  let $obsoleteAttribute := $class/AttributeList/Attribute[@Name="SysObsolete"]
  let $obsoleteReason := $obsoleteAttribute/AttributeExpression/StringAttributeLiteral/@Value
  let $obsoleteError := $obsoleteAttribute/AttributeExpression/BooleanAttributeLiteral/@Value
  let $obsoleteSince := $obsoleteAttribute/AttributeExpression/DateAttributeLiteral/@Value
  let $obsoleteMethods := $class/Method[./AttributeList/Attribute[@Name="SysObsolete"]]
  return 
    <Class>
      <Package>{data($class/@Package)}</Package>
      <Model>{data(/AxModelInfo[Id=$class/@ModelId]/DisplayName)}</Model>
      <ClassName>{data($class/@Name)}</ClassName>
      { if ($obsoleteAttribute) then (
      <ObsoleteReason>{data($obsoleteReason)}</ObsoleteReason>,
      <CompileResult>
        {if ($obsoleteError = 'true') then 'Error' else 'Warning'}
      </CompileResult>,
      <ObsoleteSince>{data($obsoleteSince)}</ObsoleteSince>)
      else ()
      }
      { if ($obsoleteMethods) then
      <ObsoleteMethods count="{count($obsoleteMethods)}">{
        for $method in $obsoleteMethods
        let $obsoleteMethodAttribute := $method/AttributeList/Attribute[@Name="SysObsolete"]
        let $obsoleteMethodReason := $obsoleteMethodAttribute/AttributeExpression/StringAttributeLiteral/@Value
        let $obsoleteMethodError := $obsoleteMethodAttribute/AttributeExpression/BooleanAttributeLiteral/@Value
        let $obsoleteMethodSince := $obsoleteMethodAttribute/AttributeExpression/DateAttributeLiteral/@Value
        return
          <Method>
            <Name>{data($method/@Name)}</Name>
            <ObsoleteReason>{data($obsoleteMethodReason)}</ObsoleteReason>
            <CompileResult>
              {if ($obsoleteMethodError = 'true') then 'Error' else 'Warning'}
            </CompileResult>
            <ObsoleteSince>{data($obsoleteMethodSince)}</ObsoleteSince>
          </Method>
      }
      </ObsoleteMethods>
      else ()  
      }
    </Class>
}
</ObsoleteClasses>