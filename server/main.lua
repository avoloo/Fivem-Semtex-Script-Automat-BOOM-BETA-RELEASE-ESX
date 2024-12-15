ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Callback, um zu überprüfen, ob der Spieler eine Gasflasche im Inventar hat
ESX.RegisterServerCallback('my_atm_script:hasItem', function(source, cb, item)
    local xPlayer = ESX.GetPlayerFromId(source)
    local itemData = xPlayer.getInventoryItem(item)
    cb(itemData and itemData.count > 0)
end)

-- Entfernt die Gasflasche aus dem Inventar
RegisterServerEvent('my_atm_script:removeGasCanister')
AddEventHandler('my_atm_script:removeGasCanister', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeInventoryItem('gasflasche', 1)
end)

-- Explosion bei Erfolg (nur Automat)
RegisterServerEvent('my_atm_script:successExplosion')
AddEventHandler('my_atm_script:successExplosion', function(atmPosition, cashPositions)
    TriggerClientEvent('my_atm_script:createExplosion', source, atmPosition, 1.0, cashPositions)
end)

-- Explosion bei Misserfolg (Automat und Gasflasche)
RegisterServerEvent('my_atm_script:failExplosion')
AddEventHandler('my_atm_script:failExplosion', function(canisterCoords, atmPosition)
    TriggerClientEvent('my_atm_script:createExplosion', source, canisterCoords, 10.0, nil)
    TriggerClientEvent('my_atm_script:createExplosion', source, atmPosition, 10.0, nil)
end)

-- Belohnung beim Geldsammeln
RegisterServerEvent('my_atm_script:collectCash')
AddEventHandler('my_atm_script:collectCash', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addInventoryItem('wool', 1)
    TriggerClientEvent('esx:showNotification', source, "Du hast Geld eingesammelt!")
end)
