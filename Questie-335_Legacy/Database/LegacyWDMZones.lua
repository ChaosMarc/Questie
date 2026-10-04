local zone = QuestieLoader:ImportModule("ZoneDB").private

-- World-map subzones supplied by the WDM client patch.
local worldMaps = {
    [198] = 616, [824] = 876, [2257] = 2257,
    [425] = 6170, [427] = 6176, [460] = 6450, [461] = 6451,
    [462] = 6452, [465] = 6454, [467] = 6455, [468] = 6456,
    [38] = 6001, [39] = 6002, [426] = 6003, [53] = 6004,
    [54] = 6005, [28] = 6006, [29] = 6007, [470] = 6008,
    [428] = 6009, [30] = 6010, [31] = 6011, [466] = 6012,
    [19] = 6013, [33] = 6014, [34] = 6015, [35] = 6016,
    [55] = 6017, [16] = 6018, [40] = 6019, [86] = 6020,
    [58] = 6021, [59] = 6022, [60] = 6023, [61] = 6024,
    [8] = 6025, [9] = 6026, [2] = 6027, [3] = 6028,
    [4] = 6029, [5] = 6030, [82] = 6031, [79] = 6032,
    [72] = 6033, [73] = 6034, [74] = 6035, [75] = 6036,
    [6] = 6037, [11] = 6038, [67] = 6039, [68] = 6040,
    [96] = 6041, [98] = 6042, [99] = 6043,
}

for uiMapId, areaId in pairs(worldMaps) do
    zone.areaIdToUiMapId[areaId] = uiMapId
    zone.uiMapIdToAreaId[uiMapId] = areaId
end

zone.areaIdToUiMapId[2057] = 306
zone.uiMapIdToAreaId[306] = 2057
zone.areaIdToUiMapId[4131] = 348
zone.uiMapIdToAreaId[348] = 4131

zone.specialZoneIdToUiMapId = zone.specialZoneIdToUiMapId or {}
local specialMaps = {
    [10002] = 243, [10062] = 162, [10063] = 163, [10064] = 164,
    [10065] = 165, [10066] = 167, [10067] = 190, [10068] = 191,
    [10069] = 189, [10070] = 187, [10071] = 188, [10072] = 192,
    [10089] = 947,
    [10102] = 350, [10103] = 351, [10104] = 352, [10105] = 353,
    [10106] = 354, [10107] = 355, [10108] = 356, [10109] = 357,
    [10110] = 358, [10111] = 359, [10112] = 360, [10113] = 361,
    [10114] = 362, [10115] = 363, [10116] = 364, [10117] = 365,
    [10118] = 366,
}
for zoneId, uiMapId in pairs(specialMaps) do
    zone.specialZoneIdToUiMapId[zoneId] = uiMapId
end

zone.wdmInstanceFloorZoneIdOffset = 11000
zone.wdmInstanceFloorZoneIdToUiMapId = {}
-- These floors have no separate AreaID; other WDM floors retain Legacy's existing IDs.
local floorMaps = {
    222, 223, 227, 228, 229, 231, 235, 236, 237, 238, 239,
    251, 252, 253, 254, 255, 257, 259, 264, 268, 270, 271,
    281, 288, 289, 290, 292, 303, 304, 305, 307, 308, 309,
    311, 312, 313, 314, 315, 316, 318, 320, 321,
    340, 341, 342, 343, 344, 345, 349, 11001, 11002, 11003,
}
for _, uiMapId in ipairs(floorMaps) do
    zone.wdmInstanceFloorZoneIdToUiMapId[11000 + uiMapId] = uiMapId
end
