# EDT Pre-Collection Elements Not Present In All 10 Types

This note documents EDT child elements that were observed before `ArrayElements` in the full BaseX corpus run, but were not present across all 10 EDT types.

Basis:
- Query: `edt-verify-element-order.xq`
- Database: `D365ApplicationExtended`
- Scope: full run (`limit=0`)
- EDT types considered: `AxEdtString`, `AxEdtEnum`, `AxEdtReal`, `AxEdtInt64`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`

## In 2-9 Types

| Element                    | Docs | Type Count | Occurs In                                                                                                                         | Does Not Occur In                                                                                                   |
|----------------------------|-----:|-----------:|-----------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `DisplayLength`            |  826 |          9 | `AxEdtString`, `AxEdtInt`, `AxEdtReal`, `AxEdtInt64`, `AxEdtEnum`, `AxEdtContainer`, `AxEdtUtcDateTime`, `AxEdtDate`, `AxEdtGuid` | `AxEdtTime`                                                                                                         |
| `IsObsolete`               |  153 |          9 | `AxEdtGuid`, `AxEdtString`, `AxEdtEnum`, `AxEdtInt`, `AxEdtReal`, `AxEdtDate`, `AxEdtInt64`, `AxEdtUtcDateTime`, `AxEdtContainer` | `AxEdtTime`                                                                                                         |
| `ReferenceTable`           | 2171 |          7 | `AxEdtInt64`, `AxEdtString`, `AxEdtInt`, `AxEdtDate`, `AxEdtReal`, `AxEdtEnum`, `AxEdtGuid`                                       | `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtTime`                                                                   |
| `EnforceHierarchy`         |   22 |          7 | `AxEdtReal`, `AxEdtGuid`, `AxEdtString`, `AxEdtEnum`, `AxEdtUtcDateTime`, `AxEdtInt64`, `AxEdtInt`                                | `AxEdtDate`, `AxEdtContainer`, `AxEdtTime`                                                                          |
| `Alignment`                |   66 |          5 | `AxEdtDate`, `AxEdtInt`, `AxEdtString`, `AxEdtReal`, `AxEdtInt64`                                                                 | `AxEdtEnum`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`                                         |
| `ButtonImage`              | 1220 |          4 | `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtString`, `AxEdtContainer`                                                                  | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt64`, `AxEdtInt`, `AxEdtGuid`, `AxEdtTime`                                        |
| `FormHelp`                 |  224 |          4 | `AxEdtString`, `AxEdtInt`, `AxEdtInt64`, `AxEdtDate`                                                                              | `AxEdtEnum`, `AxEdtReal`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`                            |
| `CollectionLabel`          |   31 |          3 | `AxEdtString`, `AxEdtInt64`, `AxEdtEnum`                                                                                          | `AxEdtReal`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`                |
| `Tags`                     |   25 |          3 | `AxEdtEnum`, `AxEdtString`, `AxEdtInt`                                                                                            | `AxEdtReal`, `AxEdtInt64`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`              |
| `PresenceIndicatorAllowed` |    9 |          3 | `AxEdtString`, `AxEdtEnum`, `AxEdtDate`                                                                                           | `AxEdtReal`, `AxEdtInt64`, `AxEdtInt`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`               |
| `PresenceMethod`           |   14 |          2 | `AxEdtInt64`, `AxEdtString`                                                                                                       | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`   |
| `PresenceClass`            |   12 |          2 | `AxEdtInt64`, `AxEdtString`                                                                                                       | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`   |
| `Direction`                |    5 |          2 | `AxEdtString`, `AxEdtInt`                                                                                                         | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt64`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime` |
| `ControlClass`             |    3 |          2 | `AxEdtString`, `AxEdtInt64`                                                                                                       | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime`   |

## Single-Type Outlier

| Element                 | Docs | Occurs In     | Does Not Occur In                                                                                                               |
|-------------------------|-----:|---------------|---------------------------------------------------------------------------------------------------------------------------------|
| `DataInteractorFactory` |    4 | `AxEdtString` | `AxEdtEnum`, `AxEdtReal`, `AxEdtInt64`, `AxEdtInt`, `AxEdtDate`, `AxEdtUtcDateTime`, `AxEdtContainer`, `AxEdtGuid`, `AxEdtTime` |
