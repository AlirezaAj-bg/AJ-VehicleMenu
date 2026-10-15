Driving = {}

local S = {
    cruise = { on = false, speed = 0 },          -- speed in Config.SpeedUnit
    limiter = { on = false, speed = Config.Limiter.default },
    mode = Config.DefaultDriveMode,
    launch = false,                              -- false | 'armed' | 'charging'
    tcs = true,
    veh = 0,
}
local loopRunning = false
local boostUntil = 0
local nextItemCheck = 0

local function factor() return VM.SpeedFactor end

local function modeData(id)
    for _, m in ipairs(Config.DriveModes) do
        if m.id == id then return m end
    end
    return nil
end

local function unitLabel() return Config.SpeedUnit == 'mph' and 'mph' or 'km/h' end

-- ---------------------------------------------------------------------------
--  Item requirements (Config.Items)
-- ---------------------------------------------------------------------------
local function hasToolItem(key)
    local item = Config.Items and Config.Items[key]
    if not item then return true end
    local ok, has = pcall(QBCore.Functions.HasItem, item)
    return ok and has and true or false
end

local function itemLabel(key)
    local item = Config.Items and Config.Items[key]
    if not item then return nil end
    local def = QBCore.Shared.Items and QBCore.Shared.Items[item]
    return def and def.label or item
end
Driving.ItemLabel = itemLabel

function Driving.GetItems()
    return { driveMode = hasToolItem('driveMode'), launch = hasToolItem('launch'), tcs = hasToolItem('tcs') }
end

local function needItem(key)
    return false, Lang:t('notify.need_item', { item = itemLabel(key) })
end

function Driving.GetState()
    return {
        cruise = { on = S.cruise.on, speed = S.cruise.speed },
        limiter = { on = S.limiter.on, speed = S.limiter.speed },
        mode = S.mode,
        launch = S.launch,
        tcs = S.tcs,
    }
end

local function releaseVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    SetEntityMaxSpeed(veh, 999.0)
    SetVehicleReduceGrip(veh, false)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
end

function Driving.Reset()
    releaseVehicle(S.veh)
    S.cruise.on = false
    S.limiter.on = false
    S.mode = Config.DefaultDriveMode
    S.launch = false
    S.tcs = true
    S.veh = 0
end

local function isActive()
    local m = modeData(S.mode)
    return S.cruise.on or S.limiter.on or S.launch or not S.tcs or GetGameTimer() < boostUntil
        or (m and (m.power ~= 1.0 or m.torque ~= 1.0))
end

-- One per-frame loop that only runs while any driving tool is active and the player is still driving.
local function ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while isActive() do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 or veh ~= S.veh or GetPedInVehicleSeat(veh, -1) ~= ped then
                Driving.Reset()
                break
            end

            if GetGameTimer() >= nextItemCheck then
                nextItemCheck = GetGameTimer() + 1000
                if S.mode ~= Config.DefaultDriveMode and not hasToolItem('driveMode') then
                    S.mode = Config.DefaultDriveMode
                    SetVehicleEngineTorqueMultiplier(veh, 1.0)
                end
                if S.launch and not hasToolItem('launch') then S.launch = false end
                if not S.tcs and not hasToolItem('tcs') then
                    S.tcs = true
                    SetVehicleReduceGrip(veh, false)
                end
            end

            local speed = GetEntitySpeed(veh)                -- m/s
            local m = modeData(S.mode)

            -- drive mode
            if m then
                if m.torque ~= 1.0 then SetVehicleEngineTorqueMultiplier(veh, m.torque) end
                if m.power ~= 1.0 and GetGameTimer() >= boostUntil then SetVehicleCheatPowerIncrease(veh, m.power) end
            end

            -- cruise control: cancel on brake/handbrake, let the player accelerate past it, hold otherwise
            if S.cruise.on then
                if IsControlPressed(0, 72) or IsControlPressed(0, 76) or speed < 1.0 then
                    S.cruise.on = false
                    Notify(Lang:t('notify.cruise_off'), 'primary', 1500)
                elseif not IsControlPressed(0, 71) then
                    local target = S.cruise.speed / factor()
                    if speed < target - 0.2 and IsVehicleOnAllWheels(veh) then
                        SetVehicleForwardSpeed(veh, math.min(target, speed + 0.15))
                    end
                end
            end

            -- launch control
            if S.launch then
                local stopped = speed < 1.0
                if S.launch == 'armed' and stopped and IsControlPressed(0, 72) and IsControlPressed(0, 71) then
                    S.launch = 'charging'
                end
                if S.launch == 'charging' then
                    SetVehicleBurnout(veh, false)
                    if not IsControlPressed(0, 71) then
                        S.launch = 'armed'
                    elseif not IsControlPressed(0, 72) then
                        S.launch = false
                        boostUntil = GetGameTimer() + Config.Launch.boostTime
                        Notify(Lang:t('notify.launch_go'), 'success', 1200)
                    end
                end
            end
            if GetGameTimer() < boostUntil then
                SetVehicleCheatPowerIncrease(veh, Config.Launch.boostPower)
                SetVehicleReduceGrip(veh, false)
            elseif not S.tcs then
                SetVehicleReduceGrip(veh, true)
            end

            Wait(0)
        end
        loopRunning = false
    end)
end

local H = {}

function H.cruise(veh)
    if not Config.UseOwnCruise then
        ExecuteCommand('togglecruise')
        return true
    end
    if S.cruise.on then
        S.cruise.on = false
        Notify(Lang:t('notify.cruise_off'), 'primary', 1500)
        return true
    end
    local fuel = GetVehicleFuelLevel(veh)
    local ok, f = pcall(function() return exports['qb-fuel']:GetFuel(veh) end)
    if ok and f then fuel = f end
    if fuel <= Config.CruiseMinFuel then return false, Lang:t('notify.cruise_fuel') end
    local speed = math.floor(GetEntitySpeed(veh) * factor() + 0.5)
    if speed < Config.CruiseMinSpeed then return false, Lang:t('notify.cruise_slow') end
    if S.limiter.on then speed = math.min(speed, S.limiter.speed) end
    S.cruise.on, S.cruise.speed = true, speed
    Notify(Lang:t('notify.cruise_on', { speed = speed, unit = unitLabel() }), 'success', 1500)
    return true
end

function H.cruiseAdjust(_, delta)
    delta = tonumber(delta) or 0
    if not S.cruise.on then return false end
    local speed = S.cruise.speed + (delta > 0 and Config.CruiseStep or -Config.CruiseStep)
    S.cruise.speed = math.max(Config.CruiseMinSpeed, speed)
    if S.limiter.on then S.cruise.speed = math.min(S.cruise.speed, S.limiter.speed) end
    return true
end

local function applyLimiter(veh)
    if S.limiter.on then
        SetEntityMaxSpeed(veh, S.limiter.speed / factor())
    else
        SetEntityMaxSpeed(veh, 999.0)
    end
end

function H.limiter(veh)
    S.limiter.on = not S.limiter.on
    applyLimiter(veh)
    if S.limiter.on then
        Notify(Lang:t('notify.limiter_on', { speed = S.limiter.speed, unit = unitLabel() }), 'success', 1500)
    else
        Notify(Lang:t('notify.limiter_off'), 'primary', 1500)
    end
    return true
end

function H.limiterSpeed(veh, v)
    v = tonumber(v)
    if not v then return false end
    S.limiter.speed = math.floor(math.max(Config.Limiter.min, math.min(Config.Limiter.max, v)))
    applyLimiter(veh)
    return true
end

function H.driveMode(veh, id)
    local m = modeData(id)
    if not m then return false end
    if id ~= Config.DefaultDriveMode and not hasToolItem('driveMode') then return needItem('driveMode') end
    S.mode = id
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    Notify(Lang:t('notify.mode', { mode = m.label }), 'primary', 1500)
    return true
end

function H.launch()
    if S.launch then
        S.launch = false
    else
        if not hasToolItem('launch') then return needItem('launch') end
        S.launch = 'armed'
        Notify(Lang:t('notify.launch_armed'), 'primary', 4000)
    end
    return true
end

function H.tcs(veh)
    if S.tcs and not hasToolItem('tcs') then return needItem('tcs') end
    S.tcs = not S.tcs
    if S.tcs then SetVehicleReduceGrip(veh, false) end
    Notify(S.tcs and Lang:t('notify.tcs_on') or Lang:t('notify.tcs_off'), S.tcs and 'success' or 'error', 1500)
    return true
end

function Driving.Handle(veh, id, value)
    if S.veh ~= veh then
        releaseVehicle(S.veh)
        S.veh = veh
    end
    local fn = H[id]
    if not fn then return false end
    local ok, err = fn(veh, value)
    ensureLoop()
    return ok, err
end
