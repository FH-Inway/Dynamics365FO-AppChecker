# EDT Schema Tightening Plan

## Purpose
Document a safe, incremental strategy for tightening `AxEdt.1.0.xsd` and `AxEdt.1.1.xsd` using the value distributions captured in `edt-element-value-summary.txt`.

The goal is to improve schema precision without overfitting the current corpus and creating false negatives for valid EDT metadata.

## Evidence Base
- Source report: `XMLSchemas/EDTSchema/edt-element-value-summary.txt`
- Corpus size analyzed: `23,846` EDTs
- Summary generation query: `XMLSchemas/EDTSchema/edt-element-value-summary.xq`

## Guiding Principles
1. Restrict low-cardinality closed vocabularies first.
2. Add numeric bounds only where the observed values strongly indicate intrinsic domain rules.
3. Leave high-cardinality identifiers, labels, references, and free-text fields as `xs:string` unless there is external platform evidence that they are closed sets.
4. Treat collection payloads separately from scalar EDT fields.
5. Prefer small, reversible tightening steps followed by full validation runs.

## Tightening Tiers

## Tier 1: Safe To Restrict Now
These elements have small, stable observed value sets and are the best first candidates for shared simple types.

### Existing Boolean-Like Elements
These are already modeled with `AxBooleanLikeType`. It should be investigated whether this type can be split up into more specific enums.

- `AllowNegative`
- `ShowZero`
- `TimeHours`
- `TimeMinute`
- `TimeSeconds`
- `StringSizeIsExtensible`
- `NoOfDecimalsIsExtensible`
- `IsObsolete`
- `PresenceIndicatorAllowed`
- `FormatMST`
- `RotateSign`
- `AutoInsSeparator`
- `EnforceHierarchy`

Elements were remodeled to use more specific enum types.

### Strong Enum Candidates
Add dedicated simple types for these elements and use them in both schemas.

- `Alignment`: `Center`, `Left`, `Right`
- `ChangeCase`: `LowerCase`, `None`, `UpperCase`
  - `ChangeCase` is hidden on `AxEdtString`, appears to be legacy, and should be used with care.
- `DateDay`: `Digits2`, `Digits1or2`, `None`
- `DateMonth`: `Digits2`, `Digits1or2`, `Short`, `Long`, `None`
- `DateSeparator`: `Slash_Slash`, `Slash_Dash`, `Slash_Dot`, `Slash_Space`, `Slash_None`, `Dash_Slash`, `Dash_Dash`, `Dash_Dot`, `Dash_Space`, `Dash_None`, `Dot_Slash`, `Dot_Dash`, `Dot_Dot`, `Dot_Space`, `Dot_None`, `Space_Slash`, `Space_Dash`, `Space_Dot`, `Space_Space`, `Space_None`, `None_Slash`, `None_Dash`, `None_Dot`, `None_Space`, `None_None`, `ChineseFormal`
- `DateYear`: `Digits2`, `Digits4`, `None`
- `DecimalSeparator`: `Comma`, `Dot`
- `Direction`: `LTR`, `RTL`
- `SignDisplay`: `None`, `Parentheses`, `Prefixed`, `Suffixed`
- `Style`: `Combobox`, `Radiobutton`
- `ThousandSeparator`: `None`, `Comma`, `Dot`, `Space`, `Apostrophe`
- `TimeFormat`: `Hour24`, `AMPM`
- `TimeSeparator`: `Colon`, `Dot`, `Space`, `Comma`, `Slash`

Enum types were added.

### Recommended Shared Types
- `AxAlignmentType`
- `AxChangeCaseType`
- `AxDateDayType`
- `AxDateMonthType`
- `AxDateSeparatorType`
- `AxDateYearType`
- `AxDecimalSeparatorType`
- `AxDirectionType`
- `AxSignDisplayType`
- `AxStyleType`
- `AxThousandSeparatorType`
- `AxTimeFormatType`
- `AxTimeSeparatorType`

## Tier 2: Likely Restrictable, But Validate Conservatively
These elements show limited ranges or small observed sets, but the evidence is weaker than Tier 1.

### Numeric Range Candidates
- `DisplayHeight`: observed min `0`, max `20`
- `NoOfDecimals`: observed min `0`, max `12`
- `Scale`: observed values `2`, `10`, `12`, `15`, `16`
- `DatabaseStringSize`: observed values `10`, `20`, `100`

### Recommended Approach
1. Restrict `DisplayHeight` to `xs:integer` with `minInclusive="0"`.
2. Restrict `NoOfDecimals` to `xs:integer` with `minInclusive="0"`.
3. Restrict `Scale` as `xs:integer` with `minInclusive="0"`.
4. Restrict `DatabaseStringSize` as `xs:integer` with `minInclusive="0"`.

### Other Small-Set Candidates To Review Carefully
- `TimezonePreference`
- `DisplaceNegative`
- `Adjustment`
- `MaxDateLabel`

These should not be hard-coded until the full distinct-value set and platform semantics are reviewed.

## Tier 3: Do Not Restrict Yet
These fields are high-cardinality identifiers, labels, or free-text-like values and should remain `xs:string`.

- `Name`
- `Extends`
- `EnumType`
- `ReferenceTable`
- `ConfigurationKey`
- `CountryRegionCodes`
- `HelpText`
- `Label`
- `FormHelp`
- `CollectionLabel`
- `PresenceClass`
- `PresenceMethod`
- `ControlClass`
- `DataInteractorFactory`

### Rationale
The corpus shows many distinct values for these fields. Enumerating them in the schemas would overfit the current dataset and is likely to reject valid future metadata.

## Tier 4: Separate Structural Analysis Required
These elements are not scalar values in practice and should not be tightened using the current collapsed string-value summary.

- `ArrayElements`
- `Relations`
- `TableReferences`

### Rationale
The current summary query uses normalized string-value, which collapses descendant text into a single string. That is not a stable basis for schema restriction.

### Recommended Next Step For Collections
Create dedicated XQueries that inspect:
1. child element names
2. nested `xsi:type` usage
3. required vs optional nested fields
4. repeated structure patterns

Only after that should collection payload schemas be tightened.

## First Tightening Pass
Apply these changes first in both `AxEdt.1.0.xsd` and `AxEdt.1.1.xsd`.

1. Add enum simple types for:
- `Alignment`
- `ChangeCase`
- `DateDay`
- `DateMonth`
- `DateSeparator`
- `DateYear`
- `DecimalSeparator`
- `Direction`
- `SignDisplay`
- `Style`
- `ThousandSeparator`
- `TimeFormat`
- `TimeSeparator`

2. Add conservative numeric restrictions for:
- `DisplayHeight >= 0`
- `NoOfDecimals` in range `0..12`

3. Re-run full XSD 1.0 and XSD 1.1 validation over the standard EDT corpus.

## Second Tightening Pass
After revalidation of the first pass, review these elements for further restriction.

1. `TimezonePreference`
2. `Scale`
3. `DatabaseStringSize`
4. `DisplaceNegative`
5. `Adjustment`
6. `MaxDateLabel`

Do not tighten these until the observed values and business semantics are confirmed.

## Explicit Do-Not-Overfit List
Do not infer a closed set from current corpus evidence alone for these fields.

- `Tags`
- `Adjustment`
- `ControlClass`
- `PresenceMethod`
- `MaxDateLabel`
- `CollectionLabel`

These may look small or sparse in the current corpus, but they are especially likely to vary by module, extension, or future platform update.

## Legacy / Hidden Elements
- `ChangeCase` on `AxEdtString`: now suitable for `AxChangeCaseType`, but it appears to be a hidden legacy element and should be used with care.

## XSD 1.0 vs XSD 1.1 Guidance
### XSD 1.0
- Keep tightening mostly to shared simple types and basic numeric restrictions.
- Avoid designs that require advanced assertions or cross-field dependencies.

### XSD 1.1
- Mirror the same simple-type restrictions where practical.
- Use `xs:assert` only for clearly justified semantic rules, not as a substitute for empirical data quality assumptions.

## Validation Workflow
For every tightening step:

1. Apply the change to both schemas.
2. Run sample validation.
3. Run broad corpus validation for XSD 1.0 and XSD 1.1.
4. Classify any failures as one of:
- true invalid metadata caught by the tighter schema
- overfitting caused by incomplete corpus assumptions
- schema implementation bug
5. Only keep restrictions that survive full-corpus validation without unexplained false negatives.

## Success Criteria
The tightening effort is successful when:

1. The schemas reject clearly invalid scalar values for closed-vocabulary fields.
2. The schemas still validate the known standard EDT corpus without unexplained failures.
3. Tightening decisions remain explainable from either corpus evidence or platform semantics.
4. The collection payloads are deferred until structural evidence is gathered separately.