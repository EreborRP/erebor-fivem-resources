local QBCore = exports['qb-core']:GetCoreObject()

function NearBusStation(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    for k, v in pairs(Config.NPCLocations.Locations) do
        local dist = #(coords - vector3(v.x, v.y, v.z))
        if dist < 20 then
            return true
        end
    end
end

local function round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces > 0 then
        local mult = 10 ^ numDecimalPlaces
        return math.floor(num * mult + 0.5) / mult
    end
    return math.floor(num + 0.5)
end

local function computePayment(distance)
    local Payment = math.random(Config.PayRangeFrom, Config.PayRangeTo)

    return Payment + round(distance / 10, 0)
end

local function isBusDriver(Player)
    if not Player.PlayerData.job then
        print("qb-busjob:server:main - isBusDriver: Cannot receive player this shouldn't happen")
        return false
    end

    return Player.PlayerData.job.name == "bus"
end

RegisterNetEvent('qb-busjob:server:NpcPay', function(distance)

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if isBusDriver(Player) then
        if NearBusStation(src) then
            local Payment = computePayment(distance)
            Player.Functions.AddMoney('cash', Payment)
            TriggerClientEvent('qb-busjob:client:SuccessfullPayment', src, Payment)
        else
            DropPlayer(src, 'Attempting To Exploit')
        end
    else
        DropPlayer(src, 'Attempting To Exploit')
    end
end)
