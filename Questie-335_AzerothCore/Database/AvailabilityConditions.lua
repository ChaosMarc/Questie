---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieReputation
local QuestieReputation = QuestieLoader:ImportModule("QuestieReputation")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

local bitband = bit.band
local IsQuestCompletedOnServer = QuestieCompat.IsQuestCompletedOnServer or QuestieCompat.IsQuestFlaggedCompleted
local IsAzerothCoreDailyQuestComplete = QuestieCompat.IsAzerothCoreDailyQuestComplete
local IsSpellKnownOrOverridesKnown = QuestieCompat.IsSpellKnownOrOverridesKnown
local IsPlayerSpell = QuestieCompat.IsPlayerSpell

local ACORE_CONDITION_AURA = 1
local ACORE_CONDITION_ITEM = 2
local ACORE_CONDITION_ZONE_ID = 4
local ACORE_CONDITION_REPUTATION_RANK = 5
local ACORE_CONDITION_QUEST_REWARDED = 8
local ACORE_CONDITION_QUEST_TAKEN = 9
local ACORE_CONDITION_QUEST_NONE = 14
local ACORE_CONDITION_CLASS = 15
local ACORE_CONDITION_ACHIEVEMENT = 17
local ACORE_CONDITION_SPAWNMASK = 19
local ACORE_CONDITION_AREA_ID = 23
local ACORE_CONDITION_SPELL = 25
local ACORE_CONDITION_QUEST_COMPLETE = 28
local ACORE_CONDITION_DAILY_QUEST_DONE = 43
local ACORE_CONDITION_QUEST_STATE = 47
local ACORE_QUEST_STATUS_NONE = 1
local ACORE_QUEST_STATUS_COMPLETE = 2
local ACORE_QUEST_STATUS_IN_PROGRESS = 8
local ACORE_QUEST_STATUS_FAILED = 32
local ACORE_QUEST_STATUS_REWARDED = 64

local ACORE_CONDITION_NAMES = {
    [ACORE_CONDITION_AURA] = "aura",
    [ACORE_CONDITION_ITEM] = "item",
    [ACORE_CONDITION_ZONE_ID] = "zone",
    [ACORE_CONDITION_REPUTATION_RANK] = "reputation rank",
    [ACORE_CONDITION_QUEST_REWARDED] = "rewarded quest",
    [ACORE_CONDITION_QUEST_TAKEN] = "active quest",
    [ACORE_CONDITION_QUEST_NONE] = "untaken quest",
    [ACORE_CONDITION_CLASS] = "class",
    [ACORE_CONDITION_ACHIEVEMENT] = "achievement",
    [ACORE_CONDITION_SPAWNMASK] = "spawn mask",
    [ACORE_CONDITION_AREA_ID] = "area",
    [ACORE_CONDITION_SPELL] = "spell",
    [ACORE_CONDITION_QUEST_COMPLETE] = "completed quest",
    [ACORE_CONDITION_DAILY_QUEST_DONE] = "daily quest completion",
    [ACORE_CONDITION_QUEST_STATE] = "quest state",
}

local function GetConditions()
    return QuestieCompat.AzerothCoreQuestAvailabilityConditions or {}
end

local function HasPlayerAura(spellId)
    for index = 1, 40 do
        local auraSpellId = select(11, UnitBuff("player", index))
        if not auraSpellId then
            break
        elseif auraSpellId == spellId then
            return true
        end
    end

    for index = 1, 40 do
        local auraSpellId = select(11, UnitDebuff("player", index))
        if not auraSpellId then
            break
        elseif auraSpellId == spellId then
            return true
        end
    end

    return false
end

local function IsAzerothCoreQuestRewarded(questId)
    -- AzerothCore does not mark ordinary repeatable quests as rewarded.
    return not QuestieDB.IsRepeatable(questId) and IsQuestCompletedOnServer(questId)
end

local function GetAzerothCoreQuestStatusMask(questId)
    if QuestiePlayer.currentQuestlog[questId] then
        local questLogEntry = QuestLogCache.questLog_DO_NOT_MODIFY[questId]
        if questLogEntry and questLogEntry.isComplete == 1 then
            return ACORE_QUEST_STATUS_COMPLETE
        elseif questLogEntry and questLogEntry.isComplete == -1 then
            return ACORE_QUEST_STATUS_FAILED
        end

        return ACORE_QUEST_STATUS_IN_PROGRESS
    end

    if IsAzerothCoreQuestRewarded(questId) then
        return ACORE_QUEST_STATUS_REWARDED
    end

    return ACORE_QUEST_STATUS_NONE
end

local function GetAzerothCoreSpawnMode()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance then
        return 0
    end

    local _, _, difficulty, _, _, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    difficulty = difficulty or 1

    if instanceType == "raid" and isDynamicInstance and (difficulty == 1 or difficulty == 2) then
        return difficulty - 1 + ((playerDifficulty or 0) * 2)
    end

    return math.max(difficulty - 1, 0)
end

local function IsAzerothCoreLocationConditionType(conditionType)
    return conditionType == ACORE_CONDITION_ZONE_ID or conditionType == ACORE_CONDITION_AREA_ID
end

local function IsAzerothCoreConditionFulfilled(condition, ignoreLocationConditions)
    local conditionType = condition[1]
    local value1 = condition[2]
    local value2 = condition[3]
    local value3 = condition[4]
    local isNegative = condition[5] == 1
    local fulfilled = false

    if ignoreLocationConditions and IsAzerothCoreLocationConditionType(conditionType) then
        return true
    end

    if conditionType == ACORE_CONDITION_AURA then
        fulfilled = HasPlayerAura(value1)
    elseif conditionType == ACORE_CONDITION_ITEM then
        fulfilled = GetItemCount(value1, value3 ~= 0) >= value2
    elseif conditionType == ACORE_CONDITION_ZONE_ID then
        fulfilled = QuestiePlayer:GetCurrentZoneId() == value1
    elseif conditionType == ACORE_CONDITION_REPUTATION_RANK then
        local standingId = QuestieReputation:GetFactionStandingId(value1)
        local rankMask = 2 ^ math.max((standingId or 4) - 1, 0)
        fulfilled = bitband(value2, rankMask) ~= 0
    elseif conditionType == ACORE_CONDITION_QUEST_REWARDED then
        fulfilled = IsAzerothCoreQuestRewarded(value1)
    elseif conditionType == ACORE_CONDITION_QUEST_TAKEN then
        fulfilled = GetAzerothCoreQuestStatusMask(value1) == ACORE_QUEST_STATUS_IN_PROGRESS
    elseif conditionType == ACORE_CONDITION_QUEST_NONE then
        fulfilled = GetAzerothCoreQuestStatusMask(value1) == ACORE_QUEST_STATUS_NONE
    elseif conditionType == ACORE_CONDITION_CLASS then
        fulfilled = QuestiePlayer.HasRequiredClass(value1)
    elseif conditionType == ACORE_CONDITION_ACHIEVEMENT then
        fulfilled = select(4, GetAchievementInfo(value1)) == true
    elseif conditionType == ACORE_CONDITION_SPAWNMASK then
        fulfilled = bitband(value1, 2 ^ GetAzerothCoreSpawnMode()) ~= 0
    elseif conditionType == ACORE_CONDITION_AREA_ID then
        fulfilled = QuestiePlayer:GetCurrentAreaId() == value1
    elseif conditionType == ACORE_CONDITION_SPELL then
        fulfilled = IsSpellKnownOrOverridesKnown(value1) or IsPlayerSpell(value1)
    elseif conditionType == ACORE_CONDITION_QUEST_COMPLETE then
        fulfilled = GetAzerothCoreQuestStatusMask(value1) == ACORE_QUEST_STATUS_COMPLETE
    elseif conditionType == ACORE_CONDITION_DAILY_QUEST_DONE then
        fulfilled = (IsAzerothCoreDailyQuestComplete and IsAzerothCoreDailyQuestComplete(value1))
            or (Questie.db.char.daily and Questie.db.char.daily[value1] == true)
    elseif conditionType == ACORE_CONDITION_QUEST_STATE then
        fulfilled = bitband(value2, GetAzerothCoreQuestStatusMask(value1)) ~= 0
    end

    return isNegative and not fulfilled or (not isNegative and fulfilled)
end

function QuestieDB:IsProviderAvailabilityConditionFulfilled(questId, ignoreLocationConditions)
    local groups = GetConditions()[questId]
    if not groups then
        return true
    end

    local lastFailedCondition
    for _, group in ipairs(groups) do
        local groupFulfilled = true
        for _, condition in ipairs(group) do
            if not IsAzerothCoreConditionFulfilled(condition, ignoreLocationConditions) then
                groupFulfilled = false
                lastFailedCondition = condition
                break
            end
        end

        if groupFulfilled then
            return true
        end
    end

    return false, lastFailedCondition
end

function QuestieDB:HasProviderLocationCondition(questId)
    if self.providerLocationConditionQuestIds[questId] then
        return true
    end

    for _, group in ipairs(GetConditions()[questId] or {}) do
        for _, condition in ipairs(group) do
            if IsAzerothCoreLocationConditionType(condition[1]) then
                return true
            end
        end
    end

    return false
end

function QuestieDB:IsProviderAvailabilityConditionFulfilledForSpawnZone(questId, spawnZoneId)
    if not self:HasProviderLocationCondition(questId) then
        return true
    end

    local groups = GetConditions()[questId]
    local subZoneToParentZone = ZoneDB.private and ZoneDB.private.subZoneToParentZone

    for _, group in ipairs(groups) do
        local groupFulfilled = true

        for _, condition in ipairs(group) do
            local conditionType = condition[1]
            if IsAzerothCoreLocationConditionType(conditionType) then
                local requiredZoneId = condition[2]
                if conditionType == ACORE_CONDITION_AREA_ID and subZoneToParentZone then
                    requiredZoneId = subZoneToParentZone[requiredZoneId] or requiredZoneId
                end

                local fulfilled = spawnZoneId == requiredZoneId
                if condition[5] == 1 then
                    fulfilled = not fulfilled
                end

                if not fulfilled then
                    groupFulfilled = false
                    break
                end
            elseif not IsAzerothCoreConditionFulfilled(condition) then
                groupFulfilled = false
                break
            end
        end

        if groupFulfilled then
            return true
        end
    end

    return false
end

function QuestieDB:InitializeProviderAvailabilityConditionIndexes()
    self.providerAuraConditionQuestIds = {}
    self.providerLocationConditionQuestIds = {}

    for questId, groups in pairs(GetConditions()) do
        for _, group in ipairs(groups) do
            for _, condition in ipairs(group) do
                if condition[1] == ACORE_CONDITION_ITEM then
                    self.requiredItemConditionQuestIds[questId] = true
                elseif condition[1] == ACORE_CONDITION_AURA then
                    self.providerAuraConditionQuestIds[questId] = true
                elseif IsAzerothCoreLocationConditionType(condition[1]) then
                    self.providerLocationConditionQuestIds[questId] = true
                end
            end
        end
    end
end

local GetCoreAvailabilityItemConditionState = QuestieDB.GetAvailabilityItemConditionState

function QuestieDB:GetAvailabilityItemConditionState(questId)
    local states = {GetCoreAvailabilityItemConditionState(self, questId)}
    for _, group in ipairs(GetConditions()[questId] or {}) do
        for _, condition in ipairs(group) do
            if condition[1] == ACORE_CONDITION_ITEM then
                states[#states + 1] = IsAzerothCoreConditionFulfilled(condition) and "1" or "0"
            end
        end
    end

    return table.concat(states)
end

function QuestieDB:GetProviderAvailabilityConditionDescription(condition)
    if not condition then
        return "unknown AzerothCore condition"
    end

    local conditionName = ACORE_CONDITION_NAMES[condition[1]] or ("condition " .. tostring(condition[1]))
    local negativeText = condition[5] == 1 and "negative " or ""
    return "AzerothCore " .. negativeText .. conditionName .. " " .. tostring(condition[2])
end
