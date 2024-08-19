local BLIPS = {}
function openMenu()
    local sperrzoneOptions = {
        {
            title = 'Neue Sperrzone erstellen',
            icon = 'plus',
            onSelect = function()
                local coords = GetEntityCoords(cache.ped)
                local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
                local input = lib.inputDialog('Sperrzone erstellen', {
                    {type = 'input', label = 'Titel', description = 'Anzeigename der Sperrzone', required = true, default = street},
                    {type = 'slider', label = 'Radius', min = 50, default = 100, max = 250, required = true},
                    {type = 'select', label = 'Zonentyp',  required = true, default='1', options = {{value='1',label='Sperrzone (rot)'},{value='5', label='Gefahrenstelle (gelb)'},{value='3', label='Öffentliche Veranstaltung (blau)'}}},
                })
                
                if not input then return end
                TriggerServerEvent('snov_sperrzone:create', input, GetEntityCoords(cache.ped))
            end
        }
    }

    if GlobalState.sperrzonen then
        for key, zoneInfo in pairs(json.decode(GlobalState.sperrzonen)) do
            table.insert(sperrzoneOptions, {
                title = zoneInfo.zoneName..' ('..zoneInfo.job..')',
                description = 'Ausgerufen von: '..zoneInfo.creator,
                icon = 'pen-to-square',
                onSelect = function()
                    lib.registerContext({
                        id = 'snov_sperrzone_edit',
                        title = 'Sperrzone bearbeiten',
                        menu = 'snov_sperrzone',
                        options = {
                            {
                                title = zoneInfo.zoneName..' ('..zoneInfo.job..')',
                                description = 'Ausgerufen von: '..zoneInfo.creator,
                                readOnly = true,
                            },
                            {
                                title = 'Sperrzone bearbeiten',
                                icon = 'pen-to-square',
                                onSelect = function()
                                    local input = lib.inputDialog('Sperrzone bearbeiten', {
                                        {type = 'input', label = 'Titel', description = 'Anzeigename der Sperrzone', required = true, default = zoneInfo.zoneName},
                                        {type = 'slider', label = 'Radius', min = 50, default = zoneInfo.radius, max = 250, required = true},
                                        {type = 'select', label = 'Zonentyp',  required = true, default=''..zoneInfo.color, options = {{value='1',label='Sperrzone (rot)'},{value='5', label='Gefahrenstelle (gelb)'},{value='3', label='Öffentliche Veranstaltung (blau)'}}},
                                    })

                                    if not input then return end
                                    TriggerServerEvent('snov_sperrzone:update', input, key)
                                end
                            },
                            {
                                title = 'Sperrzone entfernen',
                                icon = 'trash',
                                onSelect = function()
                                    TriggerServerEvent('snov_sperrzone:delete', key)
                                end
                            },
                        },
                    })
                    lib.showContext('snov_sperrzone_edit')
                end
            })
        end
    end


    lib.registerContext({
        id = 'snov_sperrzone',
        title = 'Sperrzone',
        options = sperrzoneOptions,
    })

    lib.showContext('snov_sperrzone')
end
AddEventHandler('snov_sperrzone:openMenu', openMenu)

RegisterNetEvent('snov_sperrzone:created', function(zoneId)
    while not GlobalState.sperrzonen or json.decode(GlobalState.sperrzonen)[zoneId] == nil do
        Wait(100)
    end
    local zoneInfo = json.decode(GlobalState.sperrzonen)[zoneId]
    local radiusBlip = AddBlipForRadius(zoneInfo.coords.x, zoneInfo.coords.y, zoneInfo.coords.z, zoneInfo.radius + 0.0)
    SetBlipColour(radiusBlip, zoneInfo.color)
    SetBlipAlpha(radiusBlip, 70)

    BLIPS[zoneId] = radiusBlip

    if zoneInfo.color == 1 then
        lib.notify({
            title = 'Sperrzone',
            description = 'Es wurde eine neue Sperrzone ausgerufen: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 10000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
        PlaySoundFrontend(-1, 'Event_Start_Text','GTAO_FM_Events_Soundset')
    elseif zoneInfo.color == 5 then
        lib.notify({
            title = 'Gefahrenstelle',
            description = 'Es wurde eine neue Gefahrenstelle ausgerufen: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 8000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
        PlaySoundFrontend(-1, 'Event_Message_Purple','GTAO_FM_Events_Soundset')
    else
        lib.notify({
            title = 'Veranstaltung',
            description = 'Ein Veranstaltungsort wurde markiert: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 6000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
    end
end)

RegisterNetEvent('snov_sperrzone:updated', function(zoneId, zoneInfo)
    if BLIPS[zoneId] then
        RemoveBlip(BLIPS[zoneId])
    end
    local radiusBlip = AddBlipForRadius(zoneInfo.coords.x, zoneInfo.coords.y, zoneInfo.coords.z, zoneInfo.radius + 0.0)
    SetBlipColour(radiusBlip, zoneInfo.color)
    SetBlipAlpha(radiusBlip, 70)

    BLIPS[zoneId] = radiusBlip

    if zoneInfo.color == 1 then
        lib.notify({
            title = 'Sperrzone',
            description = 'Eine Sperrzone wurde aktualisiert: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 10000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
        PlaySoundFrontend(-1, 'Event_Message_Purple','GTAO_FM_Events_Soundset')
    elseif zoneInfo.color == 5 then
        lib.notify({
            title = 'Gefahrenstelle',
            description = 'Eine Gefahrenstelle wurde aktualisiert: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 8000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
        PlaySoundFrontend(-1, 'Event_Message_Purple','GTAO_FM_Events_Soundset')
    else
        lib.notify({
            title = 'Veranstaltung',
            description = 'Ein Veranstaltungsort wurde aktualisiert: '..zoneInfo.zoneName..' ('..zoneInfo.job..')',
            duration = 6000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
    end
end)

RegisterNetEvent('snov_sperrzone:deleted', function(zoneId)
    if BLIPS[zoneId] then
        RemoveBlip(BLIPS[zoneId])
        lib.notify({
            title = 'Sperrzone aufgehoben',
            description = 'Eine Sperrzone/Gefahrenstelle wurde aufgehoben',
            duration = 6000,
            position = 'top',
            style = {
                width = '500px'
            }
        })
    end
end)

local playerJob = nil

RegisterNetEvent('esx:setJob', function(job, lastJob)
    playerJob = job.name
end)
AddEventHandler('esx:playerLoaded', function()
    while ESX.GetPlayerData().job == nil do
		Wait(100)
	end
    playerJob = ESX.GetPlayerData().job.name
end)
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    while ESX.GetPlayerData().job == nil do
		Wait(100)
	end
    playerJob = ESX.GetPlayerData().job.name
end)

RegisterCommand('sperrzone', function(source, args, raw)
    if lib.table.contains(Config.allowedJobs, playerJob) then
        TriggerEvent('snov_sperrzone:openMenu')
    else
        lib.notify({description='Du hast dafür keine Berechtigung!', type='error'})
    end
end)