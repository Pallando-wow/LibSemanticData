# LibBrokerData Test Status

## Current tested core

- Library: `LibBrokerData-1.0`
- Implementation revision: `MINOR = 5`
- Test addon: `LibBrokerDataTest 0.2.1`
- Result: **220/220 tests passed**
- Test type: automated in-game test
- WoW client/flavor: not recorded in this test result

## Covered areas

The automated test suite covered:

- global library identity
- `MAJOR` / `MINOR`
- MINOR-3 → MINOR-4 in-place upgrade
- preservation of Provider object identity
- preservation of Field object identity
- preservation of a pre-existing callback registration
- downgrade protection after MINOR 4 is active
- MINOR-4 → MINOR-5 Entity-store migration
- preservation of existing Entity Values and ordering during migration
- Boolean `false` → `true` callbacks with `oldValue = false`
- large numeric Entity IDs
- distinction between numeric and string Entity IDs
- collision-safe typed Entity identity
- strict Entity payload validation
- strict `progress` payload validation
- Provider registration, lookup, iteration and duplicate registration
- Provider metadata and read-only behavior
- Field registration, lookup, iteration and duplicate registration
- Field metadata and read-only behavior
- `single` and `entity` scopes
- Field type validation
- `SetValue()`
- `GetValue()`
- `IterateValues()`
- multiple Entities for one Field
- Entity metadata updates
- Entity removal and re-add ordering
- all scalar value types
- `progress` values
- Producer input snapshot isolation
- Consumer result snapshot isolation
- callback snapshot stability
- `SetValues()` atomic batch updates
- duplicate batch-target detection
- rollback on invalid batches
- Provider, Field and Values events
- callback registration and removal
- callback error isolation
- no-op update behavior
- scope and Entity error codes

## Result

The tested MINOR-5 core completed the suite without a reported failure:

```text
LibBrokerDataTest: 220/220 tests passed
```

## Audit findings resolved in MINOR 5

The final audit found two edge cases that were not covered by the earlier 165-test suite:

1. a previous Boolean Value of `false` could be represented as `nil` in a Values-changed callback
2. textual conversion of numeric Entity IDs could allow identity collisions for sufficiently large numbers

Both were corrected in MINOR 5. The expanded `LibBrokerDataTest 0.2.1` suite then passed **220/220 tests**.

## Before declaring the 1.0 API stable

The next validation stage should use a real Producer and Consumer together.

The planned first integration is expected to include:

- a small Gold Provider addon using `LibBrokerData-1.0`
- Broker Panels as a Consumer
- single Values such as realm/account totals
- Entity-scoped character Values
- live updates
- Consumer-side formatting and line composition
- coexistence with classic LibDataBroker data

Findings from the first real integration should be resolved before the public 1.0 API is declared stable.
