local QuestXP = QuestieLoader:ImportModule("QuestXP")
local floor = math.floor
local multiplier = 1

function QuestXP.Init()
    if multiplier ~= 1 then return end
    for i = 1, 40 do
        local spellId = select(10, QuestieCompat.UnitBuff("player", i))
        if spellId == 377749 then
            multiplier = 1.5
            break
        end
    end
end

function QuestXP:GetQuestLogRewardXP(questId, ignorePlayerLevel)
    self.Init()
    local quest = self.db[questId]
    if not quest then return 0 end
    local level, xp = quest[1], quest[2]
    if level <= 0 or xp <= 0 then return 0 end

    local playerLevel = UnitLevel("player")
    if not ignorePlayerLevel and playerLevel == QuestieCompat.GetMaxPlayerLevel() then
        return 0
    end
    local scale = math.max(1, math.min(10, 2 * (level - playerLevel) + 20))
    xp = xp * scale / 10
    if xp <= 100 then
        xp = 5 * floor((xp + 2) / 5)
    elseif xp <= 500 then
        xp = 10 * floor((xp + 5) / 10)
    elseif xp <= 1000 then
        xp = 25 * floor((xp + 12) / 25)
    else
        xp = 50 * floor((xp + 25) / 50)
    end
    return floor(xp * multiplier)
end
