(: Copyright (c) Microsoft Corporation.
   Licensed under the MIT license. :)

(: Provide interesting metrics for the system. :)
(: @Category Informational :)
(: @Language Xpp :)

<OverallMetrics Category='Informational' href='docs.microsoft.com/Socratex/OverallMetrics' Version='1.0'>
    <Models>{count(/AxModelInfo)}</Models>    
    <Classes Count='{count(/Class)}'   Methods='{count(/Class/Method)}'   Lines='{sum(/Class/@EndLine)}'/>
    <Tables Count='{count(/Table)}'    Methods='{count(/Table//Method)}'  Lines='{sum(/Table/Method/(@EndLine - @StartLine + 1))}'/>
    <Queries Count='{count(/Query)}'   Methods='{count(/Query//Method)}'  Lines='{sum(/Query//Method/(@EndLine - @StartLine + 1))}'/>
    <Forms Count='{count(/Form)}'      Methods='{count(/Form//Method)}'   Lines='{sum(/Form//Method/(@EndLine - @StartLine + 1))}'/>
    <Entities Count='{count(/Entity)}' Methods='{count(/Entity//Method)}' Lines='{sum(/Entity//Method/(@EndLine - @StartLine + 1))}' />
    {for $model in /AxModelInfo
    return <Model Name="{$model/DisplayName}" Package='{$model/ModelModule}'>
      <Classes Count='{count(/Class[@ModelId=$model/Id])}'   Methods='{count(/Class[@ModelId=$model/Id]/Method)}'   Lines='{sum(/Class[@ModelId=$model/Id]/@EndLine)}'/>
      <Tables Count='{count(/Table[@ModelId=$model/Id])}'    Methods='{count(/Table[@ModelId=$model/Id]//Method)}'  Lines='{sum(/Table[@ModelId=$model/Id]/Method/(@EndLine - @StartLine + 1))}'/>
      <Queries Count='{count(/Query[@ModelId=$model/Id])}'   Methods='{count(/Query[@ModelId=$model/Id]//Method)}'  Lines='{sum(/Query[@ModelId=$model/Id]//Method/(@EndLine - @StartLine + 1))}'/>
      <Forms Count='{count(/Form[@ModelId=$model/Id])}'      Methods='{count(/Form[@ModelId=$model/Id]//Method)}'   Lines='{sum(/Form[@ModelId=$model/Id]//Method/(@EndLine - @StartLine + 1))}'/>
      <Entities Count='{count(/Entity[@ModelId=$model/Id])}' Methods='{count(/Entity[@ModelId=$model/Id]//Method)}' Lines='{sum(/Entity[@ModelId=$model/Id]//Method/(@EndLine - @StartLine + 1))}' />
    </Model>}
</OverallMetrics>