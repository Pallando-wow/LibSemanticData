# LibBrokerData-1.0 Specification

**Status:** Draft 0.3  
**Library ID:** `LibBrokerData-1.0`  
**Repository:** `LibBrokerData`

## 1. Purpose

LibBrokerData is a dependency-free data library for World of Warcraft addons.

It allows producer addons to publish structured, individually addressable semantic values that consumer addons can discover and use independently of presentation.

LibBrokerData provides data only.

It does not define:

- UI
- panels
- lines
- alignment
- colors
- icons or icon placement
- formatting
- tooltips
- persistence
- SavedVariables
- current-character selection
- communication between game clients

A consumer decides which values are displayed, where they are displayed, how they are combined, and how they are formatted.

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
- keeps Field identity separate from Entity identity
- exposes semantic source data rather than presentation-oriented strings
- remains independent of any specific consumer such as Broker Panels

LibBrokerData may coexist with LibDataBroker. An addon may publish classic LibDataBroker objects and LibBrokerData values at the same time.

## 3. No display semantics

LibBrokerData must not introduce presentation-oriented metadata such as:

```text
line1
line2
alignment
color
iconPosition
panel
preferredDisplay
secondaryText
primaryField
secondaryField
preferredLine
preferredPanel
compactLabel
displayOrderForBrokerPanels
```

If a producer exposes several pieces of information, each semantic value is registered as a separate Field.

Example:

```text
MyAccountant
├── realmGold
├── characterGold
├── sessionIncome
└── sessionExpenses
```

A consumer may later combine those Fields in one line, multiple lines, different panels, or any other presentation.

## 4. Core data model

The core hierarchy is:

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

`characterGold` is registered only once.

Multiple character values are distinguished through Entity identity rather than by encoding character identity into the Field ID.

## 5. Library identity and implementation revision

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

The exact in-place upgrade behavior remains to be finalized before implementation.

## 6. Provider

A Provider is a logical data source, normally an addon.

Example:

```lua
local provider = LBD:RegisterProvider("MyAccountant", {
    label = "MyAccountant",
})
```

### 6.1 Provider ID

The Provider ID must be:

- stable
- non-localized
- unique within LibBrokerData
- case-sensitive

Recommended characters:

```text
A-Z a-z 0-9 _ - . :
```

Spaces should not be used.

Examples:

```text
MyAccountant
HunterThreat
PetAdvisor
PortalMaster
MyAddon:Character
```

### 6.2 Provider metadata

Supported Provider metadata for 1.0:

| Key | Required | Meaning |
| --- | --- | --- |
| `label` | yes | localized display name |
| `description` | no | localized description |
| `addon` | no | technical addon name |

Unknown metadata keys must not cause registration to fail. Consumers may ignore metadata they do not understand.

### 6.3 Provider metadata immutability

After successful registration, Provider metadata is immutable for the remainder of the current session.

A compatible duplicate registration may return the existing Provider.

An incompatible redefinition is a conflict.

The exact conflict return behavior remains to be finalized before implementation.

## 7. Field

A Field describes one semantic value.

Example:

```lua
provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
    scope = "entity",
    entityType = "character",
})
```

The Field ID is the stable technical identity.

Localized labels must not be used as technical IDs.

### 7.1 Field metadata

Supported Field metadata for 1.0:

| Key | Required | Meaning |
| --- | --- | --- |
| `label` | yes | localized field name |
| `type` | yes | semantic data type |
| `scope` | yes | value scope: `single` or `entity` |
| `entityType` | required for `scope = "entity"` | expected Entity type |
| `description` | no | localized description |
| `unit` | no | semantic unit |
| `category` | no | stable technical group ID |
| `categoryLabel` | no | localized group label |

Unknown metadata keys must be tolerated.

### 7.2 Field scope

Every Field must declare its value scope at registration time.

Allowed values are:

```text
single
entity
```

For a single-value Field:

```lua
provider:RegisterField("realmGold", {
    label = "Realm Gold",
    type = "money",
    scope = "single",
})
```

Normative rules for `scope = "single"`:

- the Field has exactly one unscoped value slot
- `SetValue(fieldID, value)` is valid
- `SetValue(fieldID, value, entity)` is invalid
- `entityType` metadata is not allowed for the Field

For an Entity-scoped Field:

```lua
provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
    scope = "entity",
    entityType = "character",
})
```

Normative rules for `scope = "entity"`:

- all values are Entity-scoped
- `entityType` is required at Field registration
- `SetValue(fieldID, value, entity)` is valid when `entity.entityType` matches the Field's declared `entityType`
- `SetValue(fieldID, value)` without an Entity is invalid
- Entities of another type are invalid for that Field

Requiring `entityType` for Entity-scoped Fields allows Consumers to understand the shape of a Field before the first value exists. It also allows Consumers to provide their own context-specific selection logic, such as selecting the current character, without adding that logic to LibBrokerData.

### 7.3 Field metadata immutability

After successful registration, Field metadata is immutable for the remainder of the current session.

A compatible duplicate registration may return the existing Field.

Changing the semantic meaning of a Field is a conflict. This includes changing its `type`, `scope`, or declared `entityType`.

For example, changing a Field from `money` to `text`, from `single` to `entity`, or from `entityType = "character"` to another Entity type is incompatible.

## 8. Entities

A Field may expose values associated with Entities.

Entity identity is independent of Field identity.

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

Recommended Entity types may include:

```text
character
pet
realm
guild
account
profession
```

The library does not attach built-in semantics to these names.

### 8.1 Stable Entity identity

The Entity identity is the combination of:

```text
entityType + entityID
```

`entityID` should be as stable as the source addon can reasonably provide.

For WoW characters, a stable character GUID is preferred when available.

A display label such as a character name must not be used as the only identity when a more stable technical key exists.

### 8.2 Entity metadata changes

Entity identity is stable, but Entity metadata may change.

Example:

Before:

```lua
{
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
```

Later:

```lua
{
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas-NewName",
}
```

The Entity remains the same because `entityType` and `entityID` are unchanged.

An Entity metadata change is treated as a relevant change even if the effective data value itself did not change.

Consumers must be notified through `EVENT_VALUES_CHANGED`.

## 9. Values

A Field publishes values according to its declared `scope`.

A `single` Field publishes one unscoped value. An `entity` Field publishes zero or more values scoped to Entities of its declared `entityType`.

Examples:

```text
realmGold
└── 14244856
```

and:

```text
characterGold
├── character / Player-...ABCD / Pitronas → 5639221
├── character / Player-...EF01 / Temlin   → 4213345
└── character / Player-...2345 / Paljande → 2661287
```

A Field ID must not be expanded with Entity identity.

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

## 10. Data types

LibBrokerData-1.0 defines these initial semantic types:

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

### 10.1 money

`money` values are integers in copper.

Example:

```lua
14244856
```

Formatting such as:

```text
1,424g 48s 56c
```

is the consumer's responsibility.

### 10.2 percent

Percent values are stored directly as percentages.

```lua
82
```

means:

```text
82%
```

Values above 100 are valid.

### 10.3 duration

Duration values are seconds.

```lua
3665
```

Formatting is the consumer's responsibility.

### 10.4 status

Recommended status identifiers:

```text
ok
info
warning
critical
inactive
unknown
```

Additional provider-specific values are allowed.

Consumers must tolerate unknown status values.

### 10.5 progress

A progress value is:

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

Progress tables are treated as immutable values.

Producers must publish a new table when changing progress data.

## 11. Nil and unavailable data

A registered Field remains registered even when no current value exists.

Setting a value to `nil` means:

> The Field exists, but no current value is available for that value scope.

A consumer decides whether to hide the value, show a placeholder, hide a complete line, or use another presentation.

## 12. Producer API

The initial Producer API is intended to include:

```lua
LBD:RegisterProvider(providerID, info)

provider:RegisterField(fieldID, info)

provider:SetValue(fieldID, value)
provider:SetValue(fieldID, value, entity)

provider:SetValues(values)
```

`RegisterProvider` returns a Provider object.

`RegisterField` returns a Field object.

The concrete public return signatures remain to be finalized before implementation.

### 12.1 SetValue without Entity

For a Field registered with `scope = "single"`:

```lua
provider:SetValue("realmGold", 14244856)
```

Passing an Entity for a `single` Field is invalid.

### 12.2 SetValue with Entity

```lua
provider:SetValue("characterGold", 5639221, {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
})
```

For a Field registered with `scope = "entity"`, omitting the Entity is invalid. The supplied `entityType` must match the Field's declared `entityType`.

### 12.3 Atomic SetValues

`SetValues()` is intended for updating several logically related values as one operation.

Required behavior:

1. validate all submitted updates
2. apply all valid changes
3. update Entity metadata where applicable
4. emit one consolidated change notification afterward
5. never expose a partially updated logical set through the change event

`SetValues()` may therefore produce multiple entries in one `EVENT_VALUES_CHANGED` payload.

The final concrete input structure for `SetValues()` remains to be finalized before implementation.

## 13. Consumer API

The initial Consumer API is intended to include:

```lua
LBD:GetProvider(providerID)
LBD:GetField(providerID, fieldID)
LBD:GetValue(providerID, fieldID)
LBD:GetValue(providerID, fieldID, entityType, entityID)

LBD:IterateProviders()
LBD:IterateFields(providerID)
LBD:IterateValues(providerID, fieldID)
```

Consumers must be able to discover Providers and Fields regardless of load order.

## 14. IterateValues

`IterateValues(providerID, fieldID)` returns:

```lua
for value, entity in LBD:IterateValues(providerID, fieldID) do
    ...
end
```

For an unscoped value:

```lua
value = 14244856
entity = nil
```

For an Entity-scoped value:

```lua
value = 4250000

entity = {
    entityType = "character",
    entityID = "Player-1234-0000EF01",
    entityLabel = "Temlin",
}
```

The Entity table keeps Entity metadata together and allows future optional metadata to be added without changing the iterator signature.

Consumers must treat returned Entity tables as read-only.

The library may replace an Entity metadata table when metadata changes.

Entity-scoped values are iterated in first-seen Entity order.

## 15. Registration and iteration order

`IterateProviders()` preserves Provider registration order.

`IterateFields()` preserves Field registration order.

`IterateValues()` preserves first-seen Entity order for Entity-scoped values.

Consumers remain free to apply their own sorting.

## 16. Events and callbacks

LibBrokerData provides its own callback system.

The initial public API is intended to include:

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

### 16.1 Provider registered

```lua
callback(providerID, provider)
```

### 16.2 Field registered

```lua
callback(providerID, fieldID, field)
```

### 16.3 Values changed

The callback signature is:

```lua
callback(providerID, changes)
```

`changes` is an array of change records.

For an unscoped Field:

```lua
changes = {
    {
        fieldID = "realmGold",

        oldValue = 14000000,
        newValue = 14244856,

        oldEntity = nil,
        newEntity = nil,
    },
}
```

For an Entity-scoped Field:

```lua
changes = {
    {
        fieldID = "characterGold",

        oldValue = 4213345,
        newValue = 4250000,

        oldEntity = {
            entityType = "character",
            entityID = "Player-1234-0000EF01",
            entityLabel = "Temlin",
        },

        newEntity = {
            entityType = "character",
            entityID = "Player-1234-0000EF01",
            entityLabel = "Temlin",
        },
    },
}
```

For an Entity metadata-only change:

```lua
changes = {
    {
        fieldID = "characterGold",

        oldValue = 4250000,
        newValue = 4250000,

        oldEntity = {
            entityType = "character",
            entityID = "Player-1234-0000EF01",
            entityLabel = "Temlin",
        },

        newEntity = {
            entityType = "character",
            entityID = "Player-1234-0000EF01",
            entityLabel = "Temlin-NewName",
        },
    },
}
```

### 16.4 VALUES_CHANGED rules

The following rules are normative:

- `fieldID` is always present.
- `oldValue` is the previous effective value.
- `newValue` is the new effective value.
- `oldEntity` and `newEntity` are `nil` for unscoped values.
- Entity-scoped changes contain Entity metadata.
- `entityType` and `entityID` identify the Entity.
- Entity metadata may change without changing Entity identity.
- `SetValues()` may produce multiple change records in one event.
- No change record is produced when neither effective value nor Entity metadata changed.
- An Entity metadata-only change produces a change record even when `oldValue == newValue`.
- Consumers must be able to determine whether a displayed source reference is affected without rereading the complete Provider.
- After the callback begins, normal getters and iterators must expose the new state.

Using `oldEntity` and `newEntity` rather than flattening Entity metadata keeps the callback format extensible if optional Entity metadata is added later.

### 16.5 Entity snapshot semantics

`oldEntity` and `newEntity` are logical read-only snapshots.

Normative rules:

- `oldEntity` describes the Entity metadata state before the change.
- `newEntity` describes the Entity metadata state after the change.
- A later Entity metadata update must never alter an Entity snapshot that was already delivered in an earlier callback.
- When Entity metadata changed, `oldEntity` and `newEntity` must not reference the same mutable table.
- If Entity metadata did not change, an implementation may reuse an equivalent immutable snapshot representation within that change record.
- Consumers must treat all Entity tables returned by LibBrokerData as read-only.
- Producers must not treat Entity tables passed to `SetValue()` or `SetValues()` as shared mutable library state. The library owns its stored Entity metadata after the call.
- The implementation must not depend on a Producer keeping its input Entity table unchanged after the call.

The library should implement Entity metadata with replacement semantics rather than mutating a previously published Entity metadata table in place. This guarantees that old callback snapshots remain stable across later metadata changes.

## 17. Callback isolation

A failing consumer must not prevent remaining callbacks from running.

Callbacks are isolated from one another.

The implementation should use WoW-compatible protected error handling.

## 18. Load order

The library must support both directions.

Producer first:

```text
Producer addon loads
→ registers data
→ consumer loads later
→ consumer discovers existing registry
```

Consumer first:

```text
Consumer loads
→ registers callbacks
→ producer loads later
→ registration events notify consumer
```

No fixed addon load order is part of the specification.

## 19. Duplicate registration

Provider and Field registration must be idempotent when the repeated registration is compatible.

Registering the same Provider ID again:

- must not create a second Provider
- must not discard values
- must not duplicate the registration event
- must return the existing Provider when compatible

Registering the same Field ID again under the same Provider follows the same principle.

An incompatible semantic redefinition is a conflict.

The exact return behavior and conflict rules remain to be finalized before implementation.

## 20. Errors

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

Exact return signatures remain to be finalized before implementation.

## 21. Current context is consumer logic

LibBrokerData does not define special semantics such as:

```text
currentCharacter
currentRealm
currentGuild
currentPet
```

LibBrokerData only exposes the available Entities.

Example:

```text
characterGold
├── Player-A → 563g
├── Player-B → 421g
└── Player-C → 266g
```

A consumer that wants the current character may use WoW APIs such as:

```lua
UnitGUID("player")
```

and select the matching Entity itself.

This behavior belongs to the consumer, not LibBrokerData.

## 22. Non-normative Broker Panels reference example

A consumer such as Broker Panels may internally refer to a fixed Entity approximately like this:

```lua
{
    sourceType = "LibBrokerData",
    providerID = "MyAccountant",
    fieldID = "characterGold",

    entity = {
        mode = "fixed",
        entityType = "character",
        entityID = "Player-1234-0000ABCD",
    },
}
```

Or it may use its own dynamic selection mode:

```lua
{
    sourceType = "LibBrokerData",
    providerID = "MyAccountant",
    fieldID = "characterGold",

    entity = {
        mode = "currentCharacter",
    },
}
```

`entity.mode` is consumer-specific configuration.

It is not part of LibBrokerData.

LibBrokerData only needs to provide stable source information:

```text
providerID
fieldID
entityType
entityID
entityLabel
```

## 23. LibDataBroker independence

LibBrokerData does not replace LibDataBroker.

An addon may simultaneously publish:

```text
LibDataBroker-1.1
→ classic broker presentation
```

and:

```text
LibBrokerData-1.0
→ structured semantic values
```

Example:

```text
LibDataBroker:
[Gold Icon] 1424g

LibBrokerData:
├── realmGold
├── characterGold
├── sessionIncome
└── sessionExpenses
```

A consumer may use both systems in parallel.

Neither library depends on the other.

## 24. No formatting

LibBrokerData never converts semantic data into final display strings.

Examples:

```text
money:    14244856
percent:  82
duration: 3665
```

A consumer decides how these values appear.

## 25. No UI semantics

LibBrokerData does not define:

- font
- size
- color
- alignment
- line position
- icon position
- tooltip layout
- panel position
- spacing
- visibility behavior

A `status` value such as `warning` does not imply a specific color.

## 26. Persistence

LibBrokerData stores no SavedVariables and has no persistence responsibility.

A Producer owns its source data.

A Consumer owns its configuration.

LibBrokerData only exposes current runtime data.

## 27. Relationship to other WoW libraries

LibBrokerData is an independent implementation.

It uses established architectural ideas common in WoW addon development, such as:

- registries
- Producer/Consumer separation
- stable technical IDs
- callback-based change notifications
- metadata-driven discovery

It is not a fork or derivative implementation of LibDataBroker, DataStore, LibDogTag, Ace libraries, or other third-party libraries.

No third-party source code is required for its implementation.

## 28. Out of scope for 1.0

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
- current-character/current-realm/current-guild/current-pet semantics
- display recommendations for specific consumers

## 29. Example: MyAccountant

```lua
local LBD = _G["LibBrokerData-1.0"]

local provider = LBD:RegisterProvider("MyAccountant", {
    label = "MyAccountant",
    addon = "MyAccountant",
})

provider:RegisterField("realmGold", {
    label = "Realm Gold",
    type = "money",
    scope = "single",
    category = "balance",
    categoryLabel = "Balance",
})

provider:RegisterField("characterGold", {
    label = "Character Gold",
    type = "money",
    scope = "entity",
    entityType = "character",
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

A consumer can display those values freely or combine them with Fields from entirely different Providers.

## 30. Repository structure

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

## 31. Remaining 1.0 decisions before implementation

Before the first implementation, the following points still need to be finalized:

1. concrete `SetValues()` input structure
2. concrete public API return signatures
3. exact library revision upgrade behavior
4. exact conflict behavior for incompatible duplicate registration

The `EVENT_VALUES_CHANGED` payload, `IterateValues()` return shape, Field scope rules, Entity type declaration, and Entity snapshot semantics are defined by Draft 0.3 and should no longer be considered open unless implementation testing reveals a concrete problem.

---

This specification remains a draft until the remaining 1.0 decisions have been finalized and the first implementation has been tested.
