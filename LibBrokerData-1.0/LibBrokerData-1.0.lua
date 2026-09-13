local MAJOR = "LibBrokerData-1.0"
local MINOR = 5

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

    if type(info.label) ~= "string" or info.label == "" then
        return nil, "INVALID_VALUE"
    end

    if info.description ~= nil and type(info.description) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    if info.addon ~= nil and type(info.addon) ~= "string" then
        return nil, "INVALID_VALUE"
    end

    return true
end

local function isCompatibleProviderInfo(current, incoming)
    if current.label ~= incoming.label then
        return false
    end

    if incoming.description ~= nil and current.description ~= incoming.description then
        return false
    end

    if incoming.addon ~= nil and current.addon ~= incoming.addon then
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

local function isCompatibleFieldInfo(current, incoming)
    if current.label ~= incoming.label
        or current.type ~= incoming.type
        or current.scope ~= incoming.scope
    then
        return false
    end

    if current.scope == "entity" and current.entityType ~= incoming.entityType then
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

        if incoming[key] ~= nil and current[key] ~= incoming[key] then
            return false
        end
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

lib.EVENT_PROVIDER_REGISTERED = "LibBrokerData_ProviderRegistered"
lib.EVENT_FIELD_REGISTERED = "LibBrokerData_FieldRegistered"
lib.EVENT_VALUES_CHANGED = "LibBrokerData_ValuesChanged"

local supportedEvents = {
    [lib.EVENT_PROVIDER_REGISTERED] = true,
    [lib.EVENT_FIELD_REGISTERED] = true,
    [lib.EVENT_VALUES_CHANGED] = true,
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

local providerObjectIDs = {}
local fieldObjectInfo = {}

state.providerObjectIDs = providerObjectIDs
state.fieldObjectInfo = fieldObjectInfo

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

function providerMethods:RegisterField(fieldID, info)
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
