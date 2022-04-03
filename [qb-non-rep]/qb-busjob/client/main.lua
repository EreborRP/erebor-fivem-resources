-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local route = 1
local max = 0
local blip = {}

for k, v in pairs(Config.NPCLocations.Locations) do
    max = max + 1
end

local NpcData = {
    Active = false,
    CurrentNpc = nil,
    LastNpcRoute = nil,
    CurrentDeliver = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local BusData = {
    Active = false
}
-- Functions

local function ResetNpcTask()
    NpcData = {
        Active = false,
        CurrentNpc = nil,
        LastNpcRoute = nil,
        CurrentDeliver = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false
    }
end

local function DrawText3Ds(coords, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function whitelistedVehicle()
    local ped = PlayerPedId()
    local veh = GetEntityModel(GetVehiclePedIsIn(ped))
    local retval = false

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == GetHashKey(Config.AllowedVehicles[i].model) then
            retval = true
        end
    end

    if veh == GetHashKey("dynasty") then
        retval = true
    end

    return retval
end

local function computeNextStation(currentRoute)
    local toRet = 0
    if currentRoute <= (max - 1) then
        toRet = currentRoute + 1
    else
        toRet = 1
    end

    return toRet
end

local function spawnBus(data)
    QBCore.Functions.SpawnVehicle(data.model, function(veh)
        SetVehicleNumberPlateText(veh, Lang:t('info.bus_plate') .. tostring(math.random(1000, 9999)))
        exports['LegacyFuel']:SetFuel(veh, 100.0)
        closeMenuFull()
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, Config.SpawnLocation, true)
end

local function generatePassengerAtStation(position)
    local Gender = math.random(1, #Config.NpcSkins)
    local PedSkin = math.random(1, #Config.NpcSkins[Gender])
    local model = GetHashKey(Config.NpcSkins[Gender][PedSkin])
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local passenger = CreatePed(3, model, position.x, position.y, position.z - 0.98, position.w, false, true)
    PlaceObjectOnGroundProperly(passenger)
    FreezeEntityPosition(passenger, true)

    return passenger
end

local function getCurrentStation()
    return Config.NPCLocations.Locations[route]
end

local function focusStation(station)
    if NpcData.NpcBlip ~= nil then
        RemoveBlip(NpcData.NpcBlip)
    end

    NpcData.NpcBlip = AddBlipForCoord(station.x, station.y, station.z)
    SetBlipColour(NpcData.NpcBlip, 3)
    SetBlipRoute(NpcData.NpcBlip, true)
    SetBlipRouteColour(NpcData.NpcBlip, 3)

    QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')
end

local function searchVehicleFreeSeat(vehicle)
    local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)

    for i = maxSeats - 1, 0, -1 do
        if IsVehicleSeatFree(vehicle, i) then
            freeSeat = i
            break
        end
    end

    return freeSeat
end

local function pickUpPassenger(passenger, vehicle, freeSeat)
    ClearPedTasksImmediately(passenger.Npc)
    FreezeEntityPosition(passenger.Npc, false)
    TaskEnterVehicle(passenger.Npc, vehicle, -1, freeSeat, 1.0, 0)
end

local function focusDeliveryStation(station)
    if NpcData.DeliveryBlip ~= nil then
        RemoveBlip(NpcData.DeliveryBlip)
    end
    NpcData.DeliveryBlip = AddBlipForCoord(station.x, station.y, station.z)
    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)

    NpcData.LastDeliver = route
end

local function dropPassenger(passenger, vehicle, freeSeat)
    TaskLeaveVehicle(passenger.Npc, veh, 0)
    SetEntityAsMissionEntity(passenger.Npc, false, true)
    SetEntityAsNoLongerNeeded(passenger.Npc)

    local station = Config.NPCLocations.Locations[math.random(1, max)]
    TaskGoStraightToCoord(passenger.Npc, station.x, station.y, station.z, 1.0, -1, 0.0, 0.0)

    if passenger.DeliveryBlip ~= nil then
        RemoveBlip(passenger.DeliveryBlip)
    end
    local RemovePed = function(ped)
        SetTimeout(60000, function()
            DeletePed(ped)
        end)
    end
    RemovePed(passenger.Npc)
end

local function GetDeliveryLocation()
    route = computeNextStation(route)
    local deliveryStation = Config.NPCLocations.Locations[route]
    focusDeliveryStation(deliveryStation)

    local inRange = false
    print(vector3(deliveryStation.x, deliveryStation.y, deliveryStation.z))
    local PolyZone = CircleZone:Create(vector3(deliveryStation.x, deliveryStation.y, deliveryStation.z), 10, {
        name = 'busjobpick',
        useZ = true,
        debugPoly = false
    })

    PolyZone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inRange = true
            exports["qb-core"]:DrawText(Lang:t('info.busstop_text'), 'rgb(220, 20, 60)')
            CreateThread(function()
                repeat
                    Wait(0)
                    if IsControlJustPressed(0, 38) then
                        local veh = GetVehiclePedIsIn(PlayerPedId(), 0)

                        dropPassenger(NpcData, veh)
                        ResetNpcTask()

                        local pickupStation = Config.NPCLocations.Locations[route - 1]
                        local from = vector3(pickupStation.x, pickupStation.y, pickupStation.z)
                        local to = vector3(deliveryStation.x, deliveryStation.y, deliveryStation.z)
                        local distanceCost = CalculateTravelDistanceBetweenPoints(from.x, from.y, from.z, to.x, to.y,
                            to.z)
                        TriggerServerEvent('qb-busjob:server:NpcPay', distanceCost)

                        route = computeNextStation(route)

                        TriggerEvent('qb-busjob:client:DoBusNpc')
                        PolyZone:destroy()
                        break
                    end
                until not inRange
            end)
        else
            exports["qb-core"]:HideText()
            inRange = false
        end
    end)
end

function BusGarage()
    local vehicleMenu = {{
        header = Lang:t('menu.bus_header'),
        isMenuHeader = true
    }}
    for veh, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = v.label,
            params = {
                event = "qb-busjob:client:TakeVehicle",
                args = {
                    model = v.model
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu + 1] = {
        header = Lang:t('menu.bus_close'),
        params = {
            event = "qb-menu:client:closeMenu"
        }
    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

RegisterNetEvent("qb-busjob:client:TakeVehicle", function(data)
    if (BusData.Active) then
        QBCore.Functions.Notify(Lang:t('error.one_bus_active'), 'error')
        return
    else
        spawnBus(data)

        Wait(1000)
        TriggerEvent('qb-busjob:client:DoBusNpc')
    end
end)

RegisterNetEvent("qb-busjob:client:SuccessfullPayment", function(money)
    QBCore.Functions.Notify(Lang:t('success.success_payment') .. money, 'success')
end)

function closeMenuFull()
    exports['qb-menu']:closeMenu()
end

local function pointOutside()
    exports["qb-core"]:HideText()
    inRange = false
end

-- Events

RegisterNetEvent('qb-busjob:client:DoBusNpc', function()
    if not whitelistedVehicle() then
        QBCore.Functions.Notify(Lang:t('error.not_in_bus'), 'error')
        return
    end

    if NpcData.Active then
        QBCore.Functions.Notify(Lang:t('error.already_driving_bus'), 'error')
        return
    end

    local currentStationPosition = getCurrentStation()

    NpcData.Npc = generatePassengerAtStation(currentStationPosition)
    focusStation(currentStationPosition)
    NpcData.Active = true

    NpcData.LastNpcRoute = route

    local PolyZone = CircleZone:Create(vector3(currentStationPosition.x, currentStationPosition.y,
        currentStationPosition.z), 10, {
        name = 'busjobpick',
        useZ = true,
        debugPoly = false
    })
    local inRange = false
    PolyZone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inRange = true
            exports["qb-core"]:DrawText(Lang:t('info.busstop_text'), 'rgb(220, 20, 60)')
            CreateThread(function()
                repeat
                    Wait(1)
                    if IsControlJustPressed(0, 38) then
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), 0)
                        local freeSeat = searchVehicleFreeSeat()

                        pickUpPassenger(NpcData, vehicle, freeSeat)
                        QBCore.Functions.Notify(Lang:t('info.goto_busstop'), 'primary')

                        if NpcData.NpcBlip ~= nil then
                            RemoveBlip(NpcData.NpcBlip)
                        end
                        Wait(1)

                        GetDeliveryLocation()
                        NpcData.NpcTaken = true
                        PolyZone:destroy()
                        pointOutside()
                        return
                    end
                until not inRange
            end)
        else
            pointOutside()
        end
    end)
end)

-- Threads

CreateThread(function()
    BusBlip = AddBlipForCoord(Config.BusDepot)
    SetBlipSprite(BusBlip, 513)
    SetBlipDisplay(BusBlip, 4)
    SetBlipScale(BusBlip, 0.6)
    SetBlipAsShortRange(BusBlip, true)
    SetBlipColour(BusBlip, 49)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('info.bus_depot'))
    EndTextCommandSetBlipName(BusBlip)
end)

-- Remove polyzone from bus depot currently using blips and markers

-- CreateThread(function()
--     local inRange = false
--     local busDepotZone = CircleZone:Create(vector3(Config.BusDepot.x, Config.BusDepot.y, Config.BusDepot.z), 5, {
--         name = "busMain",
--         useZ = true,
--         debugPoly = false
--     })
--     busDepotZone:onPlayerInOut(function(isPointInside)
--         local Player = QBCore.Functions.GetPlayerData()
--         local inVeh = whitelistedVehicle()
--         if Player.job and Player.job.name == "bus" then
--             if isPointInside then
--                 inRange = true
--                 CreateThread(function()
--                     repeat
--                         Wait(0)
--                         if not inVeh then
--                             exports["qb-core"]:DrawText(Lang:t('info.busstop_text'), 'left')
--                             if IsControlJustReleased(0, 38) then
--                                 BusGarage()
--                                 exports["qb-core"]:HideText()
--                                 break
--                             end
--                         else
--                             exports["qb-core"]:DrawText(Lang:t('info.bus_stop_work'), 'left')
--                             if IsControlJustReleased(0, 38) then
--                                 if (not NpcData.Active or NpcData.Active and NpcData.NpcTaken == false) then
--                                     if IsPedInAnyVehicle(PlayerPedId(), false) then
--                                         BusData.Active = false;
--                                         DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
--                                         RemoveBlip(NpcData.NpcBlip)
--                                         exports["qb-core"]:HideText()
--                                         break
--                                     end
--                                 else
--                                     QBCore.Functions.Notify(Lang:t('error.drop_off_passengers'), 'error')
--                                 end
--                             end
--                         end
--                     until not inRange
--                 end)
--             else
--                 exports["qb-core"]:HideText()
--                 inRange = false
--             end
--         end
--     end)
-- end)

CreateThread(function()

    while true do
        local Player = QBCore.Functions.GetPlayerData()
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        inRange = false

        local dist = #(pos - Config.BusDepot)
        if dist < 50 then
            inRange = true
            DrawMarker(36, Config.BusDepot.x, Config.BusDepot.y, Config.BusDepot.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9,
                0.7, 0.7, 0, 204, 0, 155, false, false, false, true, false, false, false)
            if #(pos - vector3(Config.BusDepot.x, Config.BusDepot.y, Config.BusDepot.z)) < 5 then
                if whitelistedVehicle() then
                    DrawText3Ds(Config.BusDepot, '~g~E~w~ - Park bus')
                else
                    DrawText3Ds(Config.BusDepot, '~g~E~w~ - Access bus depot')
                end

                if IsControlJustPressed(0, 38) then
                    if Player.job and Player.job.name == "bus" then
                        if not whitelistedVehicle() then
                            BusGarage()
                        else
                            if (not NpcData.Active or NpcData.Active and NpcData.NpcTaken == false) then
                                if IsPedInAnyVehicle(PlayerPedId(), false) then
                                    BusData.Active = false;
                                    DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                                    RemoveBlip(NpcData.NpcBlip)
                                end
                            else
                                QBCore.Functions.Notify(Lang:t('error.drop_off_passengers'), 'error')
                            end
                        end
                    else
                        QBCore.Functions.Notify(Lang:t('error.no_bus_job'), 'error')
                    end
                end
            end
        end

        if not inRange then
            Wait(1500)
        end

        Wait(4)
    end
end)
