---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

-- Quests where the reputation only goes in one direction (ex. Thorium Brotherhood)
QuestieDB.questsOnlyAvailableUntilReputationValue = {
    -- Thorium Brotherhood
    [7736] = true, -- Restoring Fiery Flux Supplies via Kingsblood
    [7737] = true, -- Gaining Acceptance
    [8241] = true, -- Restoring Fiery Flux Supplies via Iron
    [8242] = true, -- Restoring Fiery Flux Supplies via Heavy Leather

    -- Brood of Nozdormu
    [8302] = true, -- The Hand of the Righteous

    -- Argent Dawn
    [9221] = true, -- Superior Armaments of Battle - Friend of the Dawn
    [9222] = true, -- Epic Armaments of Battle - Friend of the Dawn
    [9223] = true, -- Superior Armaments of Battle - Honored Amongst the Dawn
    [9224] = true, -- Epic Armaments of Battle - Honored Amongst the Dawn
    [9225] = true, -- Epic Armaments of Battle - Revered Amongst the Dawn
    [9226] = true, -- Superior Armaments of Battle - Revered Amongst the Dawn
    [28755] = true, -- Annals of the Silver Hand
    [28756] = true, -- Aberrations of Bone

    -- Consortium
    [9882] = true, -- Stealing from Thieves
    [9883] = true, -- More Crystal Fragments
    [9884] = true, -- Membership Benefits
    [9885] = true, -- Membership Benefits
    [9886] = true, -- Membership Benefits
    [9914] = true, -- A Head Full of Ivory
    [9915] = true, -- More Heads Full of Ivory

    -- Cenarion Expedition
    [9784] = true, -- Identify Plant Parts
    --[9802] = true, -- Plants of Zangarmarsh -- TO DO CHECK THIS
    [9875] = true, -- Uncatalogued Species

    -- Sporregar
    --[9739] = true, -- The Sporelings' Plight -- TO DO CHECK THIS
    [9742] = true, -- More Spore Sacs
    --[9743] = true, -- Natural Enemies -- TO DO CHECK THIS
    [9744] = true, -- More Tendrils!
    --[9808] = true, -- Glowcap Mushrooms -- TO DO CHECK THIS
    [9809] = true, -- More Glowcaps

    -- Lower City
    --[10917] = true, -- The Outcast's Plight -- TO DO CHECK THIS
    [10918] = true, -- More Feathers

    -- Order of the Cloud Serpent
    [31784] = true, -- Onyx To Goodness
}

QuestieDB.waypointPresets = {
    ORGRIMS_HAMMER = {[ZoneDB.zoneIDs.ICECROWN]={{{62.37,30.60},{61.93,30.93},{61.48,31.24},{61.08,31.55},{60.74,31.92},{60.46,32.44},{60.26,33.11},{60.14,33.85},{60.11,34.63},{60.17,35.35},{60.31,36.01},{60.56,36.66},{60.84,37.33},{61.15,38.00},{61.44,38.67},{61.71,39.28},{62.00,39.92},{62.31,40.55},{62.60,41.20},{62.90,41.83},{63.05,42.20},{63.33,42.85},{63.58,43.53},{63.85,44.19},{64.08,44.86},{64.33,45.50},{64.45,45.87},{64.69,46.56},{64.94,47.21},{65.16,47.87},{65.43,48.51},{65.71,49.15},{66.03,49.77},{66.36,50.46},{66.72,51.10},{67.07,51.67},{67.41,52.08},{67.82,52.37},{68.31,52.47},{68.80,52.38},{69.23,51.98},{69.45,51.56},{69.57,51.13},{69.67,50.59},{69.73,49.96},{69.77,49.26},{69.79,48.48},{69.80,47.62},{69.79,46.68},{69.79,45.68},{69.78,44.90},{69.78,44.25},{69.76,43.55},{69.75,42.80},{69.72,42.01},{69.70,41.20},{69.67,40.38},{69.64,39.54},{69.61,38.71},{69.58,37.88},{69.55,37.07},{69.52,36.28},{69.49,35.54},{69.46,34.83},{69.45,34.18},{69.42,33.50},{69.41,32.46},{69.42,31.52},{69.45,30.67},{69.47,29.92},{69.48,29.25},{69.46,28.65},{69.42,28.12},{69.35,27.83},{69.11,27.19},{68.71,26.77},{68.23,26.54},{67.71,26.51},{67.24,26.55},{66.81,26.76},{66.35,27.09},{65.90,27.52},{65.44,27.95},{65.01,28.39},{64.58,28.73},{64.16,29.10},{63.74,29.43},{63.34,29.79},{62.94,30.11},{62.65,30.37},{62.37,30.60}}}},
    THE_SKYBREAKER = {[ZoneDB.zoneIDs.ICECROWN]={{{63.59,52.34},{63.44,51.88},{63.30,51.52},{63.15,51.19},{63.01,50.85},{62.85,50.52},{62.68,50.17},{62.50,49.78},{62.31,49.36},{62.09,48.88},{61.86,48.33},{61.81,48.20},{61.67,47.88},{61.52,47.52},{61.37,47.13},{61.19,46.74},{61.02,46.32},{60.84,45.88},{60.65,45.44},{60.46,44.99},{60.28,44.53},{60.09,44.08},{59.90,43.63},{59.72,43.18},{59.54,42.75},{59.36,42.34},{59.20,41.94},{59.04,41.56},{58.89,41.22},{58.75,40.87},{58.52,40.30},{58.32,39.77},{58.14,39.27},{57.97,38.80},{57.81,38.39},{57.65,38.03},{57.49,37.72},{57.31,37.50},{57.12,37.34},{56.87,37.29},{56.57,37.39},{56.27,37.60},{55.97,37.88},{55.72,38.23},{55.53,38.61},{55.43,38.95},{55.43,39.09},{55.46,39.49},{55.52,39.92},{55.62,40.39},{55.76,40.88},{55.89,41.38},{56.02,41.85},{56.17,42.25},{56.33,42.68},{56.51,43.13},{56.70,43.56},{56.88,43.99},{57.05,44.39},{57.22,44.74},{57.42,45.15},{57.64,45.52},{57.83,45.81},{58.03,46.14},{58.23,46.56},{58.41,46.90},{58.60,47.25},{58.80,47.62},{59.00,48.03},{59.19,48.46},{59.36,48.84},{59.53,49.22},{59.69,49.63},{59.86,50.04},{60.03,50.46},{60.19,50.90},{60.36,51.32},{60.51,51.74},{60.65,52.17},{60.79,52.59},{60.94,53.02},{61.07,53.46},{61.23,53.89},{61.39,54.30},{61.55,54.72},{61.70,55.18},{61.88,55.65},{62.05,56.14},{62.23,56.58},{62.43,56.95},{62.65,57.21},{62.87,57.30},{62.95,57.27},{63.22,57.16},{63.52,56.97},{63.81,56.68},{64.07,56.32},{64.26,55.91},{64.33,55.47},{64.30,55.11},{64.25,54.72},{64.16,54.30},{64.04,53.84},{63.91,53.36},{63.76,52.88},{63.59,52.34}}}},
}
