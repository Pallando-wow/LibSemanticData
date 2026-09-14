# LibBrokerData-1.0 Specification

**Status:** Draft 0.8 – implementation candidate
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

The first complete core implementation described by this draft uses:

```lua
lib.MINOR = 6
```

`MINOR` is an implementation revision, not part of the public API identity.

A newer embedded implementation must upgrade the existing global library table in place so that existing providers, fields, values, callbacks, and registration order are preserved.

A future incompatible API may use a separate global identity such as:

```lua
_G["LibBrokerData-2.0"]
```


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

### 6.3 Provider metadata immutability and access

After successful registration, Provider metadata is immutable for the remainder of the current session.

The Provider object returned by `RegisterProvider()` and `GetProvider()` exposes registered metadata through read-only property access.

Example:

```lua
local provider = LBD:GetProvider("MyAccountant")

print(provider.label)
print(provider.description)
print(provider.addon)
```

Unknown Provider metadata stored at registration may also be exposed through the Provider object.

Consumers must treat Provider objects and their exposed metadata as read-only.

A compatible duplicate registration returns the existing Provider object.

An incompatible redefinition is a conflict.


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
| `origin` | no | structured technical origin reference |

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

### 7.3 Field metadata immutability and access

After successful registration, Field metadata is immutable for the remainder of the current session.

The Field object returned by `RegisterField()` and `GetField()` exposes registered metadata through read-only property access.

Example:

```lua
local field = LBD:GetField("MyAccountant", "characterGold")

print(field.label)
print(field.type)
print(field.scope)
print(field.entityType)
```

Unknown Field metadata stored at registration may also be exposed through the Field object.

Consumers must treat Field objects and their exposed metadata as read-only.

A compatible duplicate registration returns the existing Field object.

Changing the semantic meaning of a Field is a conflict. This includes changing its `type`, `scope`, or declared `entityType`.

For example, changing a Field from `money` to `text`, from `single` to `entity`, or from `entityType = "character"` to another Entity type is incompatible.

### 7.4 Field origin metadata

A Field may optionally declare the technical source from which its value is derived:

```lua
origin = {
    sourceType = "...",
}
```

`origin` is standardized Field metadata. It describes provenance only. It does not define UI, tooltip, formatting, panel, or Consumer behavior.

General normative rules:

- `origin` is optional.
- when present, `origin` must be a table
- `sourceType` is required and must be a non-empty string
- all `origin` keys must be strings
- additional origin properties may use string, boolean, or finite number values
- nested tables, functions, userdata, threads, and non-finite numbers are not part of the 1.0 origin schema
- unknown `sourceType` values are allowed when these general rules are satisfied
- `origin` is immutable Field metadata and is exposed through the Field object using the same read-only snapshot behavior as other table-valued metadata
- no additional event is emitted for `origin`, because Field metadata does not change after registration

#### 7.4.1 LibDataBroker origin

For a Field derived from a classic LibDataBroker DataObject:

```lua
origin = {
    sourceType = "LibDataBroker-1.1",
    sourceID = "AzerothDeedsInspector",
    attribute = "text",
}
```

Normative rules:

- `sourceID` is required and must be a non-empty string
- `sourceID` is the exact technical LibDataBroker DataObject name, not a display label
- no LibBrokerData technical-ID regular expression is applied to `sourceID`; valid DataObject names may contain spaces, for example `Hunter Threat`
- `attribute` is optional; when present it must be a non-empty string
- common aggregator attributes include `text` and `value`, but LibBrokerData does not restrict the property to those names

#### 7.4.2 LibBrokerData origin

For a Field derived from another LibBrokerData Field:

```lua
origin = {
    sourceType = "LibBrokerData-1.0",
    providerID = "SomeProvider",
    fieldID = "someField",
}
```

Normative rules:

- `providerID` is required and must satisfy the normal LibBrokerData Provider-ID rules
- `fieldID` is required and must satisfy the normal LibBrokerData Field-ID rules
- the reference identifies the technical source Field only; it does not imply a current Entity, display line, formatting rule, or other Consumer context

#### 7.4.3 Duplicate registration compatibility

`origin` participates in standardized Field compatibility checks.

A duplicate Field registration may omit `origin`, like other optional metadata. When `origin` is supplied again, the complete structured origin must be deep-equal to the originally registered value. A different origin is incompatible and returns:

```text
nil, FIELD_CONFLICT
```

The Producer-supplied origin table is copied at registration. Mutating that input table later must not modify registered metadata. A table returned through `field.origin` is likewise a snapshot; mutating it must not modify the registered origin.

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

For LibBrokerData-1.0, the defined Entity keys are `entityType`, `entityID`, and optional `entityLabel`. Additional Entity keys are rejected as `INVALID_ENTITY`.

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

For LibBrokerData-1.0, `entityID` may be:

- a non-empty string, or
- a finite number

The Lua type is part of the identity. Therefore numeric `1` and string `"1"` are distinct Entity IDs.

Implementations must preserve the typed Entity ID strongly enough to avoid collisions. Numeric Entity identity must not derive uniqueness solely from `tostring(entityID)`.

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

For LibBrokerData-1.0, the defined `progress` keys are exactly:

- `current`
- `maximum`
- optional `minimum`

Additional keys are rejected as `INVALID_VALUE`.

Progress tables are logical immutable value snapshots.

Normative rules:

- Producers must publish a new table when changing progress data.
- LibBrokerData must not keep a Producer-owned progress table as mutable shared state.
- The library must capture the submitted progress value as library-owned state.
- A Producer may mutate or reuse its original input table after `SetValue()` or `SetValues()` returns without changing LibBrokerData's stored value.
- Consumers must treat progress tables returned by LibBrokerData as read-only.
- A later value update must not mutate an older progress snapshot that was already returned or delivered in a callback.

## 11. Nil and unavailable data

A registered Field remains registered even when no current value exists.

Setting a value to `nil` means:

> The Field exists, but no current value is available for that value scope.

A consumer decides whether to hide the value, show a placeholder, hide a complete line, or use another presentation.

## 12. Producer API

The Producer API for 1.0 includes:

```lua
LBD:RegisterProvider(providerID, info)

provider:RegisterField(fieldID, info)

provider:SetValue(fieldID, value)
provider:SetValue(fieldID, value, entity)

provider:SetValues(values)
```

`RegisterProvider` returns a Provider object.

`RegisterField` returns a Field object.

The public return signatures for 1.0 are defined below.

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

`SetValues()` updates several values as one atomic operation.

The input is an array of update records.

Example:

```lua
provider:SetValues({
    {
        fieldID = "realmGold",
        value = 14244856,
    },

    {
        fieldID = "characterGold",
        value = 5639221,
        entity = {
            entityType = "character",
            entityID = "Player-1234-0000ABCD",
            entityLabel = "Pitronas",
        },
    },

    {
        fieldID = "characterGold",
        value = 4250000,
        entity = {
            entityType = "character",
            entityID = "Player-1234-0000EF01",
            entityLabel = "Temlin",
        },
    },
})
```

Each update record contains:

| Key | Required | Meaning |
| --- | --- | --- |
| `fieldID` | yes | target Field |
| `value` | no | new value; omitted or `nil` means unavailable/remove current value |
| `entity` | depends on scope | required for `scope = "entity"`, forbidden for `scope = "single"` |

Required behavior:

1. validate the complete batch before applying any change
2. reject the complete batch if any update is invalid
3. apply all valid changes only after successful validation
4. update Entity metadata where applicable
5. emit at most one consolidated `EVENT_VALUES_CHANGED` event afterward
6. never expose a partially updated logical set through the change event

For `scope = "single"` the target identity is:

```text
fieldID
```

For `scope = "entity"` the target identity is:

```text
fieldID + entityType + entityID
```

The same target may occur only once in one `SetValues()` batch.

A duplicate target in the same batch is rejected with:

```text
DUPLICATE_UPDATE
```

For a `scope = "single"` Field, a missing or `nil` value marks the current value as unavailable.

For a `scope = "entity"` Field, a missing or `nil` value removes the current value for the specified Entity.

Entity identity remains known only while a current value exists unless the Producer publishes that Entity again later.

`SetValues()` returns the number of effective changes made.

If validation fails, no change is applied.

## 13. Public return signatures

The public API uses explicit return values for normal validation and lookup failures.

### 13.1 Registration

```lua
LBD:RegisterProvider(providerID, info)
→ provider, err
```

```lua
provider:RegisterField(fieldID, info)
→ field, err
```

On success:

```text
object, nil
```

On failure:

```text
nil, ERROR_CODE
```

### 13.2 Value updates

```lua
provider:SetValue(fieldID, value)
provider:SetValue(fieldID, value, entity)
→ changed, err
```

On success:

```text
true, nil
```

if an effective value or Entity metadata change occurred, otherwise:

```text
false, nil
```

On failure:

```text
nil, ERROR_CODE
```

`SetValues()` returns:

```lua
provider:SetValues(updates)
→ changedCount, err
```

On success, `changedCount` is the number of effective change records generated.

On validation failure:

```text
nil, ERROR_CODE
```

and no changes are applied.

### 13.3 Lookups

```lua
LBD:GetProvider(providerID)
→ provider, err
```

```lua
LBD:GetField(providerID, fieldID)
→ field, err
```

For values:

```lua
LBD:GetValue(providerID, fieldID)
LBD:GetValue(providerID, fieldID, entityType, entityID)
→ value, entity, err
```

For a Field with `scope = "single"`:

```lua
LBD:GetValue(providerID, fieldID)
```

is valid and returns:

```text
value, nil, nil
```

If Entity arguments are supplied for a `single` Field, the call returns:

```text
nil, nil, ENTITY_NOT_ALLOWED
```

For a Field with `scope = "entity"`:

```lua
LBD:GetValue(providerID, fieldID, entityType, entityID)
```

is required.

If the Entity arguments are omitted, the call returns:

```text
nil, nil, ENTITY_REQUIRED
```

If `entityType` does not match the Field's declared Entity type, the call returns:

```text
nil, nil, ENTITY_TYPE_MISMATCH
```

If the Entity identity is malformed, the call returns:

```text
nil, nil, INVALID_ENTITY
```

For an existing Entity-scoped value, the result is:

```text
value, entitySnapshot, nil
```

If a valid Field and valid Entity identity currently have no value, the result is:

```text
nil, nil, nil
```

A valid but currently absent Entity is therefore not an API error.

For an invalid Provider or Field lookup:

```text
nil, nil, ERROR_CODE
```

### 13.4 Iterators

Iterator functions return iterators only and do not return normal API error codes.

The signatures are:

```lua
for providerID, provider in LBD:IterateProviders() do
    ...
end
```

```lua
for fieldID, field in LBD:IterateFields(providerID) do
    ...
end
```

```lua
for value, entity in LBD:IterateValues(providerID, fieldID) do
    ...
end
```

An unknown Provider or Field produces an empty iterator.

### 13.5 Callbacks

```lua
LBD:RegisterCallback(event, callback)
→ token, err
```

On success:

```text
token, nil
```

The token is opaque to the Consumer.

Unsupported events return:

```text
nil, INVALID_EVENT
```

A non-callable callback returns:

```text
nil, INVALID_CALLBACK
```

Callback removal uses:

```lua
LBD:UnregisterCallback(token)
→ removed, err
```

If the token was registered and removed:

```text
true, nil
```

If the token is well-formed but is no longer registered:

```text
false, nil
```

An invalid token representation returns:

```text
nil, INVALID_CALLBACK_TOKEN
```

## 14. Consumer API

The Consumer API for 1.0 includes:

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

## 15. IterateValues

`IterateValues(providerID, fieldID)` returns:

```lua
for value, entity in LBD:IterateValues(providerID, fieldID) do
    ...
end
```

For a `single` Field with a current value:

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

Consumers must treat returned Entity tables and table-valued values as read-only.

`IterateValues()` returns only currently available values.

A `nil` value is never yielded because `nil` in the iterator's first return position would terminate Lua iteration.

Removing or marking a value unavailable therefore removes it from `IterateValues()` output.

For Entity-scoped Fields:

- values are iterated in first-seen order
- changing a value does not change its position
- changing Entity metadata does not change its position
- removing an Entity-scoped value removes that Entity from the current order
- publishing the same `entityType + entityID` again after removal appends it to the end as newly seen

## 16. Registration and iteration order

`IterateProviders()` preserves Provider registration order.

`IterateFields()` preserves Field registration order.

`IterateValues()` preserves current first-seen Entity order for Entity-scoped values.

Removal deletes the Entity from that order. If the same Entity is published again later, it is appended to the end as newly seen.

Consumers remain free to apply their own sorting.

## 17. Events and callbacks

LibBrokerData provides its own callback system.

The callback API for 1.0 includes:

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

### 17.1 Provider registered

```lua
callback(providerID, provider)
```

### 17.2 Field registered

```lua
callback(providerID, fieldID, field)
```

### 17.3 Values changed

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

Boolean `false` is a valid Value and is distinct from `nil`.

For example, a change from:

```lua
false
```

to:

```lua
true
```

must report:

```lua
oldValue = false
newValue = true
```

It must not report `oldValue = nil`.

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

### 17.4 Entity change cases

For an Entity-scoped value, the four relevant change shapes are:

New Entity-scoped value:

```lua
oldValue = nil
newValue = 5639221
oldEntity = nil
newEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
```

Existing Entity-scoped value changed:

```lua
oldValue = 5500000
newValue = 5639221
oldEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
newEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
```

Entity metadata-only change:

```lua
oldValue = 5639221
newValue = 5639221
oldEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
newEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas-NewName",
}
```

Entity-scoped value removed:

```lua
oldValue = 5639221
newValue = nil
oldEntity = {
    entityType = "character",
    entityID = "Player-1234-0000ABCD",
    entityLabel = "Pitronas",
}
newEntity = nil
```

For `scope = "single"` Fields, both `oldEntity` and `newEntity` are always `nil`. Creation, update, and removal are represented only through `oldValue` and `newValue`.

### 17.5 VALUES_CHANGED rules

The following rules are normative:

- `fieldID` is always present.
- `oldValue` is the previous effective value snapshot.
- `newValue` is the new effective value snapshot.
- `oldEntity` and `newEntity` are `nil` for `scope = "single"` values.
- For a newly created Entity-scoped value, `oldEntity` is `nil` and `newEntity` is the new Entity snapshot.
- For a removed Entity-scoped value, `oldEntity` is the previous Entity snapshot and `newEntity` is `nil`.
- For an existing Entity-scoped value, both Entity snapshots are present unless creation or removal is being represented.
- `entityType` and `entityID` identify an Entity.
- Entity metadata may change without changing Entity identity.
- `SetValues()` may produce multiple change records in one event.
- No change record is produced when neither the effective value nor Entity metadata changed.
- An Entity metadata-only change produces a change record even when `oldValue` and `newValue` are equal.
- Consumers must be able to determine whether a displayed source reference is affected without rereading the complete Provider.
- After the callback begins, normal getters and iterators expose the new state.
- Consumers must treat `oldValue`, `newValue`, `oldEntity`, and `newEntity` table values as read-only snapshots.
- A later library update must never mutate table-valued snapshots already delivered in an earlier callback.
- A Producer's later mutation of an input table passed to `SetValue()` or `SetValues()` must not alter stored values or callback snapshots.

Using `oldEntity` and `newEntity` rather than flattening Entity metadata keeps the callback format extensible if optional Entity metadata is added later.

### 17.6 Entity snapshot semantics

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

The library must implement Entity metadata with snapshot/replacement semantics rather than mutating a previously published Entity metadata table in place.

The library must capture Producer-supplied Entity metadata as library-owned state. A Producer may mutate or reuse its original Entity table after `SetValue()` or `SetValues()` returns without changing the Entity metadata stored by LibBrokerData.

This guarantees that old callback snapshots remain stable across later metadata changes.

## 18. Callback isolation

A failing consumer must not prevent remaining callbacks from running.

Callbacks are isolated from one another.

The implementation should use WoW-compatible protected error handling.

## 19. Load order

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

## 20. Duplicate registration

Provider and Field registration is idempotent when repeated registration is compatible.

Registering the same Provider ID again:

- does not create a second Provider
- does not discard values
- does not duplicate the registration event
- returns the existing Provider

Registering the same Field ID again under the same Provider follows the same principle.

Optional metadata may be omitted in a duplicate registration.

If an optional metadata key is supplied again, it must match the original registered value.

Provider compatibility checks use the standardized Provider metadata:

```text
label
description
addon
```

Field compatibility checks use the standardized semantic Field metadata:

```text
label
description
type
scope
entityType
unit
category
categoryLabel
origin
```

Changing `type`, `scope`, or `entityType` is always incompatible.

An incompatible Provider registration returns:

```text
nil, PROVIDER_CONFLICT
```

An incompatible Field registration returns:

```text
nil, FIELD_CONFLICT
```

The existing registration is not modified.

## 21. Embedded MINOR revision upgrade behavior

Multiple addons may embed different implementation revisions of `LibBrokerData-1.0`.

Example:

```text
Addon A → MINOR 3
Addon B → MINOR 5
Addon C → MINOR 2
```

The first loaded revision initializes the shared global library table.

When a newer MINOR revision loads, it upgrades the existing library in place.

The following state must be preserved:

- Provider registry
- Field registry
- current values
- Entity metadata
- callbacks
- Provider registration order
- Field registration order
- current first-seen Entity order
- existing Provider object identity
- existing Field object identity
- the existing global library table identity

The global table:

```lua
_G["LibBrokerData-1.0"]
```

must never be replaced during a compatible MINOR upgrade.

A newer implementation may replace or add library methods and perform backward-compatible internal state migrations.

The new `lib.MINOR` value is assigned only after the upgrade and any required migration complete successfully.

If an equal or newer MINOR revision is already loaded, an older embedded copy performs no downgrade and leaves the current implementation untouched.

All MINOR revisions within `LibBrokerData-1.0` must remain backward-compatible with the public 1.0 specification.

## 22. Errors

The public API should prefer explicit return values over intentionally raising Lua errors for normal validation failures.

Stable error identifiers for 1.0 include:

```text
INVALID_PROVIDER_ID
UNKNOWN_PROVIDER

INVALID_FIELD_ID
UNKNOWN_FIELD
INVALID_FIELD_TYPE

INVALID_VALUE

INVALID_ENTITY
ENTITY_REQUIRED
ENTITY_NOT_ALLOWED
ENTITY_TYPE_MISMATCH

DUPLICATE_UPDATE

INVALID_EVENT
INVALID_CALLBACK
INVALID_CALLBACK_TOKEN

PROVIDER_CONFLICT
FIELD_CONFLICT
```

Normal validation failures return these identifiers rather than intentionally raising Lua errors.

Malformed Provider or Field metadata that does not have a more specific error code returns `INVALID_VALUE`. Unsupported Field types return `INVALID_FIELD_TYPE`; malformed Entity metadata returns `INVALID_ENTITY`. A malformed standardized Field `origin` also returns `INVALID_VALUE`.

## 23. Current context is consumer logic

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

## 24. Non-normative Broker Panels reference example

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

## 25. LibDataBroker independence

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

## 26. No formatting

LibBrokerData never converts semantic data into final display strings.

Examples:

```text
money:    14244856
percent:  82
duration: 3665
```

A consumer decides how these values appear.

## 27. No UI semantics

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

## 28. Persistence

LibBrokerData stores no SavedVariables and has no persistence responsibility.

A Producer owns its source data.

A Consumer owns its configuration.

LibBrokerData only exposes current runtime data.

## 29. Relationship to other WoW libraries

LibBrokerData is an independent implementation.

It uses established architectural ideas common in WoW addon development, such as:

- registries
- Producer/Consumer separation
- stable technical IDs
- callback-based change notifications
- metadata-driven discovery

It is not a fork or derivative implementation of LibDataBroker, DataStore, LibDogTag, Ace libraries, or other third-party libraries.

No third-party source code is required for its implementation.

## 30. Out of scope for 1.0

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

## 31. Example: MyAccountant

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

## 32. Repository structure

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

## 33. 1.0 specification status

Draft 0.8 is the implementation-candidate specification for `LibBrokerData-1.0`.

The current implementation revision is:

```text
MINOR = 6
```

The MINOR-6 implementation extends standardized Field metadata with an optional immutable technical origin reference.

Validation for earlier revisions covers Provider/Field discovery, typed Values, `single` and `entity` scopes, atomic batches, callbacks and events, snapshot semantics, ordering, typed Entity identity, strict 1.0 payload validation, MINOR upgrades, migration of existing Entity Values, and downgrade protection. MINOR 6 additionally standardizes immutable Field origin metadata while preserving existing MINOR-5 Producers that do not provide `origin`.

No structural API mismatch is currently known from the implementation/specification audit.

The public 1.0 API remains pre-release until the first real Producer/Consumer integration has been completed and any findings from that integration have been resolved.

---

This specification remains an implementation-candidate draft until the first real Producer/Consumer integration has been completed and the 1.0 API is explicitly declared stable.
