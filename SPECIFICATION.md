# LibBrokerData-1.0 Specification

**Status:** Draft 0.1  
**Library ID:** `LibBrokerData-1.0`  
**Repository:** `LibBrokerData`

## 1. Purpose

LibBrokerData is a dependency-free data library for World of Warcraft addons.

It allows producer addons to publish structured, individually addressable values that consumer addons can discover and use independently of presentation.

LibBrokerData provides data only. It does not define UI, formatting, tooltips, panel layout, persistence, or communication between game clients.

## 2. Design principles

LibBrokerData-1.0:

- has no dependency on LibStub
- has no dependency on CallbackHandler-1.0
- has no dependency on LibDataBroker-1.1
- contains no UI
- contains no formatting logic
- contains no SavedVariables
- stores no persistent data
- provides its own registry
- provides its own callback/event mechanism
- supports multiple embedded copies safely
- keeps data identity separate from display labels
- keeps field identity separate from entity identity

The library may coexist with LibDataBroker. An addon may publish classic LibDataBroker objects and LibBrokerData values at the same time.

## 3. Core data model

```text
Provider
└── Field
    └── Value(s)
        └── optional Entity
```

Example:

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

`characterGold` is registered only once. Multiple character values are distinguished through entity metadata rather than by encoding character identity into the Field ID.

## 4. Library identity and implementation revision

The public library ID is:

```lua
_G["LibBrokerData-1.0"]
```

The major API identity remains `LibBrokerData-1.0` while changes stay backward-compatible.

Internal implementation revisions use a numeric `MINOR` value:

```lua
lib.MAJOR = "LibBrokerData-1.0"
lib.MINOR = 1
```

A newer embedded implementation must upgrade the existing global library table in place so that existing providers, fields, values, callbacks, and registration order are preserved.

A future incompatible API may use a separate global identity such as:

```lua
_G["LibBrokerData-2.0"]
```

## 5. Provider

A provider is a logical data source, normally an addon.

```lua
local provider = LBD:RegisterProvider("MyAccountant", {
    label = "MyAccountant",
})
```

### 5.1 Provider ID

The Provider ID must be stable, non-localized, unique within LibBrokerData, and case-sensitive.

Recommended characters:

```text
A-Z a-z 0-9 _ - . :
```

Spaces should not be used.

### 5.2 Provider metadata

| Key | Required | Meaning |
| --- | --- | --- |
| `label` | yes | localized display name |
| `description` | no | localized description |
| `addon` | no | technical addon name |

Unknown metadata keys must not cause registration to fail.

## 6. Field

A Field describes one semantic value.

```lua
provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
})
```

The Field ID is the stable technical identity. Localized labels must not be used as technical IDs.

### 6.1 Field metadata

| Key | Required | Meaning |
| --- | --- | --- |
| `label` | yes | localized field name |
| `type` | yes | semantic data type |
| `description` | no | localized description |
| `unit` | no | semantic unit |
| `category` | no | stable technical group ID |
| `categoryLabel` | no | localized group label |

Unknown metadata keys must be tolerated.

## 7. Entities

A Field may have either one value without an Entity or multiple values belonging to distinct Entities.

Entity identity is independent of the Field ID.

An Entity consists of:

| Key | Required | Meaning |
| --- | --- | --- |
| `entityType` | yes | stable technical entity type |
| `entityID` | yes | stable technical identity within that entity type |
| `entityLabel` | no | localized or user-facing name |

Example:

```lua
{
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
```

Recommended entity types may include `character`, `pet`, `realm`, `guild`, `account`, and `profession`.

The library does not attach built-in semantics to these names.

### 7.1 Stable entity identity

`entityID` should be as stable as the source addon can reasonably provide.

For WoW characters, a stable character GUID is preferred when available. A display label such as a character name must not be the only identity when a more stable technical key exists.

## 8. Values

A Field can publish one unscoped value or multiple entity-scoped values.

Example:

```text
realmGold
└── 14244856

characterGold
├── character / Player-...ABCD / Pitronas → 5639221
├── character / Player-...EF01 / Temlin   → 4213345
└── character / Player-...2345 / Paljande → 2661287
```

A Field ID must not be expanded with entity identity.

Avoid:

```text
characterGold:Player-1234-0000ABCD
```

Prefer:

```text
fieldID     = characterGold
entityType  = character
entityID    = Player-1234-0000ABCD
```

## 9. Data types

| Type | Lua value | Semantics |
| --- | --- | --- |
| `text` | string | text |
| `number` | number | general numeric value |
| `integer` | number | integral numeric value |
| `percent` | number | percentage value |
| `money` | number | copper |
| `duration` | number | seconds |
| `boolean` | boolean | true/false |
| `status` | string | status identifier |
| `progress` | table | progress value |

### 9.1 money

`money` values are integers in copper. Formatting is the consumer's responsibility.

### 9.2 percent

Percent values are stored directly as percentages. `82` means `82%`. Values above 100 are valid.

### 9.3 duration

Duration values are seconds. Formatting is the consumer's responsibility.

### 9.4 status

Recommended identifiers:

```text
ok
info
warning
critical
inactive
unknown
```

Additional provider-specific values are allowed.

### 9.5 progress

```lua
{
    current = 73,
    maximum = 100,
}
```

Optionally:

```lua
{
    minimum = 0,
    current = 73,
    maximum = 100,
}
```

Progress tables are treated as immutable values. Producers must publish a new table when changing progress data.

## 10. Nil and unavailable data

A registered Field remains registered even when no current value exists.

Setting a value to `nil` means that the Field exists but no current value is available for that value scope.

The consumer decides how unavailable values are presented.

## 11. Producer API

The initial producer API is intended to include:

```lua
LBD:RegisterProvider(providerID, info)

provider:RegisterField(fieldID, info)

provider:SetValue(fieldID, value)
provider:SetValue(fieldID, value, entity)

provider:SetValues(values)
```

`RegisterProvider` returns a Provider object.

`RegisterField` returns a Field object.

### 11.1 SetValue without Entity

```lua
provider:SetValue("realmGold", 14244856)
```

### 11.2 SetValue with Entity

```lua
provider:SetValue("characterGold", 5639221, {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
})
```

### 11.3 Atomic multi-value updates

`SetValues()` is intended for updating several logically related values as one operation.

Required behavior:

1. validate all submitted updates
2. apply all valid changes
3. emit one consolidated change notification afterward

Consumers must never observe a partially updated logical set through the change event.

The final concrete input shape for `SetValues()` will be fixed before implementation.

## 12. Consumer API

The initial consumer API is intended to include:

```lua
LBD:GetProvider(providerID)
LBD:GetField(providerID, fieldID)
LBD:GetValue(providerID, fieldID)
LBD:GetValue(providerID, fieldID, entityType, entityID)

LBD:IterateProviders()
LBD:IterateFields(providerID)
LBD:IterateValues(providerID, fieldID)
```

Consumers must be able to discover providers and fields regardless of load order.

## 13. Registration order

`IterateProviders()` should preserve provider registration order.

`IterateFields()` should preserve field registration order.

For entity-scoped values, the library should preserve first-seen entity order unless a future version explicitly defines another order.

Consumers remain free to apply their own sorting.

## 14. Events and callbacks

LibBrokerData provides its own callback system.

```lua
local token = LBD:RegisterCallback(event, callback)
LBD:UnregisterCallback(token)
```

The returned token is opaque to consumers.

Initial events:

```lua
LBD.EVENT_PROVIDER_REGISTERED
LBD.EVENT_FIELD_REGISTERED
LBD.EVENT_VALUES_CHANGED
```

### 14.1 Provider registered

```lua
callback(providerID, provider)
```

### 14.2 Field registered

```lua
callback(providerID, fieldID, field)
```

### 14.3 Values changed

```lua
callback(providerID, changes)
```

Each change should identify at least the Field ID, old value, new value, and optional entity identity.

No change event is emitted when the effective value did not change.

Callbacks must be isolated so that one failing consumer does not prevent remaining callbacks from running.

## 15. Load order

The library must support both producer-first and consumer-first loading.

No fixed addon load order is part of the specification.

## 16. Duplicate registration

Provider and Field registration must be idempotent when repeated registration is compatible.

Registering the same Provider ID again must not create a second Provider, discard values, or duplicate the registration event.

Registering the same Field ID again follows the same principle.

An incompatible semantic redefinition, such as changing a Field from `money` to `text`, is a conflict.

## 17. Errors

The public API should prefer explicit return values over intentionally raising Lua errors for normal validation failures.

Stable error identifiers should include at least:

```text
INVALID_PROVIDER_ID
UNKNOWN_PROVIDER
INVALID_FIELD_ID
UNKNOWN_FIELD
INVALID_FIELD_TYPE
INVALID_VALUE
INVALID_ENTITY
PROVIDER_CONFLICT
FIELD_CONFLICT
```

Exact return signatures will be finalized before implementation.

## 18. No formatting

LibBrokerData never converts semantic values into final display strings.

Consumers own all presentation and formatting.

## 19. No UI semantics

LibBrokerData does not define font, size, color, alignment, line position, icon position, tooltip layout, panel position, spacing, or visibility behavior.

A status value such as `warning` does not imply a specific color.

## 20. Persistence

LibBrokerData stores no SavedVariables and has no persistence responsibility.

A producer owns its source data. A consumer owns its configuration. LibBrokerData exposes current runtime data only.

## 21. Relationship to other WoW libraries

LibBrokerData is an independent implementation.

It uses established architectural ideas common in WoW addon development, such as registries, producer/consumer separation, stable technical IDs, callback-based change notifications, and metadata-driven discovery.

It is not a fork or derivative implementation of LibDataBroker, DataStore, LibDogTag, Ace libraries, or other third-party libraries.

## 22. Out of scope for 1.0

The initial specification intentionally excludes:

- UI widgets
- tooltips
- click actions
- colors
- panel layout
- SavedVariables
- networking
- cross-client synchronization
- automatic LibDataBroker bridges
- arbitrary nested object graphs
- generic list/table payloads
- expression parsing
- consumer-specific formatting rules

## 23. Example: MyAccountant

```lua
local LBD = _G["LibBrokerData-1.0"]

local provider = LBD:RegisterProvider("MyAccountant", {
    label = "MyAccountant",
    addon = "MyAccountant",
})

provider:RegisterField("realmGold", {
    label = "Realm Gold",
    type = "money",
    category = "balance",
    categoryLabel = "Balance",
})

provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
    category = "balance",
    categoryLabel = "Balance",
})

provider:SetValue("realmGold", 14244856)

provider:SetValue("characterGold", 5639221, {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
})

provider:SetValue("characterGold", 4213345, {
    entityType = "character",
    entityID = "Player-1234-0000EF01",
    entityLabel = "Temlin",
})
```

A consumer can display those values freely or combine them with fields from entirely different providers.

## 24. Repository structure

Recommended initial structure:

```text
LibBrokerData/
├── LibBrokerData-1.0/
│   └── LibBrokerData-1.0.lua
├── README.md
├── SPECIFICATION.md
├── CHANGELOG.md
└── LICENSE
```

Only the runtime library directory needs to be embedded into normal addons.

---

This specification remains a draft until the concrete 1.0 API signatures, `SetValues()` input structure, callback payload structure, and version-upgrade behavior have been implemented and tested.
