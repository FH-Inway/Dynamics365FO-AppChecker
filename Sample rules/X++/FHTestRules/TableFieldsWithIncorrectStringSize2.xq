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
  for $table in /Table[@Package="ApplicationFoundation"]
  for $field in $table/Metadata/Fields/AxTableField[StringSize]
  let $edt := $edts/Extend[@Name=$field/ExtendedDataType]
  let $rootEDTName := local:findRootEDTName($edt)
  let $rootEDT := /AxEdt[Name=$rootEDTName]
  where $field/StringSize != $rootEDT/StringSize
  return 
    <Field>
      <Package>{data($table/@Package)}</Package>
      <Model>{data(/AxModelInfo[Id=$table/@ModelId]/DisplayName)}</Model>
      <Table>{data($table/@Name)}</Table>
      <Name>{data($field/Name)}</Name>
      <ExtendedDataType>{data($field/ExtendedDataType)}</ExtendedDataType>
      <FieldStringSize>{data($field/StringSize)}</FieldStringSize>
      <RootEDT>{data($rootEDT/Name)}</RootEDT>
      <EDTStringSize>{data($rootEDT/StringSize)}</EDTStringSize>
    </Field>
}</TableFieldsWithIncorrectStringSize>;

$tables