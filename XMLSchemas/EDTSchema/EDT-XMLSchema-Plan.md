# EDT XML Schema Plan

## Goal
Create an XML Schema (XSD) for Dynamics 365 Finance and Operations Extended Data Types (EDTs) that validates all observed EDT variants while remaining maintainable for future platform updates.

## Inputs and Evidence
- Data source: BaseX database `D365ApplicationExtended`
- Metrics file: `XMLSchemas/EDTSchema/edt-child-element-counts.txt`
- Metrics file: `XMLSchemas/EDTSchema/edt-elements-by-type.txt`
- Metrics file: `XMLSchemas/EDTSchema/edt-type-counts.txt`
- Repro script: `XMLSchemas/EDTSchema/edt-child-element-counts.xq`
- Repro script: `XMLSchemas/EDTSchema/edt-elements-by-type.xq`
- Repro script: `XMLSchemas/EDTSchema/edt-type-counts.xq`

## Current Status
- Completed: BaseX query guidance reviewed and adjusted for this environment.
- Completed: Compatibility constraint captured (`db:list(...)` and `collection(...)` work; `db:open(...)` not available in this setup).
- Completed: EDT metrics collected and stored in `.txt` files in this folder.
- Completed: Reproducible `.xq` scripts created and verified to regenerate the metrics files.
- Completed: Bulk validation script created and smoke-tested against package data.
- Completed: First schema draft created as `XMLSchemas/EDTSchema/AxEdt.1.0.xsd`.
- Completed: XSD 1.1 variant created as `XMLSchemas/EDTSchema/AxEdt.1.1.xsd`.
- Completed: Root/type polymorphism finalized:
  - XSD 1.0 uses abstract `AxEdt` root + `i:type` targeting standalone concrete types
  - XSD 1.1 uses concrete `AxEdt` root typed as abstract base; missing/invalid `i:type` fails
- Completed: Targeted validation checks executed:
  - valid typed sample passes
  - missing type fails
  - unknown type fails
  - invalid field fails with allowed-field list from validator
- Completed: Initial bulk validation run over `ApplicationCommon` (`39` XML files) reduced from `14/39` pass to `39/39` pass after correcting base-sequence ordering.
- Completed: Full BaseX corpus order analysis executed with `edt-verify-element-order.xq` over `23,846` EDTs.
- Completed: Universal pre-collection fields confirmed from full-corpus analysis and moved into the common base sequence in both schemas.
- Completed: Non-universal pre-collection fields documented, including occurrence and non-occurrence by EDT type.
- Completed: Order-conflict analysis proved that no single fixed pre-collection sequence can satisfy the full corpus.
- Completed: `AxEdt.1.0.xsd` was redesigned to use standalone per-type `xs:all` complex types so each EDT type exposes only its allowed elements while still permitting any element order.
- Completed: Broader XSD 1.0 package validation executed:
  - `ApplicationCommon`: `39/39` pass
  - `AdvancedQualityManagement`: `238/238` pass
- Completed: `AxEdt.1.1.xsd` aligned to XSD 1.1 inheritance model using `xs:all` extension merging:
  - abstract `AxEdtBaseType` with shared EDT fields
  - concrete derived types extending the base with type-specific `xs:all`
  - concrete `AxEdt` root element typed as abstract base, with `i:type` selecting concrete subtype
- Completed: XSD 1.1 compatibility fixes applied from live package failures:
  - reordered `xs:anyAttribute` / `xs:assert` to valid XSD 1.1 content order
  - switched collection wildcard processing to `processContents="skip"` so nested relation/table-reference subtype payloads do not require local type declarations
- Completed: XSD 1.1 root switched to `xs:alternative` with fallback `AxEdtInvalidType` assertion so missing `i:type` reports an explicit allowed-types list.
- Completed: Clarified XSD 1.1 limitation: unknown `i:type` values still fail early with Xerces type-resolution error (`cvc-elt.4.2`) before fallback assertion messaging can override it.
- Completed: Bulk XSD 1.1 validation performance improvement implemented:
  - `Validate-EdtBulk.ps1` now batches many XML files per single JVM invocation (`jaxp.SourceValidator -i <many files>`) with chunking for command-length safety
- In progress: Running broader XSD 1.1 package validation with the new batched validator and triaging any remaining edge cases.

## Observed EDT Type Variants
From the collected BaseX output, the schema must support these EDT root type variants:
- AxEdtString
- AxEdtEnum
- AxEdtReal
- AxEdtInt64
- AxEdtInt
- AxEdtDate
- AxEdtUtcDateTime
- AxEdtContainer
- AxEdtGuid
- AxEdtTime

## Observed Structural Baseline
These elements appear for all observed EDT documents and should be modeled as required in the base structure:
- Name
- ArrayElements
- Relations
- TableReferences

Frequently used optional elements that should be in shared/common metadata:
- Label
- Extends
- ConfigurationKey
- CountryRegionCodes
- HelpText
- ReferenceTable
- IsObsolete

## Corpus Ordering Findings
The full BaseX run using `edt-verify-element-order.xq` established two important structural facts:

1. The collection block order is stable across the full checked corpus:
- ArrayElements
- Relations
- TableReferences

2. Several optional fields are legitimately emitted before the collection block.

Fields observed before the collection block in all 10 EDT types:
- Label
- Extends
- ConfigurationKey
- CountryRegionCodes
- HelpText

Fields observed before the collection block in more than one, but not all, EDT types are documented in `XMLSchemas/EDTSchema/EDT-PreCollection-NonUniversal-Elements.md`.

Full-corpus order analysis snapshot:
- Checked EDTs: `23,846`
- Violations against the earlier narrow pre-collection rule: `15,988`
- Most common pre-collection fields beyond the universal set included `ReferenceTable`, `ButtonImage`, `DisplayLength`, and `IsObsolete`.

## Schema Design Approach
1. For XSD 1.0, define one standalone complex type per observed EDT variant using `xs:all` so allowed elements can appear in any order.
2. Model polymorphism through the `i:type` value on the `AxEdt` root.
3. Keep each EDT type explicit and redundant by design so every type lists only the elements observed for that type.
4. For XSD 1.1, use an abstract shared base type plus derived subtype extensions, each with `xs:all`, relying on XSD 1.1 merge semantics for unordered combined content.
5. Keep shared collection payloads (`ArrayElements`, `Relations`, `TableReferences`) permissive via wildcard container typing, and use `processContents="skip"` for XSD 1.1 to avoid false failures from nested, out-of-scope subtype declarations.
6. Keep subtype-specific fields only where they are observed, for example:
- String-centric: StringSize, StringSizeIsExtensible, ChangeCase, DisplayHeight
- Enum-centric: EnumType, Style
- Numeric-centric: AllowNegative, ShowZero, NoOfDecimals, Scale, SignDisplay
- Date/time-centric: DateYear, DateMonth, DateDay, DateSeparator, TimeSeconds, TimeHours, TimeMinute, TimeSeparator, TimezonePreference, TimeFormat
6. Document inside the schema which elements are shared by all types, shared by a subset of types, or unique to a single type.
7. Use strict element typing where stable, but avoid over-constraining first iteration.
8. Add limited extension tolerance (`xs:any`) only where justified to avoid blocking unknown future metadata.

## Implementation Plan
1. Create `XMLSchemas/EDTSchema/AxEdt.1.0.xsd` with:
- Shared simple types for booleans, integers, and common text nodes
- `AxEdt` root declaration
- Standalone `xs:all` complex types for each observed EDT subtype
- In-schema comments identifying common, subset-shared, and single-type elements

2. Add subtype mapping strategy in XSD:
- For XSD 1.0, use an abstract `AxEdt` element with `xsi:type` targeting standalone concrete types
- For XSD 1.1, use abstract `AxEdtBaseType` + derived complex types with `xs:all` extension merging
- Ensure support for the existing XML namespace pattern and `i:type` usage

3. Add schema annotations:
- Document source of each field (common vs subtype-specific)
- Note that coverage is based on current BaseX corpus

4. Validate against corpus:
- Run bulk validation over AxEDT/AxEdt resources
- Use batched XSD 1.1 validation mode to keep one JVM alive for many XML files
- Capture validation failures by category:
  - missing required element
  - unexpected element
  - invalid datatype
  - subtype mismatch
  - ordering mismatch

5. Iterate to closure:
- Adjust minOccurs/maxOccurs and types from failure evidence
- Repeat until all valid EDTs pass

## Next Step (Active)
Run broader XSD 1.1 batched validation beyond `ApplicationCommon` (for example `AdvancedQualityManagement` and `ApplicationPlatform`), capture any remaining failures, and finalize regression baselines for both XSD 1.0 and XSD 1.1.

## Deferred TODOs
- Current finding (XSD 1.0/.NET): `xsi:type` cannot be constrained as a normal enumerated attribute with guaranteed enum-style validator output.
- Current finding (XSD 1.1/Xerces):
  - Missing `i:type` can be routed to a fallback `xs:alternative` type and produce a custom allowed-types assertion message.
  - Unknown `i:type` fails during QName/type resolution (`cvc-elt.4.2`) before fallback assertion messaging can be applied.
- Candidate follow-up: keep schema behavior as-is and augment validator tooling to append a friendly allowed-types list when type-related failures are detected (especially unknown `i:type`).

## Validation and Regression Strategy
- Keep generated reports in this folder and refresh them before schema updates.
- Store a repeatable query script for type and element metrics.
- Add a lightweight validation script to run XSD checks in batch and emit a summary file.
- Keep the XQuery order-analysis script (`edt-verify-element-order.xq`) aligned with the current schema assumptions so ordering decisions remain evidence-based.
- Require report + validation refresh when updating the schema.

## Risks and Mitigations
- Risk: Overly strict first version causes false negatives.
- Mitigation: Start with strict shared baseline and moderate subtype constraints, then tighten iteratively.

- Risk: Platform introduces new EDT metadata elements.
- Mitigation: Keep controlled extension points and monitor metric diffs on refresh.

- Risk: Case differences in AxEdt/AxEDT resource paths produce incomplete coverage.
- Mitigation: Always query both path variants or normalize paths before analysis.

## Definition of Done
- `AxEdt.1.0.xsd` and `AxEdt.1.1.xsd` exist under `XMLSchemas/EDTSchema`.
- All known EDT subtype variants are represented.
- Schema validates current corpus with zero unexplained failures.
- Validation process is scriptable and repeatable.
- XSD 1.1 bulk validation runs in batched JVM mode with acceptable throughput for package-scale checks.
- Documentation in this folder explains assumptions and refresh steps.
