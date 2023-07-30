declare namespace wsdl="http://schemas.xmlsoap.org/wsdl/";

let $typespec := <typespec>
import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/http";

using TypeSpec.Http;

@service(&#123;
  title: "Microsoft Dynamics 365 Finance and Operations Custom Services API",
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
@tag("/{$service/@name/string()}")
namespace {$service/@name/string()} &#123;

  {
    for $portType in $portTypes
    return <namespace>
  
  @route("/{$portType/@name/string()}")  
  namespace {$portType/@name/string()} &#123;
  
    {
      for $operation in $portType/wsdl:operation
      return <operation>
    
    @route("/{$operation/@name/string()}")
    @get 
    op {$operation/@name/string()}(
      
      {
        let $input := $operation/wsdl:input
        let $messageName := substring-after($input/@message/string(), ":")
        let $message := //wsdl:message[@name=$messageName]
        let $inputParameterName := substring-after($message/wsdl:part/@element/string(), ":")
        for $parameter in //wsdl:types//xs:element[@name=$inputParameterName]//xs:element/@type/string()
        let $parameterName := substring-after($parameter, ":")
        return <parameter>
        
        test {$parameterName}
        
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

return file:write-text("C:\Temp\Typespec.tsp", $typespec)