-- State bags written by server/main.lua. Indicators, cabin light and siren mute are not synced by the
-- game itself, so every client that has the vehicle streamed in applies them locally.

local function vehFromBag(bagName)
    local veh = GetEntityFromStateBagName(bagName)
    if veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

function ApplyIndicator(veh, state)
    state = state or 0
    SetVehicleIndicatorLights(veh, 1, state == 1 or state == 3) -- 1 = left
    SetVehicleIndicatorLights(veh, 0, state == 2 or state == 3) -- 0 = right
end
local applyIndicator = ApplyIndicator

AddStateBagChangeHandler('ajvm_ind', nil, function(bagName, _, value)
    local veh = vehFromBag(bagName)
    if veh then applyIndicator(veh, value) end
end)

AddStateBagChangeHandler('ajvm_cabin', nil, function(bagName, _, value)
    local veh = vehFromBag(bagName)
    if veh then SetVehicleInteriorlight(veh, value and true or false) end
end)

AddStateBagChangeHandler('ajvm_siren', nil, function(bagName, _, value)
    local veh = vehFromBag(bagName)
    if veh then SetVehicleHasMutedSirens(veh, value and true or false) end
end)

-- Vehicles streamed in after the bag was set: re-apply once when they appear nearby.
CreateThread(function()
    local seen = {}
    while true do
        local now = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local bag = Entity(veh).state
            local ind, cabin, siren = bag['ajvm_ind'], bag['ajvm_cabin'], bag['ajvm_siren']
            if ind or cabin or siren then
                now[veh] = true
                if not seen[veh] then
                    if ind then applyIndicator(veh, ind) end
                    if cabin then SetVehicleInteriorlight(veh, true) end
                    if siren then SetVehicleHasMutedSirens(veh, true) end
                end
            end
        end
        seen = now
        Wait(1500)
    end
end)
