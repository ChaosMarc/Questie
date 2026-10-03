---@class QuestieDBProvider
local QuestieDBProvider = QuestieLoader:CreateModule("QuestieDBProvider")

-- Raw quest/NPC/object/item contract, independent of the compiled cache format.
-- Providers may also install optional hooks on core modules before PLAYER_LOGIN.
QuestieDBProvider.schemaVersion = 1

local activeProvider
local coreKeys

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

    activeProvider = provider
end

---@return table provider
function QuestieDBProvider:GetActive()
    if not activeProvider then
        error("No Questie database provider registered")
    end
    return activeProvider
end
