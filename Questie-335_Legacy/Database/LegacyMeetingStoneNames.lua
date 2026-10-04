local MeetingStones = QuestieLoader:ImportModule("MeetingStones")
local Townsfolk = QuestieLoader:ImportModule("Townsfolk")
local l10n = QuestieLoader:ImportModule("l10n")

local rangesByName

function MeetingStones:GetLevelRangeByDungeonName(dungeonName)
    if not dungeonName then
        return nil
    end

    if not rangesByName then
        rangesByName = {}
        for _, objectId in ipairs(Townsfolk.GetMeetingStones()) do
            local name, range = self:GetLocalizedDungeonNameAndLevelRangeByObjectId(objectId)
            if name and range then
                rangesByName[string.lower(name)] = range
            end
        end
    end

    return rangesByName[string.lower(l10n(dungeonName))]
end
