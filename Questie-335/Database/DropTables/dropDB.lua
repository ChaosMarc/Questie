---@class DropDB
local DropDB = QuestieLoader:CreateModule("DropDB")

local providerDropRates
local providerSource
local providerIconName

function DropDB:Initialize()
end

function DropDB:SetProviderDrops(dropRates, source, iconName)
    if type(dropRates) ~= "table" or type(source) ~= "string" or source == ""
        or (iconName ~= nil and (type(iconName) ~= "string" or iconName == "")) then
        error("Invalid item drop provider data")
    end
    providerDropRates = dropRates
    providerSource = source
    providerIconName = iconName
end

function DropDB.GetSourceIconName(source)
    if source == providerSource then
        return providerIconName
    end
end

-- To obtain final drop rate data, query QuestieDB.GetItemDroprate(ItemID,NpcID).
-- DropDB returns the effective drop rate supplied by the database provider.

-- The number provided is a float; it is up to the end user to determine how to display that.
-- 100.0 would be 100%, 47.254 would be 47.254%, etc.

-- Return values are {dropRate, sourceDB} as {float, str}

-- This function will return nil if the DB is not loaded properly or there is no data match.
-- Be sure you can handle successful nil returns!

---@param itemId ItemId
---@param npcId NpcId
---@return table<number, string>?
function DropDB.GetItemDroprate(itemId, npcId)
    local rate = providerDropRates and providerDropRates[itemId] and providerDropRates[itemId][npcId]
    if rate then
        return {rate, providerSource}
    end

    return nil
end
