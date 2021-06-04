let $package := 'Calendar'
let $entityFieldDataSources := /Entity[@Package=$package]/Metadata/Fields/AxDataEntityViewField/DataSource
let $tableFieldEDTs := /Table/Metadata/Fields/AxTableField/ExtendedDataType

for $datasource in $entityFieldDataSources
let $table := $entityFieldDataSources/(following::AxQuerySimpleRootDataSource, following::AxQuerySimpleEmbeddedDataSource)[Name=$datasource]/Table
let $tableFieldEDT := $tableFieldEDTs[ancestor::Table/@Name=$table and ancestor::AxTableField/Name=$datasource/parent::AxDataEntityViewField/DataField]

return $tableFieldEDT