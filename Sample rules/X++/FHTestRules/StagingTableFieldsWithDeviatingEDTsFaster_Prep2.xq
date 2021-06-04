let $tableFieldEDTs := /Table/Metadata/Fields/AxTableField/ExtendedDataType
return $tableFieldEDTs[ancestor::AxTableField/Name="ItemId" and ancestor::Table/@Name="InventTable"]