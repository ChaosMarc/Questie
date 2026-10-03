---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")

local meetingStones = {}

function Townsfolk.SetMeetingStones(stones)
    if type(stones) ~= "table" then
        error("Questie meeting stones must be a table")
    end
    meetingStones = stones
end

function Townsfolk.GetMeetingStones()
    return meetingStones
end
