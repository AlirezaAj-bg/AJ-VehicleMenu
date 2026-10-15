Remote = {}

-- Nearest vehicle within keyfob range that the player holds keys for.
function Remote.FindVehicle()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, Config.Remote.range + 0.001
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(coords - GetEntityCoords(veh))
        if dist < bestDist then
            local ok, has = pcall(function() return exports['qb-vehiclekeys']:HasKeys(VM.GetPlate(veh)) end)
            if ok and has then
                best, bestDist = veh, dist
            end
        end
    end
    return best, best and bestDist or nil
end
