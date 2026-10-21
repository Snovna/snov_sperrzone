# snov_sperrzone

_Stand: 2026-10-21 21:10_

Restricted zone management system for FiveM. Authorized players can create, edit, and remove temporary zones displayed as radius blips on the map. Supports three zone types: restricted zones (red), hazard areas (yellow), and public events (blue).

## Features

- Create, edit, and delete zones via context menu
- Three zone types with distinct colors and notifications
- Map radius blips visible to all players
- Server-wide notifications with sound effects on zone changes
- Job-based access control for zone management
- NPC traffic blocking: every zone closes its roads for NPC traffic (re-route + stop at the edge), player vehicles are never touched
- Optional automatic clearing of NPCs and vehicles inside zones
- Street name auto-detection when creating a zone
- Automatic version check

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [es_extended (ESX)](https://github.com/esx-framework/esx_core)

## Installation

1. Place `snov_sperrzone` in your resources folder.
2. Add `ensure snov_sperrzone` to your `server.cfg`.
3. Configure allowed jobs in `config.lua`.

## Configuration

Edit `config.lua` to set allowed jobs and zone behavior:

```lua
Config.ClearPeds = false        -- Remove NPCs inside zones
Config.ClearVehicles = true     -- Remove vehicles inside zones
Config.allowedJobs = {'police', 'sheriff', 'ambulance'}
Config.redZoneJobs = {'police', 'sheriff'} -- Jobs that default to red zone type

Config.BlockTraffic = true         -- NPC traffic blocking for every zone, false = off
Config.TrafficBoxHeight = 30.0     -- Road nodes are switched off within zone height +/- this
Config.TrafficNetworked = true     -- Network flag of SetRoadsInArea
Config.TrafficEnforceRange = 200.0 -- Zones further than radius + this from the player are not enforced
Config.TrafficApproach = 25.0      -- Width of the approach ring around the zone
Config.TrafficApproachSpeed = 5.0  -- Speed cap (m/s) in the approach ring
Config.TrafficDeleteAfter = 4000   -- ms an NPC car may stay inside before it is deleted
```

## NPC traffic blocking

Every zone blocks NPC traffic while it exists; there is no per-zone option, only the global switch `Config.BlockTraffic`. Ambient traffic is simulated by whichever client owns it, so every client applies every zone (on create, on update, on delete, and for zones that already exist when a player joins).

- **Re-route:** `SetRoadsInArea` switches off the road nodes in the axis-aligned box around the zone circle (center x/y +/- radius, zone height +/- `Config.TrafficBoxHeight`). NPCs plan their routes around it. The box corners reach past the circle, so roads just outside the circle near the diagonal corners are closed too (up to about 0.41 x radius beyond the edge). With the network flag (`Config.TrafficNetworked`); if that call fails the client falls back to local switching and says so in F8.
- **Stop at the edge:** one road node speed zone (0 m/s, radius + 15 m) stops cars that are already on their way in.
- **Enforcement:** every 250 ms, for zones within radius + `Config.TrafficEnforceRange` of the player, each client checks the ambient NPC cars it controls (population types 2-5, not mission entities, no player in any seat, not last driven by a player). A car in the approach ring (radius to radius + `Config.TrafficApproach`) that moves toward the center gets a fresh wander task (it plans over active nodes only) and is capped to `Config.TrafficApproachSpeed`. A car inside the circle without a driver is deleted at once; with a driver it is deleted (with its occupants) after `Config.TrafficDeleteAfter`. The speed cap is lifted when a car leaves.
- **Self-check:** if the node nearest the zone center lies inside the circle but is still active after applying, F8 shows a warning (would mean the native parameters are wrong).
- **Restore:** deleting a zone, editing it (old area first, then the new one) or stopping the resource calls `SetRoadsBackToOriginal` and `RemoveRoadNodeSpeedZone`; remaining overlapping zones are re-applied.
- **NPCs only:** player vehicles, vehicles last driven by a player and mission entities (e.g. job or script vehicles) are never touched. `Config.ClearVehicles` (`ClearAreaOfVehicles` every 5 s) runs alongside unchanged.

## Usage

Use the `/sperrzone` command in-game to open the management menu.
