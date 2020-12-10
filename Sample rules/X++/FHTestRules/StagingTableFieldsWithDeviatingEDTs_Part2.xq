declare variable $deviatingEDTs := doc("C:\Temp\StagingTableFieldsWithDeviatingEDTs.xml");
declare variable $edtsFull := /AxEdt;

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

let $fields := <StagingTableFieldsWithIncorrectStringSize> {
let $edtPairs2Check := ($deviatingEDTs/StagingTableFieldsWithIncorrectStringSize/StagingTableFieldWithIncorrectStringSize)
  [position() = (1 to last())]
  (: [Entity = ('ProjInvoiceProposalExpenseEntity', 'ProjInvoiceProposalHourEntity')] :)

for $edtPair in $edtPairs2Check
let $targetTableFieldEDT := $edts/Extend[@Name = $edtPair/TargetTableFieldEDT]
let $targetTableFieldRootEDTName := local:findRootEDTName($targetTableFieldEDT)
let $targetTableFieldRootEDT := $edtsFull[Name = $targetTableFieldRootEDTName]

let $stagingTableFieldEDT := $edts/Extend[@Name = $edtPair/StagingTableFieldEDT]
let $stagingTableFieldRootEDTName := local:findRootEDTName($stagingTableFieldEDT)
let $stagingTableFieldRootEDT := $edtsFull[Name = $stagingTableFieldRootEDTName]

where $targetTableFieldRootEDT/StringSize != $stagingTableFieldRootEDT/StringSize
return <StagingTableFieldWithIncorrectStringSize>
  <Package>{data($edtPair/Package)}</Package>
  <Model>{data($edtPair/Model)}</Model>
  <Entity>{data($edtPair/Entity)}</Entity>
  <EntityFieldName>{data($edtPair/EntityFieldName)}</EntityFieldName>
  <TargetTableName>{data($edtPair//TargetTableName)}</TargetTableName>
  <TargetTableFieldName>{data($edtPair/TargetTableFieldName)}</TargetTableFieldName>
  <TargetTableFieldEDT>{data($edtPair/TargetTableFieldEDT)}</TargetTableFieldEDT>
  <TargetTableFieldEDTStringSize>{data($targetTableFieldRootEDT/StringSize)}</TargetTableFieldEDTStringSize>
  <StagingTableName>{data($edtPair/StagingTableName)}</StagingTableName>
  <StagingTableFieldEDT>{data($edtPair/StagingTableFieldEDT)}</StagingTableFieldEDT>
  <StagingTableFieldEDTStringSize>{data($stagingTableFieldRootEDT/StringSize)}</StagingTableFieldEDTStringSize>
</StagingTableFieldWithIncorrectStringSize>

}</StagingTableFieldsWithIncorrectStringSize>

return $fields