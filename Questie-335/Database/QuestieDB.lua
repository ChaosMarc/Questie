---@class QuestieDB
local QuestieDB = QuestieLoader:CreateModule("QuestieDB")

---@type QuestieDBPrivate
QuestieDB.private = QuestieDB.private or {}

---@class QuestieDBPrivate
local _QuestieDB = QuestieDB.private

-------------------------
--Import modules.
-------------------------
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type DailyQuests
local DailyQuests = QuestieLoader:ImportModule("DailyQuests")
---@type QuestieReputation
local QuestieReputation = QuestieLoader:ImportModule("QuestieReputation")
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type DBCompiler
local QuestieDBCompiler = QuestieLoader:ImportModule("DBCompiler")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@type DropDB
local DropDB = QuestieLoader:ImportModule("DropDB")

---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieQuestPrivate
local _QuestieQuest = QuestieQuest.private

--- A list of quests that will never be available, used to quickly skip quests.
---@alias AutoBlacklistString "rep"|"skill"|"race"|"class"|"rank"
---@type table<number, AutoBlacklistString>
QuestieDB.autoBlacklist = {}

--- Quests whose availability depends on items currently in the player's bags.
---@type table<number, boolean>
QuestieDB.requiredItemConditionQuestIds = {}

--- Quests whose provider availability expression depends on player auras.
---@type table<number, boolean>
QuestieDB.providerAuraConditionQuestIds = {}

--- Quests whose provider availability expression depends on player location.
---@type table<number, boolean>
QuestieDB.providerLocationConditionQuestIds = {}

local tinsert = table.insert
local bitband = bit.band

-- questFlags https://github.com/cmangos/issues/wiki/Quest_template#questflags
local QUEST_FLAGS_DAILY = 4096
local QUEST_FLAGS_WEEKLY = 32768
-- Pre calculated 2 * QUEST_FLAGS, for testing a bit flag
local QUEST_FLAGS_DAILY_X2 = 2 * QUEST_FLAGS_DAILY
local QUEST_FLAGS_WEEKLY_X2 = 2 * QUEST_FLAGS_WEEKLY
local playerFaction = UnitFactionGroup("Player")

---@type fun(questId: QuestId): boolean|nil
local unavailableQuestChecker

---@enum QuestTagIds
QuestieDB.questTagIds = {
    ELITE = 1,
    CLASS = 21,
    PVP = 41,
    RAID = 62,
    DUNGEON = 81,
    WORLD_EVENT = 82,
    LEGENDARY = 83,
    ESCORT = 84,
    HEROIC = 85,
    RAID_10 = 88,
    RAID_25 = 89,
}
---@enum DoableStates
QuestieDB.DoableStates = {
    AVAILABLE = 0,
    COMPLETED = 1,
    QUEST_LOG = 2,
    BLACKLISTED = 3,
    EXCEED_REPUTATION = 4,
    PARENT_ACTIVE = 5,
    WRONG_RACE = 6,
    NO_PREQUESTSINGLE = 7,
    WRONG_CLASS = 8,
    MISSING_REPUTATION = 9,
    PROFESSION_SKILL = 10,
    NO_PREQUESTGROUP = 11,
    PARENT_INACTIVE = 12,
    NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED = 13,
    EXCLUSIVE_COMPLETED = 14,
    EXCLUSIVE_IN_QUEST_LOG = 15,
    MISSING_DAILY = 16,
    PROFESSION_SPECIALIZATION = 17,
    SPELL_MISSING = 18,
    SPELL_KNOWN = 19,
    MISSING_ACHIEVEMENT = 20,
    BREADCRUMB_FOLLOWUP = 21,
    EVENT_INACTIVE = 22,
    BREADCRUMB_ACTIVE = 23,
    INACTIVE_DAILY = 24,
    LEVEL_TOO_HIGH = 25,
    LEVEL_TOO_LOW = 26,
    DISABLING_QUEST_COMPLETED = 27,
    ENABLING_QUEST_MISSING = 28,
    PROFESSION_MISSING = 29,
    PROFESSION_RANK = 30,
    DISABLED_BY = 31,
    MISSING_START_ITEM = 32,
    PROVIDER_CONDITION = 33,
}

---@param checker fun(questId: QuestId): boolean
function QuestieDB.SetUnavailableQuestChecker(checker)
    unavailableQuestChecker = checker
end

--- COMPATIBILITY ---
local WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_ID
local WOW_PROJECT_CLASSIC = QuestieCompat.WOW_PROJECT_CLASSIC
local C_QuestLog = QuestieCompat.C_QuestLog
local C_Timer = QuestieCompat.C_Timer
local GetQuestTagInfo = QuestieCompat.GetQuestTagInfo
local IsPlayerSpell = QuestieCompat.IsPlayerSpell
local IsSpellKnownOrOverridesKnown = QuestieCompat.IsSpellKnownOrOverridesKnown
local IsQuestFlaggedCompleted = QuestieCompat.IsQuestFlaggedCompleted or C_QuestLog.IsQuestFlaggedCompleted

--- Tag corrections for quests for which the API returns the wrong values.
--- Strucute: [questId] = {tagId, "questType"}
---@type table<number, {[1]: number, [2]: string}>
local questTagCorrections

function QuestieDB.LoadQuestTagCorrections()
    return {}
end

-- race bitmask data, for easy access
local VANILLA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

QuestieDB.raceKeys = {
    ALL_ALLIANCE = VANILLA and 77 or 1101,
    ALL_HORDE = VANILLA and 178 or 690,
    NONE = 0,

    HUMAN = 1,
    ORC = 2,
    DWARF = 4,
    NIGHT_ELF = 8,
    UNDEAD = 16,
    TAUREN = 32,
    GNOME = 64,
    TROLL = 128,
    --GOBLIN = 256,
    BLOOD_ELF = 512,
    DRAENEI = 1024
}

-- Combining these with "and" makes the order matter
-- 1 and 2 ~= 2 and 1
QuestieDB.classKeys = {
    ALL_CLASSES = (function()
        if Questie.IsClassic then
            return playerFaction == "Alliance" and 1439 or 1501
        elseif Questie.IsTBC then
            return 1503
        elseif Questie.IsWotlk or QuestieCompat.Is335 then
            return 1535
        else
            Questie.Error("Unknown expansion for ALL_CLASSES")
            return playerFaction == "Alliance" and 1439 or 1501
        end
    end)(),

    NONE = 0,
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 4,
    ROGUE = 8,
    PRIEST = 16,
    DEATH_KNIGHT = 32,
    SHAMAN = 64,
    MAGE = 128,
    WARLOCK = 256,
    DRUID = 1024
}

QuestieDB.specialFlags = {
    NONE = 0,
    REPEATABLE = 1,
    EXPLORATION_OR_EVENT = 2,
    AUTO_ACCEPT = 4,
    DUNGEON_FINDER_QUEST = 8,
    MONTHLY = 16,
    SPELL_CAST = 32,
    NO_REP_SPILLOVER = 64,
    CAN_FAIL_IN_ANY_STATE = 128,
    NO_LOREMASTER_COUNT = 256,
}

_QuestieDB.questCache = {}; -- stores quest objects so they dont need to be regenerated
_QuestieDB.npcCache = {};

---A Memoized table for function Quest:CheckRace
---
---Usage: checkRace[requiredRaces]
---@type table<number, boolean>
local checkRace
---A Memoized table for function Quest:CheckClass
---
---Usage: checkRace[requiredClasses]
---@type table<number, boolean>
local checkClass

---QuestieCorrections.hiddenQuests
local QuestieCorrectionshiddenQuests
---Questie.db.char.hidden
local Questiedbcharhidden

QuestieDB.itemDataOverrides = {}
QuestieDB.npcDataOverrides = {}
QuestieDB.objectDataOverrides = {}
QuestieDB.questDataOverrides = {}

QuestieDB.activeChildQuests = {}


function QuestieDB:Initialize()

    StaticPopupDialogs["QUESTIE_DATABASE_ERROR"] = { -- /run StaticPopup_Show ("QUESTIE_DATABASE_ERROR")
        text = l10n("There was a problem initializing Questie's database. This can usually be fixed by recompiling the database."),
        button1 = l10n("Recompile Database"),
        button2 = l10n("Don't show again"),
        OnAccept = function()
            Questie.db.global.dbIsCompiled = false
            ReloadUI()
        end,
        OnDecline = function()
            Questie.db.profile.disableDatabaseWarnings = true
        end,
        OnShow = function(self)
            self:SetFrameStrata("TOOLTIP")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3
    }

    questTagCorrections = QuestieDB.LoadQuestTagCorrections()

    -- For now we store the Era/HC database
    local npcBin, npcPtrs, questBin, questPtrs, objBin, objPtrs, itemBin, itemPtrs

    npcBin = Questie.db.global.npcBin
    npcPtrs = Questie.db.global.npcPtrs
    questBin = Questie.db.global.questBin
    questPtrs = Questie.db.global.questPtrs
    objBin = Questie.db.global.objBin
    objPtrs = Questie.db.global.objPtrs
    itemBin = Questie.db.global.itemBin
    itemPtrs = Questie.db.global.itemPtrs

    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieDB:Init] Begin GetDBHandles.")
    local npcSkipMap = QuestieDBCompiler:BuildSkipMap(QuestieDB.npcCompilerTypes, QuestieDB.npcCompilerOrder)
    QuestieDB.QueryNPC = QuestieDBCompiler:GetDBHandle(npcBin, npcPtrs, npcSkipMap, QuestieDB.npcKeys, QuestieDB.npcDataOverrides)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieDB:Init] NPC GetDBHandle complete.")

    local questSkipMap = QuestieDBCompiler:BuildSkipMap(QuestieDB.questCompilerTypes, QuestieDB.questCompilerOrder)
    QuestieDB.QueryQuest = QuestieDBCompiler:GetDBHandle(questBin, questPtrs, questSkipMap, QuestieDB.questKeys, QuestieDB.questDataOverrides)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieDB:Init] Quest GetDBHandle complete.")

    local objectSkipMap = QuestieDBCompiler:BuildSkipMap(QuestieDB.objectCompilerTypes, QuestieDB.objectCompilerOrder)
    QuestieDB.QueryObject = QuestieDBCompiler:GetDBHandle(objBin, objPtrs, objectSkipMap, QuestieDB.objectKeys, QuestieDB.objectDataOverrides)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieDB:Init] Object GetDBHandle complete.")

    local itemSkipMap = QuestieDBCompiler:BuildSkipMap(QuestieDB.itemCompilerTypes, QuestieDB.itemCompilerOrder)
    QuestieDB.QueryItem = QuestieDBCompiler:GetDBHandle(itemBin, itemPtrs, itemSkipMap, QuestieDB.itemKeys, QuestieDB.itemDataOverrides)
    Questie.Debug(Questie.DEBUG_DEVELOP, "[QuestieDB:Init] Item GetDBHandle complete.")

    QuestieDB.NPCPointers = QuestieDB.QueryNPC.pointers
    QuestieDB.QuestPointers = QuestieDB.QueryQuest.pointers
    QuestieDB.ObjectPointers = QuestieDB.QueryObject.pointers
    QuestieDB.ItemPointers = QuestieDB.QueryItem.pointers

    QuestieDB.QueryNPCSingle = QuestieDB.QueryNPC.QuerySingle
    QuestieDB.QueryQuestSingle = QuestieDB.QueryQuest.QuerySingle
    QuestieDB.QueryObjectSingle = QuestieDB.QueryObject.QuerySingle
    QuestieDB.QueryItemSingle = QuestieDB.QueryItem.QuerySingle

    QuestieDB.QueryNPC = QuestieDB.QueryNPC.Query
    QuestieDB.QueryQuest = QuestieDB.QueryQuest.Query
    QuestieDB.QueryObject = QuestieDB.QueryObject.Query
    QuestieDB.QueryItem = QuestieDB.QueryItem.Query

    -- data has been corrected, ensure cache is empty (something might have accessed the api before questie initialized)
    _QuestieDB.questCache = {};
    _QuestieDB.npcCache = {};

    --? This improves performance a lot, the regular functions still work but this is much faster because i caches
    checkRace  = QuestieLib:TableMemoizeFunction(QuestiePlayer.HasRequiredRace)
    checkClass = QuestieLib:TableMemoizeFunction(QuestiePlayer.HasRequiredClass)
    --? Set the localized versions of these.
    QuestieCorrectionshiddenQuests = QuestieCorrections.hiddenQuests
    Questiedbcharhidden = Questie.db.char.hidden
end

function QuestieDB:GetObject(objectId)
    if not objectId then
        return nil
    end

    --local rawdata = QuestieDB.objectData[objectId];
    local rawdata = QuestieDB.QueryObject(objectId, QuestieDB._objectAdapterQueryOrder)

    if not rawdata then
        Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetObject] rawdata is nil for objectID:", objectId)
        return nil
    end

    local obj = {
        id = objectId,
        type = "object"
    }

    for stringKey, intKey in pairs(QuestieDB.objectKeys) do
        obj[stringKey] = rawdata[intKey]
    end
    return obj;
end

function QuestieDB:GetItem(itemId)
    if (not itemId) or (itemId == 0) then
        return nil
    end

    local rawdata = QuestieDB.QueryItem(itemId, QuestieDB._itemAdapterQueryOrder)

    if not rawdata then
        Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetItem] rawdata is nil for itemID:", itemId)
        return nil
    end

    local item = {
        Id = itemId,
        Sources = {},
        Hidden = QuestieCorrections.questItemBlacklist[itemId]
    }

    for stringKey, intKey in pairs(QuestieDB.itemKeys) do
        item[stringKey] = rawdata[intKey]
    end

    local sources = item.Sources

    if rawdata[QuestieDB.itemKeys.npcDrops] then
        for _, npcId in pairs(rawdata[QuestieDB.itemKeys.npcDrops]) do
            sources[#sources + 1] = {
                Id = npcId,
                Type = "monster",
            }
        end
    end

    if rawdata[QuestieDB.itemKeys.vendors] then
        for _, npcId in pairs(rawdata[QuestieDB.itemKeys.vendors]) do
            local friendlyToFaction = QuestieDB.QueryNPCSingle(npcId, "friendlyToFaction")
            local isFriendlyToPlayer = QuestieDB.IsFriendlyToPlayer(friendlyToFaction)
            if isFriendlyToPlayer then
                -- We don't want to show vendors from the opposite faction
                sources[#sources + 1] = {
                    Id = npcId,
                    Type = "monster",
                }
            end
        end
    end

    if rawdata[QuestieDB.itemKeys.objectDrops] then
        for _, v in pairs(rawdata[QuestieDB.itemKeys.objectDrops]) do
            sources[#sources + 1] = {
                Id = v,
                Type = "object",
            }
        end
    end

    return item
end

---@param itemId ItemId
---@param npcId NpcId
---@return table<number, string>?
function QuestieDB.GetItemDroprate(itemId, npcId)
     if not DropDB or not DropDB.GetItemDroprate then
         Questie.Debug(Questie.DEBUG_CRITICAL, "ItemDrops: DropDB not available")
         return nil
     end
     return DropDB.GetItemDroprate(itemId, npcId)
end

---@param questId number
---@return boolean
function QuestieDB.IsRepeatable(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
    return flags and bitband(flags, QuestieDB.specialFlags.REPEATABLE) ~= 0
end

---@param questId number
---@return boolean
function QuestieDB.IsDailyQuest(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "questFlags")
    -- test a bit flag: (value % (2*flag) >= flag)
    return flags and (flags % QUEST_FLAGS_DAILY_X2) >= QUEST_FLAGS_DAILY
end

---@param questId number
---@return boolean
function QuestieDB.IsWeeklyQuest(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "questFlags")
    -- test a bit flag: (value % (2*flag) >= flag)
    return flags and (flags % QUEST_FLAGS_WEEKLY_X2) >= QUEST_FLAGS_WEEKLY
end

---@param questId number
---@return boolean
function QuestieDB.IsMonthlyQuest(questId)
    local flags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
    return flags and bitband(flags, QuestieDB.specialFlags.MONTHLY) ~= 0
end

---@param questId number
---@return boolean
function QuestieDB.IsDungeonQuest(questId)
    local questTagId, _ = QuestieDB.GetQuestTagInfo(questId)
    return questTagId == QuestieDB.questTagIds.DUNGEON
end

---@param questId number
---@return boolean
function QuestieDB.IsRaidQuest(questId)
    local questTagId, _ = QuestieDB.GetQuestTagInfo(questId)
    return questTagId == QuestieDB.questTagIds.RAID or questTagId == QuestieDB.questTagIds.RAID_10 or questTagId == QuestieDB.questTagIds.RAID_25
end

---@param questId number
---@return boolean
function QuestieDB.IsPvPQuest(questId)
    local questTagId, _ = QuestieDB.GetQuestTagInfo(questId)
    return questTagId == QuestieDB.questTagIds.PVP
end

---@param questId number
---@return boolean
function QuestieDB.IsGroupQuest(questId)
    local questTagId, _ = QuestieDB.GetQuestTagInfo(questId)
    return questTagId == QuestieDB.questTagIds.ELITE
end

--[[ Commented out because not used anywhere
---@param questId number
---@return boolean
function QuestieDB:IsAQWarEffortQuest(questId)
    return QuestieCorrections.AQWarEffortQuests[questId]
end
]]--

---@param class string
---@return number
function QuestieDB:GetZoneOrSortForClass(class)
    return QuestieDB.sortKeys[class]
end

local questTagInfoCache = {}

--- Wrapper function for the GetQuestTagInfo API to correct
--- quests that are falsely marked by Blizzard and cache the results.
---@param questId number
---@return number|nil questTagId
---@return string|nil questTagName
function QuestieDB.GetQuestTagInfo(questId)
    if not questId then return nil, nil end

    if questTagInfoCache[questId] then
        return questTagInfoCache[questId][1], questTagInfoCache[questId][2]
    end

    local questTagId, questTagName
    if questTagCorrections[questId] then
        questTagId, questTagName = questTagCorrections[questId][1], questTagCorrections[questId][2]
    else
        questTagId, questTagName = GetQuestTagInfo(questId)

        if questTagId == nil and questTagName == nil then
            -- Retry the API call after a short delay, as the API tends to incorrectly return nil on the first call.
            -- Doing it here asserts, we only call the API twice per quest at most.
            local retryQuestId = questId
            C_Timer.After(1, function()
                if not retryQuestId then
                    return
                end

                local retryQuestTagId, retryQuestTagName = GetQuestTagInfo(retryQuestId)
                questTagInfoCache[retryQuestId] = {retryQuestTagId, retryQuestTagName}
            end)
        end
    end

    -- cache the result to avoid hitting the API throttling limit
    questTagInfoCache[questId] = {questTagId, questTagName}

    return questTagId, questTagName
end

---@param questId number
---@return boolean
function QuestieDB.IsActiveEventQuest(questId)
    --! If you edit the logic here, also edit in QuestieDB:IsLevelRequirementsFulfilled
    return QuestieEvent.activeQuests[questId] == true
end

---@param exclusiveTo table<number, number>
---@return boolean
function QuestieDB:IsExclusiveQuestInQuestLogOrComplete(exclusiveTo)
    if (not exclusiveTo) then
        return false
    end

    for _, exId in pairs(exclusiveTo) do
        if Questie.db.char.complete[exId] or QuestiePlayer.currentQuestlog[exId] then
            return true
        end
    end
    return false
end

---@param questId QuestId
---@param minLevel Level @The level a quest must have at least to be shown
---@param maxLevel Level @The level a quest can have at most to be shown
---@param playerLevel Level? @Pass player level to avoid calling UnitLevel or to use custom level
---@return boolean
function QuestieDB.IsLevelRequirementsFulfilled(questId, minLevel, maxLevel, playerLevel)
    local level, requiredLevel, requiredMaxLevel = QuestieLib.GetEffectiveQuestLevel(questId, playerLevel)

    --* QuestiePlayer.currentQuestlog[parentQuestId] logic is from QuestieDB.IsParentQuestActive, if you edit here, also edit there
    local parentQuestId = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuestId and QuestiePlayer.currentQuestlog[parentQuestId] then
        -- If the quest is in the player's log already, there's no need to do any logic here, it must already be available
        return true
    end

    --* QuestieEvent.activeQuests[questId] logic is from QuestieDB.IsParentQuestActive, if you edit here, also edit there
    if (Questie.db.profile.lowLevelStyle ~= Questie.LOWLEVEL_RANGE) and
        minLevel > requiredLevel and
        QuestieEvent.activeQuests[questId]  then
        return true
    end

    if maxLevel >= level then
        if (Questie.db.profile.lowLevelStyle ~= Questie.LOWLEVEL_ALL) and minLevel > level then
            -- The quest level is too low and trivial quests are not shown
            return false
        end
    else
        if (Questie.db.profile.lowLevelStyle == Questie.LOWLEVEL_RANGE) or maxLevel < requiredLevel then
            -- Either an absolute level range is set and maxLevel < level OR the maxLevel is manually set to a lower value
            return false
        end
    end

    if maxLevel < requiredLevel then
        -- Either the players level is not high enough or the maxLevel is manually set to a lower value
        return false
    end

    if requiredMaxLevel ~= 0 and playerLevel > requiredMaxLevel then
        -- The players level exceeds the requiredMaxLevel of a quest
        return false
    end

    return true
end

---@param parentID number
---@return boolean
function QuestieDB.IsParentQuestActive(parentID)
    --! If you edit the logic here, also edit in QuestieDB:IsLevelRequirementsFulfilled
    if (not parentID) or (parentID == 0) then
        return false
    end
    if QuestiePlayer.currentQuestlog[parentID] then
        return true
    end
    return false
end

---@param questId number
---@return boolean
function QuestieDB:IsProviderPrerequisiteCompleted()
    return false
end

---@param questId number
---@return boolean
local function IsPreQuestCompleted(questId)
    return Questie.db.char.complete[questId] or QuestieDB:IsProviderPrerequisiteCompleted(questId)
end

---@param preQuestGroup table<number, number>
---@return boolean
function QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
    if (not preQuestGroup) or (not next(preQuestGroup)) then
        return true
    end
    for preQuestIndex=1, #preQuestGroup do
        local preQuestId = preQuestGroup[preQuestIndex]
        if preQuestId < 0 then
            -- Negative entries in preQuestGroup skip the exclusiveTo check
            if not IsPreQuestCompleted(-preQuestId) then
                return false
            end
        -- If a quest is not complete and no exclusive quest is complete, the requirement is not fulfilled
        elseif not IsPreQuestCompleted(preQuestId) then
            local preQuest = QuestieDB.QueryQuestSingle(preQuestId, "exclusiveTo")
            if (not preQuest) then
                return false
            end

            local anyExclusiveFinished = false
            for i=1, #preQuest do
                if IsPreQuestCompleted(preQuest[i]) then
                    anyExclusiveFinished = true
                end
            end
            if not anyExclusiveFinished then
                return false
            end
        end
    end
    -- All preQuests are complete
    return true
end

---@param preQuestSingle number[]
---@return boolean
function QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
    if (not preQuestSingle) or (not next(preQuestSingle)) then
        return true
    end
    for preQuestIndex=1, #preQuestSingle do
        -- If a quest is complete the requirement is fulfilled
        if IsPreQuestCompleted(preQuestSingle[preQuestIndex]) then
            return true
        end
    end
    -- No preQuest is complete
    return false
end

---@param requiredItemConditions table<number, {number, number}>
---@return boolean fulfilled
---@return number? itemId
---@return boolean? itemRequired
---@return number? requiredCount
function QuestieDB:IsRequiredItemConditionsFulfilled(requiredItemConditions)
    if not requiredItemConditions then
        return true
    end

    for _, condition in pairs(requiredItemConditions) do
        local signedItemId = condition[1]
        local requiredCount = condition[2] or 1
        local itemId = math.abs(signedItemId)
        local itemCount = GetItemCount(itemId)

        if signedItemId > 0 and itemCount < requiredCount then
            return false, itemId, true, requiredCount
        elseif signedItemId < 0 and itemCount >= requiredCount then
            return false, itemId, false, requiredCount
        end
    end

    return true
end

function QuestieDB:IsProviderAvailabilityConditionFulfilled()
    return true
end

function QuestieDB:HasProviderLocationCondition()
    return false
end

function QuestieDB:IsProviderAvailabilityConditionFulfilledForSpawnZone()
    return true
end

function QuestieDB:InitializeProviderAvailabilityConditionIndexes()
    self.providerAuraConditionQuestIds = {}
    self.providerLocationConditionQuestIds = {}
end

---@param questId number
---@return string stateKey
function QuestieDB:GetAvailabilityItemConditionState(questId)
    local states = {}
    local requiredItemConditions = QuestieDB.QueryQuestSingle(questId, "requiredItemConditions")
    for _, condition in ipairs(requiredItemConditions or {}) do
        local signedItemId = condition[1]
        local itemCount = GetItemCount(math.abs(signedItemId))
        local requiredCount = condition[2] or 1
        local fulfilled = signedItemId > 0 and itemCount >= requiredCount
            or signedItemId < 0 and itemCount < requiredCount
        states[#states + 1] = fulfilled and "1" or "0"
    end

    return table.concat(states)
end

function QuestieDB:GetProviderAvailabilityConditionDescription()
    return "unknown provider condition"
end

---@param questId number
---@param debugPrint boolean? -- if true, IsDoable will print conclusions to debug channel
---@param ignoreProviderLocationConditions boolean? -- map pins filter these conditions per starter spawn
---@return boolean
function QuestieDB.IsDoable(questId, debugPrint, ignoreProviderLocationConditions)

    --!  Before changing any logic in QuestieDB.IsDoable, make sure
    --!  to mirror the same logic to QuestieDB.IsDoableVerbose!

    -- IsDoable determines if the player is currently eligible for
    -- a quest, and returns that result as true/false in order to
    -- programmatically show/hide quests and determine further logic.

    -- IsDoableVerbose does the same logic, but returns human-readable
    -- explanations as a string for display in the UI.

    -- These functions are maintained separately for performance,
    -- because IsDoable is often called in a loop through every
    -- quest in the DB in order to update icons, while
    -- IsDoableVerbose is only called manually by the user.

    local completedQuests = Questie.db.char.complete
    local currentQuestlog = QuestiePlayer.currentQuestlog

    -- These are localized in the init function
    if completedQuests[questId] then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is already finished!") end
        return false
    end

    -- Blacklisted quests
    if QuestieCorrectionshiddenQuests[questId] then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is hidden automatically!") end
        return false
    end

    -- Only present in IsDoable, not IsDoableVerbose
    if Questiedbcharhidden[questId] then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is hidden manually!") end
        return false
    end

    if C_QuestLog.IsOnQuest(questId) == true then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is eligible because Player is on the quest!") end
        return true
    end

    if QuestieEvent:IsEventQuestInCurrentExpansion(questId) and not QuestieEvent:IsEventActiveForQuest(questId) then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Event quest " .. questId .. " is not active") end
        return false
    end

    if QuestieDB.activeChildQuests[questId] then -- The parent quest is active, so this quest is doable
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is eligible because it's a child quest and the parent is active!") end
        return true
        -- this scenario actually returns true, so it skips the rest of the later checks, because
        -- if we're on the parent quest then we implicitly know all other requirements are met
    end

    local requiredRaces = QuestieDB.QueryQuestSingle(questId, "requiredRaces")
    if (requiredRaces and not checkRace[requiredRaces]) then
        QuestieDB.autoBlacklist[questId] = "race"
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Race requirement not fulfilled for quest " .. questId) end
        return false
    end

    -- Check the preQuestSingle field where just one of the required quests has to be complete for a quest to show up
    local preQuestSingle = QuestieDB.QueryQuestSingle(questId, "preQuestSingle")
    if preQuestSingle then
        local isPreQuestSingleFulfilled = QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
        if not isPreQuestSingleFulfilled then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Pre-quest requirement not fulfilled for quest " .. questId) end
            return false
        end
    end

    local requiredClasses = QuestieDB.QueryQuestSingle(questId, "requiredClasses")
    if (requiredClasses and not checkClass[requiredClasses]) then
        QuestieDB.autoBlacklist[questId] = "class"
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Class requirement not fulfilled for quest " .. questId) end
        return false
    end

    local requiredMinRep = QuestieDB.QueryQuestSingle(questId, "requiredMinRep")
    local requiredMaxRep = QuestieDB.QueryQuestSingle(questId, "requiredMaxRep")
    if (requiredMinRep or requiredMaxRep) then
        local aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction = QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)
        if (not ((aboveMinRep and hasMinFaction) and (belowMaxRep and hasMaxFaction))) then
            --- If we haven't got the faction for min or max we blacklist it
            if not (aboveMinRep and belowMaxRep) then
                QuestieDB.autoBlacklist[questId] = "rep"
            end

            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet reputation requirements for quest " .. questId) end
            return false
        end
    end

    local requiredSkill = QuestieDB.QueryQuestSingle(questId, "requiredSkill")
    if (requiredSkill) then
        local hasProfession, hasSkillLevel = QuestieProfessions:HasProfessionAndSkillLevel(requiredSkill)
        if (not (hasProfession and hasSkillLevel)) then
            --? We haven't got the profession so we blacklist it.
            if(not hasProfession) then
                QuestieDB.autoBlacklist[questId] = "skill"
            end

            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet profession requirements for quest " .. questId) end
            return false
        end
    end

    local requiredRanks = QuestieDB.QueryQuestSingle(questId, "requiredRanks")
    if (requiredRanks) then
        local hasProfession, hasRankLevel = QuestieProfessions:HasProfessionAndRankLevel(requiredRanks)
        if (not (hasProfession and hasRankLevel)) then
            --? We haven't got the profession so we blacklist it.
            if(not hasProfession) then
                QuestieDB.autoBlacklist[questId] = "rank"
            end

            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not have profession rank for quest " .. questId) end
            return false
        end
    end

    --? preQuestGroup and preQuestSingle are mutualy exclusive to eachother and preQuestSingle is more prevalent
    --? Only try group if single does not exist.
    if not preQuestSingle then
        -- Check the preQuestGroup field where every required quest has to be complete for a quest to show up
        local preQuestGroup = QuestieDB.QueryQuestSingle(questId, "preQuestGroup")
        if preQuestGroup then
            local isPreQuestGroupFulfilled = QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
            if not isPreQuestGroupFulfilled then
                if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Group pre-quest requirement not fulfilled for quest " .. questId) end
                return false
            end
        end
    end

    local parentQuest = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuest and parentQuest ~= 0 then
        if not currentQuestlog[parentQuest] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " has an inactive parent quest") end
            return false
        end
    end

    local nextQuestInChain = QuestieDB.QueryQuestSingle(questId, "nextQuestInChain")
    if nextQuestInChain and nextQuestInChain ~= 0 then
        if completedQuests[nextQuestInChain] or currentQuestlog[nextQuestInChain] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Follow up quests already completed or in the quest log for quest " .. questId) end
            return false
        end
    end

    -- Check if a quest which is exclusive to the current has already been completed or accepted
    -- If yes the current quest can't be accepted
    local ExclusiveQuestGroup = QuestieDB.QueryQuestSingle(questId, "exclusiveTo")
    if ExclusiveQuestGroup then -- fix (DO NOT REVERT, tested thoroughly)
        for _, v in pairs(ExclusiveQuestGroup) do
            if completedQuests[v] or currentQuestlog[v] then
                if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player has completed a quest exclusive with quest " .. questId) end
                return false
            end
        end
    end

    local requiredSpecialization = QuestieDB.QueryQuestSingle(questId, "requiredSpecialization")
    if (requiredSpecialization) and (requiredSpecialization > 0) then
        local hasSpecialization = QuestieProfessions:HasSpecialization(requiredSpecialization)
        if (not hasSpecialization) then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet profession specialization requirements for quest " .. questId) end
            return false
        end
    end

    local requiredSpell = QuestieDB.QueryQuestSingle(questId, "requiredSpell")
    if (requiredSpell) and (requiredSpell ~= 0) then
        local hasSpell = IsSpellKnownOrOverridesKnown(math.abs(requiredSpell))
        local hasProfSpell = IsPlayerSpell(math.abs(requiredSpell))
        if (requiredSpell > 0) and (not hasSpell) and (not hasProfSpell) then --if requiredSpell is positive, we make the quest unavailable if the player does NOT have the spell
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet learned spell requirements for quest " .. questId) end
            return false
        elseif (requiredSpell < 0) and (hasSpell or hasProfSpell) then --if requiredSpell is negative, we make the quest unavailable if the player DOES  have the spell
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet unlearned spell requirements for quest " .. questId) end
            return false
        end
    end

    local requiredItemConditions = QuestieDB.QueryQuestSingle(questId, "requiredItemConditions")
    if requiredItemConditions then
        QuestieDB.requiredItemConditionQuestIds[questId] = true
        local itemConditionsFulfilled = QuestieDB:IsRequiredItemConditionsFulfilled(requiredItemConditions)
        if not itemConditionsFulfilled then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet item requirements for quest " .. questId) end
            return false
        end
    end

    local providerConditionsFulfilled = QuestieDB:IsProviderAvailabilityConditionFulfilled(questId, ignoreProviderLocationConditions)
    if not providerConditionsFulfilled then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet provider availability conditions for quest " .. questId) end
        return false
    end

    -- Check and see if the Quest requires an achievement before showing as available
    if _QuestieDB:CheckAchievementRequirements(questId) == false then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Player does not meet achievement requirements for quest " .. questId) end
        return false
    end

    -- Check if this quest is a breadcrumb
    local breadcrumbForQuestId = QuestieDB.QueryQuestSingle(questId, "breadcrumbForQuestId")
    if breadcrumbForQuestId and breadcrumbForQuestId ~= 0 then
        -- Check the target quest of this breadcrumb
        if completedQuests[breadcrumbForQuestId] or currentQuestlog[breadcrumbForQuestId] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Target of breadcrumb quest already completed or in the quest log for quest " .. questId) end
            return false
        end
        -- The next case is commented out since it's not a valid check to have. Breadcrumbs to the same quest are not always exclusive to each other
        --[[ Check if the other breadcrumbs are active
        local otherBreadcrumbs = QuestieDB.QueryQuestSingle(breadcrumbForQuestId, "breadcrumbs")
        for _, breadcrumbId in ipairs(otherBreadcrumbs or {}) do -- TODO: Remove `or {}` when we have a validation for the breadcrumb data
            if breadcrumbId ~= questId and currentQuestlog[breadcrumbId] then
                if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Alternative breadcrumb quest in the quest log for quest " .. questId) end
                return false
            end
        end]]
    end

    -- Check if this quest has active breadcrumbs
    local breadcrumbs = QuestieDB.QueryQuestSingle(questId, "breadcrumbs")
    if breadcrumbs then
        for _, breadcrumbId in ipairs(breadcrumbs) do
            if currentQuestlog[breadcrumbId] then
                if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Breadcrumb quest " .. breadcrumbId .. " in the quest log for quest " .. questId) end
                return false
            end
        end
    end

    -- Check if this quest has a quest that disables it while in quest log
    local disabledByQuest = QuestieDB.QueryQuestSingle(questId, "disabledByQuest")
    if disabledByQuest and disabledByQuest ~= 0 then
        if QuestiePlayer.currentQuestlog[disabledByQuest] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Disabling quest " .. disabledByQuest .. " in the quest log for quest " .. questId) end
            return false
        end
    end

    -- Check if this quest is not detected as active from the NPC/object itself
    if DailyQuests.ShouldBeHidden(questId, completedQuests, currentQuestlog) then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Daily quest " .. questId .. " is not active") end
        return false
    end

    if QuestieDB.IsDailyQuest(questId) and DailyQuests:IsAtDailyQuestLimit() then
        if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Daily quest " .. questId .. " is unavailable because daily quest limit is reached") end
        return false
    end

    -- Check if this quest is visible until you turn in a certain quest
    local availableUntilCompleted = QuestieDB.QueryQuestSingle(questId, "availableUntilCompleted")
    if availableUntilCompleted and availableUntilCompleted ~= 0 then
        if completedQuests[availableUntilCompleted] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is not available because " .. availableUntilCompleted .. " has been turned in!") end
            return false
        end
    end

    -- Check if this quest is visible if you have a certain quest in log or turned in (slightly different to preQuestSingle)
    -- In order to not mess with the existing logic for preQuestSingle, this field must be accompanied by preQuestSingle
    local availableStartingWith = QuestieDB.QueryQuestSingle(questId, "availableStartingWith")
    if availableStartingWith and availableStartingWith ~= 0 then
        if not completedQuests[availableStartingWith] and not currentQuestlog[availableStartingWith] then
            if debugPrint then Questie.Debug(Questie.DEBUG_SPAM, "[QuestieDB.IsDoable] Quest " .. questId .. " is not available because " .. availableStartingWith .. " is not active/turned in!") end
            return false
        end
    end

    return true
end

---@param questId number
---@param debugPrint boolean? -- if true, IsDoable will print conclusions to debug channel
---@param returnText boolean? -- if true, IsDoable will return plaintext explanation instead of true/false
---@param returnBrief boolean? -- if true and returnText is true, IsDoable will return a very brief explanation instead of a verbose one
---@return boolean
function QuestieDB.IsDoableVerbose(questId, debugPrint, returnText, returnBrief)

    --!  Before changing any logic in QuestieDB.IsDoable, make sure
    --!  to mirror the same logic to QuestieDB.IsDoableVerbose!

    -- IsDoable determines if the player is currently eligible for
    -- a quest, and returns that result as true/false in order to
    -- programmatically show/hide quests and determine further logic.

    -- IsDoableVerbose does the same logic, but returns human-readable
    -- explanations as a string for display in the UI.

    -- These functions are maintained separately for performance,
    -- because IsDoable is often called in a loop through every
    -- quest in the DB in order to update icons, while
    -- IsDoableVerbose is only called manually by the user.

    local completedQuests = Questie.db.char.complete
    local currentQuestlog = QuestiePlayer.currentQuestlog
    local DoableStates = QuestieDB.DoableStates
    local HIDE_ON_MAP = QuestieCorrections.HIDE_ON_MAP

    local function _HasItemInBags(itemId)
        return GetItemCount(itemId) > 0
    end

    local function _HasKnownItemStartSource(itemId)
        local npcDrops = QuestieDB.QueryItemSingle(itemId, "npcDrops")
        if npcDrops and next(npcDrops) then
            return true
        end

        local objectDrops = QuestieDB.QueryItemSingle(itemId, "objectDrops")
        if objectDrops and next(objectDrops) then
            return true
        end

        return false
    end

    -- Completed quests
    if completedQuests[questId] then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Already complete"), false, DoableStates.COMPLETED -- we return false here as we don't want to show it as label when completed in QBZ/QBF
        elseif returnText then
            return "Player has already completed quest " .. questId .. "!", false, DoableStates.COMPLETED
        end
    end

    -- The player has this quest in the quest log
    if C_QuestLog.IsOnQuest(questId) == true then
        local msg = "Quest " .. questId .. " is active"
        if returnText and returnBrief then
            return l10n("Available")..l10n(": ")..l10n("Player is on quest"), false, DoableStates.QUEST_LOG
        elseif returnText and not returnBrief then
            return msg, false, DoableStates.QUEST_LOG
        end
    end

    -- Automatically blacklisted quests by Questie. These are localized in the init function
    if QuestieCorrectionshiddenQuests[questId] and QuestieCorrectionshiddenQuests[questId] ~= HIDE_ON_MAP then
        local msg = "Quest " .. questId .. " is hidden automatically"
        local msgevent = "Quest " .. questId .. " is unavailable because the world event is inactive"
        if QuestieEvent:IsEventQuestInCurrentExpansion(questId) and not QuestieEvent:IsEventActiveForQuest(questId) then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
            elseif returnText and not returnBrief then
                return msgevent, true, DoableStates.EVENT_INACTIVE
            end
        end
        if returnText and returnBrief then
            return l10n("Unknown")..l10n(": ")..l10n("Automatically blacklisted"), true, DoableStates.BLACKLISTED
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.BLACKLISTED
        end
    end

    if QuestieEvent:IsEventQuestInCurrentExpansion(questId) and not QuestieEvent:IsEventActiveForQuest(questId) then
        local msg = "Quest " .. questId .. " is unavailable because the world event is inactive"
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.EVENT_INACTIVE
        end
    end

    -- AQ War Effort quests (one-time world event that has ended for all realms)
    if QuestieCorrections.AQWarEffortQuests[questId] then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
        elseif returnText then
            return "AQ event quest " .. questId .. " is not active", true, DoableStates.EVENT_INACTIVE
        end
    end

    -- Scourge Invasion quests can be gated by the provider's world event.
    if QuestieCorrections.ScourgeInvasionQuests[questId] then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Event inactive"), true, DoableStates.EVENT_INACTIVE
        elseif returnText then
            return "Scourge Invasion quest " .. questId .. " is not active", true, DoableStates.EVENT_INACTIVE
        end
    end

    -- Check character race
    local requiredRaces = QuestieDB.QueryQuestSingle(questId, "requiredRaces")
    if (requiredRaces and not checkRace[requiredRaces]) then
        local requirementLabel = "Race requirement"
        if requiredRaces == QuestieDB.raceKeys.ALL_ALLIANCE or requiredRaces == QuestieDB.raceKeys.ALL_HORDE then
            requirementLabel = "Faction requirement"
        end
        local msg = requirementLabel .. " not fulfilled for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n(requirementLabel), true, DoableStates.WRONG_RACE
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.WRONG_RACE
        end
    end

    -- Check character class
    local requiredClasses = QuestieDB.QueryQuestSingle(questId, "requiredClasses")
    if (requiredClasses and not checkClass[requiredClasses]) then
        QuestieDB.autoBlacklist[questId] = "class"
        local msg = "Class requirement not fulfilled for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Class requirement"), true, DoableStates.WRONG_CLASS
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.WRONG_CLASS
        end
    end

    -- We keep this here, even though it is removed from QuestieDB.IsDoable because AvailableQuests.CalculateAndDrawAll
    -- checks child quests differently and before IsDoable
    if QuestieDB.activeChildQuests[questId] then -- The parent quest is active, so this quest is doable
        local msg = "Quest " .. questId .. " is available because it's a child quest, the parent is active and conditions are met"
        if returnText and returnBrief then
            return l10n("Available")..l10n(": ")..l10n("Parent active"), false, DoableStates.PARENT_ACTIVE
        elseif returnText and not returnBrief then
            return msg, false, DoableStates.PARENT_ACTIVE
        end
    end

    -- Check if a quest which is exclusive to the current has already been completed or accepted
    -- If yes the current quest can't be accepted
    local ExclusiveQuestGroup = QuestieDB.QueryQuestSingle(questId, "exclusiveTo")
    if ExclusiveQuestGroup then -- fix (DO NOT REVERT, tested thoroughly)
        for _, v in pairs(ExclusiveQuestGroup) do
            if completedQuests[v] then
                local msg = "Quest " .. questId .. " is unavailable because exclusive quest " .. v .. " is completed"
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Exclusive quest completed"), true, DoableStates.EXCLUSIVE_COMPLETED
                elseif returnText and not returnBrief then
                    return msg, true, DoableStates.EXCLUSIVE_COMPLETED
                end
            elseif currentQuestlog[v] then
                local msg = "Quest " .. questId .. " is unavailable because exclusive quest " .. v .. " is in the quest log"
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Exclusive quest in quest log"), true, DoableStates.EXCLUSIVE_IN_QUEST_LOG
                elseif returnText and not returnBrief then
                    return msg, true, DoableStates.EXCLUSIVE_IN_QUEST_LOG
                end
            end
        end
    end

    -- Check profession requirements
    local requiredSkill = QuestieDB.QueryQuestSingle(questId, "requiredSkill")
    local requiredRanks = QuestieDB.QueryQuestSingle(questId, "requiredRanks")
    -- Until then these two should be mutually exclusive
    -- TODO: if we find a quest that has both requiredSkill and requiredRanks we need to be able to return correct message
    if (requiredSkill) then
        local hasProfession, hasSkillLevel = QuestieProfessions:HasProfessionAndSkillLevel(requiredSkill)
        if not hasProfession then
            local msg = "Profession missing for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession missing"), true, DoableStates.PROFESSION_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_MISSING
            end
        elseif not hasSkillLevel then
            local msg = "Player does not have required profession skill for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession skill"), true, DoableStates.PROFESSION_SKILL
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_SKILL
            end
        end
    end
    if (requiredRanks) then
        local hasProfession, hasRankLevel = QuestieProfessions:HasProfessionAndRankLevel(requiredRanks)
        if not hasProfession then
            local msg = "Profession missing for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession missing"), true, DoableStates.PROFESSION_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_MISSING
            end
        elseif not hasRankLevel then
            local msg = "Player does not have required profession rank for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession rank"), true, DoableStates.PROFESSION_RANK
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_RANK
            end
        end
    end

    -- Check profession specialization requirements
    local requiredSpecialization = QuestieDB.QueryQuestSingle(questId, "requiredSpecialization")
    if (requiredSpecialization) and (requiredSpecialization > 0) then
        local hasSpecialization = QuestieProfessions:HasSpecialization(requiredSpecialization)
        if (not hasSpecialization) then
            local msg = "Player does not meet profession specialization requirements for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Profession specialization requirement"), true, DoableStates.PROFESSION_SPECIALIZATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PROFESSION_SPECIALIZATION
            end
        end
    end

    -- Check if the character is higher than the quest allows
    local requiredMaxLevel = QuestieDB.QueryQuestSingle(questId, "requiredMaxLevel")
    if (requiredMaxLevel and requiredMaxLevel ~= 0 and (UnitLevel("player") > requiredMaxLevel)) then
        local msg = "Player level is too high for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Level too high"), true, DoableStates.LEVEL_TOO_HIGH
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.LEVEL_TOO_HIGH
        end
    end

    -- only present in verbose.
    -- IsDoable has its own logic that varies based on player settings for quest visibility
    local requiredLevel = QuestieDB.QueryQuestSingle(questId, "requiredLevel")
    if (requiredLevel and (UnitLevel("player") < requiredLevel)) then
        local msg = "Player level is too low for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Level too low"), true, DoableStates.LEVEL_TOO_LOW
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.LEVEL_TOO_LOW
        end
    end

    -- Check if this quest is a breadcrumb
    local breadcrumbForQuestId = QuestieDB.QueryQuestSingle(questId, "breadcrumbForQuestId")
    if breadcrumbForQuestId and breadcrumbForQuestId ~= 0 then
        -- Check the follow up quest of this breadcrumb
        if completedQuests[breadcrumbForQuestId] or currentQuestlog[breadcrumbForQuestId] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Follow up quest active or completed"), true, DoableStates.BREADCRUMB_FOLLOWUP
            elseif returnText and not returnBrief then
                return "Follow up of breadcrumb quest " .. breadcrumbForQuestId .. " already completed or in the quest log for quest " .. questId, true, DoableStates.BREADCRUMB_FOLLOWUP
            end
        end
        -- The next case is commented out since it's not a valid check to have. Breadcrumbs to the same quest are not always exclusive to eachother
        --[[ Check if the other breadcrumbs are active
        local otherBreadcrumbs = QuestieDB.QueryQuestSingle(breadcrumbForQuestId, "breadcrumbs")
        for _, breadcrumbId in ipairs(otherBreadcrumbs or {}) do
            if breadcrumbId ~= questId and currentQuestlog[breadcrumbId] then
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("Another breadcrumb is active"), true, DoableStates.EXCLUSIVE_BREADCRUMB
                elseif returnText and not returnBrief then
                    return "Alternative breadcrumb quest " .. breadcrumbId .." in the quest log for quest " .. questId, true, DoableStates.EXCLUSIVE_BREADCRUMB
                end
            end
        end]]
    end

    -- Check reputation requirements
    local requiredMinRep = QuestieDB.QueryQuestSingle(questId, "requiredMinRep")
    local requiredMaxRep = QuestieDB.QueryQuestSingle(questId, "requiredMaxRep")
    if (requiredMinRep or requiredMaxRep) then
        local aboveMinRep, hasMinFaction, belowMaxRep, hasMaxFaction = QuestieReputation:HasFactionAndReputationLevel(requiredMinRep, requiredMaxRep)
        -- Below reputation requirement
        if not (aboveMinRep and hasMinFaction) then
            local msg = "Reputation too low for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Reputation too low"), true, DoableStates.MISSING_REPUTATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.MISSING_REPUTATION
            end
        end
        -- Above reputation requirement
        if not (belowMaxRep and hasMaxFaction) then
            local msg = "Reputation too high for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Reputation too high"), true, DoableStates.EXCEED_REPUTATION
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.EXCEED_REPUTATION
            end
        end
    end

    -- Check the preQuestSingle field where just one of the required quests has to be complete for a quest to show up
    local preQuestSingle = QuestieDB.QueryQuestSingle(questId, "preQuestSingle")
    if preQuestSingle then
        local isPreQuestSingleFulfilled = QuestieDB:IsPreQuestSingleFulfilled(preQuestSingle)
        if not isPreQuestSingleFulfilled then
            local msg = "Pre-quest requirement not fulfilled for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Incomplete pre-quest"), true, DoableStates.NO_PREQUESTSINGLE
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NO_PREQUESTSINGLE
            end
        end
    end

    -- Check the preQuestGroup field where every required quest has to be complete for a quest to show up
    local preQuestGroup = QuestieDB.QueryQuestSingle(questId, "preQuestGroup")
    if preQuestGroup then
        local isPreQuestGroupFulfilled = QuestieDB:IsPreQuestGroupFulfilled(preQuestGroup)
        if not isPreQuestGroupFulfilled then
            local msg = "Group pre-quest requirement not fulfilled for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Incomplete pre-quest group"), true, DoableStates.NO_PREQUESTGROUP
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NO_PREQUESTGROUP
            end
        end
    end

    -- Check parent quests
    local parentQuest = QuestieDB.QueryQuestSingle(questId, "parentQuest")
    if parentQuest and parentQuest ~= 0 then
        if not currentQuestlog[parentQuest] then
            local msg = "Quest " .. questId .. " has an inactive parent quest: " .. parentQuest
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Inactive parent"), true, DoableStates.PARENT_INACTIVE
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.PARENT_INACTIVE
            end
        end
    end

    -- Check if it has nextQuestInChain completed or in quest log
    local nextQuestInChain = QuestieDB.QueryQuestSingle(questId, "nextQuestInChain")
    if nextQuestInChain and nextQuestInChain ~= 0 then
        if completedQuests[nextQuestInChain] or currentQuestlog[nextQuestInChain] then
            local msg = "Follow up quest " .. nextQuestInChain .. " already completed or in the quest log for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Later quest completed or active"), true, DoableStates.NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.NEXTQUESTINCHAIN_ACTIVE_OR_COMPLETED
            end
        end
    end

    -- Check spell requirements
    local requiredSpell = QuestieDB.QueryQuestSingle(questId, "requiredSpell")
    if (requiredSpell) and (requiredSpell ~= 0) then
        local hasSpell = IsSpellKnownOrOverridesKnown(math.abs(requiredSpell))
        local hasProfSpell = IsPlayerSpell(math.abs(requiredSpell))
        if (requiredSpell > 0) and (not hasSpell) and (not hasProfSpell) then --if requiredSpell is positive, we make the quest unavailable if the player does NOT have the spell
            local msg = "Player does not know spell ID: " .. math.abs(requiredSpell) .. " for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Spell not yet learned"), true, DoableStates.SPELL_MISSING
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.SPELL_MISSING
            end
        elseif (requiredSpell < 0) and (hasSpell or hasProfSpell) then --if requiredSpell is negative, we make the quest unavailable if the player DOES have the spell
            local msg = "Player knows spell ID: " .. math.abs(requiredSpell) .. " for quest " .. questId
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Already learned spell"), true, DoableStates.SPELL_KNOWN
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.SPELL_KNOWN
            end
        end
    end

    local requiredItemConditions = QuestieDB.QueryQuestSingle(questId, "requiredItemConditions")
    if requiredItemConditions then
        QuestieDB.requiredItemConditionQuestIds[questId] = true
        local itemConditionsFulfilled, itemId, itemRequired, requiredCount = QuestieDB:IsRequiredItemConditionsFulfilled(requiredItemConditions)
        if not itemConditionsFulfilled then
            local msg
            if itemRequired then
                msg = "Quest " .. questId .. " requires " .. requiredCount .. " of item " .. itemId .. " in the player's bags"
            else
                msg = "Quest " .. questId .. " requires fewer than " .. requiredCount .. " of item " .. itemId .. " in the player's bags"
            end

            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Missing Requirement"), true, DoableStates.MISSING_START_ITEM
            elseif returnText and not returnBrief then
                return msg, true, DoableStates.MISSING_START_ITEM
            end
        end
    end

    local providerConditionsFulfilled, failedProviderCondition = QuestieDB:IsProviderAvailabilityConditionFulfilled(questId)
    if not providerConditionsFulfilled then
        local msg = "Player does not meet " .. QuestieDB:GetProviderAvailabilityConditionDescription(failedProviderCondition) .. " requirement for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Missing Requirement"), true, DoableStates.PROVIDER_CONDITION
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.PROVIDER_CONDITION
        end
    end

    -- Check and see if the Quest requires an achievement before showing as available
    if _QuestieDB:CheckAchievementRequirements(questId) == false then
        local msg = "Player does not meet achievement requirements for quest " .. questId
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Achievement requirement"), true, DoableStates.MISSING_ACHIEVEMENT
        elseif returnText and not returnBrief then
            return msg, true, DoableStates.MISSING_ACHIEVEMENT
        end
    end

    -- Check if this quest has active breadcrumbs
    local breadcrumbs = QuestieDB.QueryQuestSingle(questId, "breadcrumbs")
    if breadcrumbs then
        for _, breadcrumbId in ipairs(breadcrumbs) do
            if currentQuestlog[breadcrumbId] then
                if returnText and returnBrief then
                    return l10n("Unavailable")..l10n(": ")..l10n("A breadcrumb is active"), true, DoableStates.BREADCRUMB_ACTIVE
                elseif returnText and not returnBrief then
                    return "A breadcrumb quest " .. breadcrumbId .." is in the quest log for quest " .. questId, true, DoableStates.BREADCRUMB_ACTIVE
                end
            end
        end
    end

    -- Check if this quest has a quest that disables it while in quest log
    local disabledByQuest = QuestieDB.QueryQuestSingle(questId, "disabledByQuest")
    if disabledByQuest and disabledByQuest ~= 0 then
        if currentQuestlog[disabledByQuest] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Disabling quest is active"), true, DoableStates.DISABLED_BY
            elseif returnText and not returnBrief then
                return "Disabling quest " .. disabledByQuest .. " is in the quest log for quest " .. questId, true, DoableStates.DISABLED_BY
            end
        end
    end

    -- Daily quest not active (based on ShouldBeHidden)
    if DailyQuests.ShouldBeHidden(questId, completedQuests, currentQuestlog) then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Daily quest not active"), true, DoableStates.INACTIVE_DAILY
        elseif returnText then
            return "Daily quest " .. questId .. " is not active", true, DoableStates.INACTIVE_DAILY
        end
    end

    if QuestieDB.IsDailyQuest(questId) and DailyQuests:IsAtDailyQuestLimit() then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Daily quest limit reached"), true, DoableStates.INACTIVE_DAILY
        elseif returnText then
            return "Daily quest " .. questId .. " is unavailable because daily quest limit is reached", true, DoableStates.INACTIVE_DAILY
        end
    end

    -- Check if this quest is visible until you turn in a certain quest
    local availableUntilCompleted = QuestieDB.QueryQuestSingle(questId, "availableUntilCompleted")
    if availableUntilCompleted and availableUntilCompleted ~= 0 then
        if completedQuests[availableUntilCompleted] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Disabling quest already turned in"), true, DoableStates.DISABLING_QUEST_COMPLETED
            elseif returnText and not returnBrief then
                return "Quest " .. questId .. " is not available because " .. availableUntilCompleted .. " has been turned in", true, DoableStates.DISABLING_QUEST_COMPLETED
            end
        end
    end

    -- Check if this quest is visible if you have a certain quest in log or turned in (slightly different to preQuestSingle)
    local availableStartingWith = QuestieDB.QueryQuestSingle(questId, "availableStartingWith")
    if availableStartingWith and availableStartingWith ~= 0 then
        if not completedQuests[availableStartingWith] and not currentQuestlog[availableStartingWith] then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Enabling quest not active nor turned in"), true, DoableStates.ENABLING_QUEST_MISSING
            elseif returnText and not returnBrief then
                return "Quest " .. questId .. " is not available because " .. availableStartingWith .. " is not active/turned in", true, DoableStates.ENABLING_QUEST_MISSING
            end
        end
    end

    local startedBy = QuestieDB.QueryQuestSingle(questId, "startedBy")
    local itemStarts = startedBy and startedBy[3]
    if itemStarts and next(itemStarts) and (not startedBy[1]) and (not startedBy[2]) then
        local hasStartItem = false
        local hasKnownStartSource = false
        local missingStartItems = {}

        for _, itemId in pairs(itemStarts) do
            if _HasItemInBags(itemId) then
                hasStartItem = true
                break
            end

            if _HasKnownItemStartSource(itemId) then
                hasKnownStartSource = true
            else
                tinsert(missingStartItems, itemId)
            end
        end

        if (not hasStartItem) and (not hasKnownStartSource) then
            if returnText and returnBrief then
                return l10n("Unavailable")..l10n(": ")..l10n("Missing Requirement"), true, DoableStates.MISSING_START_ITEM
            elseif returnText and not returnBrief then
                return "Quest " .. questId .. " is unavailable because item start item " .. table.concat(missingStartItems, ", ") .. " is missing", true, DoableStates.MISSING_START_ITEM
            end
        end
    end

    -- Check if daily quests are unavailable via NPC interaction and/or comms.
    if unavailableQuestChecker and unavailableQuestChecker(questId) then
        if returnText and returnBrief then
            return l10n("Unavailable")..l10n(": ")..l10n("Daily quest not active"), true, DoableStates.MISSING_DAILY
        elseif returnText then
            return "Daily quest " .. questId .. " is not active", true, DoableStates.MISSING_DAILY
        end
    end

    -- Available quests
    if returnText and returnBrief then
        return l10n("Available"), false, DoableStates.AVAILABLE
    elseif returnText and not returnBrief then
        return "Quest " .. questId .. " is available", false, DoableStates.AVAILABLE
    else
        return "", false, DoableStates.AVAILABLE
    end
end

---@param questId number
---@return number @Complete = 1, Failed = -1, Incomplete = 0
function QuestieDB.IsComplete(questId)
    local questLogEntry = QuestLogCache.questLog_DO_NOT_MODIFY[questId] -- DO NOT MODIFY THE RETURNED TABLE
    local noQuestItem = not QuestieQuest:CheckQuestSourceItem(questId)

    --[[ pseudo:
    if no questLogEntry then return 0
    if has questLogEntry.isComplete then return questLogEntry.isComplete
    if no objectives and an item is needed but not obtained then return 0
    if no objectives then return 1
    return 0
    --]]

    return questLogEntry and (questLogEntry.isComplete or (questLogEntry.objectives[1] and 0) or (#questLogEntry.objectives == 0 and noQuestItem and 0) or 1) or 0
end

---@param self Quest
---@return number @Complete = 1, Failed = -1, Incomplete = 0
local function _IsComplete(self)
    return QuestieDB.IsComplete(self.Id)
end

---@param questLevel number? the level of the quest
---@return boolean @Returns true if the quest should be grey, false otherwise
function QuestieDB.IsTrivial(questLevel)
    if questLevel == nil then
        -- We assume unknown quests are not trivial
        return false
    end

    if questLevel == -1 then
        return false -- Scaling quests are never trivial
    end

    local levelDiff = questLevel - QuestiePlayer.GetPlayerLevel();
    if (levelDiff >= 5) then
        return false -- Red
    elseif (levelDiff >= 3) then
        return false -- Orange
    elseif (levelDiff >= -2) then
        return false -- Yellow
    elseif (-levelDiff <= GetQuestGreenRange("player")) then
        return false -- Green
    else
        return true -- Grey
    end
end

---@return number
local _GetIconScale = function()
    return Questie.db.profile.objectScale or 1
end

local function _GetObjectiveIcon(icon)
    if icon == 0 then
        return nil
    end
    return icon
end

local function _CreateObjectiveData(objectiveType, objective)
    return {
        Type = objectiveType,
        Id = objective[1],
        Text = objective[2],
        Icon = _GetObjectiveIcon(objective[3])
    }
end

local function _CreateKillCreditObjective(objective)
    return {
        Type = "killcredit",
        IdList = objective[1],
        RootId = objective[2],
        Text = objective[3],
        Icon = _GetObjectiveIcon(objective[4])
    }
end

---@param questId QuestId
---@return Quest|nil @The quest object or nil if the quest is missing
function QuestieDB.GetQuest(questId) -- /dump QuestieDB.GetQuest(867)
    if not questId then
        Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieDB.GetQuest] No questId.")
        return nil
    end
    if _QuestieDB.questCache[questId] then
        return _QuestieDB.questCache[questId];
    end

    local rawdata = QuestieDB.QueryQuest(questId, QuestieDB._questAdapterQueryOrder)

    if (not rawdata) then
        Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieDB.GetQuest] rawdata is nil for questID:", questId)
        return nil
    end

    ---@class Quest
    ---@field public Id QuestId
    ---@field public name Name
    ---@field public startedBy StartedBy
    ---@field public finishedBy FinishedBy
    ---@field public requiredLevel Level
    ---@field public questLevel Level
    ---@field public requiredRaces number @bitmask
    ---@field public requiredClasses number @bitmask
    ---@field public objectivesText string[]
    ---@field public triggerEnd { [1]: string, [2]: table<AreaId, CoordPair[]>}
    ---@field public objectives RawObjectives
    ---@field public sourceItemId ItemId
    ---@field public preQuestGroup QuestId[]
    ---@field public preQuestSingle QuestId[]
    ---@field public childQuests QuestId[]
    ---@field public inGroupWith QuestId[]
    ---@field public exclusiveTo QuestId[]
    ---@field public zoneOrSort ZoneOrSort
    ---@field public requiredSkill SkillPair
    ---@field public requiredMinRep ReputationPair
    ---@field public requiredMaxRep ReputationPair
    ---@field public requiredSourceItems ItemId[]
    ---@field public nextQuestInChain number
    ---@field public questFlags number @bitmask: see https://github.com/cmangos/issues/wiki/Quest_template#questflags
    ---@field public specialFlags number @bitmask: 1 = Repeatable, 2 = Needs event, 4 = Monthly reset (req. 1). See https://github.com/cmangos/issues/wiki/Quest_template#specialflags
    ---@field public parentQuest QuestId
    ---@field public reputationReward ReputationPair[]
    ---@field public extraObjectives ExtraObjective[]
    ---@field public requiredMaxLevel Level
    ---@field public breacrumbForQuestId number
    ---@field public breacrumbs QuestId[]
    ---@field public availableUntilCompleted QuestId
    ---@field public availableStartingWith QuestId
    ---@field public requiredRanks SkillPair[]
    ---@field public disabledByQuest QuestId
    ---@field public requiredItemConditions table<number, {number, number}>
    local QO = {
        Id = questId
    }

    -- General filling of the QuestObjective with all database values
    local questKeys = QuestieDB.questKeys
    for stringKey, intKey in pairs(questKeys) do
        QO[stringKey] = rawdata[intKey]
    end

    local questLevel, requiredLevel = QuestieLib.GetEffectiveQuestLevel(questId)
    QO.level = questLevel
    QO.requiredLevel = requiredLevel

    ---@type StartedBy
    local startedBy = QO.startedBy
    QO.Starts = {
        NPC = startedBy[1],
        GameObject = startedBy[2],
        Item = startedBy[3],
    }
    QO.isHidden = rawdata.hidden or QuestieCorrections.hiddenQuests[questId]
    QO.Description = QO.objectivesText
    if QO.specialFlags then
        QO.IsRepeatable = bitband(QO.specialFlags, QuestieDB.specialFlags.REPEATABLE) ~= 0
    end

    QO.IsComplete = _IsComplete

    ---@type FinishedBy
    local finishedBy = QO.finishedBy
    if finishedBy[1] then
        for _, id in pairs(finishedBy[1]) do
            if id then
                QO.Finisher = {
                    Type = "monster",
                    Id = id,
                    ---@type Name @We have to hard-type it here because of the function
                    Name = QuestieDB.QueryNPCSingle(id, "name")
                }
            end
        end
    end
    if finishedBy[2] then
        for _, id in pairs(finishedBy[2]) do
            if id then
                QO.Finisher = {
                    Type = "object",
                    Id = id,
                    ---@type Name @We have to hard-type it here because of the function
                    Name = QuestieDB.QueryObjectSingle(id, "name")
                }
            end
        end
    end

    --- to differentiate from the current quest log info.
    --- Quest objectives generated from DB+Corrections.
    --- Data itself is for example for monster type { Type = "monster", Id = 16518, Text = "Nestlewood Owlkin inoculated" }
    ---@type Objective[]
    QO.ObjectiveData = {}

    ---@type RawObjectives
    local objectives = QO.objectives
    if objectives then
        if objectives[1] then
            for _, creatureObjective in pairs(objectives[1]) do
                if creatureObjective then
                    ---@type NpcObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = _CreateObjectiveData("monster", creatureObjective)
                end
            end
        end
        if objectives[2] then
            for _, objectObjective in pairs(objectives[2]) do
                if objectObjective then
                    ---@type ObjectObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = _CreateObjectiveData("object", objectObjective)
                end
            end
        end
        if objectives[3] then
            for _, itemObjective in pairs(objectives[3]) do
                if itemObjective then
                    ---@type ItemObjective
                    local itemObjectiveData = _CreateObjectiveData("item", itemObjective)
                    if QuestieCorrections.itemObjectiveFirst[questId] then
                        tinsert(QO.ObjectiveData, 1, itemObjectiveData)
                    else
                        tinsert(QO.ObjectiveData, itemObjectiveData)
                    end
                end
            end
        end
        if objectives[4] then
            ---@type ReputationObjective
            QO.ObjectiveData[#QO.ObjectiveData+1] = {
                Type = "reputation",
                Id = objectives[4][1],
                RequiredRepValue = objectives[4][2]
            }
        end
        if objectives[5] and type(objectives[5]) == "table" and #objectives[5] > 0 then
            for _, creditObjective in pairs(objectives[5]) do
                ---@type KillObjective
                local killCreditObjective = _CreateKillCreditObjective(creditObjective)

                --? There are quest(s) which have the killCredit at first so we need to switch them
                -- Place the kill credit objective first
                if QuestieCorrections.killCreditObjectiveFirst[questId] then
                    tinsert(QO.ObjectiveData, 1, killCreditObjective);
                else
                    tinsert(QO.ObjectiveData, killCreditObjective);
                end
            end
        end
        if objectives[6] then
            for _, spellObjective in pairs(objectives[6]) do
                if spellObjective then
                    ---@type SpellObjective
                    QO.ObjectiveData[#QO.ObjectiveData+1] = {
                        Type = "spell",
                        Id = spellObjective[1],
                        Text = spellObjective[2],
                        ItemSourceId = spellObjective[3],
                    }
                    QO.SpellItemId = spellObjective[3]
                end
            end
        end
    end

    -- Events need to be added at the end of ObjectiveData
    local triggerEnd = QO.triggerEnd
    if triggerEnd then
        ---@type TriggerEndObjective
        QO.ObjectiveData[#QO.ObjectiveData+1] = {
            Type = "event",
            Text = triggerEnd[1],
            Coordinates = triggerEnd[2],
            TooltipTargets = QuestieCorrections.triggerEndTooltipTargets[questId],
        }
    end

    local preQuestGroup = QO.preQuestGroup
    local preQuestSingle = QO.preQuestSingle
    if preQuestGroup and preQuestSingle and next(preQuestGroup) and next(preQuestSingle) then
        Questie.Debug(Questie.DEBUG_CRITICAL, "ERRRRORRRRRRR not mutually exclusive for questID:", questId)
    end

    --- Quest objectives generated from quest log in QuestieQuest.lua -> QuestieQuest:PopulateQuestLogInfo(quest)
    --- Includes also icons drawn to maps, and other stuff.
    ---@type table<ObjectiveIndex, QuestObjective>
    QO.Objectives = {}

    QO.SpecialObjectives = {}

    ---@type ItemId[]
    local requiredSourceItems = QO.requiredSourceItems
    if requiredSourceItems then
        for _, itemId in pairs(requiredSourceItems) do
            if itemId then
                -- Make sure requiredSourceItems aren't already an objective
                local itemObjPresent = false
                if objectives and objectives[3] then
                    for _, itemObjective in pairs(objectives[3]) do
                        if itemObjective then
                            if itemId == itemObjective[1] then
                                itemObjPresent = true
                                break
                            end
                        end
                    end
                end

                -- Make an objective for requiredSourceItem
                if not itemObjPresent then
                    QO.SpecialObjectives[itemId] = {
                        Type = "item",
                        Id = itemId,
                        ---@type string @We have to hard-type it here because of the function
                        Description = QuestieDB.QueryItemSingle(itemId, "name")
                    }
                end
            end
        end
    end

    ---@type ExtraObjective[]
    local extraObjectives = QO.extraObjectives
    if extraObjectives then
        for index, o in pairs(extraObjectives) do
            local specialObjective = {
                Icon = o[2],
                Description = o[3],
                RealObjectiveIndex = o[4],
            }
            if o[1] then -- custom spawn
                specialObjective.spawnList = {{
                    Name = o[3],
                    Spawns = o[1],
                    Icon = o[2],
                    GetIconScale = _GetIconScale,
                    IconScale = _GetIconScale(),
                }}
            end
            if o[5] then -- db ref
                specialObjective.Type = o[5][1][1]
                specialObjective.Id = o[5][1][2]
                local spawnList = {}

                for _, ref in pairs(o[5]) do
                    local sourceHandler = _QuestieQuest.objectiveSpawnListCallTable[ref[1]]
                    local sourceList = sourceHandler and sourceHandler(ref[2], specialObjective)
                    if not sourceList then
                        Questie.Error("Missing extra objective data for", tostring(ref[1]), "'", specialObjective.Description, "'", tostring(ref[2]))
                    else
                        for k, v in pairs(sourceList) do
                            -- we want to be able to override the icon in the corrections (e.g. Questie.ICON_TYPE_OBJECT on objects instead of Questie.ICON_TYPE_LOOT)
                            v.Icon = o[2]
                            spawnList[k] = v
                        end
                    end
                end

                specialObjective.spawnList = spawnList
            end
            QO.SpecialObjectives[index] = specialObjective
        end
    end

    _QuestieDB.questCache[questId] = QO
    return QO
end

QuestieDB._CreatureLevelCache = {}
---@param quest Quest
---@return table<string, table> @List of creature names with their min-max level and rank
function QuestieDB:GetCreatureLevels(quest)
    if quest and QuestieDB._CreatureLevelCache[quest.Id] then
        return QuestieDB._CreatureLevelCache[quest.Id]
    end
    local creatureLevels = {}

    local function _CollectCreatureLevels(npcIds)
        for _, npcId in pairs(npcIds) do
            local npc = QuestieDB:GetNPC(npcId)
            if npc and not creatureLevels[npc.name] then
                creatureLevels[npc.name] = {npc.minLevel, npc.maxLevel, npc.rank}
            end
        end
    end

    if quest.objectives then
        if quest.objectives[1] then -- Killing creatures
            for _, creatureObjective in pairs(quest.objectives[1]) do
                local npcId = creatureObjective[1]
                _CollectCreatureLevels({npcId})
            end
        end
        if quest.objectives[3] then -- Looting items from creatures
            for _, itemObjective in pairs(quest.objectives[3]) do
                local itemId = itemObjective[1]
                local npcIds = QuestieDB.QueryItemSingle(itemId, "npcDrops")
                if npcIds then
                    _CollectCreatureLevels(npcIds)
                end
            end
        end
        if quest.objectives[5] then -- Kill credit creatures
            for _, killCreditObjective in pairs(quest.objectives[5]) do
                local npcIds = killCreditObjective[1]
                if npcIds then
                    for i = 1, #npcIds do
                        local npcId = npcIds[i]
                        _CollectCreatureLevels({npcId})
                    end
                end
            end
        end
    end
    if quest.requiredSourceItems then
        for _, itemId in pairs(quest.requiredSourceItems) do
            local npcIds = QuestieDB.QueryItemSingle(itemId, "npcDrops")
            if npcIds then
                _CollectCreatureLevels(npcIds)
            end
        end
    end
    if quest.extraObjectives then
        for _, extraObjective in pairs(quest.extraObjectives) do
            if extraObjective[5] then
                for _, extraObjectiveTarget in pairs(extraObjective[5]) do
                    if extraObjectiveTarget[1] == "monster" then
                        local npcId = extraObjectiveTarget[2]
                        _CollectCreatureLevels({npcId})
                    end
                end
            end
        end
    end
    if quest.Id then
        QuestieDB._CreatureLevelCache[quest.Id] = creatureLevels
    end
    return creatureLevels
end

local playerFaction = UnitFactionGroup("player")
local factionReactions = {
    A = (playerFaction == "Alliance") or nil,
    H = (playerFaction == "Horde") or nil,
    AH = true,
}
--
--
--function __TEST()
--    local questsWithoutTriggerEnd = {
--        869,
--        944,
--        1448,
--        6185,
--        9260,
--        9261,
--        9262,
--        9263,
--        9264,
--        9265,
--        12032,
--        12036,
--        12816,
--        12817,
--        13564,
--        13639,
--        13881,
--        13961,
--        14066,
--        14165,
--        14389,
--        24452,
--        24618,
--        25081,
--        25325,
--        25621,
--        25715,
--        25930,
--        26258,
--        26512,
--        26930,
--        26975,
--        27007,
--        27044,
--        27152,
--        27341,
--        27349,
--        27610,
--        27704,
--        28228,
--        28635,
--        28732,
--        29392,
--        29415,
--        29536,
--        29539,
--    }
--
--    local corrections = {}
--
--    -- Read QuestieDB to check if the quest has a triggerEnd
--    for _, questId in pairs(questsWithoutTriggerEnd) do
--        local quest = QuestieDB.GetQuest(questId)
--        if (not quest) then
--            print("Quest " .. questId .. " not found in QuestieDB")
--            corrections[questId] = true
--        else
--            if quest.triggerEnd then
--                print("Quest " .. questId .. " has a triggerEnd")
--            else
--                print("Quest " .. questId .. " does not have a triggerEnd")
--                corrections[questId] = true
--            end
--        end
--    end
--
--    Questie.db.global.__TEST = corrections
--end
---@param npcId number
---@return table
function QuestieDB:GetNPC(npcId)
    if not npcId then
        return nil
    end
    if _QuestieDB.npcCache[npcId] then
        return _QuestieDB.npcCache[npcId]
    end

    local rawdata = QuestieDB.QueryNPC(npcId, QuestieDB._npcAdapterQueryOrder)
    if (not rawdata) then
        Questie.Debug(Questie.DEBUG_CRITICAL, "[QuestieDB:GetNPC] rawdata is nil for npcID:", npcId)
        return nil
    end

    local npcKeys = QuestieDB.npcKeys
    local npc = {
        id = npcId,
        type = "monster",
    }
    for stringKey, intKey in pairs(npcKeys) do
        npc[stringKey] = rawdata[intKey]
    end

    local friendlyToFaction = rawdata[npcKeys.friendlyToFaction]
    npc.friendly = QuestieDB.IsFriendlyToPlayer(friendlyToFaction)

    _QuestieDB.npcCache[npcId] = npc
    return npc
end

---@param friendlyToFaction string --The NPC database field friendlyToFaction - so either nil, "A", "H" or "AH"
---@return boolean
function QuestieDB.IsFriendlyToPlayer(friendlyToFaction)
    if (not friendlyToFaction) or friendlyToFaction == "AH" then
        return true
    end

    if friendlyToFaction == "H" then
        return QuestiePlayer.faction == "Horde"
    elseif friendlyToFaction == "A" then
        return QuestiePlayer.faction == "Alliance"
    end

    return false
end

---------------------------------------------------------------------------------------------------
-- Modifications to objectDB
function _QuestieDB:DeleteGatheringNodes()
    local prune = { -- gathering nodes
        1617,1618,1619,1620,1621,1622,1623,1624,1628, -- herbs

        1731,1732,1733,1734,1735,123848,150082,175404,176643,177388,324,150079,176645,2040,123310 -- mining
    }
    local objectSpawnsKey = QuestieDB.objectKeys.spawns
    for i=1, #prune do
        local id = prune[i]
        QuestieDB.objectData[id][objectSpawnsKey] = nil
    end
end

---------------------------------------------------------------------------------------------------
-- Modifications to questDB


function _QuestieDB:CheckAchievementRequirements(questId)
    -- So far the only Quests that we know of that requires an earned Achievement are the ones offered by:
    -- https://www.wowhead.com/wotlk/npc=35094/crusader-silverdawn
    -- Get Kraken (14108)
    -- The Fate Of The Fallen (14107)
    -- This NPC requires these earned Achievements baseed on a Players home faction:
    -- https://www.wowhead.com/wotlk/achievement=2817/exalted-argent-champion-of-the-alliance
    -- https://www.wowhead.com/wotlk/achievement=2816/exalted-argent-champion-of-the-horde
    if questId == 14101 or questId == 14102 or questId == 14104 or questId == 14105 or questId == 14107 or questId == 14108 then
        local retN = QuestieCompat.Is335 and 4 or 13
        if select(retN, GetAchievementInfo(2817)) or select(retN, GetAchievementInfo(2816)) then
            return true
        end

        return false
    end
end

function _QuestieDB:HideClassAndRaceQuests()
    local questKeys = QuestieDB.questKeys
    for _, entry in pairs(QuestieDB.questData) do
        -- check requirements, set hidden flag if not met
        local requiredClasses = entry[questKeys.requiredClasses]
        if (requiredClasses) and (requiredClasses ~= 0) then
            if (not QuestiePlayer.HasRequiredClass(requiredClasses)) then
                entry.hidden = true
            end
        end
        local requiredRaces = entry[questKeys.requiredRaces]
        if (requiredRaces) and (requiredRaces ~= 0) and (requiredRaces ~= 255) then
            if (not QuestiePlayer.HasRequiredRace(requiredRaces)) then
                entry.hidden = true
            end
        end
    end
    Questie.Debug(Questie.DEBUG_DEVELOP, "Other class and race quests hidden");
end

-- This function is intended for usage with Gossip and Greeting frames, where there's a list of quests but no QuestIDs are
-- obtainable until entering the specific quest dialog.
-- This is a bruteforce method for obtaining a QuestID with no input other than a quest name, and the ID of the questgiver.
-- It compares the name of the quest entry with the names of every quest that questgiver can either start or end.
---@param name string? @The name of the quest entry
---@param questgiverGUID string? @Should be UnitGUID("questnpc")
---@param questStarter boolean @Should be True if this is an available quest, False if this is an "active" quest (quest ender)
---@return number
function QuestieDB.GetQuestIDFromName(name, questgiverGUID, questStarter)
    local questID = 0 -- worst case, we end up returning an ID of 0 if we can't find a match; any function relying on this one should handle 0 cleanly
    if questgiverGUID then
        local questgiverID = tonumber(questgiverGUID:match("-(%d+)-%x+$"), 10)
        local unit_type = strsplit("-", questgiverGUID)
        local questsStarted
        local questsEnded
        if unit_type == "Creature" then -- if questgiver is an NPC
            questsStarted = QuestieDB.QueryNPCSingle(questgiverID, "questStarts")
            questsEnded = QuestieDB.QueryNPCSingle(questgiverID, "questEnds")
        elseif unit_type == "GameObject" then -- if questgiver is an object (it's rare for an object to have a gossip/greeting frame, but Wanted Boards exist; see object 2713)
            questsStarted = QuestieDB.QueryObjectSingle(questgiverID, "questStarts")
            questsEnded = QuestieDB.QueryObjectSingle(questgiverID, "questEnds")
        else
            return questID; -- If the questgiver is not an NPC or object, bail!
        end
        -- iterate through every questEnds entry in our questgiver's DB, and check if each quest name matches this greeting frame entry
        if questStarter == true then
            if questsStarted then
                for _, id in pairs(questsStarted) do
                    if (name == QuestieDB.QueryQuestSingle(id, "name")) and (QuestieDB.IsDoable(id)) then
                        -- the QuestieDB.IsDoable check is important to filter out identically named quests
                        questID = id
                    end
                end
            else
                Questie.Debug(Questie.DEBUG_ELEVATED, "Database mismatch! No entries found that match quest name. Queststarter is: " .. unit_type .. " " .. questgiverID .. ", quest name is: " .. name)
            end
        else
            if questsEnded then
                for _, id in pairs(questsEnded) do
                    if (name == QuestieDB.QueryQuestSingle(id, "name")) and (QuestieDB.IsDoable(id)) and QuestiePlayer.currentQuestlog[id] then
                        questID = id
                    end
                end
            else
                Questie.Debug(Questie.DEBUG_ELEVATED, "Database mismatch! No entries found that match quest name. Questender is: " .. unit_type .. " " .. questgiverID .. ", quest name is: " .. name)
            end
        end
    end
    return questID;
end
