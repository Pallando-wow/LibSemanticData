local MAJOR = "LibSemanticData-1.0"
local MINOR = 7

local existing = _G[MAJOR]

if type(existing) == "table" and type(existing.MINOR) == "number" and existing.MINOR >= MINOR then
    return
end

local lib

if type(existing) == "table" then
    lib = existing
else
    lib = {}
    _G[MAJOR] = lib
end

local state = lib._state

if type(state) ~= "table" then
    state = {}
    lib._state = state
end

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end

    return parent[key]
end

local providers = ensureTable(state, "providers")
local providerInfo = ensureTable(state, "providerInfo")
local providerOrder = ensureTable(state, "providerOrder")
local fields = ensureTable(state, "fields")
local fieldInfo = ensureTable(state, "fieldInfo")
local fieldOrder = ensureTable(state, "fieldOrder")
local values = ensureTable(state, "values")
local fieldHandlers = ensureTable(state, "fieldHandlers")
local settingSections = ensureTable(state, "settingSections")
local settingSectionInfo = ensureTable(state, "settingSectionInfo")
local settingSectionOrder = ensureTable(state, "settingSectionOrder")
local settings = ensureTable(state, "settings")
local settingInfo = ensureTable(state, "settingInfo")
local settingOrder = ensureTable(state, "settingOrder")
local settingHandlers = ensureTable(state, "settingHandlers")
local actions = ensureTable(state, "actions")
local actionInfo = ensureTable(state, "actionInfo")
local actionOrder = ensureTable(state, "actionOrder")
local actionHandlers = ensureTable(state, "actionHandlers")
local callbacks = ensureTable(state, "callbacks")
local callbackTokens = ensureTable(state, "callbackTokens")

if type(state.nextCallbackToken) ~= "number" or state.nextCallbackToken < 1 then
    state.nextCallbackToken = 1
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function cloneValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] ~= nil then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for key, item in pairs(value) do
        result[key] = cloneValue(item, seen)
    end

    return result
end

local function deepEqual(left, right, seen)
    if left == right then
        return true
    end

    if type(left) ~= type(right) then
        return false
    end

    if type(left) ~= "table" then
        return false
    end

    seen = seen or {}
    local rightSeen = seen[left]

    if rightSeen ~= nil and rightSeen[right] then
        return true
    end

    if rightSeen == nil then
        rightSeen = {}
        seen[left] = rightSeen
    end

    rightSeen[right] = true

    for key, value in pairs(left) do
        if not deepEqual(value, right[key], seen) then
            return false
        end
    end

    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end

    return true
end

local function strictArrayLength(value)
    if type(value) ~= "table" then
        return nil
    end

    local count = 0
    local highest = 0

    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key ~= math.floor(key)
        then
            return nil
        end

        count = count + 1

        if key > highest then
            highest = key
        end
    end

    if highest ~= count then
        return nil
    end

    return count
end

local function isValidTechnicalID(value)
    return type(value) == "string"
        and value ~= ""
        and value:match("^[A-Za-z0-9_%.:%-]+$") ~= nil
end

local function isValidProviderID(providerID)
    return isValidTechnicalID(providerID)
end

local function isValidFieldID(fieldID)
    return isValidTechnicalID(fieldID)
end

local function isValidEntityType(entityType)
    return isValidTechnicalID(entityType)
end

local function isValidEntityID(entityID)
    if type(entityID) == "string" then
        return entityID ~= ""
    end

    return isFiniteNumber(entityID)
end

local function isValidLocale(locale)
    return type(locale) == "string"
        and locale:match("^[a-z][a-z][A-Z][A-Z]$") ~= nil
end

local function validateLocalizedText(value)
    if type(value) ~= "table"
        or type(value.enUS) ~= "string"
        or value.enUS == ""
    then
        return nil, "INVALID_LOCALIZED_TEXT"
    end

    for locale, text in pairs(value) do
        if not isValidLocale(locale)
            or type(text) ~= "string"
            or text == ""
        then
            return nil, "INVALID_LOCALIZED_TEXT"
        end
    end

    return true
end

local function validateOptionalLocalizedText(value)
    if value == nil then
        return true
    end

    return validateLocalizedText(value)
end

local function validateIcon(icon)
    if icon == nil then
        return true
    end

    if type(icon) == "number" then
        return isFiniteNumber(icon)
            and icon > 0
            and icon == math.floor(icon)
    end

    return type(icon) == "string" and icon ~= ""
end

local function isValidSettingSectionID(sectionID)
    return isValidTechnicalID(sectionID)
end

local function isValidSettingID(settingID)
    return isValidTechnicalID(settingID)
end

local function isValidActionID(actionID)
    return isValidTechnicalID(actionID)
end

local fieldTypes = {
    text = true,
    number = true,
    integer = true,
    percent = true,
    money = true,
    duration = true,
    boolean = true,
    status = true,
    progress = true,
}

local function validateProviderInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    local valid, validationError = validateLocalizedText(info.label)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.description)

    if not valid then
        return nil, validationError
    end

    if info.addon ~= nil and type(info.addon) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if not validateIcon(info.icon) then
        return nil, "INVALID_ICON"
    end

    return true
end

local function isCompatibleProviderInfo(current, incoming)
    if not deepEqual(current.label, incoming.label) then
        return false
    end

    if incoming.description ~= nil
        and not deepEqual(current.description, incoming.description)
    then
        return false
    end

    if incoming.addon ~= nil and current.addon ~= incoming.addon then
        return false
    end

    if incoming.icon ~= nil and current.icon ~= incoming.icon then
        return false
    end

    return true
end

local function validateOrigin(origin)
    if type(origin) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    if type(origin.sourceType) ~= "string" or origin.sourceType == "" then
        return nil, "INVALID_VALUE"
    end

    for key, value in pairs(origin) do
        if type(key) ~= "string" then
            return nil, "INVALID_VALUE"
        end

        local valueType = type(value)

        if valueType == "number" then
            if not isFiniteNumber(value) then
                return nil, "INVALID_VALUE"
            end
        elseif valueType ~= "string" and valueType ~= "boolean" then
            return nil, "INVALID_VALUE"
        end
    end

    if origin.sourceType == "LibDataBroker-1.1" then
        if type(origin.sourceID) ~= "string" or origin.sourceID == "" then
            return nil, "INVALID_VALUE"
        end

        if origin.attribute ~= nil
            and (type(origin.attribute) ~= "string" or origin.attribute == "")
        then
            return nil, "INVALID_VALUE"
        end
    elseif origin.sourceType == "LibSemanticData-1.0" then
        if not isValidProviderID(origin.providerID)
            or not isValidFieldID(origin.fieldID)
        then
            return nil, "INVALID_VALUE"
        end
    end

    return true
end

local function validateFieldInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    local valid, validationError = validateLocalizedText(info.label)

    if not valid then
        return nil, validationError
    end

    if type(info.type) ~= "string" or not fieldTypes[info.type] then
        return nil, "INVALID_FIELD_TYPE"
    end

    if info.scope ~= "single" and info.scope ~= "entity" then
        return nil, "INVALID_VALUE"
    end

    if info.scope == "entity" then
        if not isValidEntityType(info.entityType) then
            return nil, "INVALID_ENTITY"
        end
    elseif info.entityType ~= nil then
        return nil, "INVALID_ENTITY"
    end

    valid, validationError = validateOptionalLocalizedText(info.description)

    if not valid then
        return nil, validationError
    end

    if info.unit ~= nil and type(info.unit) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if info.category ~= nil and not isValidTechnicalID(info.category) then
        return nil, "INVALID_VALUE"
    end

    valid, validationError = validateOptionalLocalizedText(info.categoryLabel)

    if not valid then
        return nil, validationError
    end

    if not validateIcon(info.icon) then
        return nil, "INVALID_ICON"
    end

    if info.origin ~= nil then
        local originValid, originError = validateOrigin(info.origin)

        if not originValid then
            return nil, originError
        end
    end

    if info.interactions ~= nil then
        if type(info.interactions) ~= "table" then
            return nil, "INVALID_VALUE"
        end

        for key, actionID in pairs(info.interactions) do
            if key ~= "primary" and key ~= "secondary" then
                return nil, "INVALID_VALUE"
            end

            if not isValidActionID(actionID) then
                return nil, "INVALID_ACTION_ID"
            end
        end
    end

    return true
end

local function isCompatibleFieldInfo(current, incoming)
    if not deepEqual(current.label, incoming.label)
        or current.type ~= incoming.type
        or current.scope ~= incoming.scope
    then
        return false
    end

    if current.scope == "entity" and current.entityType ~= incoming.entityType then
        return false
    end

    local optionalScalarKeys = {
        "unit",
        "category",
        "icon",
    }

    for index = 1, #optionalScalarKeys do
        local key = optionalScalarKeys[index]

        if incoming[key] ~= nil and current[key] ~= incoming[key] then
            return false
        end
    end

    local optionalTableKeys = {
        "description",
        "categoryLabel",
        "origin",
        "interactions",
    }

    for index = 1, #optionalTableKeys do
        local key = optionalTableKeys[index]

        if incoming[key] ~= nil and not deepEqual(current[key], incoming[key]) then
            return false
        end
    end

    return true
end

local function validateFieldHandlers(handlers)
    if handlers == nil then
        return true
    end

    if type(handlers) ~= "table" then
        return nil, "INVALID_HANDLER"
    end

    for key, value in pairs(handlers) do
        if key ~= "getIcon" or type(value) ~= "function" then
            return nil, "INVALID_HANDLER"
        end
    end

    return true
end

local settingTypes = {
    boolean = true,
    enum = true,
    number = true,
    string = true,
}

local function validateSettingSectionInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    local valid, validationError = validateLocalizedText(info.label)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.description)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.help)

    if not valid then
        return nil, validationError
    end

    return true
end

local function isCompatibleSettingSectionInfo(current, incoming)
    if not deepEqual(current.label, incoming.label) then
        return false
    end

    if incoming.description ~= nil
        and not deepEqual(current.description, incoming.description)
    then
        return false
    end

    if incoming.help ~= nil and not deepEqual(current.help, incoming.help) then
        return false
    end

    return true
end

local function validateEnumChoices(choices)
    local count = strictArrayLength(choices)

    if count == nil or count < 1 then
        return nil, "INVALID_SETTING_VALUE"
    end

    local seen = {}

    for index = 1, count do
        local choice = choices[index]

        if type(choice) ~= "table"
            or type(choice.value) ~= "string"
            or choice.value == ""
            or seen[choice.value]
        then
            return nil, "INVALID_SETTING_VALUE"
        end

        local valid, validationError = validateLocalizedText(choice.label)

        if not valid then
            return nil, validationError
        end

        valid, validationError = validateOptionalLocalizedText(choice.description)

        if not valid then
            return nil, validationError
        end

        for key in pairs(choice) do
            if key ~= "value" and key ~= "label" and key ~= "description" then
                return nil, "INVALID_SETTING_VALUE"
            end
        end

        seen[choice.value] = true
    end

    return seen
end

local function validateSettingValue(info, value)
    if info.type == "boolean" then
        return type(value) == "boolean"
    end

    if info.type == "string" then
        return type(value) == "string"
    end

    if info.type == "number" then
        if not isFiniteNumber(value) then
            return false
        end

        if info.min ~= nil and value < info.min then
            return false
        end

        if info.max ~= nil and value > info.max then
            return false
        end

        return true
    end

    if info.type == "enum" then
        if type(value) ~= "string" then
            return false
        end

        for index = 1, #info.choices do
            if info.choices[index].value == value then
                return true
            end
        end

        return false
    end

    return false
end

local function validateSettingInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    local valid, validationError = validateLocalizedText(info.label)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.description)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.help)

    if not valid then
        return nil, validationError
    end

    if type(info.type) ~= "string" or not settingTypes[info.type] then
        return nil, "INVALID_SETTING_TYPE"
    end

    if info.scope ~= "single" and info.scope ~= "entity" then
        return nil, "INVALID_VALUE"
    end

    if info.scope == "entity" then
        if not isValidEntityType(info.entityType) then
            return nil, "INVALID_ENTITY"
        end
    elseif info.entityType ~= nil then
        return nil, "INVALID_ENTITY"
    end

    if info.section ~= nil and not isValidSettingSectionID(info.section) then
        return nil, "INVALID_SETTING_SECTION_ID"
    end

    if info.type == "enum" then
        local choicesValid, choicesError = validateEnumChoices(info.choices)

        if not choicesValid then
            return nil, choicesError
        end

        if info.min ~= nil or info.max ~= nil or info.step ~= nil then
            return nil, "INVALID_SETTING_VALUE"
        end
    elseif info.choices ~= nil then
        return nil, "INVALID_SETTING_VALUE"
    end

    if info.type == "number" then
        if info.min ~= nil and not isFiniteNumber(info.min) then
            return nil, "INVALID_SETTING_VALUE"
        end

        if info.max ~= nil and not isFiniteNumber(info.max) then
            return nil, "INVALID_SETTING_VALUE"
        end

        if info.min ~= nil and info.max ~= nil and info.min > info.max then
            return nil, "INVALID_SETTING_VALUE"
        end

        if info.step ~= nil
            and (not isFiniteNumber(info.step) or info.step <= 0)
        then
            return nil, "INVALID_SETTING_VALUE"
        end
    elseif info.min ~= nil or info.max ~= nil or info.step ~= nil then
        return nil, "INVALID_SETTING_VALUE"
    end

    if info.default == nil or not validateSettingValue(info, info.default) then
        return nil, "INVALID_SETTING_VALUE"
    end

    return true
end

local function isCompatibleSettingInfo(current, incoming)
    local requiredKeys = {
        "type",
        "scope",
    }

    if not deepEqual(current.label, incoming.label) then
        return false
    end

    for index = 1, #requiredKeys do
        local key = requiredKeys[index]

        if current[key] ~= incoming[key] then
            return false
        end
    end

    if current.scope == "entity" and current.entityType ~= incoming.entityType then
        return false
    end

    local optionalScalarKeys = {
        "section",
        "min",
        "max",
        "step",
    }

    for index = 1, #optionalScalarKeys do
        local key = optionalScalarKeys[index]

        if incoming[key] ~= nil and current[key] ~= incoming[key] then
            return false
        end
    end

    local optionalTableKeys = {
        "description",
        "help",
        "choices",
    }

    for index = 1, #optionalTableKeys do
        local key = optionalTableKeys[index]

        if incoming[key] ~= nil and not deepEqual(current[key], incoming[key]) then
            return false
        end
    end

    return deepEqual(current.default, incoming.default)
end

local function validateSettingHandlers(handlers)
    if type(handlers) ~= "table"
        or type(handlers.get) ~= "function"
        or type(handlers.set) ~= "function"
    then
        return nil, "INVALID_HANDLER"
    end

    for key in pairs(handlers) do
        if key ~= "get" and key ~= "set" then
            return nil, "INVALID_HANDLER"
        end
    end

    return true
end

local function validateActionInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    local valid, validationError = validateLocalizedText(info.label)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.description)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateOptionalLocalizedText(info.help)

    if not valid then
        return nil, validationError
    end

    return true
end

local function isCompatibleActionInfo(current, incoming)
    if not deepEqual(current.label, incoming.label) then
        return false
    end

    if incoming.description ~= nil
        and not deepEqual(current.description, incoming.description)
    then
        return false
    end

    if incoming.help ~= nil and not deepEqual(current.help, incoming.help) then
        return false
    end

    return true
end

local function validateEntity(entity, expectedEntityType)
    if entity == nil then
        return nil, "ENTITY_REQUIRED"
    end

    if type(entity) ~= "table" then
        return nil, "INVALID_ENTITY"
    end

    if not isValidEntityType(entity.entityType)
        or not isValidEntityID(entity.entityID)
    then
        return nil, "INVALID_ENTITY"
    end

    if entity.entityType ~= expectedEntityType then
        return nil, "ENTITY_TYPE_MISMATCH"
    end

    if entity.entityLabel ~= nil and type(entity.entityLabel) ~= "string" then
        return nil, "INVALID_ENTITY"
    end

    for key in pairs(entity) do
        if key ~= "entityType"
            and key ~= "entityID"
            and key ~= "entityLabel"
        then
            return nil, "INVALID_ENTITY"
        end
    end

    return cloneValue(entity), nil
end

local function validateValue(info, value)
    if value == nil then
        return true
    end

    if info.type == "text" then
        return type(value) == "string"
    end

    if info.type == "number"
        or info.type == "percent"
        or info.type == "duration"
    then
        return isFiniteNumber(value)
    end

    if info.type == "integer" or info.type == "money" then
        return isFiniteNumber(value) and value == math.floor(value)
    end

    if info.type == "boolean" then
        return type(value) == "boolean"
    end

    if info.type == "status" then
        return type(value) == "string"
    end

    if info.type == "progress" then
        if type(value) ~= "table"
            or not isFiniteNumber(value.current)
            or not isFiniteNumber(value.maximum)
            or (value.minimum ~= nil and not isFiniteNumber(value.minimum))
        then
            return false
        end

        for key in pairs(value) do
            if key ~= "minimum"
                and key ~= "current"
                and key ~= "maximum"
            then
                return false
            end
        end

        return true
    end

    return false
end

local function emptyIterator()
    return nil
end

lib.EVENT_PROVIDER_REGISTERED = "LibSemanticData_ProviderRegistered"
lib.EVENT_FIELD_REGISTERED = "LibSemanticData_FieldRegistered"
lib.EVENT_FIELD_ICON_CHANGED = "LibSemanticData_FieldIconChanged"
lib.EVENT_VALUES_CHANGED = "LibSemanticData_ValuesChanged"
lib.EVENT_SETTING_SECTION_REGISTERED = "LibSemanticData_SettingSectionRegistered"
lib.EVENT_SETTING_REGISTERED = "LibSemanticData_SettingRegistered"
lib.EVENT_SETTINGS_CHANGED = "LibSemanticData_SettingsChanged"
lib.EVENT_ACTION_REGISTERED = "LibSemanticData_ActionRegistered"

local supportedEvents = {
    [lib.EVENT_PROVIDER_REGISTERED] = true,
    [lib.EVENT_FIELD_REGISTERED] = true,
    [lib.EVENT_FIELD_ICON_CHANGED] = true,
    [lib.EVENT_VALUES_CHANGED] = true,
    [lib.EVENT_SETTING_SECTION_REGISTERED] = true,
    [lib.EVENT_SETTING_REGISTERED] = true,
    [lib.EVENT_SETTINGS_CHANGED] = true,
    [lib.EVENT_ACTION_REGISTERED] = true,
}

for event in pairs(supportedEvents) do
    if type(callbacks[event]) ~= "table" then
        callbacks[event] = {}
    end
end

local unpackValues = unpack or table.unpack

local function errorHandler(errorValue)
    if type(_G.geterrorhandler) == "function" then
        local handler = _G.geterrorhandler()

        if type(handler) == "function" then
            return handler(errorValue)
        end
    end

    return errorValue
end

local function fireEvent(event, ...)
    local registered = callbacks[event]

    if type(registered) ~= "table" or #registered == 0 then
        return
    end

    local tokens = {}

    for index = 1, #registered do
        tokens[index] = registered[index]
    end

    local arguments = {
        n = select("#", ...),
        ...,
    }

    for index = 1, #tokens do
        local record = callbackTokens[tokens[index]]

        if record ~= nil and record.event == event then
            xpcall(function()
                record.callback(unpackValues(arguments, 1, arguments.n))
            end, errorHandler)
        end
    end
end

local providerMethods = lib._providerMethods

if type(providerMethods) ~= "table" then
    providerMethods = {}
    lib._providerMethods = providerMethods
else
    for key in pairs(providerMethods) do
        providerMethods[key] = nil
    end
end

local fieldMethods = lib._fieldMethods

if type(fieldMethods) ~= "table" then
    fieldMethods = {}
    lib._fieldMethods = fieldMethods
else
    for key in pairs(fieldMethods) do
        fieldMethods[key] = nil
    end
end

local settingSectionMethods = lib._settingSectionMethods

if type(settingSectionMethods) ~= "table" then
    settingSectionMethods = {}
    lib._settingSectionMethods = settingSectionMethods
else
    for key in pairs(settingSectionMethods) do
        settingSectionMethods[key] = nil
    end
end

local settingMethods = lib._settingMethods

if type(settingMethods) ~= "table" then
    settingMethods = {}
    lib._settingMethods = settingMethods
else
    for key in pairs(settingMethods) do
        settingMethods[key] = nil
    end
end

local actionMethods = lib._actionMethods

if type(actionMethods) ~= "table" then
    actionMethods = {}
    lib._actionMethods = actionMethods
else
    for key in pairs(actionMethods) do
        actionMethods[key] = nil
    end
end

local providerObjectIDs = {}
local fieldObjectInfo = {}
local settingSectionObjectInfo = {}
local settingObjectInfo = {}
local actionObjectInfo = {}

state.providerObjectIDs = providerObjectIDs
state.fieldObjectInfo = fieldObjectInfo
state.settingSectionObjectInfo = settingSectionObjectInfo
state.settingObjectInfo = settingObjectInfo
state.actionObjectInfo = actionObjectInfo

local providerMetatable = lib._providerMetatable

if type(providerMetatable) ~= "table" then
    providerMetatable = {}
    lib._providerMetatable = providerMetatable
end

local fieldMetatable = lib._fieldMetatable

if type(fieldMetatable) ~= "table" then
    fieldMetatable = {}
    lib._fieldMetatable = fieldMetatable
end

local settingSectionMetatable = lib._settingSectionMetatable

if type(settingSectionMetatable) ~= "table" then
    settingSectionMetatable = {}
    lib._settingSectionMetatable = settingSectionMetatable
end

local settingMetatable = lib._settingMetatable

if type(settingMetatable) ~= "table" then
    settingMetatable = {}
    lib._settingMetatable = settingMetatable
end

local actionMetatable = lib._actionMetatable

if type(actionMetatable) ~= "table" then
    actionMetatable = {}
    lib._actionMetatable = actionMetatable
end

providerMetatable.__index = function(provider, key)
    local method = providerMethods[key]

    if method ~= nil then
        return method
    end

    local providerID = providerObjectIDs[provider]
    local info = providerID and providerInfo[providerID] or nil

    if info == nil then
        return nil
    end

    local value = info[key]

    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

providerMetatable.__newindex = function()
    error(MAJOR .. " provider objects are read-only", 2)
end

fieldMetatable.__index = function(field, key)
    local method = fieldMethods[key]

    if method ~= nil then
        return method
    end

    local identity = fieldObjectInfo[field]

    if identity == nil then
        return nil
    end

    local info = fieldInfo[identity.providerID]
        and fieldInfo[identity.providerID][identity.fieldID]
        or nil

    if info == nil then
        return nil
    end

    local value = info[key]

    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

fieldMetatable.__newindex = function()
    error(MAJOR .. " field objects are read-only", 2)
end

settingSectionMetatable.__index = function(section, key)
    local method = settingSectionMethods[key]

    if method ~= nil then
        return method
    end

    local identity = settingSectionObjectInfo[section]

    if identity == nil then
        return nil
    end

    local info = settingSectionInfo[identity.providerID]
        and settingSectionInfo[identity.providerID][identity.sectionID]
        or nil

    if info == nil then
        return nil
    end

    local value = info[key]

    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

settingSectionMetatable.__newindex = function()
    error(MAJOR .. " setting section objects are read-only", 2)
end

settingMetatable.__index = function(setting, key)
    local method = settingMethods[key]

    if method ~= nil then
        return method
    end

    local identity = settingObjectInfo[setting]

    if identity == nil then
        return nil
    end

    local info = settingInfo[identity.providerID]
        and settingInfo[identity.providerID][identity.settingID]
        or nil

    if info == nil then
        return nil
    end

    local value = info[key]

    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

settingMetatable.__newindex = function()
    error(MAJOR .. " setting objects are read-only", 2)
end

actionMetatable.__index = function(action, key)
    local method = actionMethods[key]

    if method ~= nil then
        return method
    end

    local identity = actionObjectInfo[action]

    if identity == nil then
        return nil
    end

    local info = actionInfo[identity.providerID]
        and actionInfo[identity.providerID][identity.actionID]
        or nil

    if info == nil then
        return nil
    end

    local value = info[key]

    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

actionMetatable.__newindex = function()
    error(MAJOR .. " action objects are read-only", 2)
end

local function clearObject(object)
    for key in pairs(object) do
        rawset(object, key, nil)
    end
end

local function migrateEntityStore(store)
    if type(store.byKey) ~= "table" then
        store.byKey = {}
    end

    if type(store.order) ~= "table" then
        store.order = {}
    end

    if store.entityKeyMode == "entityID" then
        return
    end

    local oldByKey = store.byKey
    local oldOrder = store.order
    local newByID = {}
    local newOrder = {}

    for index = 1, #oldOrder do
        local oldKey = oldOrder[index]
        local current = oldByKey[oldKey]
        local entity = current and current.entity or nil
        local entityID = entity and entity.entityID or nil

        if isValidEntityID(entityID) and newByID[entityID] == nil then
            newByID[entityID] = current
            newOrder[#newOrder + 1] = entityID
        end
    end

    for _, current in pairs(oldByKey) do
        local entity = current and current.entity or nil
        local entityID = entity and entity.entityID or nil

        if isValidEntityID(entityID) and newByID[entityID] == nil then
            newByID[entityID] = current
            newOrder[#newOrder + 1] = entityID
        end
    end

    store.byKey = newByID
    store.order = newOrder
    store.entityKeyMode = "entityID"
end

local function ensureValueStore(providerID, fieldID, info)
    if type(values[providerID]) ~= "table" then
        values[providerID] = {}
    end

    local store = values[providerID][fieldID]

    if type(store) == "table" and store.scope == info.scope then
        if info.scope == "entity" then
            migrateEntityStore(store)
        end

        return store
    end

    if info.scope == "single" then
        store = {
            scope = "single",
            hasValue = false,
            value = nil,
        }
    else
        store = {
            scope = "entity",
            byKey = {},
            order = {},
            entityKeyMode = "entityID",
        }
    end

    values[providerID][fieldID] = store

    return store
end

for providerID, provider in pairs(providers) do
    if type(provider) == "table" then
        clearObject(provider)
        setmetatable(provider, providerMetatable)
        providerObjectIDs[provider] = providerID
    end

    if type(providerInfo[providerID]) == "table" then
        providerInfo[providerID] = cloneValue(providerInfo[providerID])
    end

    if type(fields[providerID]) ~= "table" then
        fields[providerID] = {}
    end

    if type(fieldInfo[providerID]) ~= "table" then
        fieldInfo[providerID] = {}
    end

    if type(fieldOrder[providerID]) ~= "table" then
        fieldOrder[providerID] = {}
    end

    if type(values[providerID]) ~= "table" then
        values[providerID] = {}
    end

    if type(fieldHandlers[providerID]) ~= "table" then
        fieldHandlers[providerID] = {}
    end

    if type(settingSections[providerID]) ~= "table" then
        settingSections[providerID] = {}
    end

    if type(settingSectionInfo[providerID]) ~= "table" then
        settingSectionInfo[providerID] = {}
    end

    if type(settingSectionOrder[providerID]) ~= "table" then
        settingSectionOrder[providerID] = {}
    end

    if type(settings[providerID]) ~= "table" then
        settings[providerID] = {}
    end

    if type(settingInfo[providerID]) ~= "table" then
        settingInfo[providerID] = {}
    end

    if type(settingOrder[providerID]) ~= "table" then
        settingOrder[providerID] = {}
    end

    if type(settingHandlers[providerID]) ~= "table" then
        settingHandlers[providerID] = {}
    end

    if type(actions[providerID]) ~= "table" then
        actions[providerID] = {}
    end

    if type(actionInfo[providerID]) ~= "table" then
        actionInfo[providerID] = {}
    end

    if type(actionOrder[providerID]) ~= "table" then
        actionOrder[providerID] = {}
    end

    if type(actionHandlers[providerID]) ~= "table" then
        actionHandlers[providerID] = {}
    end

    for fieldID, field in pairs(fields[providerID]) do
        if type(field) == "table" then
            clearObject(field)
            setmetatable(field, fieldMetatable)
            fieldObjectInfo[field] = {
                providerID = providerID,
                fieldID = fieldID,
            }
        end

        local info = fieldInfo[providerID][fieldID]

        if type(info) == "table" then
            fieldInfo[providerID][fieldID] = cloneValue(info)
            ensureValueStore(providerID, fieldID, fieldInfo[providerID][fieldID])
        end
    end

    for sectionID, section in pairs(settingSections[providerID]) do
        if type(section) == "table" then
            clearObject(section)
            setmetatable(section, settingSectionMetatable)
            settingSectionObjectInfo[section] = {
                providerID = providerID,
                sectionID = sectionID,
            }
        end

        if type(settingSectionInfo[providerID][sectionID]) == "table" then
            settingSectionInfo[providerID][sectionID] = cloneValue(
                settingSectionInfo[providerID][sectionID]
            )
        end
    end

    for settingID, setting in pairs(settings[providerID]) do
        if type(setting) == "table" then
            clearObject(setting)
            setmetatable(setting, settingMetatable)
            settingObjectInfo[setting] = {
                providerID = providerID,
                settingID = settingID,
            }
        end

        if type(settingInfo[providerID][settingID]) == "table" then
            settingInfo[providerID][settingID] = cloneValue(
                settingInfo[providerID][settingID]
            )
        end
    end

    for actionID, action in pairs(actions[providerID]) do
        if type(action) == "table" then
            clearObject(action)
            setmetatable(action, actionMetatable)
            actionObjectInfo[action] = {
                providerID = providerID,
                actionID = actionID,
            }
        end

        if type(actionInfo[providerID][actionID]) == "table" then
            actionInfo[providerID][actionID] = cloneValue(
                actionInfo[providerID][actionID]
            )
        end
    end
end

local function getProviderID(provider)
    local providerID = providerObjectIDs[provider]

    if providerID == nil or providers[providerID] ~= provider then
        return nil
    end

    return providerID
end

local function getFieldRecord(providerID, fieldID)
    local providerFields = fields[providerID]

    if type(providerFields) ~= "table" then
        return nil, nil
    end

    local field = providerFields[fieldID]

    if field == nil then
        return nil, nil
    end

    return field, fieldInfo[providerID][fieldID]
end

local function getSettingSectionRecord(providerID, sectionID)
    local providerSections = settingSections[providerID]

    if type(providerSections) ~= "table" then
        return nil, nil
    end

    local section = providerSections[sectionID]

    if section == nil then
        return nil, nil
    end

    return section, settingSectionInfo[providerID][sectionID]
end

local function getSettingRecord(providerID, settingID)
    local providerSettings = settings[providerID]

    if type(providerSettings) ~= "table" then
        return nil, nil, nil
    end

    local setting = providerSettings[settingID]

    if setting == nil then
        return nil, nil, nil
    end

    return setting,
        settingInfo[providerID][settingID],
        settingHandlers[providerID][settingID]
end

local function getActionRecord(providerID, actionID)
    local providerActions = actions[providerID]

    if type(providerActions) ~= "table" then
        return nil, nil, nil
    end

    local action = providerActions[actionID]

    if action == nil then
        return nil, nil, nil
    end

    return action,
        actionInfo[providerID][actionID],
        actionHandlers[providerID][actionID]
end

local function validateSettingEntity(info, entity)
    if info.scope == "single" then
        if entity ~= nil then
            return nil, "ENTITY_NOT_ALLOWED"
        end

        return nil, nil
    end

    return validateEntity(entity, info.entityType)
end

local function callSettingGetter(providerID, settingID, info, handlers, entity)
    if type(handlers) ~= "table" or type(handlers.get) ~= "function" then
        return nil, "INVALID_HANDLER"
    end

    local ok, value, providerError = pcall(
        handlers.get,
        entity and cloneValue(entity) or nil
    )

    if not ok then
        return nil, "PROVIDER_ERROR"
    end

    if providerError ~= nil then
        if type(providerError) == "string" and providerError ~= "" then
            return nil, providerError
        end

        return nil, "PROVIDER_ERROR"
    end

    if not validateSettingValue(info, value) then
        return nil, "INVALID_SETTING_VALUE"
    end

    return value, nil
end

local function callSettingSetter(handlers, value, entity)
    if type(handlers) ~= "table" or type(handlers.set) ~= "function" then
        return nil, "INVALID_HANDLER"
    end

    local ok, accepted, providerError = pcall(
        handlers.set,
        value,
        entity and cloneValue(entity) or nil
    )

    if not ok then
        return nil, "PROVIDER_ERROR"
    end

    if providerError ~= nil then
        if type(providerError) == "string" and providerError ~= "" then
            return nil, providerError
        end

        return nil, "PROVIDER_ERROR"
    end

    if accepted == false then
        return nil, "SETTING_REJECTED"
    end

    return true, nil
end

local function callActionHandler(handler, context)
    if type(handler) ~= "function" then
        return nil, "INVALID_HANDLER"
    end

    local ok, accepted, providerError = pcall(
        handler,
        context and cloneValue(context) or nil
    )

    if not ok then
        return nil, "PROVIDER_ERROR"
    end

    if accepted == false then
        if type(providerError) == "string" and providerError ~= "" then
            return nil, providerError
        end

        return nil, "ACTION_REJECTED"
    end

    return true, nil
end

local function removeEntityFromOrder(store, entityID)
    for index = 1, #store.order do
        if store.order[index] == entityID then
            table.remove(store.order, index)
            return
        end
    end
end

local function makePublicValue(value)
    if type(value) == "table" then
        return cloneValue(value)
    end

    return value
end

local function makePublicEntity(entity)
    if entity == nil then
        return nil
    end

    return cloneValue(entity)
end

local function makeChange(fieldID, oldValue, newValue, oldEntity, newEntity)
    return {
        fieldID = fieldID,
        oldValue = makePublicValue(oldValue),
        newValue = makePublicValue(newValue),
        oldEntity = makePublicEntity(oldEntity),
        newEntity = makePublicEntity(newEntity),
    }
end

local function prepareUpdate(providerID, fieldID, value, entity)
    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local field, info = getFieldRecord(providerID, fieldID)

    if field == nil then
        return nil, "UNKNOWN_FIELD"
    end

    if not validateValue(info, value) then
        return nil, "INVALID_VALUE"
    end

    local store = ensureValueStore(providerID, fieldID, info)

    if info.scope == "single" then
        if entity ~= nil then
            return nil, "ENTITY_NOT_ALLOWED"
        end

        if value == nil then
            if not store.hasValue then
                return {
                    changed = false,
                    fieldID = fieldID,
                    scope = "single",
                }, nil
            end

            return {
                changed = true,
                fieldID = fieldID,
                scope = "single",
                remove = true,
                change = makeChange(
                    fieldID,
                    store.value,
                    nil,
                    nil,
                    nil
                ),
            }, nil
        end

        local newValue = makePublicValue(value)

        if store.hasValue and deepEqual(store.value, newValue) then
            return {
                changed = false,
                fieldID = fieldID,
                scope = "single",
            }, nil
        end

        local oldValue = nil

        if store.hasValue then
            oldValue = store.value
        end

        return {
            changed = true,
            fieldID = fieldID,
            scope = "single",
            remove = false,
            value = newValue,
            change = makeChange(
                fieldID,
                oldValue,
                newValue,
                nil,
                nil
            ),
        }, nil
    end

    local entitySnapshot, entityError = validateEntity(entity, info.entityType)

    if entitySnapshot == nil then
        return nil, entityError
    end

    local entityID = entitySnapshot.entityID
    local current = store.byKey[entityID]

    if value == nil then
        if current == nil then
            return {
                changed = false,
                fieldID = fieldID,
                scope = "entity",
                entityID = entityID,
            }, nil
        end

        return {
            changed = true,
            fieldID = fieldID,
            scope = "entity",
            entityID = entityID,
            remove = true,
            change = makeChange(
                fieldID,
                current.value,
                nil,
                current.entity,
                nil
            ),
        }, nil
    end

    local newValue = makePublicValue(value)

    if current ~= nil
        and deepEqual(current.value, newValue)
        and deepEqual(current.entity, entitySnapshot)
    then
        return {
            changed = false,
            fieldID = fieldID,
            scope = "entity",
            entityID = entityID,
        }, nil
    end

    local oldValue = current and current.value
    local oldEntity = current and current.entity

    return {
        changed = true,
        fieldID = fieldID,
        scope = "entity",
        entityID = entityID,
        remove = false,
        value = newValue,
        entity = entitySnapshot,
        isNewEntity = current == nil,
        change = makeChange(
            fieldID,
            oldValue,
            newValue,
            oldEntity,
            entitySnapshot
        ),
    }, nil
end

local function applyPreparedUpdate(providerID, action)
    if not action.changed then
        return
    end

    local info = fieldInfo[providerID][action.fieldID]
    local store = ensureValueStore(providerID, action.fieldID, info)

    if action.scope == "single" then
        if action.remove then
            store.hasValue = false
            store.value = nil
        else
            store.hasValue = true
            store.value = makePublicValue(action.value)
        end

        return
    end

    if action.remove then
        store.byKey[action.entityID] = nil
        removeEntityFromOrder(store, action.entityID)
        return
    end

    store.byKey[action.entityID] = {
        value = makePublicValue(action.value),
        entity = makePublicEntity(action.entity),
    }

    if action.isNewEntity then
        store.order[#store.order + 1] = action.entityID
    end
end

function lib:ResolveLocalizedText(localizedText, locale)
    local valid, validationError = validateLocalizedText(localizedText)

    if not valid then
        return nil, nil, validationError
    end

    if not isValidLocale(locale) then
        return nil, nil, "INVALID_LOCALE"
    end

    if localizedText[locale] ~= nil then
        return localizedText[locale], locale, nil
    end

    return localizedText.enUS, "enUS", nil
end

function lib:RegisterCallback(event, callback)
    if not supportedEvents[event] then
        return nil, "INVALID_EVENT"
    end

    if type(callback) ~= "function" then
        return nil, "INVALID_CALLBACK"
    end

    local token = state.nextCallbackToken
    state.nextCallbackToken = token + 1

    callbackTokens[token] = {
        event = event,
        callback = callback,
    }

    local registered = callbacks[event]
    registered[#registered + 1] = token

    return token, nil
end

function lib:UnregisterCallback(token)
    if type(token) ~= "number"
        or token < 1
        or token ~= math.floor(token)
    then
        return nil, "INVALID_CALLBACK_TOKEN"
    end

    local record = callbackTokens[token]

    if record == nil then
        return false, nil
    end

    callbackTokens[token] = nil

    local registered = callbacks[record.event]

    if type(registered) == "table" then
        for index = 1, #registered do
            if registered[index] == token then
                table.remove(registered, index)
                break
            end
        end
    end

    return true, nil
end

function lib:RegisterProvider(providerID, info)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    local valid, validationError = validateProviderInfo(info)

    if not valid then
        return nil, validationError
    end

    local provider = providers[providerID]

    if provider ~= nil then
        local current = providerInfo[providerID]

        if not isCompatibleProviderInfo(current, info) then
            return nil, "PROVIDER_CONFLICT"
        end

        return provider, nil
    end

    provider = setmetatable({}, providerMetatable)

    providers[providerID] = provider
    providerInfo[providerID] = cloneValue(info)
    providerOrder[#providerOrder + 1] = providerID
    fields[providerID] = {}
    fieldInfo[providerID] = {}
    fieldOrder[providerID] = {}
    values[providerID] = {}
    fieldHandlers[providerID] = {}
    settingSections[providerID] = {}
    settingSectionInfo[providerID] = {}
    settingSectionOrder[providerID] = {}
    settings[providerID] = {}
    settingInfo[providerID] = {}
    settingOrder[providerID] = {}
    settingHandlers[providerID] = {}
    actions[providerID] = {}
    actionInfo[providerID] = {}
    actionOrder[providerID] = {}
    actionHandlers[providerID] = {}
    providerObjectIDs[provider] = providerID

    fireEvent(
        lib.EVENT_PROVIDER_REGISTERED,
        providerID,
        provider
    )

    return provider, nil
end

function lib:GetProvider(providerID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    local provider = providers[providerID]

    if provider == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    return provider, nil
end

function lib:IterateProviders()
    local index = 0

    return function()
        index = index + 1

        local providerID = providerOrder[index]

        if providerID == nil then
            return nil
        end

        return providerID, providers[providerID]
    end
end

function providerMethods:RegisterAction(actionID, info, handler)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidActionID(actionID) then
        return nil, "INVALID_ACTION_ID"
    end

    local valid, validationError = validateActionInfo(info)

    if not valid then
        return nil, validationError
    end

    if type(handler) ~= "function" then
        return nil, "INVALID_HANDLER"
    end

    local providerActions = actions[providerID]
    local action = providerActions[actionID]

    if action ~= nil then
        if not isCompatibleActionInfo(actionInfo[providerID][actionID], info) then
            return nil, "ACTION_CONFLICT"
        end

        return action, nil
    end

    action = setmetatable({}, actionMetatable)
    providerActions[actionID] = action
    actionInfo[providerID][actionID] = cloneValue(info)
    actionOrder[providerID][#actionOrder[providerID] + 1] = actionID
    actionHandlers[providerID][actionID] = handler
    actionObjectInfo[action] = {
        providerID = providerID,
        actionID = actionID,
    }

    fireEvent(
        lib.EVENT_ACTION_REGISTERED,
        providerID,
        actionID,
        action
    )

    return action, nil
end

function lib:GetAction(providerID, actionID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidActionID(actionID) then
        return nil, "INVALID_ACTION_ID"
    end

    local action = actions[providerID][actionID]

    if action == nil then
        return nil, "UNKNOWN_ACTION"
    end

    return action, nil
end

function lib:IterateActions(providerID)
    if not isValidProviderID(providerID) or providers[providerID] == nil then
        return emptyIterator
    end

    local order = actionOrder[providerID]
    local providerActions = actions[providerID]
    local index = 0

    return function()
        index = index + 1

        local actionID = order[index]

        if actionID == nil then
            return nil
        end

        return actionID, providerActions[actionID]
    end
end

function lib:ExecuteAction(providerID, actionID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidActionID(actionID) then
        return nil, "INVALID_ACTION_ID"
    end

    local action, _, handler = getActionRecord(providerID, actionID)

    if action == nil then
        return nil, "UNKNOWN_ACTION"
    end

    return callActionHandler(handler, nil)
end

function providerMethods:RegisterSettingSection(sectionID, info)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingSectionID(sectionID) then
        return nil, "INVALID_SETTING_SECTION_ID"
    end

    local valid, validationError = validateSettingSectionInfo(info)

    if not valid then
        return nil, validationError
    end

    local providerSections = settingSections[providerID]
    local section = providerSections[sectionID]

    if section ~= nil then
        if not isCompatibleSettingSectionInfo(
            settingSectionInfo[providerID][sectionID],
            info
        ) then
            return nil, "SETTING_SECTION_CONFLICT"
        end

        return section, nil
    end

    section = setmetatable({}, settingSectionMetatable)
    providerSections[sectionID] = section
    settingSectionInfo[providerID][sectionID] = cloneValue(info)
    settingSectionOrder[providerID][#settingSectionOrder[providerID] + 1] = sectionID
    settingSectionObjectInfo[section] = {
        providerID = providerID,
        sectionID = sectionID,
    }

    fireEvent(
        lib.EVENT_SETTING_SECTION_REGISTERED,
        providerID,
        sectionID,
        section
    )

    return section, nil
end

function lib:GetSettingSection(providerID, sectionID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingSectionID(sectionID) then
        return nil, "INVALID_SETTING_SECTION_ID"
    end

    local section = settingSections[providerID][sectionID]

    if section == nil then
        return nil, "UNKNOWN_SETTING_SECTION"
    end

    return section, nil
end

function lib:IterateSettingSections(providerID)
    if not isValidProviderID(providerID) or providers[providerID] == nil then
        return emptyIterator
    end

    local order = settingSectionOrder[providerID]
    local providerSections = settingSections[providerID]
    local index = 0

    return function()
        index = index + 1

        local sectionID = order[index]

        if sectionID == nil then
            return nil
        end

        return sectionID, providerSections[sectionID]
    end
end

function providerMethods:RegisterSetting(settingID, info, handlers)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingID(settingID) then
        return nil, "INVALID_SETTING_ID"
    end

    local valid, validationError = validateSettingInfo(info)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateSettingHandlers(handlers)

    if not valid then
        return nil, validationError
    end

    if info.section ~= nil and settingSections[providerID][info.section] == nil then
        return nil, "UNKNOWN_SETTING_SECTION"
    end

    local providerSettings = settings[providerID]
    local setting = providerSettings[settingID]

    if setting ~= nil then
        if not isCompatibleSettingInfo(settingInfo[providerID][settingID], info) then
            return nil, "SETTING_CONFLICT"
        end

        return setting, nil
    end

    setting = setmetatable({}, settingMetatable)
    providerSettings[settingID] = setting
    settingInfo[providerID][settingID] = cloneValue(info)
    settingOrder[providerID][#settingOrder[providerID] + 1] = settingID
    settingHandlers[providerID][settingID] = handlers
    settingObjectInfo[setting] = {
        providerID = providerID,
        settingID = settingID,
    }

    fireEvent(
        lib.EVENT_SETTING_REGISTERED,
        providerID,
        settingID,
        setting
    )

    return setting, nil
end

function lib:GetSetting(providerID, settingID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingID(settingID) then
        return nil, "INVALID_SETTING_ID"
    end

    local setting = settings[providerID][settingID]

    if setting == nil then
        return nil, "UNKNOWN_SETTING"
    end

    return setting, nil
end

function lib:IterateSettings(providerID)
    if not isValidProviderID(providerID) or providers[providerID] == nil then
        return emptyIterator
    end

    local order = settingOrder[providerID]
    local providerSettings = settings[providerID]
    local index = 0

    return function()
        index = index + 1

        local settingID = order[index]

        if settingID == nil then
            return nil
        end

        return settingID, providerSettings[settingID]
    end
end

function lib:GetSettingValue(providerID, settingID, entity)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingID(settingID) then
        return nil, "INVALID_SETTING_ID"
    end

    local setting, info, handlers = getSettingRecord(providerID, settingID)

    if setting == nil then
        return nil, "UNKNOWN_SETTING"
    end

    local entitySnapshot, entityError = validateSettingEntity(info, entity)

    if entityError ~= nil then
        return nil, entityError
    end

    return callSettingGetter(
        providerID,
        settingID,
        info,
        handlers,
        entitySnapshot
    )
end

function lib:SetSettingValue(providerID, settingID, value, entity)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingID(settingID) then
        return nil, "INVALID_SETTING_ID"
    end

    local setting, info, handlers = getSettingRecord(providerID, settingID)

    if setting == nil then
        return nil, "UNKNOWN_SETTING"
    end

    if not validateSettingValue(info, value) then
        return nil, "INVALID_SETTING_VALUE"
    end

    local entitySnapshot, entityError = validateSettingEntity(info, entity)

    if entityError ~= nil then
        return nil, entityError
    end

    local oldValue, readError = callSettingGetter(
        providerID,
        settingID,
        info,
        handlers,
        entitySnapshot
    )

    if readError ~= nil then
        return nil, readError
    end

    if deepEqual(oldValue, value) then
        return false, nil
    end

    local written, writeError = callSettingSetter(
        handlers,
        value,
        entitySnapshot
    )

    if not written then
        return nil, writeError
    end

    local newValue, newReadError = callSettingGetter(
        providerID,
        settingID,
        info,
        handlers,
        entitySnapshot
    )

    if newReadError ~= nil then
        return nil, newReadError
    end

    if deepEqual(oldValue, newValue) then
        return false, nil
    end

    fireEvent(lib.EVENT_SETTINGS_CHANGED, providerID, {
        {
            settingID = settingID,
            value = newValue,
            entity = entitySnapshot and cloneValue(entitySnapshot) or nil,
        },
    })

    return true, nil
end

function providerMethods:NotifySettingChanged(settingID, entity)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidSettingID(settingID) then
        return nil, "INVALID_SETTING_ID"
    end

    local setting, info, handlers = getSettingRecord(providerID, settingID)

    if setting == nil then
        return nil, "UNKNOWN_SETTING"
    end

    local entitySnapshot, entityError = validateSettingEntity(info, entity)

    if entityError ~= nil then
        return nil, entityError
    end

    local value, readError = callSettingGetter(
        providerID,
        settingID,
        info,
        handlers,
        entitySnapshot
    )

    if readError ~= nil then
        return nil, readError
    end

    fireEvent(lib.EVENT_SETTINGS_CHANGED, providerID, {
        {
            settingID = settingID,
            value = value,
            entity = entitySnapshot and cloneValue(entitySnapshot) or nil,
        },
    })

    return true, nil
end

function providerMethods:RegisterField(fieldID, info, handlers)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local valid, validationError = validateFieldInfo(info)

    if not valid then
        return nil, validationError
    end

    valid, validationError = validateFieldHandlers(handlers)

    if not valid then
        return nil, validationError
    end

    if info.interactions ~= nil then
        for _, actionID in pairs(info.interactions) do
            if actions[providerID][actionID] == nil then
                return nil, "UNKNOWN_ACTION"
            end
        end
    end

    local providerFields = fields[providerID]
    local providerFieldInfo = fieldInfo[providerID]
    local providerFieldOrder = fieldOrder[providerID]
    local field = providerFields[fieldID]

    if field ~= nil then
        local current = providerFieldInfo[fieldID]

        if not isCompatibleFieldInfo(current, info) then
            return nil, "FIELD_CONFLICT"
        end

        return field, nil
    end

    field = setmetatable({}, fieldMetatable)

    providerFields[fieldID] = field
    providerFieldInfo[fieldID] = cloneValue(info)
    providerFieldOrder[#providerFieldOrder + 1] = fieldID
    fieldHandlers[providerID][fieldID] = handlers or {}
    fieldObjectInfo[field] = {
        providerID = providerID,
        fieldID = fieldID,
    }

    ensureValueStore(providerID, fieldID, providerFieldInfo[fieldID])

    fireEvent(
        lib.EVENT_FIELD_REGISTERED,
        providerID,
        fieldID,
        field
    )

    return field, nil
end

function lib:GetField(providerID, fieldID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local field = fields[providerID]
        and fields[providerID][fieldID]
        or nil

    if field == nil then
        return nil, "UNKNOWN_FIELD"
    end

    return field, nil
end

function lib:IterateFields(providerID)
    if not isValidProviderID(providerID)
        or providers[providerID] == nil
    then
        return emptyIterator
    end

    local order = fieldOrder[providerID]
    local providerFields = fields[providerID]
    local index = 0

    return function()
        index = index + 1

        local fieldID = order[index]

        if fieldID == nil then
            return nil
        end

        return fieldID, providerFields[fieldID]
    end
end

function lib:GetFieldIcon(providerID, fieldID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local field, info = getFieldRecord(providerID, fieldID)

    if field == nil then
        return nil, "UNKNOWN_FIELD"
    end

    local handlers = fieldHandlers[providerID][fieldID]

    if type(handlers) == "table" and type(handlers.getIcon) == "function" then
        local ok, dynamicIcon = pcall(handlers.getIcon)

        if not ok then
            return nil, "PROVIDER_ERROR"
        end

        if dynamicIcon ~= nil then
            if not validateIcon(dynamicIcon) then
                return nil, "INVALID_ICON"
            end

            return dynamicIcon, nil
        end
    end

    return info.icon, nil
end

function providerMethods:NotifyFieldIconChanged(fieldID)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    if fields[providerID][fieldID] == nil then
        return nil, "UNKNOWN_FIELD"
    end

    fireEvent(lib.EVENT_FIELD_ICON_CHANGED, providerID, fieldID)

    return true, nil
end

function lib:ExecuteFieldInteraction(
    providerID,
    fieldID,
    interaction,
    entity
)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    if interaction ~= "primary" and interaction ~= "secondary" then
        return nil, "INVALID_INTERACTION"
    end

    local field, info = getFieldRecord(providerID, fieldID)

    if field == nil then
        return nil, "UNKNOWN_FIELD"
    end

    local actionID = info.interactions and info.interactions[interaction] or nil

    if actionID == nil then
        return nil, "INTERACTION_NOT_AVAILABLE"
    end

    local entitySnapshot = nil

    if entity ~= nil then
        if info.scope == "single" then
            return nil, "ENTITY_NOT_ALLOWED"
        end

        local entityError
        entitySnapshot, entityError = validateEntity(entity, info.entityType)

        if entitySnapshot == nil then
            return nil, entityError
        end
    end

    local action, _, handler = getActionRecord(providerID, actionID)

    if action == nil then
        return nil, "UNKNOWN_ACTION"
    end

    return callActionHandler(handler, {
        fieldID = fieldID,
        interaction = interaction,
        entity = entitySnapshot,
    })
end

function providerMethods:SetValue(fieldID, value, entity)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    local action, preparationError = prepareUpdate(
        providerID,
        fieldID,
        value,
        entity
    )

    if action == nil then
        return nil, preparationError
    end

    if not action.changed then
        return false, nil
    end

    applyPreparedUpdate(providerID, action)

    fireEvent(
        lib.EVENT_VALUES_CHANGED,
        providerID,
        { action.change }
    )

    return true, nil
end

function providerMethods:SetValues(updates)
    local providerID = getProviderID(self)

    if providerID == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    local count = strictArrayLength(updates)

    if count == nil then
        return nil, "INVALID_VALUE"
    end

    local actions = {}
    local seenTargets = {}

    for index = 1, count do
        local update = updates[index]

        if type(update) ~= "table" then
            return nil, "INVALID_VALUE"
        end

        local action, preparationError = prepareUpdate(
            providerID,
            update.fieldID,
            update.value,
            update.entity
        )

        if action == nil then
            return nil, preparationError
        end

        local fieldTargets = seenTargets[action.fieldID]

        if fieldTargets == nil then
            fieldTargets = {
                single = false,
                entities = {},
            }
            seenTargets[action.fieldID] = fieldTargets
        end

        if action.scope == "single" then
            if fieldTargets.single then
                return nil, "DUPLICATE_UPDATE"
            end

            fieldTargets.single = true
        else
            if fieldTargets.entities[action.entityID] then
                return nil, "DUPLICATE_UPDATE"
            end

            fieldTargets.entities[action.entityID] = true
        end

        actions[#actions + 1] = action
    end

    local changes = {}

    for index = 1, #actions do
        local action = actions[index]

        if action.changed then
            applyPreparedUpdate(providerID, action)
            changes[#changes + 1] = action.change
        end
    end

    if #changes > 0 then
        fireEvent(
            lib.EVENT_VALUES_CHANGED,
            providerID,
            changes
        )
    end

    return #changes, nil
end

function lib:GetValue(providerID, fieldID, entityType, entityID)
    if not isValidProviderID(providerID) then
        return nil, nil, "INVALID_PROVIDER_ID"
    end

    if providers[providerID] == nil then
        return nil, nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, nil, "INVALID_FIELD_ID"
    end

    local field, info = getFieldRecord(providerID, fieldID)

    if field == nil then
        return nil, nil, "UNKNOWN_FIELD"
    end

    local store = ensureValueStore(providerID, fieldID, info)

    if info.scope == "single" then
        if entityType ~= nil or entityID ~= nil then
            return nil, nil, "ENTITY_NOT_ALLOWED"
        end

        if not store.hasValue then
            return nil, nil, nil
        end

        return makePublicValue(store.value), nil, nil
    end

    if entityType == nil or entityID == nil then
        return nil, nil, "ENTITY_REQUIRED"
    end

    if not isValidEntityType(entityType)
        or not isValidEntityID(entityID)
    then
        return nil, nil, "INVALID_ENTITY"
    end

    if entityType ~= info.entityType then
        return nil, nil, "ENTITY_TYPE_MISMATCH"
    end

    local current = store.byKey[entityID]

    if current == nil then
        return nil, nil, nil
    end

    return makePublicValue(current.value),
        makePublicEntity(current.entity),
        nil
end

function lib:IterateValues(providerID, fieldID)
    if not isValidProviderID(providerID)
        or providers[providerID] == nil
        or not isValidFieldID(fieldID)
    then
        return emptyIterator
    end

    local field, info = getFieldRecord(providerID, fieldID)

    if field == nil then
        return emptyIterator
    end

    local store = ensureValueStore(providerID, fieldID, info)

    if info.scope == "single" then
        local done = false

        return function()
            if done or not store.hasValue then
                return nil
            end

            done = true

            return makePublicValue(store.value), nil
        end
    end

    local index = 0

    return function()
        index = index + 1

        local entityID = store.order[index]

        if entityID == nil then
            return nil
        end

        local current = store.byKey[entityID]

        if current == nil then
            return nil
        end

        return makePublicValue(current.value),
            makePublicEntity(current.entity)
    end
end

lib.MAJOR = MAJOR
lib.MINOR = MINOR
