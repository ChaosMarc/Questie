---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")

---@type table<Classes, NpcId[]>
local classTrainers = {}

function Townsfolk.SetClassTrainers(trainers)
    if type(trainers) ~= "table" then
        error("Questie class trainers must be a table")
    end
    classTrainers = trainers
end

function Townsfolk.GetClassTrainers()
    return classTrainers
end
