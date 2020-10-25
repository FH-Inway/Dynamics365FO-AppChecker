<Modules count="{count(distinct-values(/AxModelInfo/ModelModule))}">{
for $module in distinct-values(/AxModelInfo/ModelModule)
order by count(/AxModelInfo[ModelModule=$module]) descending
return <Module><Name>{data($module)}</Name><Models count="{count(/AxModelInfo[ModelModule=$module])}">
  {
    for $model in /AxModelInfo[ModelModule=$module]
    return <Model>{data($model/DisplayName)}</Model>
  }
  </Models></Module>
}</Modules>