Controls = {}

-- Actions that must always go through the server (state-bag backed: every client needs to see them,
-- or the window table needs to be recorded so the UI knows window state).
local SERVER_ONLY = { indicator = true, hazards = true, cabin = true, siren = true, window = true, windowsAll = true }

-- Everything the remote/owner side may be asked to apply.
local DRIVING = { cruise = true, cruiseAdjust = true, limiter = true, limiterSpeed = true, driveMode = true, launch = true, tcs = true }

-- ---------------------------------------------------------------------------
--  Owner-side appliers (run on the network owner of the vehicle; the game replicates the result)
-- ---------------------------------------------------------------------------
local Apply = {}

function Apply.door(veh, v)
    if not GetIsDoorValid(veh, v.i) then return end
    if v.open then SetVehicleDoorOpen(veh, v.i, false, false) else SetVehicleDoorShut(veh, v.i, false) end
end

function Apply.doorsAll(veh, v)
    for i = 0, 5 do
        if GetIsDoorValid(veh, i) then
            if v.open then SetVehicleDoorOpen(veh, i, false, false) else SetVehicleDoorShut(veh, i, false) end
        end
    end
end

function Apply.window(veh, v)
    if v.down then RollDownWindow(veh, v.i) else RollUpWindow(veh, v.i) end
end

function Apply.windowsAll(veh, v)
    for i = 0, 3 do
        if v.down then RollDownWindow(veh, i) else RollUpWindow(veh, i) end
    end
end

function Apply.remoteEngine(veh, v)
    SetVehicleEngineOn(veh, v.on, false, true)
    SetVehicleUndriveable(veh, false)
end

function Apply.lights(veh, v)
    SetVehicleLights(veh, v.on and 2 or 1)
end

function Apply.highbeam(veh, v)
    if v.on then SetVehicleLights(veh, 2) end
    SetVehicleFullbeam(veh, v.on)
end

function Apply.horn(veh)
    StartVehicleHorn(veh, 450, GetHashKey('HELDDOWN'), false)
end

function Apply.flash(veh)
    CreateThread(function()
        for _ = 1, 2 do
            SetVehicleLights(veh, 2)
            SetVehicleIndicatorLights(veh, 0, true)
            SetVehicleIndicatorLights(veh, 1, true)
            Wait(220)
            SetVehicleLights(veh, 1)
            SetVehicleIndicatorLights(veh, 0, false)
            SetVehicleIndicatorLights(veh, 1, false)
            Wait(220)
        end
        SetVehicleLights(veh, 0)
    end)
end

function Apply.alarm(veh, v)
    if v.on then
        SetVehicleAlarm(veh, true)
        SetVehicleAlarmTimeLeft(veh, 15000)
        StartVehicleAlarm(veh)
    else
        SetVehicleAlarm(veh, false)
        SetVehicleAlarmTimeLeft(veh, 0)
    end
end

function Apply.neon(veh, v)
    SetVehicleNeonLightEnabled(veh, v.i, v.on)
end

function Apply.neonAll(veh, v)
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, v.on) end
end

function Apply.xenon(veh, v)
    ToggleVehicleMod(veh, 22, v.on)
end

function Apply.extra(veh, v)
    if not DoesExtraExist(veh, v.id) then return end
    SetVehicleAutoRepairDisabled(veh, true)
    SetVehicleExtra(veh, v.id, not v.on)
end

Controls.Apply = Apply

RegisterNetEvent('aj-vehiclemenu:client:apply', function(netId, action, value)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) or not Apply[action] then return end
    Apply[action](veh, value or {})
end)

-- ---------------------------------------------------------------------------
--  Routing
-- ---------------------------------------------------------------------------
local function isOwner(veh)
    return NetworkGetEntityOwner(veh) == PlayerId()
end

local function send(veh, action, value)
    if not SERVER_ONLY[action] and isOwner(veh) and Apply[action] then
        Apply[action](veh, value)
        return
    end
    TriggerServerEvent('aj-vehiclemenu:server:action', NetworkGetNetworkIdFromEntity(veh), action, value)
end

-- ---------------------------------------------------------------------------
--  Permission check (client side; synced actions are checked again on the server)
-- ---------------------------------------------------------------------------
local function allowed(id, value)
    local ctx = VM.context
    if ctx == 'driver' then return true end
    if ctx == 'passenger' then
        local p = Config.PassengerAllowed
        if id == 'seat' then return p.seat end
        if id == 'cabin' then return p.cabin end
        if id == 'window' then
            if p.window == true then return true end
            if p.window == 'own' then return type(value) == 'number' and value == VM.SeatWindow[VM.seat] end
        end
        return false
    end
    if ctx == 'remote' then
        return Config.RemoteAllowed[id] and true or false
    end
    return false
end

-- ---------------------------------------------------------------------------
--  Handlers - each receives the UI's value and returns ok, errorMessage
-- ---------------------------------------------------------------------------
local H = {}

function H.seat(veh, seat)
    seat = tonumber(seat)
    if not seat then return false end
    if not IsVehicleSeatFree(veh, seat) then return false, Lang:t('notify.seat_taken') end
    SetPedIntoVehicle(PlayerPedId(), veh, seat)
    return true
end

function H.engine(veh)
    -- Same path as qb-vehiclekeys' G key (/engine): checks own keys, job-shared keys and blacklisted
    -- vehicles in one place. (Its ToggleEngine *event* only checks own keys, which is why it silently
    -- did nothing on job/shared vehicles.)
    local before = GetIsVehicleEngineRunning(veh)
    ExecuteCommand('engine')
    SetTimeout(600, function()
        if DoesEntityExist(veh) and not before and not GetIsVehicleEngineRunning(veh) then
            Notify(Lang:t('notify.no_keys'), 'error', 2000)
        end
    end)
    return true
end

function H.remoteEngine(veh)
    send(veh, 'remoteEngine', { on = not GetIsVehicleEngineRunning(veh) })
    return true
end

function H.lights(veh)
    local _, on = GetVehicleLightsState(veh)
    send(veh, 'lights', { on = on ~= 1 })
    return true
end

function H.highbeam(veh)
    local _, _, high = GetVehicleLightsState(veh)
    send(veh, 'highbeam', { on = high ~= 1 })
    return true
end

function H.horn(veh) send(veh, 'horn', {}) return true end
function H.flash(veh) send(veh, 'flash', {}) return true end

function H.alarm(veh)
    send(veh, 'alarm', { on = not IsVehicleAlarmActivated(veh) })
    return true
end

function H.cabin(veh)
    local on = not Entity(veh).state['ajvm_cabin']
    SetVehicleInteriorlight(veh, on)
    send(veh, 'cabin', { on = on })
    return true
end

function H.siren(veh)
    if GetVehicleClass(veh) ~= 18 then return false end
    local on = not Entity(veh).state['ajvm_siren']
    SetVehicleHasMutedSirens(veh, on)
    send(veh, 'siren', { on = on })
    return true
end

-- Local mirror so indicators react instantly for the player who pressed them; the server state bag
-- then replicates the same value to everyone else (and to late-joiners).
local localInd = { veh = 0, state = 0, t = 0 }

function Controls.GetIndicator(veh)
    if localInd.veh == veh and GetGameTimer() - localInd.t < 3000 then return localInd.state end
    return Entity(veh).state['ajvm_ind'] or 0
end

local function setIndicator(veh, action, state)
    localInd.veh, localInd.state, localInd.t = veh, state, GetGameTimer()
    ApplyIndicator(veh, state)
    send(veh, action, { state = state })
end

function H.indicator(veh, side)
    local cur = Controls.GetIndicator(veh)
    local want = side == 'left' and 1 or 2
    setIndicator(veh, 'indicator', (cur == want) and 0 or want)
    return true
end

function H.hazards(veh)
    local cur = Controls.GetIndicator(veh)
    setIndicator(veh, 'hazards', (cur == 3) and 0 or 3)
    return true
end

function H.door(veh, i)
    i = tonumber(i)
    if not i or not GetIsDoorValid(veh, i) then return false end
    send(veh, 'door', { i = i, open = GetVehicleDoorAngleRatio(veh, i) <= 0.05 })
    return true
end

function H.doorsAll(veh)
    local anyOpen = false
    for i = 0, 5 do
        if GetIsDoorValid(veh, i) and GetVehicleDoorAngleRatio(veh, i) > 0.05 then anyOpen = true end
    end
    send(veh, 'doorsAll', { open = not anyOpen })
    return true
end

function H.window(veh, i)
    i = tonumber(i)
    if not i then return false end
    local win = Entity(veh).state['ajvm_win'] or {}
    send(veh, 'window', { i = i, down = not win[i + 1] })
    return true
end

function H.windowsAll(veh)
    local win = Entity(veh).state['ajvm_win'] or {}
    local anyDown = win[1] or win[2] or win[3] or win[4]
    send(veh, 'windowsAll', { down = not anyDown })
    return true
end

local function neonOk(veh)
    if not Config.RequireNeonKit then return true end
    for i = 0, 3 do
        if IsVehicleNeonLightEnabled(veh, i) then return true end
    end
    return false, Lang:t('notify.no_neon')
end

function H.neon(veh, i)
    i = tonumber(i)
    if not i then return false end
    local ok, err = neonOk(veh)
    if not ok then return false, err end
    send(veh, 'neon', { i = i, on = not IsVehicleNeonLightEnabled(veh, i) })
    return true
end

function H.neonAll(veh)
    local ok, err = neonOk(veh)
    if not ok then return false, err end
    local anyOn = false
    for i = 0, 3 do
        if IsVehicleNeonLightEnabled(veh, i) then anyOn = true end
    end
    send(veh, 'neonAll', { on = not anyOn })
    return true
end

function H.xenon(veh)
    if not Config.AllowXenonToggle then return false end
    send(veh, 'xenon', { on = not IsToggleModOn(veh, 22) })
    return true
end

function H.extra(veh, id)
    id = tonumber(id)
    if not id or not DoesExtraExist(veh, id) then return false end
    send(veh, 'extra', { id = id, on = not IsVehicleExtraTurnedOn(veh, id) })
    return true
end

function H.lock(veh)
    local plate = VM.GetPlate(veh)
    if not exports['qb-vehiclekeys']:HasKeys(plate) then return false, Lang:t('notify.no_keys') end
    local locked = GetVehicleDoorLockStatus(veh) >= 2
    TriggerServerEvent('qb-vehiclekeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(veh), locked and 1 or 2)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, Config.Remote.lockSound, 0.3)
    if VM.context == 'remote' then
        send(veh, 'flash', {})
        -- keyfob press animation
        local ped = PlayerPedId()
        RequestAnimDict('anim@mp_player_intmenu@key_fob@')
        local t = GetGameTimer() + 1000
        while not HasAnimDictLoaded('anim@mp_player_intmenu@key_fob@') and GetGameTimer() < t do Wait(0) end
        TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, -1, 49, 0, false, false, false)
        SetTimeout(750, function() StopAnimTask(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 1.0) end)
    end
    Notify(locked and Lang:t('notify.unlocked') or Lang:t('notify.locked'), 'success', 2000)
    return true
end

function Controls.Handle(id, value)
    local veh = VM.veh
    if not id or not DoesEntityExist(veh) then return false end
    if not allowed(id, value) then return false, Lang:t('notify.no_permission') end

    if DRIVING[id] then
        if VM.context ~= 'driver' then return false end
        return Driving.Handle(veh, id, value)
    end

    local fn = H[id]
    if not fn then return false end
    return fn(veh, value)
end
