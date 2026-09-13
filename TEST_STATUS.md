# LibBrokerData Test Status

## Current tested core

- Library: `LibBrokerData-1.0`
- Implementation revision: `MINOR = 4`
- Test addon: `LibBrokerDataTest 0.1.0`
- Result: **165/165 tests passed**
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

The tested MINOR-4 core completed the suite without a reported failure:

```text
LibBrokerDataTest: 165/165 tests passed
```

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
