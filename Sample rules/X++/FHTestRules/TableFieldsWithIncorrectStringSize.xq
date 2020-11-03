(: Build the EDT hierarchy. This is created to avoid having           :)
(: to pass the whole collection to the recursive method above and for :)
(: debugging convenience.                                             :)
declare variable $edts := <Extends>{
  for $c in /AxEdt
  return <Extend Name='{$c/Name}' Extends='{$c/Extends}' />
}</Extends>;

(: Recursive function to determine the name of the root EDT :)
declare function local:findRootEDTName($c)
{
  if ($c/@Extends != "") then
     (local:findRootEDTName($edts/Extend[@Name=$c/@Extends]))
  else
     ($c/@Name)
};

declare variable $tables := <TableFieldsWithIncorrectStringSize>{
  for $table in /Table[@Artifact=("table:InventQualityOrderTable","table:AbbreviationsStaging")]
  return 
    <Table>
      <Package>{data($table/@Package)}</Package>
      <Model>{data($table/@ModelId)}</Model>
      <TableName>{data($table/@Name)}</TableName>
      {
        for $field in $table/Metadata/Fields/AxTableField[StringSize]
        return 
          <Fields>
            <FieldName>{data($field/Name)}</FieldName>
            <ExtendedDataType>{data($field/ExtendedDataType)}</ExtendedDataType>
            <FieldStringSize>{data($field/StringSize)}</FieldStringSize>
            <EDTStringSize>{
              let $edt := $edts/Extend[@Name=$field/ExtendedDataType]
              let $rootEDTName := local:findRootEDTName($edt)
              return data(/AxEdt[Name=$rootEDTName]/StringSize)
            }</EDTStringSize>
          </Fields>
      }
    </Table>
}</TableFieldsWithIncorrectStringSize>;

for $table in $tables/Table[./Fields/FieldStringSize != ./Fields/EDTStringSize]
return $table