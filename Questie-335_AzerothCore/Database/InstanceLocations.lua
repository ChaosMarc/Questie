---@type InstanceLocations
local InstanceLocations = QuestieLoader:ImportModule("InstanceLocations")

InstanceLocations:SetInstanceData({
    raidGroupSizes = {
        [1977] = "20-man",    -- Zul'Gurub
        [2159] = "10/25-man", -- Onyxia's Lair
        [2677] = "40-man",    -- Blackwing Lair
        [2717] = "40-man",    -- Molten Core
        [3428] = "40-man",    -- Temple of Ahn'Qiraj
        [3429] = "20-man",    -- Ruins of Ahn'Qiraj
        [3456] = "10/25-man", -- Naxxramas
        [3457] = "10-man",    -- Karazhan
        [3606] = "25-man",    -- Hyjal Summit
        [3607] = "25-man",    -- Serpentshrine Cavern
        [3805] = "10-man",    -- Zul'Aman
        [3836] = "25-man",    -- Magtheridon's Lair
        [3845] = "25-man",    -- The Eye
        [3923] = "25-man",    -- Gruul's Lair
        [3959] = "25-man",    -- Black Temple
        [4075] = "25-man",    -- Sunwell Plateau
        [4273] = "10/25-man", -- Ulduar
        [4493] = "10/25-man", -- The Obsidian Sanctum
        [4500] = "10/25-man", -- The Eye of Eternity
        [4603] = "10/25-man", -- Vault of Archavon
        [4722] = "10/25-man", -- Trial of the Crusader
        [4812] = "10/25-man", -- Icecrown Citadel
        [4987] = "10/25-man", -- The Ruby Sanctum
    },
    raidAreaIds = {
        [1977] = true, -- Zul'Gurub
        [2159] = true, -- Onyxia's Lair
        [2677] = true, -- Blackwing Lair
        [2717] = true, -- Molten Core
        [3428] = true, -- Ahn'Qiraj Temple
        [3429] = true, -- Ruins of Ahn'Qiraj
        [3456] = true, -- Naxxramas
        [3457] = true, -- Karazhan
        [3606] = true, -- Hyjal Summit
        [3607] = true, -- Serpentshrine Cavern
        [3805] = true, -- Zul'Aman
        [3836] = true, -- Magtheridon's Lair
        [3845] = true, -- The Eye
        [3923] = true, -- Gruul's Lair
        [3959] = true, -- Black Temple
        [4075] = true, -- Sunwell Plateau
        [4273] = true, -- Ulduar
        [4493] = true, -- The Obsidian Sanctum
        [4500] = true, -- The Eye of Eternity
        [4603] = true, -- Vault of Archavon
        [4722] = true, -- Trial of the Crusader
        [4812] = true, -- Icecrown Citadel
        [4987] = true, -- The Ruby Sanctum
    },
    supplementalNames = {
        [1977] = "Zul'Gurub",
        [2159] = "Onyxia's Lair",
        [2677] = "Blackwing Lair",
        [2717] = "Molten Core",
        [3428] = "Temple of Ahn'Qiraj",
        [3429] = "Ruins of Ahn'Qiraj",
        [3607] = "Serpentshrine Cavern",
        [3845] = "The Eye",
    },
})
