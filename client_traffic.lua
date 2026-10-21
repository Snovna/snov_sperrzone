-- snov_sperrzone (client, NPC traffic blocking)
--
-- Every zone blocks NPC traffic while it exists (Config.BlockTraffic turns
-- the feature off globally). Every client applies all zones, because ambient
-- traffic is simulated by whichever client owns it:
--   1. the road nodes in the axis-aligned box around the zone circle are
--      switched off, so NPCs plan their routes around the zone,
--   2. one road node speed zone (radius + margin) stops cars already en route,
--   3. a thread keeps the ambient NPC cars this client controls out of the
--      circle (re-route + slow down on approach, delete if they are still
--      inside after Config.TrafficDeleteAfter).
-- Player vehicles are never touched.
--
-- client.lua calls SperrzoneTraffic.add / update / remove from its sync paths.

SperrzoneTraffic = {}

local zones = {}        -- zoneId -> zone (see build)
local tracked = {}      -- vehicle handle -> { retaskAt, insideSince, capped }
local enforcing = false
local enabled = Config.BlockTraffic ~= false
local networked = Config.TrafficNetworked ~= false

local ENFORCE_MS = 250
local RETASK_MS = 3000
local DRIVE_STYLE = 786603 -- normal: stop for cars and lights, avoid peds and objects
local SPEED_ZONE_MARGIN = 15.0

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

local function build(zoneId, zoneInfo)
    local center = vector3(zoneInfo.coords.x + 0.0, zoneInfo.coords.y + 0.0, zoneInfo.coords.z + 0.0)
    local radius = (tonumber(zoneInfo.radius) or 100) + 0.0
    local height = (Config.TrafficBoxHeight or 30.0) + 0.0
    return {
        id = zoneId,
        center = center,
        radius = radius,
        -- Axis-aligned box around the circle (its corners reach past the circle)
        min = vector3(center.x - radius, center.y - radius, center.z - height),
        max = vector3(center.x + radius, center.y + radius, center.z + height),
        speedZone = nil,
    }
end

local function contains(z, pos)
    if pos.z < z.min.z or pos.z > z.max.z then return false end
    return #(pos.xy - z.center.xy) <= z.radius
end

---------------------------------------------------------------------------
-- Natives
---------------------------------------------------------------------------

-- SET_ROADS_IN_AREA(x1, y1, z1, x2, y2, z2, nodeEnabled, network)
local function setRoads(z, active)
    local function call(net)
        return pcall(SetRoadsInArea, z.min.x, z.min.y, z.min.z, z.max.x, z.max.y, z.max.z, active, net)
    end
    if networked and not call(true) then
        networked = false
        print('SetRoadsInArea with network flag failed, using local switching')
    end
    if not networked then call(false) end
end

-- SET_ROADS_BACK_TO_ORIGINAL(x1, y1, z1, x2, y2, z2, network)
local function restoreRoads(z)
    local function call(net)
        return pcall(SetRoadsBackToOriginal, z.min.x, z.min.y, z.min.z, z.max.x, z.max.y, z.max.z, net)
    end
    if not (networked and call(true)) then call(false) end
end

-- One speed zone over the whole circle plus margin, the whole area is closed
local function addSpeedZone(z)
    local c = z.center
    local ok, zone = pcall(AddRoadNodeSpeedZone, c.x, c.y, c.z, z.radius + SPEED_ZONE_MARGIN, 0.0, false)
    if ok and zone then z.speedZone = zone end
end

local function removeSpeedZone(z)
    if z.speedZone then pcall(RemoveRoadNodeSpeedZone, z.speedZone) end
    z.speedZone = nil
end

-- Warn in F8 if the closest node to the zone center is inside the circle but
-- still active (wrong native parameters)
local function checkApplied(z)
    local c = z.center
    local id = GetNthClosestVehicleNodeId(c.x, c.y, c.z, 1, 1, 300.0, 300.0)
    if not id or id == 0 or not IsVehicleNodeIdValid(id) then return end
    local pos = GetVehicleNodePosition(id)
    if contains(z, pos) and not GetVehicleNodeIsSwitchedOff(id) then
        print(('zone %s: node %d inside the zone is still active'):format(z.id, id))
    end
end

---------------------------------------------------------------------------
-- Enforcement
---------------------------------------------------------------------------

local function npcOccupants(veh)
    local out = {}
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for seat = -1, seats - 2 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 then out[#out + 1] = ped end
    end
    return out
end

-- Ambient population types: 2 random parked, 3 random patrol, 4 random scenario, 5 random ambient
local function isAmbientNpcVehicle(veh)
    if not DoesEntityExist(veh) or IsEntityAMissionEntity(veh) then return false end
    local pop = GetEntityPopulationType(veh)
    if pop < 2 or pop > 5 then return false end
    if not NetworkHasControlOfEntity(veh) then return false end
    for _, ped in ipairs(npcOccupants(veh)) do
        if IsPedAPlayer(ped) or IsEntityAMissionEntity(ped) then return false end
    end
    local last = GetLastPedInVehicleSeat(veh, -1)
    if last ~= 0 and DoesEntityExist(last) and IsPedAPlayer(last) then return false end
    return true
end

local function deleteNpcVehicle(veh)
    for _, ped in ipairs(npcOccupants(veh)) do
        if not IsPedAPlayer(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeletePed(ped)
        end
    end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
end

-- 'inside', 'approach' (in the ring around the circle and heading for the center) or nil
local function zoneOf(z, pos, vel, approach)
    if pos.z < z.min.z - 2.0 or pos.z > z.max.z + 2.0 then return nil end
    local dx, dy = z.center.x - pos.x, z.center.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= z.radius then
        return (pos.z >= z.min.z and pos.z <= z.max.z) and 'inside' or nil
    end
    if dist > z.radius + approach then return nil end
    local toward = (vel.x * dx + vel.y * dy) / dist
    if toward > 1.0 then return 'approach' end
    return nil
end

local function release(veh, info)
    if info.capped and DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
        SetVehicleMaxSpeed(veh, 0.0)
    end
end

local function handleVehicle(veh, state, now, speed)
    local info = tracked[veh]
    if not info then
        info = {}
        tracked[veh] = info
    end

    local driver = GetPedInVehicleSeat(veh, -1)
    local hasDriver = driver ~= 0 and DoesEntityExist(driver) and not IsPedDeadOrDying(driver, true)

    if state == 'inside' then
        info.insideSince = info.insideSince or now
        if not hasDriver or now - info.insideSince >= (Config.TrafficDeleteAfter or 4000) then
            deleteNpcVehicle(veh)
            tracked[veh] = nil
            return
        end
    else
        info.insideSince = nil
    end

    if hasDriver then
        -- A fresh wander task plans its route over active nodes only
        if not info.retaskAt or now >= info.retaskAt then
            TaskVehicleDriveWander(driver, veh, speed, DRIVE_STYLE)
            info.retaskAt = now + RETASK_MS
        end
        SetDriveTaskCruiseSpeed(driver, speed)
        SetVehicleMaxSpeed(veh, speed)
        info.capped = true
    end
end

local function enforce()
    local me = GetEntityCoords(PlayerPedId())
    local range = Config.TrafficEnforceRange or 200.0
    local near = {}
    for _, z in pairs(zones) do
        if #(me.xy - z.center.xy) <= range + z.radius then near[#near + 1] = z end
    end

    local seen = {}
    if #near > 0 then
        local now = GetGameTimer()
        local approach = Config.TrafficApproach or 25.0
        local speed = (Config.TrafficApproachSpeed or 5.0) + 0.0
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if isAmbientNpcVehicle(veh) then
                local pos, vel = GetEntityCoords(veh), GetEntityVelocity(veh)
                local state
                for _, z in ipairs(near) do
                    local s = zoneOf(z, pos, vel, approach)
                    if s == 'inside' then state = s break end
                    state = state or s
                end
                if state then
                    seen[veh] = true
                    handleVehicle(veh, state, now, speed)
                end
            end
        end
    end

    for veh, info in pairs(tracked) do
        if not seen[veh] then
            release(veh, info)
            tracked[veh] = nil
        end
    end
end

local function startEnforcing()
    if enforcing then return end
    enforcing = true
    CreateThread(function()
        while next(zones) do
            enforce()
            Wait(ENFORCE_MS)
        end
        for veh, info in pairs(tracked) do release(veh, info) end
        tracked = {}
        enforcing = false
    end)
end

---------------------------------------------------------------------------
-- Sync (called from client.lua)
---------------------------------------------------------------------------

local function apply(z)
    setRoads(z, false)
    addSpeedZone(z)
    checkApplied(z)
end

local function restore(z)
    removeSpeedZone(z)
    restoreRoads(z)
end

-- Restoring may have re-enabled nodes of an overlapping zone
local function reapplyOthers()
    for _, other in pairs(zones) do setRoads(other, false) end
end

function SperrzoneTraffic.add(zoneId, zoneInfo)
    if not enabled or zoneId == nil or type(zoneInfo) ~= 'table' or not zoneInfo.coords then return end
    if zones[zoneId] then return SperrzoneTraffic.update(zoneId, zoneInfo) end
    local z = build(zoneId, zoneInfo)
    zones[zoneId] = z
    apply(z)
    startEnforcing()
end

-- Coords and radius may have changed: restore the old area, then apply the new one
function SperrzoneTraffic.update(zoneId, zoneInfo)
    if not enabled or zoneId == nil or type(zoneInfo) ~= 'table' or not zoneInfo.coords then return end
    local old = zones[zoneId]
    if old then
        zones[zoneId] = nil
        restore(old)
        reapplyOthers()
    end
    SperrzoneTraffic.add(zoneId, zoneInfo)
end

function SperrzoneTraffic.remove(zoneId, stopping)
    local z = zones[zoneId]
    if not z then return end
    zones[zoneId] = nil
    restore(z)
    if stopping then return end
    reapplyOthers()
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for zoneId in pairs(zones) do SperrzoneTraffic.remove(zoneId, true) end
    for veh, info in pairs(tracked) do release(veh, info) end
end)
