---@type QuestieDBProvider
local QuestieDBProvider = QuestieLoader:ImportModule("QuestieDBProvider")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

QuestieDBProvider:RestoreCoreKeys()
QuestieLoader:ImportModule("ZoneDB"):BindProviderData()

QuestieDBProvider:Register({
    id = "azerothcore-wotlk",
    version = "1",
    schemaVersion = QuestieDBProvider.schemaVersion,
    GetRawData = function(key)
        return QuestieDB[key]
    end,
})
