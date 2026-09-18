# LibSemanticData

LibSemanticData is a small, dependency-free semantic data and provider-capability library for World of Warcraft addons.

It lets Producer addons publish structured, individually addressable values that Consumers can discover independently of presentation. Providers may also describe their own configurable behavior and executable actions without LibSemanticData creating UI or storing SavedVariables.

## Core principles

- no LibStub dependency
- no CallbackHandler dependency
- no LibDataBroker dependency
- no UI or formatting layer
- no SavedVariables or persistent storage
- stable non-localized technical IDs
- strict localized static metadata with required `enUS`
- `single` and Entity-scoped Field values
- Provider-owned Settings described through a neutral schema
- Provider Actions with abstract `primary` / `secondary` Field interactions
- static/default and dynamic Field icons
- built-in registry and callbacks
- safe use by multiple embedded addon copies

## Data model

```text
Provider
├── Fields
│   ├── Values
│   ├── optional icon
│   └── optional interactions
├── Setting Sections
├── Settings
└── Actions
```

LibSemanticData describes what a Provider offers. A Consumer decides how to display it.

## Localized metadata

Static user-facing metadata uses `LocalizedText`:

```lua
label = {
    enUS = "Display mode",
    deDE = "Anzeigemodus",
}
```

`enUS` is required. Other locales are optional. Resolution is always:

```text
requested locale → enUS
```

There is no additional fallback chain, and LibSemanticData does not call `GetLocale()` to choose a Consumer language.

```lua
local text, resolvedLocale, err = LSD:ResolveLocalizedText(label, "deDE")
```

Technical IDs and values are never localized.

## Field values

The initial Field types are:

```text
text
number
integer
percent
money
duration
boolean
status
progress
```

`money` is an integer copper total, matching normal WoW money APIs. Formatting Gold/Silver/Copper remains Consumer logic.

A `progress` value contains `current`, `maximum`, and optional `minimum`.

## Quick start

```lua
local LSD = _G["LibSemanticData-1.0"]

local provider, err = LSD:RegisterProvider("ExampleAddon", {
    label = {
        enUS = "Example Addon",
        deDE = "Beispiel-Addon",
    },
    addon = "ExampleAddon",
})

local field
field, err = provider:RegisterField("characterGold", {
    label = {
        enUS = "Character Gold",
        deDE = "Charaktergold",
    },
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

A Consumer can discover Providers and Fields without knowing the Producer in advance:

```lua
for providerID, currentProvider in LSD:IterateProviders() do
    for fieldID, currentField in LSD:IterateFields(providerID) do
        print(providerID, fieldID, currentField.type, currentField.scope)
    end
end
```

## Provider Settings

Settings describe Provider-owned behavior. They are not Consumer/display settings.

For example, a Bags Provider may expose an enum describing whether it produces a free, used, free/total, used/total, or percentage display value. Broker Panels does not need Bags-specific code; it only understands the generic Setting schema.

```lua
provider:RegisterSettingSection("display", {
    label = {
        enUS = "Display",
        deDE = "Anzeige",
    },
})

provider:RegisterSetting("displayMode", {
    section = "display",
    type = "enum",
    scope = "single",
    label = {
        enUS = "Display mode",
        deDE = "Anzeigemodus",
    },
    default = "freeTotal",
    choices = {
        {
            value = "free",
            label = { enUS = "Free", deDE = "Frei" },
        },
        {
            value = "used",
            label = { enUS = "Used", deDE = "Belegt" },
        },
        {
            value = "freeTotal",
            label = { enUS = "Free / total", deDE = "Frei / Gesamt" },
        },
    },
}, {
    get = function()
        return providerOwnedSettings.displayMode
    end,
    set = function(value)
        providerOwnedSettings.displayMode = value
    end,
})
```

LibSemanticData never stores the current Setting value. `get` and `set` remain Provider-owned handlers.

Consumers use:

```lua
LSD:GetSettingValue(providerID, settingID, entity)
LSD:SetSettingValue(providerID, settingID, value, entity)
```

## Actions and Field interactions

A Provider can expose behavior without naming concrete mouse buttons:

```lua
provider:RegisterAction("toggleBags", {
    label = {
        enUS = "Open/close bags",
        deDE = "Taschen öffnen/schließen",
    },
}, function(context)
    -- Provider behavior
end)
```

A Field can bind that Action to abstract interactions:

```lua
interactions = {
    primary = "toggleBags",
    secondary = "toggleBags",
}
```

A Consumer such as Broker Panels may map `primary` to left click and `secondary` to right click. LibSemanticData itself does not define that mapping.

## Field icons

A Field may declare a static/default icon using a positive WoW texture File ID or a texture path:

```lua
icon = 133633
```

A Producer may also provide a dynamic icon resolver:

```lua
provider:RegisterField("bag1", info, {
    getIcon = function()
        return currentBagTexture
    end,
})
```

Consumers query the effective icon with:

```lua
LSD:GetFieldIcon(providerID, fieldID)
```

The Consumer decides whether to display the icon and how large or where it should be.

## Relationship to LibDataBroker

LibSemanticData does not replace LibDataBroker. An addon may publish both at the same time.

LibDataBroker can continue to expose classic ready-to-display broker behavior, while LibSemanticData exposes structured Fields, Provider Settings, semantic Actions, and metadata for Consumers that want deeper integration.

## Specification

See `SPECIFICATION.md` for the normative API contract.

## Status

The current implementation candidate is:

```text
LibSemanticData-1.0
MINOR = 7
```

MINOR 7 is the new pre-release baseline. It adds strict `LocalizedText`, Provider Settings, Provider Actions and abstract Field interactions, and static/dynamic Field icons while retaining the existing Provider → Field → Value model, Entity scopes, typed values, atomic updates, callbacks, snapshots, and `field.origin` provenance metadata.

The runtime implementation has passed syntax and local smoke tests. Full in-game Test Addon validation is still required before the MINOR-7 test status is confirmed.

## License

To be decided before the first public release.
