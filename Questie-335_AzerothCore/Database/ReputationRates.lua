---@type QuestieReputation
local QuestieReputation = QuestieLoader:ImportModule("QuestieReputation")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

---@param questId QuestId
---@param factionId number
---@return number
function QuestieReputation.GetFactionQuestRewardRate(questId, factionId)
    local rates = QuestieCompat.AzerothCoreReputationRates[factionId]
    if not rates then
        return 1
    end

    if QuestieDB.IsDailyQuest(questId) then
        return rates[2]
    elseif QuestieDB.IsWeeklyQuest(questId) then
        return rates[3]
    elseif QuestieDB.IsMonthlyQuest(questId) then
        return rates[4]
    elseif QuestieDB.IsRepeatable(questId) then
        return rates[5]
    end

    return rates[1]
end
