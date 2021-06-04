let $package := 'Calendar'
let $entityFieldDataSources := /Entity[@Package=$package]/Metadata/Fields/AxDataEntityViewField/DataSource
let $tableFieldEDTs := /Table/Metadata/Fields/AxTableField/ExtendedDataType

for $datasource in $entityFieldDataSources
let $table := $entityFieldDataSources/(following::AxQuerySimpleRootDataSource, following::AxQuerySimpleEmbeddedDataSource)[Name=$datasource]/Table
let $tableFieldEDT := $tableFieldEDTs[ancestor::Table/@Name=$table and ancestor::AxTableField/Name=$datasource/parent::AxDataEntityViewField/DataField]

let $entities := /Entity[@Package='Calendar'] (: [@Name=('ProjInvoiceProposalHourEntity', 'ProjInvoiceProposalExpenseEntity')] :)
(: let $entities := (/Entity[@Package='ApplicationSuite'])[position() = (301 to 1500)] :)
for $entity in $entities
let $entityFields := $entity/Metadata/Fields/AxDataEntityViewField

for $entityField in $entityFields
let $datasource := $entityField/DataSource
let $table := $entity/Metadata/ViewMetadata/DataSources//(AxQuerySimpleRootDataSource, AxQuerySimpleEmbeddedDataSource)[Name=$datasource]/Table
let $tableFieldEDT := $tableFieldEDTs[ancestor::Table/@Name=$table and ancestor::AxTableField/Name=$entityField/DataField]
(: let $tableFieldEDT := /Table[@Name=$table]/Metadata/Fields/AxTableField[Name=$entityField/DataField]/ExtendedDataType :)
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