local event = QuestieLoader:ImportModule("QuestieEvent")
local db = QuestieLoader:ImportModule("QuestieDB")
local zone = QuestieLoader:ImportModule("ZoneDB")

event:SetCalendarAliases({
    names = {["Darkmoon Faire"] = "Darkmoon Faire"},
    textures = {["darkmoon"] = "Darkmoon Faire"},
    plausibleMonths = {},
})

local faireNpcIds = {
    10445, 14828, 14829, 14832, 14833, 14841, 14844,
    14845, 14846, 14847, 14849, 14871,
}
local originalNpcSpawns = {}

event:SetDarkmoonRules({
    allianceQuestId = 7905,
    hordeQuestId = 7926,
    loadNpcFixes = function(eventLocation)
        local zoneIds = zone.zoneIDs
        local activeZone = eventLocation == event.darkmoonLocations.MULGORE and zoneIds.MULGORE
            or eventLocation == event.darkmoonLocations.TEROKKAR_FOREST and zoneIds.TEROKKAR_FOREST
            or zoneIds.ELWYNN_FOREST
        local npcKeys = db.npcKeys
        local fixes = {}

        for _, npcId in ipairs(faireNpcIds) do
            if not originalNpcSpawns[npcId] then
                local npc = assert(db:GetNPC(npcId), "Missing Darkmoon NPC " .. npcId)
                originalNpcSpawns[npcId] = assert(npc.spawns, "Missing Darkmoon NPC spawns " .. npcId)
            end
            local spawns = assert(originalNpcSpawns[npcId][activeZone], "Missing Darkmoon NPC location " .. npcId)
            fixes[npcId] = {
                [npcKeys.spawns] = {[activeZone] = spawns},
                [npcKeys.waypoints] = {},
                [npcKeys.zoneID] = activeZone,
            }
        end

        return fixes
    end,
})

local questIds = {
    7881, 7882, 7883, 7884, 7885, 7889, 7890, 7891, 7892, 7893,
    7894, 7895, 7896, 7897, 7898, 7899, 7900, 7901, 7902, 7903,
    7907, 7927, 7928, 7929, 7930, 7931, 7932, 7933, 7934, 7935,
    7936, 7937, 7938, 7939, 7940, 7941, 7942, 7943, 7944, 7945,
    7946, 7981, 8222, 8223, 9249, 10938, 10939, 10940, 10941,
    13324, 13325, 13326, 13327,
}

for _, questId in ipairs(questIds) do
    table.insert(event.eventQuests, {"Darkmoon Faire", questId})
end
