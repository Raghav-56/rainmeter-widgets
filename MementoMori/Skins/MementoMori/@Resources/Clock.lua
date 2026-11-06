local birth, target, span, totalWeeks
local mode = 'compact'
local showToday = true
local lastMinute, lastWeek, previousShapes = -1, -1, 0
local DAY, WEEK = 86400, 604800

local function snapshot(now)
    local remaining = math.max(0, target - now)
    local elapsed = math.min(span, math.max(0, now - birth))
    local date = os.date('*t', now)
    local sleeping = date.hour >= 22 or date.hour < 6
    local deadlineDay = date.day + (date.hour >= 22 and 1 or 0)
    local deadlineHour = sleeping and 6 or 22
    local deadline = os.time({year=date.year, month=date.month, day=deadlineDay, hour=deadlineHour, min=0, sec=0})
    local minutes = math.ceil(math.max(0, deadline - now) / 60)
    return {
        weeks = math.floor(remaining / WEEK),
        lived = elapsed / span,
        spent = now >= target and totalWeeks or math.floor(elapsed / WEEK),
        sleeping = sleeping,
        todayHours = math.floor(minutes / 60),
        todayMinutes = minutes % 60
    }
end

local function comma(number)
    local text = tostring(number)
    while true do
        local nextText, count = text:gsub('^(%d+)(%d%d%d)', '%1,%2')
        text = nextText
        if count == 0 then return text end
    end
end

local function set(meter, option, value)
    SKIN:Bang('!SetOption', meter, option, tostring(value))
end

local function paintGrid(spent)
    local shapes = {}
    local function row(index, count, color)
        if count < 1 then return end
        shapes[#shapes + 1] = string.format(
            'Line 0,%.2f,%.2f,%.2f | StrokeWidth 2.5 | StrokeDashes 1,1 | Stroke Color %s',
            index * 4 + 1.25, count * 5, index * 4 + 1.25, color)
    end
    for index = 0, math.ceil(totalWeeks / 52) - 1 do
        row(index, math.min(52, totalWeeks - index * 52), '57,70,61')
    end
    for index = 0, math.ceil(spent / 52) - 1 do
        row(index, math.min(52, spent - index * 52), '168,183,167')
    end
    if spent < totalWeeks then
        shapes[#shapes + 1] = string.format(
            'Rectangle %.2f,%.2f,3.5,3.5,0.5 | Fill Color 223,189,131 | StrokeWidth 0',
            (spent % 52) * 5 - 0.5, math.floor(spent / 52) * 4 - 0.5)
    end
    for index, shape in ipairs(shapes) do
        set('WeekGrid', index == 1 and 'Shape' or ('Shape' .. index), shape)
    end
    for index = #shapes + 1, previousShapes do
        set('WeekGrid', index == 1 and 'Shape' or ('Shape' .. index), '')
    end
    previousShapes = #shapes
    lastWeek = spent
end

local function updateClock(now)
    local state = snapshot(now)
    set('Weeks', 'Text', comma(state.weeks) .. (mode == 'mini' and 'w' or ''))
    set('Lived', 'Text', string.format('%.2f%% lived', state.lived * 100))
    set('Today', 'Text', string.format('%s  %dh %02dm', state.sleeping and 'Sleep' or 'Today', state.todayHours, state.todayMinutes))
    set('Today', 'ToolTipText', state.sleeping
        and 'Sleep window: 10 pm to 6 am. Time remaining until 6 am, rounded up to whole minutes.'
        or 'Available day: 6 am to 10 pm. Time remaining until 10 pm, rounded up to whole minutes.')
    local trackWidth = mode == 'mini' and 256 or 260
    local trackHeight = mode == 'mini' and 1 or 2
    set('Progress', 'Shape2', string.format(
        'Rectangle 0,0,%.3f,%d,0.5 | Fill Color 223,189,131 | StrokeWidth 0',
        math.max(0.001, trackWidth * state.lived), trackHeight))
    if state.spent ~= lastWeek then paintGrid(state.spent) end
    lastMinute = math.floor(now / 60)
    return state.lived
end

function Initialize()
    local year = tonumber(SKIN:GetVariable('BirthYear'))
    local month = tonumber(SKIN:GetVariable('BirthMonth'))
    local day = tonumber(SKIN:GetVariable('BirthDay'))
    local age = tonumber(SKIN:GetVariable('ReferenceAge'))
    birth = os.time({year=year, month=month, day=day, hour=0, min=0, sec=0})
    target = os.time({year=year + age, month=month, day=day, hour=0, min=0, sec=0})
    assert(birth and target and target > birth, 'Invalid birthday or horizon')
    span = target - birth
    totalWeeks = math.ceil(span / WEEK)
    set('Target', 'Text', 'Chosen horizon: ' .. os.date('%d %b %Y', target))
    set('Horizon', 'Text', tostring(age) .. '-year horizon')
    showToday = SKIN:GetVariable('ShowToday', '1') == '1'
    mode = 'compact'
    local noon = snapshot(os.time({year=2026,month=10,day=18,hour=12,min=0,sec=0}))
    assert(noon.weeks >= 0 and noon.spent >= 0, 'Week count check failed')
    assert(not noon.sleeping and noon.todayHours == 10 and noon.todayMinutes == 0, 'Available time at noon failed')
    local beforeBed = snapshot(os.time({year=2026,month=10,day=18,hour=21,min=59,sec=59}))
    assert(not beforeBed.sleeping and beforeBed.todayHours == 0 and beforeBed.todayMinutes == 1, 'Before-bed rounding failed')
    local bedtime = snapshot(os.time({year=2026,month=10,day=18,hour=22,min=0,sec=0}))
    assert(bedtime.sleeping and bedtime.todayHours == 8 and bedtime.todayMinutes == 0, 'Bedtime transition failed')
    local newDay = snapshot(os.time({year=2026,month=10,day=19,hour=0,min=0,sec=0}))
    assert(newDay.sleeping and newDay.todayHours == 6 and newDay.todayMinutes == 0, 'Overnight countdown failed')
    local beforeWake = snapshot(os.time({year=2026,month=10,day=19,hour=5,min=59,sec=59}))
    assert(beforeWake.sleeping and beforeWake.todayHours == 0 and beforeWake.todayMinutes == 1, 'Before-wake rounding failed')
    local wake = snapshot(os.time({year=2026,month=10,day=19,hour=6,min=0,sec=0}))
    assert(not wake.sleeping and wake.todayHours == 16 and wake.todayMinutes == 0, 'Wake transition failed')
    local monthEnd = snapshot(os.time({year=2026,month=10,day=31,hour=23,min=0,sec=0}))
    assert(monthEnd.sleeping and monthEnd.todayHours == 7 and monthEnd.todayMinutes == 0, 'Month rollover failed')
    assert(snapshot(birth).lived == 0, 'Birth boundary failed')
    assert(snapshot(target).spent == totalWeeks and snapshot(target).weeks == 0, 'Target boundary failed')
    assert(snapshot(target + DAY).lived == 1, 'Post-target boundary failed')
    assert(totalWeeks == math.ceil(span / WEEK) and comma(2036) == '2,036', 'Calendar shape check failed')
    SKIN:Bang('!Log', 'Life in weeks v2.2: available day 06:00-22:00, sleep 22:00-06:00. Bedtime, wake, midnight, rounding, month rollover, and horizon checks passed.', 'Notice')
end

function ApplyView()
    local mini = mode == 'mini'
    local expanded = mode == 'expanded'
    local width = mini and 280 or 304
    local height = mini and 44 or (expanded and 514 or 196)
    set('Panel', 'W', width)
    set('Panel', 'H', height)
    set('Panel', 'Shape', string.format(
        'Rectangle 0.5,0.5,%d,%d,%d | Fill Color 23,28,26,255 | Stroke Color 57,66,60,255 | StrokeWidth 1',
        width - 1, height - 1, mini and 8 or 12))
    set('Header', 'Hidden', mini and 1 or 0)
    set('ViewLink', 'Hidden', mini and 1 or 0)
    set('ViewLink', 'X', mini and 0 or 242)
    set('ViewLink', 'Y', mini and 0 or 17)
    set('ViewLink', 'Text', expanded and 'Compact -' or 'View +')
    set('ViewLink', 'ToolTipText', expanded and 'Return to compact view' or 'Open your life in weeks')
    set('MiniLink', 'Hidden', mini and 1 or 0)
    set('MiniLink', 'X', mini and 0 or 180)
    set('MiniLink', 'Y', mini and 0 or 17)
    set('TinyRestore', 'Hidden', mini and 0 or 1)
    set('HideLink', 'X', mini and 268 or 282)
    set('HideLink', 'Y', mini and 11 or 17)
    set('HideLink', 'W', mini and 28 or 36)
    set('Weeks', 'X', mini and 12 or 20)
    set('Weeks', 'Y', mini and 8 or 44)
    set('Weeks', 'W', mini and 94 or 258)
    set('Weeks', 'H', mini and 28 or 54)
    set('Weeks', 'FontSize', mini and 13 or 34)
    set('WeeksLabel', 'Hidden', mini and 1 or 0)
    set('WeeksLabel', 'Y', mini and 0 or 103)
    set('Today', 'X', mini and 210 or 282)
    set('Today', 'Y', mini and 14 or 103)
    set('Today', 'FontSize', mini and 8.5 or 9)
    set('Progress', 'X', mini and 12 or 22)
    set('Progress', 'Y', mini and 42 or 128)
    set('Progress', 'W', mini and 256 or 260)
    set('Progress', 'H', mini and 1 or 2)
    set('Progress', 'Shape', string.format('Rectangle 0,0,%d,%d,0.5 | Fill Color 57,70,61 | StrokeWidth 0', mini and 256 or 260, mini and 1 or 2))
    set('Lived', 'Hidden', mini and 1 or 0)
    set('Lived', 'Y', mini and 0 or 140)
    set('Horizon', 'Hidden', mini and 1 or 0)
    set('Horizon', 'Y', mini and 0 or 140)
    set('Horizon', 'X', mini and 0 or 282)
    set('WeekGrid', 'Y', expanded and 168 or 0)
    set('WeekGrid', 'H', expanded and 244 or 0)
    set('WeekGrid', 'Hidden', expanded and 0 or 1)
    set('Statement', 'Y', expanded and 432 or 165)
    set('Statement', 'Hidden', mini and 1 or 0)
    if mini then set('Statement', 'Y', 0) end
    set('Uncertainty', 'Y', expanded and 461 or 0)
    set('Uncertainty', 'Hidden', expanded and 0 or 1)
    set('Target', 'Y', expanded and 489 or 0)
    set('Target', 'Hidden', expanded and 0 or 1)
    set('Today', 'Hidden', showToday and 0 or 1)
    set('Rainmeter', 'ContextTitle', expanded and 'Compact view' or 'Open life in weeks')
    set('Rainmeter', 'ContextTitle2', mini and 'Compact view' or 'Super-compact view')
    set('Rainmeter', 'ContextTitle4', showToday and "Hide today's time" or "Show today's time")
    updateClock(os.time())
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function ToggleView()
    SetView(mode == 'expanded' and 'compact' or 'expanded')
end

function ToggleMini()
    SetView(mode == 'mini' and 'compact' or 'mini')
end

function SetView(nextMode)
    assert(nextMode == 'compact' or nextMode == 'expanded' or nextMode == 'mini', 'Unknown meter view')
    mode = nextMode
    ApplyView()
    SKIN:Bang('!Log', 'Life in weeks: ' .. mode .. ' view', 'Notice')
end

function ToggleToday()
    showToday = not showToday
    SKIN:Bang('!WriteKeyValue', 'Variables', 'ShowToday', showToday and '1' or '0', SKIN:MakePathAbsolute('Meter.ini'))
    ApplyView()
end

function RefreshClock()
    updateClock(os.time())
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function Update()
    local now = os.time()
    if math.floor(now / 60) ~= lastMinute then
        local ratio = updateClock(now)
        SKIN:Bang('!UpdateMeter', '*')
        return ratio
    end
    return snapshot(now).lived
end
