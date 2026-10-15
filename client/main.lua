QBCore = exports['qb-core']:GetCoreObject()

-- Shared client state for every client/*.lua file.
VM = {
    open = false,
    context = nil,      -- 'driver' | 'passenger' | 'remote'
    veh = 0,
    seat = nil,         -- seat index the player sits in (nil in remote mode)
}

local SPEED_FACTOR = Config.SpeedUnit == 'mph' and 2.236936 or 3.6
VM.SpeedFactor = SPEED_FACTOR

local WINDOW_BONES = { 'window_lf', 'window_rf', 'window_lr', 'window_rr' }
-- seat index -> window index (0-based, same as RollDownWindow)
VM.SeatWindow = { [-1] = 0, [0] = 1, [1] = 2, [2] = 3 }

function Notify(msg, kind, len)
    QBCore.Functions.Notify(msg, kind or 'primary', len or 3000)
end

local function isDead()
    local pd = QBCore.Functions.GetPlayerData()
    local meta = pd and pd.metadata
    return meta and (meta.isdead or meta.inlaststand) or false
end

local function getPlate(veh)
    return QBCore.Functions.GetPlate(veh)
end
VM.GetPlate = getPlate

local function vehicleLabel(veh)
    local model = GetEntityModel(veh)
    for _, v in pairs(QBCore.Shared.Vehicles or {}) do
        if v.hash == model or joaat(v.model or '') == model then
            return (v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. (v.name or v.model)
        end
    end
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end
    return label
end

local function findSeat(veh, ped)
    local max = GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2
    for i = -1, max do
        if GetPedInVehicleSeat(veh, i) == ped then return i end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Context detection
-- ---------------------------------------------------------------------------
local function detectContext()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local seat = findSeat(veh, ped)
        return (seat == -1) and 'driver' or 'passenger', veh, seat
    end
    if Config.Remote.enabled then
        local rveh = Remote.FindVehicle()
        if rveh then return 'remote', rveh, nil end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Static vehicle description (sent once per open / vehicle change)
-- ---------------------------------------------------------------------------
local function buildVehicleInfo(veh)
    local model = GetEntityModel(veh)
    local class = GetVehicleClass(veh)
    local seats = GetVehicleModelNumberOfSeats(model)

    local doors = {}
    for i = 0, 5 do doors[#doors + 1] = GetIsDoorValid(veh, i) and true or false end

    local windows = {}
    for i = 1, 4 do windows[i] = GetEntityBoneIndexByName(veh, WINDOW_BONES[i]) ~= -1 end

    local extras = {}
    for id = 1, 14 do
        if DoesExtraExist(veh, id) then extras[#extras + 1] = id end
    end

    local anyNeon = false
    for i = 0, 3 do
        if IsVehicleNeonLightEnabled(veh, i) then anyNeon = true end
    end

    return {
        name = vehicleLabel(veh),
        plate = getPlate(veh),
        class = class,
        seats = seats,
        doors = doors,
        windows = windows,
        extras = extras,
        isBike = class == 8 or class == 13,
        isEmergency = class == 18,
        hasNeon = (not Config.RequireNeonKit) or anyNeon,
        drivingTools = not Config.NoDrivingToolsClasses[class],
        xenon = Config.AllowXenonToggle,
    }
end

-- ---------------------------------------------------------------------------
--  Live state (sent every refresh tick)
-- ---------------------------------------------------------------------------
local function buildSeats(veh)
    local ped = PlayerPedId()
    local list = {}
    local max = GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2
    for i = -1, max do
        local p = GetPedInVehicleSeat(veh, i)
        list[#list + 1] = { index = i, occupied = p ~= 0, me = p == ped }
    end
    return list
end

local function safeExport(res, fn, ...)
    local ok, val = pcall(function(...) return exports[res][fn](exports[res], ...) end, ...)
    if ok then return val end
    return nil
end

local function buildState(veh)
    local bag = Entity(veh).state
    local _, lightsOn, highOn = GetVehicleLightsState(veh)

    local doors = {}
    for i = 0, 5 do doors[#doors + 1] = GetVehicleDoorAngleRatio(veh, i) > 0.05 end

    local neon = {}
    for i = 0, 3 do neon[#neon + 1] = IsVehicleNeonLightEnabled(veh, i) and true or false end
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)

    local extras = {}
    for id = 1, 14 do
        if DoesExtraExist(veh, id) then extras[tostring(id)] = IsVehicleExtraTurnedOn(veh, id) and true or false end
    end

    local win = bag['ajvm_win'] or {}
    local ind = Controls.GetIndicator(veh)

    return {
        engine = GetIsVehicleEngineRunning(veh) and true or false,
        lights = lightsOn == 1,
        highbeam = highOn == 1,
        cabin = bag['ajvm_cabin'] and true or false,
        indicator = ind,            -- 0 off, 1 left, 2 right, 3 hazard
        doors = doors,
        windows = { win[1] and true or false, win[2] and true or false, win[3] and true or false, win[4] and true or false },
        neon = neon,
        neonColor = { nr, ng, nb },
        xenon = IsToggleModOn(veh, 22) and true or false,
        siren = bag['ajvm_siren'] and true or false, -- true = muted
        alarm = IsVehicleAlarmActivated(veh) and true or false,
        locked = GetVehicleDoorLockStatus(veh) >= 2,
        extras = extras,
        driving = Driving.GetState(),
        items = Driving.GetItems(),
    }
end

local function buildStats(veh)
    local ped = PlayerPedId()
    local speed = GetEntitySpeed(veh) * SPEED_FACTOR
    local stats = {
        speed = math.floor(speed + 0.5),
        rpm = GetIsVehicleEngineRunning(veh) and GetVehicleCurrentRpm(veh) or 0.0,
        gear = GetVehicleCurrentGear(veh),
        fuel = math.floor((safeExport('qb-fuel', 'GetFuel', veh) or GetVehicleFuelLevel(veh)) + 0.5),
        engine = math.max(0, math.floor(GetVehicleEngineHealth(veh) / 10 + 0.5)),
        body = math.max(0, math.floor(GetVehicleBodyHealth(veh) / 10 + 0.5)),
        belt = VM.context ~= 'remote' and (safeExport('qb-smallresources', 'HasSeatbeltOn') and true or false) or nil,
        seats = buildSeats(veh),
    }
    if VM.context == 'remote' then
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(veh))
        stats.distance = math.floor(dist + 0.5)
        stats.signal = math.max(1, 4 - math.floor(dist / (Config.Remote.range / 4)))
    end
    return stats
end

local function permissions()
    return {
        context = VM.context,
        seat = VM.seat,
        passenger = Config.PassengerAllowed,
        remote = Config.RemoteAllowed,
        ownWindow = VM.seat and VM.SeatWindow[VM.seat] or nil,
    }
end

-- ---------------------------------------------------------------------------
--  Open / close
-- ---------------------------------------------------------------------------
local function sendOpen()
    SendNUIMessage({
        action = 'open',
        context = VM.context,
        vehicle = buildVehicleInfo(VM.veh),
        state = buildState(VM.veh),
        stats = buildStats(VM.veh),
        perms = permissions(),
        config = {
            unit = Config.SpeedUnit == 'mph' and 'MPH' or 'KM/H',
            keepInput = Config.KeepInput,
            driveModes = Config.DriveModes,
            limiter = Config.Limiter,
            cruiseStep = Config.CruiseStep,
            ownCruise = Config.UseOwnCruise,
            defaultMode = Config.DefaultDriveMode,
            itemLabels = {
                driveMode = Driving.ItemLabel('driveMode'),
                launch = Driving.ItemLabel('launch'),
                tcs = Driving.ItemLabel('tcs'),
            },
        },
    })
end

function CloseMenu()
    if not VM.open then return end
    VM.open = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function startLoops()
    -- live stats / context watchdog
    CreateThread(function()
        while VM.open do
            local ctx, veh, seat = detectContext()
            if VM.context == 'remote' then
                -- remote mode stays on the vehicle it opened on, until out of range or player gets in a car
                local ped = PlayerPedId()
                if GetVehiclePedIsIn(ped, false) ~= 0 then
                    ctx, veh, seat = detectContext()
                elseif not DoesEntityExist(VM.veh) or #(GetEntityCoords(ped) - GetEntityCoords(VM.veh)) > Config.Remote.range + 5.0 then
                    Notify(Lang:t('notify.out_of_range'), 'error')
                    CloseMenu()
                    break
                else
                    ctx, veh, seat = 'remote', VM.veh, nil
                end
            end

            if not ctx or not DoesEntityExist(veh) then
                CloseMenu()
                break
            end

            if ctx ~= VM.context or veh ~= VM.veh or seat ~= VM.seat then
                VM.context, VM.veh, VM.seat = ctx, veh, seat
                sendOpen()
            else
                SendNUIMessage({ action = 'update', state = buildState(veh), stats = buildStats(veh) })
            end
            Wait(Config.RefreshRate)
        end
    end)

    -- keep-input control blocking
    if Config.KeepInput then
        CreateThread(function()
            while VM.open do
                DisableControlAction(0, 1, true)    -- look LR
                DisableControlAction(0, 2, true)    -- look UD
                DisableControlAction(0, 24, true)   -- attack
                DisableControlAction(0, 25, true)   -- aim
                DisableControlAction(0, 257, true)  -- attack 2
                DisableControlAction(0, 263, true)  -- melee
                DisableControlAction(0, 68, true)   -- veh aim
                DisableControlAction(0, 69, true)   -- veh attack
                DisableControlAction(0, 70, true)   -- veh attack 2
                DisableControlAction(0, 91, true)   -- veh passenger aim
                DisableControlAction(0, 92, true)   -- veh passenger attack
                DisableControlAction(0, 106, true)  -- veh mouse control override
                DisableControlAction(0, 199, true)  -- pause
                DisableControlAction(0, 200, true)  -- pause alternate
                DisableControlAction(0, 322, true)  -- esc
                DisableControlAction(0, 14, true)   -- weapon wheel scroll
                DisableControlAction(0, 15, true)
                DisableControlAction(0, 16, true)
                DisableControlAction(0, 17, true)
                Wait(0)
            end
        end)
    end
end

function OpenMenu()
    if VM.open then return end
    if isDead() or LocalPlayer.state.ajPauseOpen or IsPauseMenuActive() then return end

    local ctx, veh, seat = detectContext()
    if not ctx then
        Notify(Lang:t('notify.no_vehicle'), 'error')
        return
    end

    VM.open, VM.context, VM.veh, VM.seat = true, ctx, veh, seat
    sendOpen()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.KeepInput and ctx ~= 'remote')
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    startLoops()
end

RegisterCommand(Config.Command, function()
    if VM.open then CloseMenu() else OpenMenu() end
end, false)
RegisterKeyMapping(Config.Command, Lang:t('keymap.open'), 'keyboard', Config.Keybind)

-- ---------------------------------------------------------------------------
--  NUI callbacks
-- ---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    if not VM.open or not DoesEntityExist(VM.veh) then return cb({ ok = false }) end
    local ok, err = Controls.Handle(data.id, data.value)
    if not ok and err then Notify(err, 'error', 2000) end
    -- push a fresh frame right away so the tile reacts without waiting for the next tick
    SetTimeout(60, function()
        if VM.open and DoesEntityExist(VM.veh) then
            SendNUIMessage({ action = 'update', state = buildState(VM.veh), stats = buildStats(VM.veh) })
        end
    end)
    cb({ ok = ok and true or false })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if VM.open then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    Driving.Reset()
end)
