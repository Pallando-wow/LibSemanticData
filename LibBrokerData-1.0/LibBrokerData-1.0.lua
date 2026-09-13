local MAJOR = "LibBrokerData-1.0"
local MINOR = 2

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
    providerMetatable = {
        __index = providerMethods,
    }
    lib._providerMetatable = providerMetatable
else
    providerMetatable.__index = providerMethods
end

local function isValidProviderID(providerID)
    return type(providerID) == "string"
        and providerID ~= ""
        and providerID:match("^[A-Za-z0-9_%.:%-]+$") ~= nil
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

lib.MAJOR = MAJOR
lib.MINOR = MINOR
