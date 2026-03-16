# EDT Bulk Validation Failure Analysis (2026-03-16)

## Scope
- Input CSV: edt-bulk-validation-test.csv
- Rows analyzed: 39
- Validator results:
  - XSD 1.0: 14 PASS, 25 FAIL
  - XSD 1.1: 14 PASS, 25 FAIL

## Top Failure Signatures (XSD 1.0)
- 12x invalid child element 'Extends' where 'ArrayElements' is expected
- 11x invalid child element 'Label' where 'ArrayElements' is expected
- 2x invalid child element 'DisplayLength' where 'ArrayElements' is expected

## Root Cause
The schema base type currently requires this fixed order:
1) Name
2) ArrayElements
3) Relations
4) TableReferences
5) optional base fields (Label, Extends, etc.)

Observed failing XMLs often use:
- Name, then Label/Extends, then ArrayElements/Relations/TableReferences
- In some cases, a type-specific field (for example DisplayLength) appears before base fields.

All failed files checked in this run still contain ArrayElements, Relations, and TableReferences; they are present but appear later than the schema allows.

## Implication
Current failures are primarily sequence-order failures, not missing-element failures.

## Suggested Next Change
Relax ordering constraints in AxEdt content model (both 1.0 and 1.1 schemas) so common D365FO ordering variants validate.

A strict extension-based base/derived ordering model may continue to fail if derived-type fields appear before some base fields in real metadata files.
