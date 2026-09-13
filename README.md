# LibBrokerData

LibBrokerData is a small, dependency-free data library for World of Warcraft addons.

Its purpose is to let addons publish structured, individually addressable data values that other addons can discover and consume independently of presentation.

## Why?

Classic broker systems are very good at exposing ready-to-display text, icons, and click actions.

LibBrokerData focuses on the values behind that presentation.

Instead of exposing only:

```text
1,424g 48s 56c
```

an addon can publish separate semantic values such as:

```text
realmGold
characterGold
income
expenses
profit
```

A consumer can then decide how those values should be displayed or combined.

## Example

A provider may register one `characterGold` field and publish multiple entity-scoped values:

```text
MyAccountant
├── realmGold
│   └── 1,424g total
│
└── characterGold
    ├── Pitronas  → 563g
    ├── Temlin    → 421g
    └── Paljande  → 266g
```

The character identity is kept separate from the Field ID.

## Core principles

- no LibStub dependency
- no CallbackHandler dependency
- no LibDataBroker dependency
- no UI
- no formatting
- no SavedVariables
- no persistent storage
- stable technical Provider and Field IDs
- optional Entity-scoped values
- built-in registry
- built-in change notifications
- safe use by multiple embedded addon copies

## Data model

```text
Provider
└── Field
    └── Value(s)
        └── optional Entity
```

## Relationship to LibDataBroker

LibBrokerData does not replace LibDataBroker.

An addon may support both:

```text
LibDataBroker
→ classic broker presentation

LibBrokerData
→ structured individual values
```

Consumers such as Broker Panels may use both systems side by side.

## Specification

See `SPECIFICATION.md`.

## Status

LibBrokerData-1.0 is currently in specification and initial implementation design.

The public API is not yet considered stable.

## License

To be decided before the first public release.
