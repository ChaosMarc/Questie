--[[
Feast of Winter Veil    1.2.0    18 December 2004
Noblegarden    1.3.0    7 March 2005    X
Children's Week    1.4.0    5 May 2005
Darkmoon Faire    1.6.0    2 July 2005
Harvest Festival    1.6.0    2 July 2005    X
Hallow's End    1.8.0    10 October 2005
Lunar Festival    1.9.0    3 January 2006    X
Love is in the Air    1.9.3    7 February 2006
Midsummer Fire Festival    1.11.0    20 June 2006
Peon Day    1.12.1    22 August 2006    X

New Year    31st Dec - 1st Jan    New Year's Eve    Gregorian calendar
Lunar Festival    Varies (Spring)    Lunar New Year    Chinese calendar
Love is in the Air    7th Feb - 20th Feb    Valentine's Day
Noblegarden    Varies (Easter)    Easter
Children's Week    1st May - 7th May    Children's Day - Japan
Mother's Day - US (and in most other countries, including: Belgium and the Netherlands)
Midsummer Fire Festival    21st June - 5th July    Midsummer
Canada Day - CAN
Independence Day - US    US observed! Fire in the Sky Engineers' Explosive Extravaganza
Pirates' Day    19th Sept    International Talk Like a Pirate Day    First observed Sept 19th, 2008.
Brewfest    20th Sept - 4th Oct    Oktoberfest - Germany
Harvest Festival    27th Sept - 4th Oct    Roughly Thanksgiving - Canada, US (actually celebrated in October and November in Canada and US, respectively)
Columbus Day - US
US Stress Test ended: September 12, 2004
Peon Day    30th Sept    EU Closed Beta began: September 30, 2004    Observed only in Europe[1]
Hallow's End    18th Oct - 1st Nov    Halloween
Day of the Dead    1st Nov - 2nd Nov    Day of the Dead
Pilgrim's Bounty    22nd Nov - 28th Nov    Thanksgiving
Feast of Winter Veil    15th Dec - 2nd Jan    Christmas

Harvest Festival history:         lunar calendar 15/8 in gregorian calendar:
2009: Su-Sa 27/9 - 3/10 (wowpedia)    3/10
2010: Th-We 16/9 - 22/9 (wowpedia)   22/9
2011: Tu-Mo  6/9 - 12/9 (wowpedia)   12/9
2012: Mo-Mo 24/9 - 1/10 (wowpedia)   30/9
2013: Fr-Fr 13/9 - 20/9 (wowpedia)   19/9
2014: Tu-Tu  2/9 -  9/9 (Blizz post)  8/9
2015: Mo-Mo 21/9 - 28/9 (wowpedia)   27/9
2016: Fr-Fr  9/9 - 16/9 (Blizz post) 15/9
2017: Fr-Fr 29/9 - 6/10 (wowpedia)    4/10
2018: Tu-Tu 18/9 - 25/9 (wowpedia)   24/9
2019: Tu-Tu 10/9 - 17/9 (classic Blizz post) 13/9
2020: Tu-Tu 29/9 - 6/10 (retail Blizz post)   1/10
2021: Fr-Fr 17/9 - 24/9 (retail Blizz post)  21/9
]] --

---@class QuestieEvent
---@field public private QuestieEventPrivate
local QuestieEvent = QuestieLoader:CreateModule("QuestieEvent")
---@class QuestieEventPrivate
local _QuestieEvent = QuestieEvent.private

QuestieEvent.activeQuests = {}
QuestieEvent.eventDates = {}
QuestieEvent.eventDateCorrections = {CLASSIC = {}, TBC = {}}
QuestieEvent.lunarFestival = {}
QuestieEvent.eventQuests = {}
_QuestieEvent.eventNamesForQuests = {}
_QuestieEvent.eventQuestsInCurrentExpansion = {}
_QuestieEvent.announcedEvents = {}
_QuestieEvent.announcedUpcomingEvents = {}
_QuestieEvent.timedEventLiveStartTimers = {}
_QuestieEvent.timedEventQuestStartTimers = {}
_QuestieEvent.timedEventQuestEndTimers = {}
_QuestieEvent.timedEventQuestIds = {}
_QuestieEvent.preEventQuestRefreshTimer = nil
_QuestieEvent.initializeTimer = nil
_QuestieEvent.initializeAttempts = 0

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_DateAndTime = QuestieCompat.C_DateAndTime
local C_Timer = QuestieCompat.C_Timer

local type = type
local strlower = string.lower
local strfind = string.find
local _WithinDates, _LoadDarkmoonFaire, _GetDarkmoonFaireLocation,
    _GetDarkmoonFaireLocationForDate, _GetDarkmoonFaireLocationForMonth,
    _GetDarkmoonFaireLocationForCalendarEvent, _GetDarkmoonFaireEventName,
    _IsEventQuestVisible, _GetCalendarEventName, _GetActiveCalendarEvents,
    _GetNextCalendarDay,
    _IsCalendarEventMonthPlausible, _IsCalendarEventActiveNow,
    _IsCalendarEventLiveNow, _IsCalendarEventQuestActiveNow,
    _GetTimedEventLiveStartDelay, _GetTimedEventQuestStartDelay,
    _GetTimedEventQuestEndDelay, _AnnounceActiveEvent,
    _AnnounceUpcomingTimedEvent, _SetTimedEventQuestState,
    _SetPreEventQuestState, _SchedulePreEventQuestRefresh,
    _ScheduleTimedEventActiveAnnouncement, _ScheduleTimedEventQuestStart,
    _ScheduleTimedEventQuestEnd,
    _PrimeCalendar, _RefreshAvailableQuests, _ShouldAnnounceWorldEvents,
    _CancelInitializeTimer

local EVENT_INIT_INITIAL_DELAY = 1
local EVENT_INIT_RETRY_INTERVAL = 1
local EVENT_INIT_MAX_ATTEMPTS = 12

_ShouldAnnounceWorldEvents = function()
    return (not Questie.db) or (not Questie.db.profile) or Questie.db.profile.announceWorldEvents ~= false
end

_CancelInitializeTimer = function()
    if _QuestieEvent.initializeTimer then
        _QuestieEvent.initializeTimer:Cancel()
        _QuestieEvent.initializeTimer = nil
    end
end

local CALENDAR_EVENT_NAME_ALIASES = {}
local CALENDAR_EVENT_TEXTURE_ALIASES = {}
local CALENDAR_EVENT_PLAUSIBLE_MONTHS = {}
local CALENDAR_EVENT_TIME_WINDOWS = {}
local PRE_EVENT_QUEST_IDS = {}
local PRE_EVENT_EVENT_NAME
local darkmoonRules

function QuestieEvent:SetCalendarRules(rules)
    if type(rules) ~= "table"
        or type(rules.timeWindows) ~= "table"
        or type(rules.preEventQuestIds) ~= "table"
        or (rules.preEventName ~= nil and type(rules.preEventName) ~= "string")
        or (next(rules.preEventQuestIds) ~= nil and not rules.preEventName) then
        error("Questie calendar rules must contain timeWindows and preEventQuestIds with a preEventName")
    end

    CALENDAR_EVENT_TIME_WINDOWS = rules.timeWindows
    PRE_EVENT_QUEST_IDS = rules.preEventQuestIds
    PRE_EVENT_EVENT_NAME = rules.preEventName
end

function QuestieEvent:SetCalendarAliases(aliases)
    if type(aliases) ~= "table" or type(aliases.names) ~= "table"
        or type(aliases.textures) ~= "table" or type(aliases.plausibleMonths) ~= "table" then
        error("Questie calendar aliases must contain names, textures and plausibleMonths")
    end

    CALENDAR_EVENT_NAME_ALIASES = aliases.names
    CALENDAR_EVENT_TEXTURE_ALIASES = aliases.textures
    CALENDAR_EVENT_PLAUSIBLE_MONTHS = aliases.plausibleMonths
end

function QuestieEvent:SetDarkmoonRules(rules)
    if type(rules) ~= "table" or type(rules.allianceQuestId) ~= "number"
        or type(rules.hordeQuestId) ~= "number" or type(rules.loadNpcFixes) ~= "function" then
        error("Questie Darkmoon rules must contain announcement quest IDs and loadNpcFixes")
    end
    darkmoonRules = rules
end

local DMF_LOCATIONS = {
    NONE = 0,
    MULGORE = 1,
    ELWYNN_FOREST = 2,
    TEROKKAR_FOREST = 3,
}
QuestieEvent.darkmoonLocations = DMF_LOCATIONS

---@param texture string?
---@return number?
_GetDarkmoonFaireLocationForCalendarEvent = function(texture)
    if type(texture) ~= "string" then
        return nil
    end

    local normalizedTexture = strlower(texture)
    if strfind(normalizedTexture, "terokkar", 1, true) or strfind(normalizedTexture, "shattrath", 1, true) then
        return DMF_LOCATIONS.TEROKKAR_FOREST
    elseif strfind(normalizedTexture, "mulgore", 1, true) or strfind(normalizedTexture, "thunder", 1, true) then
        return DMF_LOCATIONS.MULGORE
    elseif strfind(normalizedTexture, "elwynn", 1, true) or strfind(normalizedTexture, "goldshire", 1, true) then
        return DMF_LOCATIONS.ELWYNN_FOREST
    end

    return nil
end

---@param hideQuest boolean|number|nil
---@return boolean
_IsEventQuestVisible = function(hideQuest)
    if hideQuest == nil then
        return true
    end

    if type(hideQuest) == "boolean" then
        return not hideQuest
    end

    if hideQuest == QuestieCorrections.TBC_ONLY then
        return not Questie.IsTBC
    elseif hideQuest == QuestieCorrections.CLASSIC_ONLY then
        return not Questie.IsClassic
    elseif hideQuest == QuestieCorrections.WOTLK_ONLY then
        return not Questie.IsWotlk
    elseif hideQuest == QuestieCorrections.TBC_AND_WOTLK then
        return not (Questie.IsTBC or Questie.IsWotlk)
    elseif hideQuest == QuestieCorrections.CLASSIC_AND_TBC then
        return not (Questie.IsClassic or Questie.IsTBC)
    end

    return true
end

_GetCalendarEventName = function(name, texture)
    if type(name) == "string" then
        for calendarName, eventName in pairs(CALENDAR_EVENT_NAME_ALIASES) do
            if name == calendarName or name == l10n(calendarName) then
                return eventName
            end
        end
    end

    if type(texture) == "string" then
        local normalizedTexture = strlower(texture)
        for keyword, eventName in pairs(CALENDAR_EVENT_TEXTURE_ALIASES) do
            if strfind(normalizedTexture, keyword, 1, true) then
                return eventName
            end
        end
    end

    return nil
end

_IsCalendarEventMonthPlausible = function(eventName, month)
    local plausibleMonths = CALENDAR_EVENT_PLAUSIBLE_MONTHS[eventName]
    if not plausibleMonths then
        return true
    end

    local startMonth = plausibleMonths[1]
    local endMonth = plausibleMonths[2]

    if startMonth <= endMonth then
        return month >= startMonth and month <= endMonth
    end

    return month >= startMonth or month <= endMonth
end

_GetNextCalendarDay = function(currentDate)
    if not CalendarGetMonth then
        return nil
    end

    local _, _, currentMonthDays = CalendarGetMonth(0)
    if not currentMonthDays then
        return nil
    end

    if currentDate.monthDay < currentMonthDays then
        return 0, currentDate.month, currentDate.monthDay + 1
    end

    local nextMonth = CalendarGetMonth(1)
    if not nextMonth then
        return nil
    end

    return 1, nextMonth, 1
end

_IsCalendarEventActiveNow = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if not timeWindow then
        return true
    end

    if not currentDate or not currentDate.hour then
        return true
    end

    return currentDate.hour >= timeWindow.startHour and currentDate.hour < timeWindow.questEndHour
end

_IsCalendarEventLiveNow = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if not timeWindow then
        return true
    end

    if not currentDate or not currentDate.hour then
        return true
    end

    return currentDate.hour >= timeWindow.liveStartHour and currentDate.hour < timeWindow.liveEndHour
end

_IsCalendarEventQuestActiveNow = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if not timeWindow then
        return true
    end

    if not currentDate or not currentDate.hour then
        return true
    end

    return currentDate.hour >= timeWindow.questStartHour and currentDate.hour < timeWindow.questEndHour
end

_GetTimedEventLiveStartDelay = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if (not timeWindow) or (not currentDate) or (not currentDate.hour) then
        return nil
    end

    local minutesUntilStart = ((timeWindow.liveStartHour - currentDate.hour) * 60) - (currentDate.minute or 0)
    if minutesUntilStart <= 0 then
        return nil
    end

    return minutesUntilStart * 60
end

_GetTimedEventQuestStartDelay = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if (not timeWindow) or (not currentDate) or (not currentDate.hour) then
        return nil
    end

    local minutesUntilStart = ((timeWindow.questStartHour - currentDate.hour) * 60) - (currentDate.minute or 0)
    if minutesUntilStart <= 0 then
        return nil
    end

    return minutesUntilStart * 60
end

_GetTimedEventQuestEndDelay = function(eventName, currentDate)
    local timeWindow = CALENDAR_EVENT_TIME_WINDOWS[eventName]
    if (not timeWindow) or (not currentDate) or (not currentDate.hour) then
        return nil
    end

    local minutesUntilEnd = ((timeWindow.questEndHour - currentDate.hour) * 60) - (currentDate.minute or 0)
    if minutesUntilEnd <= 0 then
        return nil
    end

    return minutesUntilEnd * 60
end

_AnnounceActiveEvent = function(eventName)
    if eventName == "Darkmoon Faire" and (Questie.IsClassic or Questie.IsWotlk) then
        return
    end

    if _QuestieEvent.announcedEvents[eventName] then
        return
    end

    _QuestieEvent.announcedEvents[eventName] = true
    if not _ShouldAnnounceWorldEvents() then return end

    Questie:Print("|cFF6ce314" .. l10n("The \"%s\" world event is active!", l10n(eventName)))
end

_SetTimedEventQuestState = function(eventName, isActive)
    local questIds = _QuestieEvent.timedEventQuestIds[eventName]
    if not questIds then
        return
    end

    local changed = false
    for questId in pairs(questIds) do
        if isActive then
            if QuestieEvent.activeQuests[questId] ~= true or QuestieCorrections.hiddenQuests[questId] ~= nil then
                changed = true
            end
            QuestieCorrections.hiddenQuests[questId] = nil
            QuestieEvent.activeQuests[questId] = true
        else
            if QuestieEvent.activeQuests[questId] == true or QuestieCorrections.hiddenQuests[questId] ~= true then
                changed = true
            end
            QuestieCorrections.hiddenQuests[questId] = true
            QuestieEvent.activeQuests[questId] = nil
        end
    end

    if changed then
        _RefreshAvailableQuests()
    end
end

_SetPreEventQuestState = function(isActive)
    local changed = false
    for questId in pairs(PRE_EVENT_QUEST_IDS) do
        if isActive then
            if QuestieEvent.activeQuests[questId] ~= true or QuestieCorrections.hiddenQuests[questId] ~= nil then
                changed = true
            end
            QuestieCorrections.hiddenQuests[questId] = nil
            QuestieEvent.activeQuests[questId] = true
        else
            if QuestieEvent.activeQuests[questId] == true or QuestieCorrections.hiddenQuests[questId] ~= true then
                changed = true
            end
            QuestieCorrections.hiddenQuests[questId] = true
            QuestieEvent.activeQuests[questId] = nil
        end
    end

    if changed then
        _RefreshAvailableQuests()
    end
end

_SchedulePreEventQuestRefresh = function(currentDate)
    if not PRE_EVENT_EVENT_NAME or _QuestieEvent.preEventQuestRefreshTimer or (not currentDate) or (not currentDate.hour) then
        return
    end

    local minutesUntilMidnight = ((24 - currentDate.hour) * 60) - (currentDate.minute or 0)
    if minutesUntilMidnight <= 0 then
        return
    end

    -- Run just after midnight so CalendarGetDate has advanced to the new day.
    _QuestieEvent.preEventQuestRefreshTimer = C_Timer.After((minutesUntilMidnight * 60) + 1, function()
        _QuestieEvent.preEventQuestRefreshTimer = nil

        local _, upcomingEvents, _, calendarAvailable = _GetActiveCalendarEvents()
        if calendarAvailable then
            _SetPreEventQuestState(upcomingEvents[PRE_EVENT_EVENT_NAME] == true)
        end

        _SchedulePreEventQuestRefresh(C_DateAndTime.GetCurrentCalendarTime())
    end)
end

_ScheduleTimedEventQuestEnd = function(eventName, currentDate)
    if _QuestieEvent.timedEventQuestEndTimers[eventName] then
        return
    end

    local delay = _GetTimedEventQuestEndDelay(eventName, currentDate)
    if not delay then
        return
    end

    _QuestieEvent.timedEventQuestEndTimers[eventName] = C_Timer.After(delay, function()
        _QuestieEvent.timedEventQuestEndTimers[eventName] = nil
        _SetTimedEventQuestState(eventName, false)
    end)
end

_ScheduleTimedEventQuestStart = function(eventName, currentDate)
    if _QuestieEvent.timedEventQuestStartTimers[eventName] then
        return
    end

    local delay = _GetTimedEventQuestStartDelay(eventName, currentDate)
    if not delay then
        return
    end

    _QuestieEvent.timedEventQuestStartTimers[eventName] = C_Timer.After(delay, function()
        _QuestieEvent.timedEventQuestStartTimers[eventName] = nil
        _SetTimedEventQuestState(eventName, true)
        _ScheduleTimedEventQuestEnd(eventName, C_DateAndTime.GetCurrentCalendarTime())
    end)
end

_ScheduleTimedEventActiveAnnouncement = function(eventName, currentDate)
    if _QuestieEvent.timedEventLiveStartTimers[eventName] then
        return
    end

    local delay = _GetTimedEventLiveStartDelay(eventName, currentDate)
    if not delay then
        return
    end

    _QuestieEvent.timedEventLiveStartTimers[eventName] = C_Timer.After(delay, function()
        _QuestieEvent.timedEventLiveStartTimers[eventName] = nil
        _AnnounceActiveEvent(eventName)
    end)
end

_AnnounceUpcomingTimedEvent = function(eventName, currentDate)
    if _QuestieEvent.announcedUpcomingEvents[eventName] then
        return
    end

    local delay = _GetTimedEventLiveStartDelay(eventName, currentDate)
    if not delay then
        return
    end

    _QuestieEvent.announcedUpcomingEvents[eventName] = true

    if _ShouldAnnounceWorldEvents() then
        local hoursUntilStart = math.ceil(delay / 3600)
        if hoursUntilStart > 1 then
            Questie:Print("|cFF6ce314" .. l10n("The \"%s\" world event starts in about %d hours.", l10n(eventName), hoursUntilStart))
        else
            Questie:Print("|cFF6ce314" .. l10n("The \"%s\" world event starts in less than an hour.", l10n(eventName)))
        end
    end

    _ScheduleTimedEventActiveAnnouncement(eventName, currentDate)
end

_GetActiveCalendarEvents = function()
    local activeEvents = {}
    local upcomingEvents = {}
    local darkmoonLocation = nil

    if not QuestieCompat.Is335 or not CalendarGetNumDayEvents or not CalendarGetHolidayInfo then
        return activeEvents, upcomingEvents, darkmoonLocation, false
    end

    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    if not currentDate or not currentDate.month or not currentDate.monthDay then
        return activeEvents, upcomingEvents, darkmoonLocation, false
    end

    local numDayEvents = CalendarGetNumDayEvents(0, currentDate.monthDay) or 0
    for index = 1, numDayEvents do
        local name, description, texture = CalendarGetHolidayInfo(0, currentDate.monthDay, index)
        if name then
            local eventName = _GetCalendarEventName(name, texture)
            if eventName and _IsCalendarEventMonthPlausible(eventName, currentDate.month) and _IsCalendarEventActiveNow(eventName, currentDate) then
                activeEvents[eventName] = true
                if eventName == "Darkmoon Faire" then
                    -- Unlike the localized event name, the calendar texture identifies the active faire zone.
                    darkmoonLocation = _GetDarkmoonFaireLocationForCalendarEvent(texture)
                end
            end
        end
    end

    local nextMonthOffset, nextMonth, nextMonthDay = _GetNextCalendarDay(currentDate)
    if nextMonthOffset ~= nil then
        local numNextDayEvents = CalendarGetNumDayEvents(nextMonthOffset, nextMonthDay) or 0
        for index = 1, numNextDayEvents do
            local name, _, texture = CalendarGetHolidayInfo(nextMonthOffset, nextMonthDay, index)
            if name then
                local eventName = _GetCalendarEventName(name, texture)
                if eventName and _IsCalendarEventMonthPlausible(eventName, nextMonth) then
                    upcomingEvents[eventName] = true
                end
            end
        end
    end

    return activeEvents, upcomingEvents, darkmoonLocation, true
end

_PrimeCalendar = function()
    if OpenCalendar then
        OpenCalendar()
    elseif QuestieCompat.Is335 and ToggleCalendar then
        -- since this actually opens the calendar, we need to toggle it twice
        ToggleCalendar()
        ToggleCalendar()
    end

    if CalendarSetMonth then
        CalendarSetMonth(0)
    end
end

_RefreshAvailableQuests = function()
    if not Questie.started then
        return
    end

    local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
    QuestieJourney:RefreshQuestZoneData()

    local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")
    AvailableQuests.CalculateAndDrawAll()
end

function QuestieEvent.Initialize()
    if not Questie.db.profile.showEventQuests then
        return
    end

    if not Questie.started then
        return
    end

    _CancelInitializeTimer()
    _QuestieEvent.initializeAttempts = 0

    local function TryInitialize()
        if not QuestieEvent.eventQuests then
            _CancelInitializeTimer()
            return true
        end

        _QuestieEvent.initializeAttempts = _QuestieEvent.initializeAttempts + 1

        if QuestieCompat.Is335 then
            _PrimeCalendar()
        end

        local isFinalAttempt = _QuestieEvent.initializeAttempts >= EVENT_INIT_MAX_ATTEMPTS
        QuestieEvent:Load(isFinalAttempt)

        if isFinalAttempt then
            _CancelInitializeTimer()
            return true
        end

        return false
    end

    C_Timer.After(EVENT_INIT_INITIAL_DELAY, function()
        if not QuestieEvent.eventQuests then
            return
        end

        local finished = TryInitialize()
        if finished or _QuestieEvent.initializeTimer then
            return
        end

        if QuestieEvent.eventQuests and _QuestieEvent.initializeAttempts > 0 and _QuestieEvent.initializeAttempts < EVENT_INIT_MAX_ATTEMPTS then
            _QuestieEvent.initializeTimer = C_Timer.NewTicker(EVENT_INIT_RETRY_INTERVAL, TryInitialize)
        end
    end)
end

function QuestieEvent:Load(isFinalPass)
    if not QuestieEvent.eventQuests then
        return
    end

    local year = date("%y")
    local addedActiveQuest = false

    -- We want to replace the Lunar Festival date with the date that we estimate
    QuestieEvent.eventDates["Lunar Festival"] = QuestieEvent.lunarFestival[year]
    local activeEvents, upcomingEvents, darkmoonLocation, calendarAvailable = _GetActiveCalendarEvents()

    local eventCorrections
    if Questie.IsTBC then
        eventCorrections = QuestieEvent.eventDateCorrections["TBC"]
    elseif Questie.IsClassic then
        eventCorrections = QuestieEvent.eventDateCorrections["CLASSIC"]
    else
        eventCorrections = {}
    end

    for eventName,dates in pairs(eventCorrections) do
        if dates then
            QuestieEvent.eventDates[eventName] = dates
        end
    end

    if not calendarAvailable then
        -- The static dates are only a fallback for clients/servers without calendar data.
        -- When the calendar is available, its absence of an event is authoritative because
        -- several events (notably Harvest Festival) have dates that vary from year to year.
        for eventName, eventData in pairs(QuestieEvent.eventDates) do
            local startDay, startMonth = strsplit("/", eventData.startDate)
            local endDay, endMonth = strsplit("/", eventData.endDate)

            startDay = tonumber(startDay)
            startMonth = tonumber(startMonth)
            endDay = tonumber(endDay)
            endMonth = tonumber(endMonth)

            if (not activeEvents[eventName]) and _WithinDates(startDay, startMonth, endDay, endMonth) and (eventCorrections[eventName] ~= false) then
                activeEvents[eventName] = true
            end
        end
    end

    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    for eventName, isActive in pairs(activeEvents) do
        if isActive and not _QuestieEvent.announcedEvents[eventName] then
            if CALENDAR_EVENT_TIME_WINDOWS[eventName] and not _IsCalendarEventLiveNow(eventName, currentDate) then
                _AnnounceUpcomingTimedEvent(eventName, currentDate)
            else
                _AnnounceActiveEvent(eventName)
            end
        end
    end

    for _, questData in pairs(QuestieEvent.eventQuests) do
        local eventName = questData[1]
        local questId = questData[2]
        local startDay, startMonth = nil, nil
        local endDay, endMonth = nil, nil

        if questData[3] and questData[4] then
            startDay, startMonth = strsplit("/", questData[3])
            endDay, endMonth = strsplit("/", questData[4])
            startDay = tonumber(startDay)
            startMonth = tonumber(startMonth)
            endDay = tonumber(endDay)
            endMonth = tonumber(endMonth)
        end

        _QuestieEvent.eventNamesForQuests[questId] = eventName

        if _IsEventQuestVisible(questData[5]) then
            _QuestieEvent.eventQuestsInCurrentExpansion[questId] = true

            local isPreEventQuest = PRE_EVENT_QUEST_IDS[questId] == true
            if CALENDAR_EVENT_TIME_WINDOWS[eventName] and not isPreEventQuest then
                _QuestieEvent.timedEventQuestIds[eventName] = _QuestieEvent.timedEventQuestIds[eventName] or {}
                _QuestieEvent.timedEventQuestIds[eventName][questId] = true
            end

            local isActiveEvent
            if isPreEventQuest then
                isActiveEvent = upcomingEvents[eventName] == true
            else
                isActiveEvent = activeEvents[eventName] == true
            end
            local isActiveTimedQuest = isPreEventQuest
                or (not CALENDAR_EVENT_TIME_WINDOWS[eventName])
                or _IsCalendarEventQuestActiveNow(eventName, currentDate)
            if isActiveEvent
                and isActiveTimedQuest
                and _WithinDates(startDay, startMonth, endDay, endMonth) then
                if not QuestieEvent.activeQuests[questId] then
                    addedActiveQuest = true
                end
                QuestieCorrections.hiddenQuests[questId] = nil
                QuestieEvent.activeQuests[questId] = true
            end
        end
    end

    _SchedulePreEventQuestRefresh(currentDate)

    for eventName, isActive in pairs(activeEvents) do
        if isActive and CALENDAR_EVENT_TIME_WINDOWS[eventName] then
            if _IsCalendarEventQuestActiveNow(eventName, currentDate) then
                _ScheduleTimedEventQuestEnd(eventName, currentDate)
            else
                _ScheduleTimedEventQuestStart(eventName, currentDate)
            end
        end
    end

    if Questie.IsClassic or Questie.IsWotlk then
        if activeEvents["Darkmoon Faire"] then
            -- The calendar determines whether the Faire is active. The month rotation is only
            -- a location fallback when a server omits the zone from the active event texture.
            darkmoonLocation = darkmoonLocation or _GetDarkmoonFaireLocationForMonth(currentDate)
            addedActiveQuest = _LoadDarkmoonFaire(darkmoonLocation) or addedActiveQuest
        elseif not calendarAvailable then
            addedActiveQuest = _LoadDarkmoonFaire() or addedActiveQuest
        end
    end

    if isFinalPass then
        -- Clear the quests to save memory once initialization has settled.
        QuestieEvent.eventQuests = nil
    end

    if addedActiveQuest then
        _RefreshAvailableQuests()
    end
end

--- Date-based fallback for servers without a location-specific Darkmoon calendar texture.
--- Darkmoon Faire starts its setup the first Friday of the month and begins the following Monday.
---@return number
_GetDarkmoonFaireLocation = function()
    if not CalendarGetMonth then
        -- This is a band aid fix for private servers which do not support the calendar API.
        -- They won't see Darkmoon Faire quests, but that's the price to pay.
        return DMF_LOCATIONS.NONE
    end

    local currentDate = C_DateAndTime.GetCurrentCalendarTime()

    return _GetDarkmoonFaireLocationForDate(currentDate)
end

_GetDarkmoonFaireLocationForDate = function(currentDate)
    local baseMonth, baseYear = CalendarGetMonth(0)
    -- Calculate the offset in months so CalendarGetMonth returns the current month.
    local monthOffset = (currentDate.year - baseYear) * 12 + (currentDate.month - baseMonth)
    local _, _, _, firstWeekday = CalendarGetMonth(monthOffset)

    local eventLocation = _GetDarkmoonFaireLocationForMonth(currentDate)

    local dayOfMonth = currentDate.monthDay
    if firstWeekday == 1 then
        -- The 1st is a Sunday
        if dayOfMonth >= 9 and dayOfMonth < 15 then
            return eventLocation
        end
    elseif firstWeekday == 2 then
        -- The 1st is a Monday
        if dayOfMonth >= 8 and dayOfMonth < 14 then
            return eventLocation
        end
    elseif firstWeekday == 3 then
        -- The 1st is a Tuesday
        if dayOfMonth >= 7 and dayOfMonth < 13 then
            return eventLocation
        end
    elseif firstWeekday == 4 then
        -- The 1st is a Wednesday
        if dayOfMonth >= 6 and dayOfMonth < 12 then
            return eventLocation
        end
    elseif firstWeekday == 5 then
        -- The 1st is a Thursday
        if dayOfMonth >= 5 and dayOfMonth < 11 then
            return eventLocation
        end
    elseif firstWeekday == 6 then
        -- The 1st is a Friday
        if dayOfMonth >= 4 and dayOfMonth < 10 then
            return eventLocation
        end
    elseif firstWeekday == 7 then
        -- The 1st is a Saturday
        if dayOfMonth >= 10 and dayOfMonth < 16 then
            return eventLocation
        end
    end

    return DMF_LOCATIONS.NONE
end

---@param currentDate table
---@return number
_GetDarkmoonFaireLocationForMonth = function(currentDate)
    local monthModulo = currentDate.month % 3
    local eventLocation = DMF_LOCATIONS.ELWYNN_FOREST

    if Questie.IsWotlk then
        if monthModulo == 1 then
            eventLocation = DMF_LOCATIONS.MULGORE
        elseif monthModulo == 2 then
            eventLocation = DMF_LOCATIONS.TEROKKAR_FOREST
        end
    else
        eventLocation = (currentDate.month % 2) == 0 and DMF_LOCATIONS.MULGORE or DMF_LOCATIONS.ELWYNN_FOREST
    end

    return eventLocation
end

_GetDarkmoonFaireEventName = function(eventLocation)
    if eventLocation == DMF_LOCATIONS.MULGORE then
        return string.format("%s (%s)", l10n("Darkmoon Faire"), l10n("Mulgore"))
    elseif eventLocation == DMF_LOCATIONS.TEROKKAR_FOREST then
        return string.format("%s (%s)", l10n("Darkmoon Faire"), l10n("Terokkar Forest"))
    elseif eventLocation == DMF_LOCATIONS.ELWYNN_FOREST then
        return string.format("%s (%s)", l10n("Darkmoon Faire"), l10n("Elwynn Forest"))
    end

    return l10n("Darkmoon Faire")
end

---@param eventLocation number?
---@return boolean
_LoadDarkmoonFaire = function(eventLocation)
    eventLocation = eventLocation or _GetDarkmoonFaireLocation()
    if eventLocation == DMF_LOCATIONS.NONE or not darkmoonRules then
        return false
    end

    local addedActiveQuest = false
    local isInMulgore = eventLocation == DMF_LOCATIONS.MULGORE
    local isInTerokkar = eventLocation == DMF_LOCATIONS.TEROKKAR_FOREST
    local darkmoonNpcFixes = darkmoonRules.loadNpcFixes(eventLocation, isInMulgore)

    -- The faire is setting up right now or is already up
    local allianceAnnouncingQuestId = darkmoonRules.allianceQuestId
    local hordeAnnouncingQuestId = darkmoonRules.hordeQuestId

    if isInTerokkar then
        -- Neither city announcement quest is available while the Faire is in Terokkar
        if QuestieCorrections.hiddenQuests[allianceAnnouncingQuestId] ~= true
            or QuestieCorrections.hiddenQuests[hordeAnnouncingQuestId] ~= true
            or QuestieEvent.activeQuests[allianceAnnouncingQuestId]
            or QuestieEvent.activeQuests[hordeAnnouncingQuestId]
        then
            addedActiveQuest = true
        end
        QuestieCorrections.hiddenQuests[allianceAnnouncingQuestId] = true
        QuestieCorrections.hiddenQuests[hordeAnnouncingQuestId] = true
        QuestieEvent.activeQuests[allianceAnnouncingQuestId] = nil
        QuestieEvent.activeQuests[hordeAnnouncingQuestId] = nil
    elseif isInMulgore then
        if not QuestieEvent.activeQuests[hordeAnnouncingQuestId] then
            addedActiveQuest = true
        end
        QuestieCorrections.hiddenQuests[hordeAnnouncingQuestId] = nil
        QuestieCorrections.hiddenQuests[allianceAnnouncingQuestId] = true
        QuestieEvent.activeQuests[hordeAnnouncingQuestId] = true
        QuestieEvent.activeQuests[allianceAnnouncingQuestId] = nil
    else
        if not QuestieEvent.activeQuests[allianceAnnouncingQuestId] then
            addedActiveQuest = true
        end
        QuestieCorrections.hiddenQuests[allianceAnnouncingQuestId] = nil
        QuestieCorrections.hiddenQuests[hordeAnnouncingQuestId] = true
        QuestieEvent.activeQuests[allianceAnnouncingQuestId] = true
        QuestieEvent.activeQuests[hordeAnnouncingQuestId] = nil
    end

    for _, questData in pairs(QuestieEvent.eventQuests) do
        if questData[1] == "Darkmoon Faire" and _IsEventQuestVisible(questData[5]) then
            local questId = questData[2]
            if not QuestieEvent.activeQuests[questId] then
                addedActiveQuest = true
            end
            QuestieCorrections.hiddenQuests[questId] = nil
            QuestieEvent.activeQuests[questId] = true
        end
    end

    if darkmoonNpcFixes then
        for id, data in pairs(darkmoonNpcFixes) do
            QuestieDB.npcDataOverrides[id] = data
        end
    end

    if not _QuestieEvent.announcedEvents["Darkmoon Faire"] then
        _QuestieEvent.announcedEvents["Darkmoon Faire"] = true

        if _ShouldAnnounceWorldEvents() then
            Questie:Print("|cFF6ce314" .. l10n("The \"%s\" world event is active!", _GetDarkmoonFaireEventName(eventLocation)))
        end
    end

    return addedActiveQuest
end

--- Checks wheather the current date is within the given date range
---@param startDay number?
---@param startMonth number?
---@param endDay number?
---@param endMonth number?
---@return boolean @True if the current date is between the given, false otherwise
_WithinDates = function(startDay, startMonth, endDay, endMonth)
    if (not startDay) and (not startMonth) and (not endDay) and (not endMonth) then
        return true
    end
    local date = (C_DateAndTime.GetTodaysDate or C_DateAndTime.GetCurrentCalendarTime)()
    local day = date.day or date.monthDay
    local month = date.month
    if (startMonth <= endMonth) -- Event start and end during same year
        and ((month < startMonth) or (month > endMonth)) -- Too early or late in the year
        or ((month < startMonth) and (month > endMonth)) -- Event span across year change
        or (month == startMonth and day < startDay) -- Too early in the correct month
        or (month == endMonth and day > endDay) then -- Too late in the correct month
        return false
    else
        return true
    end
end

---@return string
function QuestieEvent:GetEventNameFor(questId)
    return _QuestieEvent.eventNamesForQuests[questId] or ""
end

function QuestieEvent:IsEventQuest(questId)
    return _QuestieEvent.eventNamesForQuests[questId] ~= nil
end

function QuestieEvent:IsEventQuestInCurrentExpansion(questId)
    return _QuestieEvent.eventQuestsInCurrentExpansion[questId] == true
end

---@param questId QuestId
---@return boolean @True if the quest is part of an event and the event is currently active, false otherwise
function QuestieEvent:IsEventActiveForQuest(questId)
    return QuestieEvent.activeQuests[questId] == true
end
