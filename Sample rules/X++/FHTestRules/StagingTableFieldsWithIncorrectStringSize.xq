let $entities := /Entity(: [@Name=('ProjInvoiceProposalHourEntity', 'ProjInvoiceProposalExpenseEntity')] :)
for $entity in $entities
let $entityFields := $entity/Metadata/Fields/AxDataEntityViewField

for $entityField in $entityFields
let $datasource := $entityField/DataSource
let $table := $entity/Metadata/ViewMetadata/DataSources//(AxQuerySimpleRootDataSource, AxQuerySimpleEmbeddedDataSource)[Name=$datasource]/Table
let $tableFieldEDT := /Table[@Name=$table]/Metadata/Fields/AxTableField[Name=$entityField/DataField]/ExtendedDataType
let $stagingTableFieldEDT := /Table[@Name=$entity/Metadata/DataManagementStagingTable]/Metadata/Fields/AxTableField[Name=$entityField/Name]/ExtendedDataType
where $tableFieldEDT != $stagingTableFieldEDT

return <StagingTableFieldWithIncorrectStringSize>
  <Package>{data($entity/@Package)}</Package>
  <Model>{data(/AxModelInfo[Id=$entity/@ModelId]/DisplayName)}</Model>
  <Entity>{data($entity/@Name)}</Entity>
  <EntityFieldName>{data($entityField/Name)}</EntityFieldName>
  <TargetTableName>{data($table)}</TargetTableName>
  <TargetTableFieldName>{data($entityField/DataField)}</TargetTableFieldName>
  <TargetTableFieldEDT>{data($tableFieldEDT)}</TargetTableFieldEDT>
  <StagingTableName>{data($entity/Metadata/DataManagementStagingTable)}</StagingTableName>
  <StagingTableFieldEDT>{data($stagingTableFieldEDT)}</StagingTableFieldEDT>
</StagingTableFieldWithIncorrectStringSize>