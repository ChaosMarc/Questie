---@type Phasing
local Phasing = QuestieLoader:ImportModule("Phasing")

local bitband = bit.band
local math_max = math.max
local IsBaseSpawnDataVisible = Phasing.IsSpawnDataVisible

local phases = {
    HAR_KOA_AT_ALTAR = 1034,
    HAR_KOA_AT_ZIM_TORGA = 1035,
}
Phasing.phases = phases

function Phasing.IsSpawnVisible(phase)
    if (not phase) or phase == 0 then
        return true
    end

    if (not Questie) or (not Questie.db) or (not Questie.db.char) or (not Questie.db.char.complete) then
        return true
    end

    local complete = Questie.db.char.complete

    if phase == phases.HAR_KOA_AT_ALTAR then
        return not complete[12685]
    end

    if phase == phases.HAR_KOA_AT_ZIM_TORGA then
        return complete[12685] or false
    end

    return false
end

-- Map::GetSpawnMode uses zero-based difficulty bits, including dynamic raids.
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

    return math_max(difficulty - 1, 0)
end

-- Spawn masks filter only inside the matching instance; world-map planning
-- continues showing all difficulty variants.
function Phasing.IsSpawnDataVisible(spawn)
    if not IsBaseSpawnDataVisible(spawn) then
        return false
    end

    if not spawn or not spawn[4] then
        return true
    end

    local isInInstance = IsInInstance()
    if not isInInstance then
        return true
    end

    local _, _, activeMapId = QuestieCompat.GetCurrentPlayerMinimapWorldPosition()
    local spawnMapId = spawn[5]
    if activeMapId and spawnMapId and activeMapId ~= spawnMapId then
        return true
    end

    return bitband(spawn[4], 2 ^ GetAzerothCoreSpawnMode()) ~= 0
end
