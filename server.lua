ESX = exports['es_extended']:getSharedObject()
ID_COUNTER = 0

RegisterNetEvent('snov_sperrzone:create', function(input, coords)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not lib.table.contains(Config.allowedJobs, xPlayer.getJob().name) then
        xPlayer.showNotification('Du hast dafür keine Berechtigung!')
        return
    end
    
    local sperrzonen = json.decode(GlobalState.sperrzonen) or {}
    local zoneId = 'zone_'..getId()
    sperrzonen[zoneId] = {
        zoneName = input[1],
        coords = coords,
        radius = input[2],
        color = tonumber(input[3]),
        creator = xPlayer.getJob().grade_label..' - '..xPlayer.getName(),
        job = xPlayer.getJob().label,
    }

    GlobalState.sperrzonen = json.encode(sperrzonen)

    TriggerClientEvent('snov_sperrzone:created', -1, zoneId)
end)

RegisterNetEvent('snov_sperrzone:update', function(input, zoneId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not lib.table.contains(Config.allowedJobs, xPlayer.getJob().name) then
        xPlayer.showNotification('Du hast dafür keine Berechtigung!')
        return
    end

    local sperrzonen = json.decode(GlobalState.sperrzonen) or {}
    sperrzonen[zoneId].zoneName = input[1]
    sperrzonen[zoneId].radius = input[2]
    sperrzonen[zoneId].color = tonumber(input[3])
    sperrzonen[zoneId].creator = xPlayer.getJob().grade_label..' - '..xPlayer.getName()
    sperrzonen[zoneId].job = xPlayer.getJob().label

    GlobalState.sperrzonen = json.encode(sperrzonen)

    TriggerClientEvent('snov_sperrzone:updated', -1, zoneId, sperrzonen[zoneId])
end)

RegisterNetEvent('snov_sperrzone:delete', function(zoneId)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not lib.table.contains(Config.allowedJobs, xPlayer.getJob().name) then
        xPlayer.showNotification('Du hast dafür keine Berechtigung!')
        return
    end

    local sperrzonen = json.decode(GlobalState.sperrzonen) or {}
    sperrzonen[zoneId] = nil
    GlobalState.sperrzonen = json.encode(sperrzonen)

    TriggerClientEvent('snov_sperrzone:deleted', -1, zoneId)
end)

function getId()
    ID_COUNTER = ID_COUNTER + 1
    return ID_COUNTER
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        GlobalState.sperrzonen = nil
    end
end)