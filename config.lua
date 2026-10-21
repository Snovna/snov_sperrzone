Config = {}

Config.ClearPeds = false -- Clear NPCs in the zone
Config.ClearVehicles = true -- Clear vehicles in the zone

Config.allowedJobs = {'police','sheriff','ambulance'}
Config.redZoneJobs = {'police','sheriff'} -- Jobs which default to a red zone

Config.BlockTraffic = true -- Every zone blocks NPC traffic (road nodes off, speed zone, NPC cars kept out). false = off
Config.TrafficBoxHeight = 30.0 -- Road nodes are switched off from zone height - this to zone height + this
Config.TrafficNetworked = true -- Network flag of SetRoadsInArea (falls back to local switching if the call fails)
Config.TrafficEnforceRange = 200.0 -- Zones further away from the player (beyond radius + this) are not enforced
Config.TrafficApproach = 25.0 -- Width of the approach ring around the zone
Config.TrafficApproachSpeed = 5.0 -- Speed cap (m/s) for NPC cars in the approach ring heading for the zone
Config.TrafficDeleteAfter = 4000 -- ms an NPC car may stay inside a zone before it is deleted
