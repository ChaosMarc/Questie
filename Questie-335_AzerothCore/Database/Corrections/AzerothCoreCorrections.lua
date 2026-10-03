---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type IsleOfQuelDanas
local IsleOfQuelDanas = QuestieLoader:ImportModule("IsleOfQuelDanas")

local QuestieQuestBlacklist = QuestieLoader:ImportModule("QuestieQuestBlacklist")
local QuestieNPCBlacklist = QuestieLoader:ImportModule("QuestieNPCBlacklist")
local QuestieItemBlacklist = QuestieLoader:ImportModule("QuestieItemBlacklist")
local QuestieQuestFixes = QuestieLoader:ImportModule("QuestieQuestFixes")
local QuestieClassicQuestReputationFixes = QuestieLoader:ImportModule("QuestieClassicQuestReputationFixes")
local QuestieNPCFixes = QuestieLoader:ImportModule("QuestieNPCFixes")
local QuestieItemFixes = QuestieLoader:ImportModule("QuestieItemFixes")
local QuestieObjectFixes = QuestieLoader:ImportModule("QuestieObjectFixes")
local QuestieTBCQuestFixes = QuestieLoader:ImportModule("QuestieTBCQuestFixes")
local QuestieTBCNpcFixes = QuestieLoader:ImportModule("QuestieTBCNpcFixes")
local QuestieTBCItemFixes = QuestieLoader:ImportModule("QuestieTBCItemFixes")
local QuestieTBCObjectFixes = QuestieLoader:ImportModule("QuestieTBCObjectFixes")
local QuestieWotlkQuestFixes = QuestieLoader:ImportModule("QuestieWotlkQuestFixes")
local QuestieWotlkNpcFixes = QuestieLoader:ImportModule("QuestieWotlkNpcFixes")
local QuestieWotlkItemFixes = QuestieLoader:ImportModule("QuestieWotlkItemFixes")
local QuestieWotlkObjectFixes = QuestieLoader:ImportModule("QuestieWotlkObjectFixes")
local QuestieItemStartFixes = QuestieLoader:ImportModule("QuestieItemStartFixes")

QuestieCorrections.AQWarEffortQuests = QuestieQuestBlacklist.AQWarEffortQuests
QuestieCorrections.ScourgeInvasionQuests = QuestieQuestBlacklist.ScourgeInvasionQuests
QuestieCorrections.SunsReachQuests = QuestieQuestBlacklist.SunsReachQuests
QuestieCorrections.HIDE_ON_MAP = QuestieQuestBlacklist.HIDE_ON_MAP

local function filterExpansion(values)
    local isClassic = Questie.IsClassic
    local isTBC = Questie.IsTBC
    local isWotlk = Questie.IsWotlk
    for k, v in pairs(values) do
        if v == QuestieCorrections.WOTLK_ONLY then
            if isWotlk then
                values[k] = true
            else
                values[k] = nil
            end
        elseif v == QuestieCorrections.TBC_ONLY then
            if isTBC then
                values[k] = true
            else
                values[k] = nil
            end
        elseif v == QuestieCorrections.CLASSIC_ONLY then
            if isTBC or isWotlk then
                values[k] = nil
            else
                values[k] = true
            end
        elseif v == QuestieCorrections.TBC_AND_WOTLK then
            if isTBC or isWotlk then
                values[k] = true
            else
                values[k] = nil
            end
        elseif v == QuestieCorrections.CLASSIC_AND_TBC then
            if isClassic or isTBC then
                values[k] = true
            else
                values[k] = nil
            end
        end
    end
    return values
end

local function addOverride(overrideTable, newOverrides)
    assert(type(overrideTable) == "table", "Override table must be a table!")
    assert(type(newOverrides) == "table", "New overrides must be a table!")
    for id, data in pairs(newOverrides) do
        assert(type(id) == "number", "Override id must be a number!")
        assert(type(data) == "table", "Override data must be a table!")
        if not overrideTable[id] then
            overrideTable[id] = data
        else
            for key, value in pairs(data) do
                overrideTable[id][key] = value
            end
        end
    end
end

local function LoadCached()
    addOverride(QuestieDB.itemDataOverrides, QuestieItemFixes:LoadFactionFixes())
    addOverride(QuestieDB.npcDataOverrides, QuestieNPCFixes:LoadFactionFixes())
    addOverride(QuestieDB.objectDataOverrides, QuestieObjectFixes:LoadFactionFixes())
    addOverride(QuestieDB.questDataOverrides, QuestieQuestFixes:LoadFactionFixes())

    if Questie.IsTBC or Questie.IsWotlk then
        addOverride(QuestieDB.itemDataOverrides, QuestieTBCItemFixes:LoadFactionFixes())
        addOverride(QuestieDB.npcDataOverrides, QuestieTBCNpcFixes:LoadFactionFixes())
        addOverride(QuestieDB.objectDataOverrides, QuestieTBCObjectFixes:LoadFactionFixes())
        addOverride(QuestieDB.questDataOverrides, QuestieTBCQuestFixes:LoadFactionFixes())
    end

    if Questie.IsWotlk then
        addOverride(QuestieDB.npcDataOverrides, QuestieWotlkNpcFixes:LoadFactionFixes())
        addOverride(QuestieDB.itemDataOverrides, QuestieWotlkItemFixes:LoadFactionFixes())
        addOverride(QuestieDB.objectDataOverrides, QuestieWotlkObjectFixes:LoadFactionFixes())
    end

    QuestieCorrections.questItemBlacklist = filterExpansion(QuestieItemBlacklist:Load())
    QuestieCorrections.questNPCBlacklist = filterExpansion(QuestieNPCBlacklist:Load())
    QuestieCorrections.hiddenQuests = filterExpansion(QuestieQuestBlacklist:Load())

    if Questie.db.profile.isleOfQuelDanasPhase == IsleOfQuelDanas.MAX_ISLE_OF_QUEL_DANAS_PHASES then
        for id, hide in pairs(IsleOfQuelDanas.quests[Questie.db.profile.isleOfQuelDanasPhase]) do
            if QuestieCorrections.hiddenQuests[id] == nil then
                QuestieCorrections.hiddenQuests[id] = hide
            end
        end
    end

    if Questie.IsWotlk then
        for id, hide in pairs(QuestieQuestBlacklist.LoadAutoBlacklistWotlk()) do
            if QuestieCorrections.hiddenQuests[id] == nil then
                QuestieCorrections.hiddenQuests[id] = hide
            end
        end
    end

    if QuestieCompat.Is335 then
        QuestieCompat.LoadBlacklists()
    end
end

local function Load(loadCorrections, validationTables)
    local classicNoNewEntries = Questie.IsTBC or Questie.IsWotlk or QuestieCompat.Is335
    local tbcNoNewEntries = Questie.IsWotlk or QuestieCompat.Is335

    loadCorrections("questData", QuestieClassicQuestReputationFixes:Load(), QuestieDB.questKeysReversed, validationTables, nil, classicNoNewEntries)
    loadCorrections("questData", QuestieQuestFixes:Load(), QuestieDB.questKeysReversed, validationTables, nil, classicNoNewEntries)
    loadCorrections("npcData", QuestieNPCFixes:Load(), QuestieDB.npcKeysReversed, validationTables, nil, classicNoNewEntries)
    loadCorrections("itemData", QuestieItemFixes:Load(), QuestieDB.itemKeysReversed, validationTables, nil, classicNoNewEntries)
    loadCorrections("objectData", QuestieObjectFixes:Load(), QuestieDB.objectKeysReversed, validationTables, nil, classicNoNewEntries)

    if Questie.IsTBC or Questie.IsWotlk then
        loadCorrections("questData", QuestieTBCQuestFixes:Load(), QuestieDB.questKeysReversed, validationTables, nil, tbcNoNewEntries)
        loadCorrections("npcData", QuestieTBCNpcFixes:Load(), QuestieDB.npcKeysReversed, validationTables, nil, tbcNoNewEntries)
        loadCorrections("itemData", QuestieTBCItemFixes:Load(), QuestieDB.itemKeysReversed, validationTables, nil, tbcNoNewEntries)
        loadCorrections("objectData", QuestieTBCObjectFixes:Load(), QuestieDB.objectKeysReversed, validationTables, nil, tbcNoNewEntries)
    end

    if Questie.IsWotlk then
        loadCorrections("questData", QuestieWotlkQuestFixes:Load(), QuestieDB.questKeysReversed, validationTables)
        loadCorrections("npcData", QuestieWotlkNpcFixes:LoadAutomatics(), QuestieDB.npcKeysReversed, validationTables)
        loadCorrections("npcData", QuestieWotlkNpcFixes:Load(), QuestieDB.npcKeysReversed, validationTables)
        loadCorrections("npcData", QuestieWotlkNpcFixes:LoadReverseLinkFixes(), QuestieDB.npcKeysReversed, validationTables)
        loadCorrections("itemData", QuestieWotlkItemFixes:Load(), QuestieDB.itemKeysReversed, validationTables)
        loadCorrections("itemData", QuestieWotlkItemFixes:LoadReverseStartQuestFixes(), QuestieDB.itemKeysReversed, validationTables)
        loadCorrections("objectData", QuestieWotlkObjectFixes:Load(), QuestieDB.objectKeysReversed, validationTables)
        loadCorrections("objectData", QuestieWotlkObjectFixes:LoadReverseLinkFixes(), QuestieDB.objectKeysReversed, validationTables)
    end

    loadCorrections("itemData", QuestieItemStartFixes:LoadAutomaticQuestStarts(), QuestieDB.itemKeysReversed, validationTables, true, true)

    if QuestieCompat.Is335 then
        QuestieCompat.LoadCorrections(loadCorrections, validationTables)
    end
end

QuestieCorrections:SetProviderCorrections({
    Load = Load,
    LoadCached = LoadCached,
})
