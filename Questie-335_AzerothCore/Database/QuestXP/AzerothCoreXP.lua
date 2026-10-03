---@type QuestXP
local QuestXP = QuestieLoader:ImportModule("QuestXP")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")

local bitband = bit.band
local QUEST_FLAGS_NO_MONEY_FROM_XP = 0x100

function QuestXP.GetEquippedQuestXPMultiplier()
    local multiplier = 1
    for inventorySlot = 1, 19 do
        local itemId = GetInventoryItemID("player", inventorySlot)
        local bonuses = itemId and QuestXP.itemQuestXPBonuses[itemId]
        if bonuses then
            for _, bonusPercent in ipairs(bonuses) do
                multiplier = multiplier * (1 + bonusPercent / 100)
            end
        end
    end
    return multiplier
end

function QuestXP.ResolveQuestLevel(level)
    if level == -1 then
        return UnitLevel("player")
    end
    return level
end

function QuestieCompat.GetProviderExtraQuestRewardMoney(questId)
    if not QuestiePlayer.IsMaxLevel() then
        return 0
    end

    local questFlags = QuestieDB.QueryQuestSingle(questId, "questFlags") or 0
    if bitband(questFlags, QUEST_FLAGS_NO_MONEY_FROM_XP) ~= 0 then
        return 0
    end

    local xpReward = QuestXP:GetQuestLogRewardXP(questId, true, true)
    if xpReward > 0 then
        return xpReward * 6
    end
    return 0
end
