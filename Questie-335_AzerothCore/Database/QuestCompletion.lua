---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

function QuestieDB:IsProviderPrerequisiteCompleted(questId)
    -- Rewarded repeatables stay eligible but still count as prerequisites.
    return QuestieCompat.Is335 and QuestieCompat.IsQuestCompletedOnServer(questId)
end

local function GetDailyCompletionIds()
    local char = Questie.db.char
    char.providerDailyQuestCompletions = char.providerDailyQuestCompletions or {}
    local completions = char.providerDailyQuestCompletions["azerothcore-wotlk"] or {}
    for questId in pairs(char.acoreDailyQuestCompletions or {}) do
        completions[questId] = true
    end
    char.acoreDailyQuestCompletions = nil
    char.providerDailyQuestCompletions["azerothcore-wotlk"] = completions
    return completions
end

function QuestieCompat.GetProviderDailyCompletionIds()
    return GetDailyCompletionIds()
end

function QuestieCompat.ClearProviderDailyCompletions()
    Questie.db.char.acoreDailyQuestCompletions = nil
end

local function EnsureDailyCompletionReset()
    GetDailyCompletionIds()
    QuestieCompat.ResetDailyQuests()
end

function QuestieCompat.SetProviderDailyQuestComplete(questId)
    EnsureDailyCompletionReset()
    GetDailyCompletionIds()[questId] = true
end

function QuestieCompat.IsAzerothCoreDailyQuestComplete(questId)
    EnsureDailyCompletionReset()
    return GetDailyCompletionIds()[questId] == true
end
