declare variable $distinctModules := distinct-values(/AxModelInfo/ModelModule);
<Modules count="{count($distinctModules)}">{
for $module in $distinctModules
let $moduleModels := /AxModelInfo[ModelModule=$module]
let $modelCount := count($moduleModels)
order by $modelCount descending
return <Module><Name>{data($module)}</Name><Models count="{$modelCount}">
  {
    unordered {
      for $model in $moduleModels
      return <Model>{data($model/DisplayName)}</Model>
    }
  }
  </Models></Module>
}</Modules>