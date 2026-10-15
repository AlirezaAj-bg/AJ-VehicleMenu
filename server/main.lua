-- action -> validator for its value table. Anything not listed here is rejected.
local function isBool(v) return type(v) == 'boolean' end
local function isInt(v, lo, hi) return type(v) == 'number' and v == math.floor(v) and v >= lo and v <= hi end

local VALID = {
    door       = function(v) return isInt(v.i, 0, 5) and isBool(v.open) end,
    doorsAll   = function(v) return isBool(v.open) end,
    window     = function(v) return isInt(v.i, 0, 3) and isBool(v.down) end,
    windowsAll = function(v) return isBool(v.down) end,
    remoteEngine = function(v) return isBool(v.on) end,
    lights     = function(v) return isBool(v.on) end,
    highbeam   = function(v) return isBool(v.on) end,
    horn       = function() return true end,
    flash      = function() return true end,
    alarm      = function(v) return isBool(v.on) end,
    neon       = function(v) return isInt(v.i, 0, 3) and isBool(v.on) end,
    neonAll    = function(v) return isBool(v.on) end,
    xenon      = function(v) return isBool(v.on) and Config.AllowXenonToggle end,
    extra      = function(v) return isInt(v.id, 1, 14) and isBool(v.on) end,
    indicator  = function(v) return isInt(v.state, 0, 2) end,
    hazards    = function(v) return v.state == 0 or v.state == 3 end,
    cabin      = function(v) return isBool(v.on) end,
    siren      = function(v) return isBool(v.on) end,
}

local SEAT_WINDOW = { [-1] = 0, [0] = 1, [1] = 2, [2] = 3 }

local function trim(s) return (s or ''):gsub('^%s*(.-)%s*$', '%1') end

-- Returns 'driver' | 'passenger' | 'remote' | nil, plus the seat index for occupants.
local function roleFor(src, veh)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    if GetVehiclePedIsIn(ped, false) == veh then
        for seat = -1, 14 do
            if GetPedInVehicleSeat(veh, seat) == ped then
                return seat == -1 and 'driver' or 'passenger', seat
            end
        end
        return nil
    end
    if Config.Remote.enabled and #(GetEntityCoords(ped) - GetEntityCoords(veh)) <= Config.Remote.range + 10.0 then
        local plate = trim(GetVehicleNumberPlateText(veh))
        local ok, has = pcall(function() return exports['qb-vehiclekeys']:HasKeys(src, plate) end)
        if ok and has then return 'remote' end
    end
    return nil
end

local function permitted(role, seat, action, value)
    if role == 'driver' then return true end
    if role == 'passenger' then
        local p = Config.PassengerAllowed
        if action == 'cabin' then return p.cabin and true or false end
        if action == 'window' then
            if p.window == true then return true end
            if p.window == 'own' then return value.i == SEAT_WINDOW[seat] end
        end
        return false
    end
    if role == 'remote' then return Config.RemoteAllowed[action] and true or false end
    return false
end

local function logReject(src, action, why)
    if Config.Debug then print(('[aj-vehiclemenu] rejected %s from %s: %s'):format(action, src, why)) end
end

local function forwardToOwner(src, veh, netId, action, value)
    local owner = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 then owner = src end
    TriggerClientEvent('aj-vehiclemenu:client:apply', owner, netId, action, value)
end

RegisterNetEvent('aj-vehiclemenu:server:action', function(netId, action, value)
    local src = source
    if type(netId) ~= 'number' or type(action) ~= 'string' or type(value) ~= 'table' then return end
    local check = VALID[action]
    if not check or not check(value) then return logReject(src, action, 'invalid value') end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return logReject(src, action, 'no vehicle for netId ' .. netId) end

    local role, seat = roleFor(src, veh)
    if not role then return logReject(src, action, 'not in vehicle / out of range / no keys') end
    if not permitted(role, seat, action, value) then return logReject(src, action, 'not allowed for ' .. role) end

    local bag = Entity(veh).state

    if action == 'indicator' or action == 'hazards' then
        bag:set('ajvm_ind', value.state, true)
    elseif action == 'cabin' then
        bag:set('ajvm_cabin', value.on, true)
    elseif action == 'siren' then
        bag:set('ajvm_siren', value.on, true)
    elseif action == 'window' or action == 'windowsAll' then
        local win = bag['ajvm_win'] or {}
        local out = { win[1] or false, win[2] or false, win[3] or false, win[4] or false }
        if action == 'window' then
            out[value.i + 1] = value.down
        else
            for i = 1, 4 do out[i] = value.down end
        end
        bag:set('ajvm_win', out, true)
        forwardToOwner(src, veh, netId, action, value)
    else
        forwardToOwner(src, veh, netId, action, value)
    end
end)
