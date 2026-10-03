---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")

---@type NpcId[]
local professionTrainers = {}

function Townsfolk.SetProfessionTrainers(trainers)
    if type(trainers) ~= "table" then
        error("Questie profession trainers must be a table")
    end
    professionTrainers = trainers
end

function Townsfolk.GetProfessionTrainers()
    return professionTrainers
end
