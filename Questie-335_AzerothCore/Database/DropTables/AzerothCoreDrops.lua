---@type DropDB
local DropDB = QuestieLoader:ImportModule("DropDB")
---@type QuestieWotlkAcoreItemDrops
local QuestieWotlkAcoreItemDrops = QuestieLoader:ImportModule("QuestieWotlkAcoreItemDrops")

function DropDB:Initialize()
    if not (Questie.IsWotlk or QuestieCompat.Is335) then
        Questie.Error("ItemDrops: AzerothCore drop data requires WotLK")
        return
    end

    local loader, errorMessage = loadstring(QuestieWotlkAcoreItemDrops.data)
    if not loader then
        error("Failed to load AzerothCore item drop data: " .. errorMessage)
    end
    self:SetProviderDrops(loader(), "azerothcore", "azerothcore.blp")
    QuestieWotlkAcoreItemDrops.data = nil
    collectgarbage()
end
