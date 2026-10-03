---@class QuestieDBProvider
local QuestieDBProvider = QuestieLoader:CreateModule("QuestieDBProvider")

-- Version of the raw quest/NPC/object/item data contract, independent of the compiled cache format.
QuestieDBProvider.schemaVersion = 1

local activeProvider

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
