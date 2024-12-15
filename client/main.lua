ESX = nil
local canisterModel = 'prop_gascyl_03a'
local hoseModel = 'prop_fire_hosebox_01'
local cashModel = 'prop_anim_cash_pile_01'
local cashObjects = {}
local canisterObject = nil
local hoseObject = nil
local hoseInHand = false  -- Schlauch in der Hand
local connected = false   -- Schlauch mit dem Automaten verbunden
local skillCheckActive = false
local skillCheckStartTime = nil
local maxSkillCheckTime = 10 -- Zeitlimit für Minispiel
local atmRobbed = {}      -- Überprüft, ob jeder Automat bereits ausgeraubt wurde
local connectedATM = nil  -- Aktuell verbundener Automat

-- Automaten und ihre Positionen
local ATMS = {
    {
        position = vector3(-254.5089, -692.2607, 33.6054),
        heading = 170.6384,
        cashPositions = {
            vector3(-255.6559, -691.0968, 33.5705),
            vector3(-252.8732, -692.7313, 33.6182),
            vector3(-253.6396, -688.6658, 33.5665),
            vector3(-254.0957, -690.8517, 33.5742),
            vector3(-251.8721, -690.9473, 33.5576)
        }
    },
    {
        position = vector3(-2074.8975, -332.7748, 13.3160),
        heading =  278.9031,
        cashPositions = {
            vector3(-2075.3535, -331.2203, 13.3132),
            vector3(-2075.3379, -332.5172, 13.3160),
            vector3(-2077.8284, -334.5557, 13.1530),
            vector3(-2078.3745, -331.3148, 13.1474),
            vector3(-2076.9119, -332.7942, 13.1808)
        }
    },
    {
        position = vector3(145.7462, -1035.0176, 29.3452),
        heading = 170.0042,
        cashPositions = {
            vector3(149.6388, -1031.8303, 29.3425),
            vector3(149.6270, -1034.5592, 29.3415),
            vector3(146.5430, -1033.9990, 29.3448),
            vector3(143.5805, -1031.9987, 29.3482),
            vector3(140.9902, -1032.0077, 29.3505)
        }
    }
}

-- Initialisiere ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Befehl zum Platzieren der Gasflasche
RegisterCommand('gass', function()
    if connected or hoseInHand then
        ESX.ShowNotification("Du hast den Schlauch bereits verbunden oder in der Hand!")
        return
    end

    ESX.TriggerServerCallback('my_atm_script:hasItem', function(hasItem)
        if hasItem then
            spawnCanister()
            TriggerServerEvent('my_atm_script:removeGasCanister') -- Gasflasche aus Inventar entfernen
        else
            ESX.ShowNotification("Du benötigst eine Gasflasche in deinem Inventar.")
        end
    end, 'gasflasche')
end, false)

-- Spawn der Gasflasche 0.5 Meter vor dem Spieler
function spawnCanister()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player) + GetEntityForwardVector(player) * 0.5
    ESX.Game.SpawnObject(canisterModel, coords, function(obj)
        canisterObject = obj
        PlaceObjectOnGroundProperly(obj)
        ESX.ShowNotification("Gasflasche aufgestellt.")
    end)
end

-- Schlauch in die Hand nehmen
function takeHoseInHand()
    local playerPed = PlayerPedId()
    RequestAnimDict("anim@heists@box_carry@")
    while not HasAnimDictLoaded("anim@heists@box_carry@") do
        Citizen.Wait(0)
    end
    TaskPlayAnim(playerPed, "anim@heists@box_carry@", "idle", 1.0, -1.0, -1, 50, 0, false, false, false)
    
    ESX.Game.SpawnObject(hoseModel, GetEntityCoords(playerPed), function(obj)
        AttachEntityToEntity(obj, playerPed, GetPedBoneIndex(playerPed, 60309), 0.05, 0.05, 0.0, 0.0, 270.0, 0.0, true, true, false, true, 1, true)
        hoseObject = obj
        hoseInHand = true
        ESX.ShowNotification("Schlauch in die Hand genommen.")
    end)
end

-- Funktion zum Verbinden des Schlauchs mit dem Automaten
function connectHoseToATM(atm)
    DetachEntity(hoseObject, true, true)
    DeleteEntity(hoseObject)
    hoseInHand = false
    connected = true
    connectedATM = atm
    ESX.ShowNotification("Schlauch erfolgreich mit dem Automaten verbunden.")

    -- Erstelle die Verbindungslinie zwischen Gasflasche und Automat
    Citizen.CreateThread(function()
        while connected and connectedATM do
            Citizen.Wait(0)
            local canisterCoords = GetEntityCoords(canisterObject)
            DrawLine(canisterCoords.x, canisterCoords.y, canisterCoords.z, atm.position.x, atm.position.y, atm.position.z, 0, 255, 0, 255) -- Zeichnet eine grüne Linie als Schlauch
        end
    end)
end

-- Spieleraktionen in der Nähe der Gasflasche und des Automaten
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())

        if canisterObject then
            local objCoords = GetEntityCoords(canisterObject)

            -- „E“ drücken, um den Schlauch zu nehmen
            if #(playerCoords - objCoords) < 1.5 and not hoseInHand and not connected then
                ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~ um den Schlauch zu nehmen.")
                if IsControlJustReleased(0, 38) then
                    takeHoseInHand()
                end
            end

            -- Skill-Check starten an der Gasflasche
            if #(playerCoords - objCoords) < 1.5 and connected then
                ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~ um den Skill-Check zu starten.")
                if IsControlJustReleased(0, 38) then
                    startSkillCheck()
                end
            end
        end

        -- Verbindung mit dem Automaten, wenn Schlauch in der Hand ist
        for _, atm in ipairs(ATMS) do
            if hoseInHand and #(playerCoords - atm.position) < 1.5 then
                ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~ um den Schlauch mit dem Automaten zu verbinden.")
                if IsControlJustReleased(0, 38) then
                    connectHoseToATM(atm)
                end
            end
        end
    end
end)

-- Funktion zum Starten des Skill-Checks
function startSkillCheck()
    skillCheckActive = true
    skillCheckStartTime = GetGameTimer() / 1000
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openUI' })
end

-- NUI-Callback für das Ergebnis des Skill-Checks
RegisterNUICallback('skillCheckResult', function(data)
    skillCheckActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })

    -- Berechne, ob der Spieler innerhalb des Zeitlimits (10 Sekunden) abgeschlossen hat
    local timeSpent = (GetGameTimer() / 1000) - skillCheckStartTime
    if data.success and timeSpent <= maxSkillCheckTime then
        -- Erfolgreiche Explosion nur des Automaten
        TriggerServerEvent('my_atm_script:successExplosion', connectedATM.position, connectedATM.cashPositions)
    else
        -- Misserfolg: Explodiert sowohl Gasflasche als auch Automat
        TriggerServerEvent('my_atm_script:failExplosion', GetEntityCoords(canisterObject), connectedATM.position)
    end

    removeCanisterAndHose()
end)

-- Funktion zum Entfernen der Gasflasche und des Schlauchs
function removeCanisterAndHose()
    if canisterObject then
        DeleteObject(canisterObject)
        canisterObject = nil
    end
    if hoseObject then
        DeleteObject(hoseObject)
        hoseObject = nil
    end
    connected = false
    hoseInHand = false
    connectedATM = nil
end

-- Explosion und Spawn von Geldhaufen mit Server-Callback
RegisterNetEvent('my_atm_script:createExplosion')
AddEventHandler('my_atm_script:createExplosion', function(coords, size, cashCoords)
    AddExplosion(coords.x, coords.y, coords.z, 1, size, true, false, 1.0)
    
    -- Geldhaufen erscheinen mit Markern für die Sammlung
    if cashCoords and size == 1.0 then
        for _, pos in ipairs(cashCoords) do
            ESX.Game.SpawnObject(cashModel, pos, function(obj)
                table.insert(cashObjects, obj)
                exports.ox_target:addLocalEntity(obj, {
                    {
                        name = 'collect_cash',
                        label = 'Sammle Geld',
                        onSelect = function()
                            TriggerServerEvent('my_atm_script:collectCash')
                            DeleteObject(obj)
                            for i, cashObj in ipairs(cashObjects) do
                                if cashObj == obj then
                                    table.remove(cashObjects, i)
                                    break
                                end
                            end
                        end,
                    }
                })
                
                -- Marker über dem Geld
                Citizen.CreateThread(function()
                    while DoesEntityExist(obj) do
                        local objCoords = GetEntityCoords(obj)
                        DrawMarker(2, objCoords.x, objCoords.y, objCoords.z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 100, false, true, 2, nil, nil, false)
                        Citizen.Wait(0)
                    end
                end)
            end)
        end
    end
end)
