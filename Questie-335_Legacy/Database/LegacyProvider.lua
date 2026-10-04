local provider = QuestieLoader:ImportModule("QuestieDBProvider")
local db = QuestieLoader:ImportModule("QuestieDB")
local zone = QuestieLoader:ImportModule("ZoneDB")
local corePrivate = QuestieLoader:ImportModule("LegacyZoneBridge").corePrivate

for key, value in pairs(zone.private) do
    corePrivate[key] = value
end
corePrivate.specialZoneIdToUiMapId = corePrivate.specialZoneIdToUiMapId or {}
corePrivate.wdmInstanceFloorZoneIdToUiMapId = corePrivate.wdmInstanceFloorZoneIdToUiMapId or {}
zone.private = corePrivate
zone:BindProviderData()

provider:RestoreCoreKeys()
db.questsOnlyAvailableUntilReputationValue = {}

local questSource = db.questData
local questSourceWithCoreFields = [[
local quests = (function()
]] .. questSource .. [[
end)()
for _, quest in pairs(quests) do
    quest[32] = quest[30]
    quest[31] = quest[29]
    quest[30] = quest[28]
    quest[29] = quest[27]
    quest[27] = nil
    quest[28] = nil
end
return quests
]]

provider:Register({
    id = "legacy-wotlk",
    version = "widxwer",
    schemaVersion = provider.schemaVersion,
    GetRawData = function(key)
        if key == "questData" then
            return questSourceWithCoreFields
        end
        return db[key]
    end,
})
