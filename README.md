# snov_sperrzone

Restricted zone management system for FiveM. Authorized players can create, edit, and remove temporary zones displayed as radius blips on the map. Supports three zone types: restricted zones (red), hazard areas (yellow), and public events (blue).

## Features

- Create, edit, and delete zones via context menu
- Three zone types with distinct colors and notifications
- Map radius blips visible to all players
- Server-wide notifications with sound effects on zone changes
- Job-based access control for zone management
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
```

## Usage

Use the `/sperrzone` command in-game to open the management menu.
