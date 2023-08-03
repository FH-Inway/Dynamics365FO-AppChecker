declare namespace wsdl="http://schemas.xmlsoap.org/wsdl/";

let $datatypeMapping := 
  <DataTypeMapping>
    <DataType wsdl="xs:long" typespec="int64" />
    <DataType wsdl="xs:int" typespec="int32" />
    <DataType wsdl="xs:short" typespec="int16" />
    <DataType wsdl="xs:byte" typespec="int8" />
    <DataType wsdl="xs:decimal" typespec="decimal" />
    <DataType wsdl="xs:float" typespec="float32" />
    <DataType wsdl="xs:double" typespec="float64" />
    <DataType wsdl="xs:boolean" typespec="boolean" />
    <DataType wsdl="xs:string" typespec="string" />
    <DataType wsdl="xs:dateTime" typespec="utcDateTime" />
  </DataTypeMapping>

let $models := <models>
  model test &#123;&#125;
</models>

let $typespec := <typespec>

import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/http";

import "./models.tsp";

using TypeSpec.Http;

@service(&#123;
  title: "Microsoft Dynamics 365 Finance and Operations Custom Services API3",
  version: "0.0.1.20230730",
&#125;)
@server(
  "https://usnconeboxax1aos.cloud.onebox.dynamics.com/api/services",
  "Microsoft Dynamics 365 Finance and Operations Local OneBox Environment",
)
namespace Microsoft.Dynamics.Services;

{
  let $service := //wsdl:service
  let $portTypes := //wsdl:portType
  return <namespace>
  
@route("/{$service/@name/string()}")
//@tag("/{$service/@name/string()}")
namespace {$service/@name/string()} &#123;

  {
    for $portType in $portTypes
    return <namespace>
  
  @route("/{$portType/@name/string()}")
  @tag("/{$portType/@name/string()}")
  namespace {$portType/@name/string()} &#123;
  
    {
      for $operation in $portType/wsdl:operation
      return <operation>
    
    @route("/{$operation/@name/string()}")
    @post 
    op {$operation/@name/string()}(
      
      {
        let $input := $operation/wsdl:input
        let $messageName := substring-after($input/@message/string(), ":")
        let $message := //wsdl:message[@name=$messageName]
        let $inputParameterName := substring-after($message/wsdl:part/@element/string(), ":")
        for $parameter in //wsdl:types//xs:element[@name=$inputParameterName]//xs:element
        let $parameterName := $parameter/@name/string()
        let $parameterType := $datatypeMapping/DataType[@wsdl = $parameter/@type]/@typespec/string()
        (:TODO determine parameter type for complex types > need to create models first:)
        return 
      <parameter>{$parameterName}: {if (empty($parameterType)) then "unknown" else $parameterType},
      </parameter>
      }
      
    ): void;
    
      </operation>      
    }
  
  &#125;
  
    </namespace>
  }

&#125;

  </namespace>
  
}

</typespec>

let $docs := ([$models, "models.tsp"], [$typespec, "main.tsp"])
for $doc in $docs

return file:write-text("C:\Repositories\GitHub\FH-Inway\Dynamics365FO-AppChecker\Sample rules\X++\FHTypespec Extractors/" || $doc(2), $doc(1))