declare variable $package := 'Calendar';
let $entityFieldDataSources := /Entity[@Package=$package]/Metadata/Fields/AxDataEntityViewField/DataSource
return $entityFieldDataSources/(following::AxQuerySimpleRootDataSource, following::AxQuerySimpleEmbeddedDataSource)