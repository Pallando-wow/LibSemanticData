local MAJOR = "LibBrokerData-1.0"
local MINOR = 3

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

if type(state.providers) ~= "table" then
    state.providers = {}
end

if type(state.providerInfo) ~= "table" then
    state.providerInfo = {}
end

if type(state.providerOrder) ~= "table" then
    state.providerOrder = {}
end

if type(state.fields) ~= "table" then
    state.fields = {}
end

if type(state.fieldInfo) ~= "table" then
    state.fieldInfo = {}
end

if type(state.fieldOrder) ~= "table" then
    state.fieldOrder = {}
end

if type(state.callbacks) ~= "table" then
    state.callbacks = {}
end

if type(state.callbackTokens) ~= "table" then
    state.callbackTokens = {}
end

if type(state.nextCallbackToken) ~= "number" then
    state.nextCallbackToken = 1
end

local providerMethods = lib._providerMethods

if type(providerMethods) ~= "table" then
    providerMethods = {}
    lib._providerMethods = providerMethods
end

local providerMetatable = lib._providerMetatable

if type(providerMetatable) ~= "table" then
    providerMetatable = { __index = providerMethods }
    lib._providerMetatable = providerMetatable
else
    providerMetatable.__index = providerMethods
end

local fieldMethods = lib._fieldMethods

if type(fieldMethods) ~= "table" then
    fieldMethods = {}
    lib._fieldMethods = fieldMethods
end

local fieldMetatable = lib._fieldMetatable

if type(fieldMetatable) ~= "table" then
    fieldMetatable = { __index = fieldMethods }
    lib._fieldMetatable = fieldMetatable
else
    fieldMetatable.__index = fieldMethods
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

local function isValidProviderID(providerID)
    return type(providerID) == "string"
        and providerID ~= ""
        and providerID:match("^[A-Za-z0-9_%.:%-]+$") ~= nil
end

local function isValidFieldID(fieldID)
    return type(fieldID) == "string"
        and fieldID ~= ""
        and fieldID:match("^[A-Za-z0-9_%.:%-]+$") ~= nil
end

local function isValidEntityType(entityType)
    return type(entityType) == "string"
        and entityType ~= ""
        and entityType:match("^[A-Za-z0-9_%.:%-]+$") ~= nil
end

local function copyTable(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function validateProviderInfo(info)
    if type(info) ~= "table" then
        return nil, "PROVIDER_CONFLICT"
    end

    if type(info.label) ~= "string" or info.label == "" then
        return nil, "PROVIDER_CONFLICT"
    end

    if info.description ~= nil and type(info.description) ~= "string" then
        return nil, "PROVIDER_CONFLICT"
    end

    if info.addon ~= nil and type(info.addon) ~= "string" then
        return nil, "PROVIDER_CONFLICT"
    end

    return true
end

local function isCompatibleProviderInfo(existingInfo, newInfo)
    if existingInfo.label ~= newInfo.label then
        return false
    end

    if newInfo.description ~= nil and existingInfo.description ~= newInfo.description then
        return false
    end

    if newInfo.addon ~= nil and existingInfo.addon ~= newInfo.addon then
        return false
    end

    return true
end

local function validateFieldInfo(info)
    if type(info) ~= "table" then
        return nil, "INVALID_VALUE"
    end

    if type(info.label) ~= "string" or info.label == "" then
        return nil, "INVALID_VALUE"
    end

    if type(info.type) ~= "string" or fieldTypes[info.type] ~= true then
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

    if info.description ~= nil and type(info.description) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if info.unit ~= nil and type(info.unit) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if info.category ~= nil and type(info.category) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if info.categoryLabel ~= nil and type(info.categoryLabel) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    return true
end

local function isCompatibleFieldInfo(existingInfo, newInfo)
    if existingInfo.label ~= newInfo.label
        or existingInfo.type ~= newInfo.type
        or existingInfo.scope ~= newInfo.scope
    then
        return false
    end

    if existingInfo.scope == "entity" and existingInfo.entityType ~= newInfo.entityType then
        return false
    end

    local optionalKeys = {
        "description",
        "unit",
        "category",
        "categoryLabel",
    }

    for index = 1, #optionalKeys do
        local key = optionalKeys[index]

        if newInfo[key] ~= nil and existingInfo[key] ~= newInfo[key] then
            return false
        end
    end

    return true
end

function lib:RegisterProvider(providerID, info)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    local valid, err = validateProviderInfo(info)

    if not valid then
        return nil, err
    end

    local provider = state.providers[providerID]

    if provider ~= nil then
        local existingInfo = state.providerInfo[providerID]

        if not isCompatibleProviderInfo(existingInfo, info) then
            return nil, "PROVIDER_CONFLICT"
        end

        return provider, nil
    end

    provider = setmetatable({
        _lbdProviderID = providerID,
    }, providerMetatable)

    state.providers[providerID] = provider
    state.providerInfo[providerID] = copyTable(info)
    state.providerOrder[#state.providerOrder + 1] = providerID
    state.fields[providerID] = {}
    state.fieldInfo[providerID] = {}
    state.fieldOrder[providerID] = {}

    return provider, nil
end

function lib:GetProvider(providerID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    local provider = state.providers[providerID]

    if provider == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    return provider, nil
end

function lib:IterateProviders()
    local index = 0

    return function()
        index = index + 1

        local providerID = state.providerOrder[index]

        if providerID == nil then
            return nil
        end

        return providerID, state.providers[providerID]
    end
end

function providerMethods:RegisterField(fieldID, info)
    local providerID = self._lbdProviderID

    if state.providers[providerID] ~= self then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local valid, err = validateFieldInfo(info)

    if not valid then
        return nil, err
    end

    local fields = state.fields[providerID]
    local fieldInfo = state.fieldInfo[providerID]
    local fieldOrder = state.fieldOrder[providerID]
    local field = fields[fieldID]

    if field ~= nil then
        local existingInfo = fieldInfo[fieldID]

        if not isCompatibleFieldInfo(existingInfo, info) then
            return nil, "FIELD_CONFLICT"
        end

        return field, nil
    end

    field = setmetatable({
        _lbdProviderID = providerID,
        _lbdFieldID = fieldID,
    }, fieldMetatable)

    fields[fieldID] = field
    fieldInfo[fieldID] = copyTable(info)
    fieldOrder[#fieldOrder + 1] = fieldID

    return field, nil
end

function lib:GetField(providerID, fieldID)
    if not isValidProviderID(providerID) then
        return nil, "INVALID_PROVIDER_ID"
    end

    if state.providers[providerID] == nil then
        return nil, "UNKNOWN_PROVIDER"
    end

    if not isValidFieldID(fieldID) then
        return nil, "INVALID_FIELD_ID"
    end

    local fields = state.fields[providerID]
    local field = fields and fields[fieldID] or nil

    if field == nil then
        return nil, "UNKNOWN_FIELD"
    end

    return field, nil
end

function lib:IterateFields(providerID)
    if not isValidProviderID(providerID) or state.providers[providerID] == nil then
        return function()
            return nil
        end
    end

    local order = state.fieldOrder[providerID]
    local fields = state.fields[providerID]
    local index = 0

    return function()
        index = index + 1

        local fieldID = order[index]

        if fieldID == nil then
            return nil
        end

        return fieldID, fields[fieldID]
    end
end

lib.MAJOR = MAJOR
lib.MINOR = MINOR
