local corrections = QuestieLoader:ImportModule("QuestieCorrections")
local db = QuestieLoader:ImportModule("QuestieDB")
local isle = QuestieLoader:ImportModule("IsleOfQuelDanas")

local questBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
local npcBlacklist = QuestieLoader:ImportModule("QuestieNPCBlacklist")
local itemBlacklist = QuestieLoader:ImportModule("QuestieItemBlacklist")
local questFixes = QuestieLoader:ImportModule("QuestieQuestFixes")
local reputationFixes = QuestieLoader:ImportModule("QuestieClassicQuestReputationFixes")
local npcFixes = QuestieLoader:ImportModule("QuestieNPCFixes")
local itemFixes = QuestieLoader:ImportModule("QuestieItemFixes")
local objectFixes = QuestieLoader:ImportModule("QuestieObjectFixes")
local tbcQuest = QuestieLoader:ImportModule("QuestieTBCQuestFixes")
local tbcNpc = QuestieLoader:ImportModule("QuestieTBCNpcFixes")
local tbcItem = QuestieLoader:ImportModule("QuestieTBCItemFixes")
local tbcObject = QuestieLoader:ImportModule("QuestieTBCObjectFixes")
local wotlkQuest = QuestieLoader:ImportModule("QuestieWotlkQuestFixes")
local wotlkNpc = QuestieLoader:ImportModule("QuestieWotlkNpcFixes")
local wotlkItem = QuestieLoader:ImportModule("QuestieWotlkItemFixes")
local wotlkObject = QuestieLoader:ImportModule("QuestieWotlkObjectFixes")
local itemStarts = QuestieLoader:ImportModule("QuestieItemStartFixes")

corrections.AQWarEffortQuests = questBlacklist.AQWarEffortQuests
corrections.ScourgeInvasionQuests = questBlacklist.ScourgeInvasionQuests
corrections.SunsReachQuests = questBlacklist.SunsReachQuests

local function filterExpansion(values)
    for id, value in pairs(values) do
        if value == corrections.WOTLK_ONLY then
            values[id] = Questie.IsWotlk or nil
        elseif value == corrections.TBC_ONLY then
            values[id] = Questie.IsTBC or nil
        elseif value == corrections.CLASSIC_ONLY then
            values[id] = Questie.IsClassic or nil
        elseif value == corrections.TBC_AND_WOTLK then
            values[id] = (Questie.IsTBC or Questie.IsWotlk) or nil
        elseif value == corrections.CLASSIC_AND_TBC then
            values[id] = (Questie.IsClassic or Questie.IsTBC) or nil
        end
    end
    return values
end

local function addOverride(overrides, additions)
    for id, data in pairs(additions) do
        if not overrides[id] then
            overrides[id] = data
        else
            for key, value in pairs(data) do
                overrides[id][key] = value
            end
        end
    end
end

local function LoadCached()
    addOverride(db.itemDataOverrides, itemFixes:LoadFactionFixes())
    addOverride(db.npcDataOverrides, npcFixes:LoadFactionFixes())
    addOverride(db.objectDataOverrides, objectFixes:LoadFactionFixes())
    addOverride(db.questDataOverrides, questFixes:LoadFactionFixes())

    addOverride(db.itemDataOverrides, tbcItem:LoadFactionFixes())
    addOverride(db.npcDataOverrides, tbcNpc:LoadFactionFixes())
    addOverride(db.objectDataOverrides, tbcObject:LoadFactionFixes())
    addOverride(db.questDataOverrides, tbcQuest:LoadFactionFixes())

    addOverride(db.npcDataOverrides, wotlkNpc:LoadFactionFixes())
    addOverride(db.itemDataOverrides, wotlkItem:LoadFactionFixes())
    addOverride(db.objectDataOverrides, wotlkObject:LoadFactionFixes())

    corrections.questItemBlacklist = filterExpansion(itemBlacklist:Load())
    corrections.questNPCBlacklist = filterExpansion(npcBlacklist:Load())
    corrections.hiddenQuests = filterExpansion(questBlacklist:Load())

    if Questie.db.profile.isleOfQuelDanasPhase == isle.MAX_ISLE_OF_QUEL_DANAS_PHASES then
        for id, hidden in pairs(isle.quests[Questie.db.profile.isleOfQuelDanasPhase]) do
            if corrections.hiddenQuests[id] == nil then
                corrections.hiddenQuests[id] = hidden
            end
        end
    end
    for id, hidden in pairs(questBlacklist.LoadAutoBlacklistWotlk()) do
        if corrections.hiddenQuests[id] == nil then
            corrections.hiddenQuests[id] = hidden
        end
    end
    QuestieCompat.LoadBlacklists()
end

local function Load(apply, validation)
    questFixes:LoadMissingQuests()
    apply("questData", reputationFixes:Load(), db.questKeysReversed, validation)
    apply("questData", questFixes:Load(), db.questKeysReversed, validation)
    apply("npcData", npcFixes:Load(), db.npcKeysReversed, validation)
    apply("itemData", itemFixes:Load(), db.itemKeysReversed, validation)
    apply("objectData", objectFixes:Load(), db.objectKeysReversed, validation)
    apply("questData", tbcQuest:Load(), db.questKeysReversed, validation)
    apply("npcData", tbcNpc:Load(), db.npcKeysReversed, validation)
    apply("itemData", tbcItem:Load(), db.itemKeysReversed, validation)
    apply("objectData", tbcObject:Load(), db.objectKeysReversed, validation)
    apply("questData", wotlkQuest:Load(), db.questKeysReversed, validation)
    apply("npcData", wotlkNpc:LoadAutomatics(), db.npcKeysReversed, validation)
    apply("npcData", wotlkNpc:Load(), db.npcKeysReversed, validation)
    apply("itemData", wotlkItem:Load(), db.itemKeysReversed, validation)
    apply("objectData", wotlkObject:Load(), db.objectKeysReversed, validation)
    apply("itemData", itemStarts:LoadAutomaticQuestStarts(), db.itemKeysReversed, validation, true, true)
    QuestieCompat.LoadCorrections(apply, validation)
end

corrections:SetProviderCorrections({
    Load = Load,
    LoadCached = LoadCached,
})
