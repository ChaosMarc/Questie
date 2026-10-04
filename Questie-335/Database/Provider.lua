---@class QuestieDBProvider
local QuestieDBProvider = QuestieLoader:CreateModule("QuestieDBProvider")

-- Raw quest/NPC/object/item contract, independent of the compiled cache format.
-- Provider addons declare X-Questie-DB-Provider and LoadOnDemand in their TOC.
-- The selected addon may install optional hooks before database initialization.
QuestieDBProvider.schemaVersion = 1

local activeProvider
local coreKeys
local availableProviders = {}
local providerAddons = {}
local selectedProviderId
local selectionRequired
local newProviders = {}

function QuestieDBProvider:Discover()
    local providers = {}
    local addons = {}
    local count = 0
    for index = 1, GetNumAddOns() do
        local addonName, title, _, enabled = GetAddOnInfo(index)
        local id = GetAddOnMetadata(addonName, "X-Questie-DB-Provider")
        if id and enabled and enabled ~= 0 then
            if providers[id] then
                error("Duplicate Questie database provider ID: " .. id)
            end
            providers[id] = title or addonName
            addons[id] = addonName
            count = count + 1
        end
    end
    availableProviders = providers
    providerAddons = addons
    return count
end

function QuestieDBProvider:GetAvailable()
    return availableProviders
end

function QuestieDBProvider:NeedsSelection()
    return selectionRequired
end

function QuestieDBProvider:LoadSelected()
    local count = self:Discover()
    local savedId = Questie.db.global.selectedDBProvider
    local selectedId
    selectionRequired = false

    selectedProviderId = nil
    if count == 1 then
        selectedId = next(availableProviders)
    elseif count > 1 then
        if savedId and availableProviders[savedId] then
            selectedId = savedId
        else
            selectionRequired = true
        end
    end

    local known = Questie.db.global.knownDBProviders
    newProviders = {}
    if savedId and known then
        for id, title in pairs(availableProviders) do
            if not known[id] then
                newProviders[#newProviders + 1] = title
            end
        end
    end
    Questie.db.global.knownDBProviders = {}
    for id in pairs(availableProviders) do
        Questie.db.global.knownDBProviders[id] = true
    end

    if selectedId then
        selectedProviderId = selectedId
        local loaded, reason = LoadAddOn(providerAddons[selectedId])
        if not loaded then
            Questie.Error("Failed to load database provider " .. selectedId .. ": " .. tostring(reason))
            selectionRequired = true
            selectedProviderId = nil
            return
        end
        if not activeProvider or activeProvider.id ~= selectedId then
            error("Database provider " .. selectedId .. " did not register correctly")
        end
        Questie.db.global.selectedDBProvider = selectedId
    end
end

function QuestieDBProvider:NotifySelection()
    local l10n = QuestieLoader:ImportModule("l10n")
    if selectionRequired then
        Questie:Print(l10n("Select a database provider under Advanced settings to enable quest data."))
    end
    for _, title in ipairs(newProviders) do
        Questie:Print(l10n("New database provider available: %s. Choose it under Advanced settings if desired.", title))
    end
    newProviders = {}
end

function QuestieDBProvider:HasActive()
    return activeProvider ~= nil
end

function QuestieDBProvider:CaptureCoreKeys()
    local db = QuestieLoader:ImportModule("QuestieDB")
    coreKeys = {
        questKeys = db.questKeys,
        npcKeys = db.npcKeys,
        objectKeys = db.objectKeys,
        itemKeys = db.itemKeys,
    }
end

function QuestieDBProvider:RestoreCoreKeys()
    if not coreKeys then
        error("Questie database field keys were not initialized")
    end
    local db = QuestieLoader:ImportModule("QuestieDB")
    for key, value in pairs(coreKeys) do
        db[key] = value
    end
end

---@param provider table @id, version, schemaVersion and GetRawData(key)
function QuestieDBProvider:Register(provider)
    if activeProvider then
        error("Questie database provider already registered: " .. activeProvider.id)
    end
    if type(provider) ~= "table"
        or type(provider.id) ~= "string" or provider.id == ""
        or type(provider.version) ~= "string" or provider.version == ""
        or provider.schemaVersion ~= self.schemaVersion
        or type(provider.GetRawData) ~= "function" then
        error("Invalid Questie database provider (expected id, version, schemaVersion " .. self.schemaVersion .. " and GetRawData)")
    end
    if provider.id ~= selectedProviderId then
        error("Unselected Questie database provider attempted to register: " .. provider.id)
    end

    activeProvider = provider
end

---@return table provider
function QuestieDBProvider:GetActive()
    if not activeProvider then
        error("No Questie database provider registered")
    end
    return activeProvider
end
