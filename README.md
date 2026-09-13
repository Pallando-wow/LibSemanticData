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

Consumers such as [Broker Panels](https://github.com/Pallando-wow/BrokerPanels) may use both systems side by side.

## Quick start

```lua
local LBD = _G["LibBrokerData-1.0"]

local provider, err = LBD:RegisterProvider("ExampleAddon", {
    label = "Example Addon",
    addon = "ExampleAddon",
})

local field
field, err = provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
    scope = "entity",
    entityType = "character",
})

provider:SetValue("characterGold", 5639221, {
    entityType = "character",
    entityID = UnitGUID("player"),
    entityLabel = UnitName("player"),
})
```

A Consumer can discover the Field and its metadata without knowing the Producer in advance:

```lua
for providerID, currentProvider in LBD:IterateProviders() do
    for fieldID, currentField in LBD:IterateFields(providerID) do
        print(
            providerID,
            fieldID,
            currentField.type,
            currentField.scope,
            currentField.entityType
        )
    end
end
```

Registered Provider and Field metadata is exposed through the returned objects as read-only information.

## Specification

See `SPECIFICATION.md`.

## Status

The first complete `LibBrokerData-1.0` core implementation is available as implementation revision `MINOR = 5`.

The current implementation covers:

- Provider and Field registration and discovery
- `single` and `entity` Field scopes
- typed Values
- Entity-scoped Values
- atomic `SetValues()` updates
- callbacks and change events
- snapshot semantics
- compatible embedded-library upgrades and downgrade protection

The current core passed **220/220 automated in-game tests**. See `TEST_STATUS.md`.

The implementation/specification audit is complete. The API remains a pre-release candidate until the first real Producer/Consumer integration is complete.

The MINOR-5 audit revision fixes two edge cases found during final review:

- Boolean change events preserve `oldValue = false` correctly instead of treating it as unavailable.
- Entity identity keeps numeric IDs type-safe and collision-free instead of deriving identity only from `tostring(entityID)`.

Entity metadata and `progress` payloads are also validated against the defined 1.0 structure.

## License

To be decided before the first public release.
