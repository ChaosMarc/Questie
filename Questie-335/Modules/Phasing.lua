---@class Phasing
local Phasing = QuestieLoader:CreateModule("Phasing")

---@param phase number|nil
---@return boolean
function Phasing.IsSpawnVisible(phase)
    return not phase or phase == 0
end

---@param spawn number[]|nil
---@return boolean
function Phasing.IsSpawnDataVisible(spawn)
    if not spawn then
        return true
    end

    return Phasing.IsSpawnVisible(spawn[3])
end
