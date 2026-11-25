# T-0034-AC4: relative retrofit paths

- retrofit verb annotations scanned: 4

| Check | Result |
|---|---|
| leading-slash paths | none |
| config apiBaseUrl without a trailing slash | none |
| negative control (planted `@GET('/x')`) | tripped |

**PASS T-0034-AC4-relative-paths**
