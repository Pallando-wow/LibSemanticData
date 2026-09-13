local MAJOR = "LibBrokerData-1.0"
local MINOR = 1

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

lib.MAJOR = MAJOR
lib.MINOR = MINOR
