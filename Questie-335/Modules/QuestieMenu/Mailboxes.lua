---@type Townsfolk
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")

local mailboxes = {}

function Townsfolk.SetMailboxes(objects)
    if type(objects) ~= "table" then
        error("Questie mailboxes must be a table")
    end
    mailboxes = objects
end

function Townsfolk.GetMailboxes()
    return mailboxes
end
