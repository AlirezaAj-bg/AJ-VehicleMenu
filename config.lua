Config = {}

-- ---------------------------------------------------------------------------
--  Opening
-- ---------------------------------------------------------------------------
Config.Command = 'vehmenu'
Config.Keybind = 'K'              -- players can rebind in GTA Settings > Key Bindings > FiveM
Config.KeepInput = true           -- true = keep driving while the menu is open (camera/attack controls are blocked)

-- ---------------------------------------------------------------------------
--  Units & refresh
-- ---------------------------------------------------------------------------
Config.SpeedUnit = 'kmh'          -- 'kmh' or 'mph'
Config.RefreshRate = 150          -- ms between live-stat updates while the menu is open
Config.Debug = true              -- true = server prints why a request was rejected (F8 / server console)

-- ---------------------------------------------------------------------------
--  Remote / keyfob mode (on foot, near a vehicle you have keys for)
-- ---------------------------------------------------------------------------
Config.Remote = {
    enabled = true,
    range = 25.0,                 -- metres
    lockSound = 'lock',           -- interact-sound file name
}

-- ---------------------------------------------------------------------------
--  Driving tools (driver only, applied locally)
-- ---------------------------------------------------------------------------
Config.UseOwnCruise = true        -- false = the Cruise tile just runs qb-smallresources' /togglecruise
Config.CruiseStep = 5             -- +/- step in Config.SpeedUnit
Config.CruiseMinSpeed = 20        -- cannot engage below this (Config.SpeedUnit)
Config.CruiseMinFuel = 10         -- same rule as qb-smallresources cruise

Config.Limiter = { min = 20, max = 250, default = 80 }

Config.DriveModes = {
    { id = 'eco',     label = 'Eco',     power = 0.75, torque = 0.85 },
    { id = 'comfort', label = 'Comfort', power = 1.0,  torque = 1.0 },
    { id = 'sport',   label = 'Sport',   power = 1.25, torque = 1.2 },
}
Config.DefaultDriveMode = 'comfort'

-- Items required for the driving tools. Set any of them to false to make that tool free.
-- The item names must exist in qb-core/shared/items.lua (the three defaults below are added there).
Config.Items = {
    driveMode = 'drivemode_ecu',  -- needed to switch to any drive mode other than Config.DefaultDriveMode
    launch = 'launch_module',     -- needed to arm launch control
    tcs = 'tcs_module',           -- needed to turn traction control OFF (turning it back on is always allowed)
}

Config.Launch = {
    boostPower = 1.8,             -- power multiplier right after launch
    boostTime = 2500,             -- ms
}

-- Vehicle classes the driving tools are hidden for (13 cycles, 14 boats, 15 helis, 16 planes, 21 trains)
Config.NoDrivingToolsClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

-- ---------------------------------------------------------------------------
--  Lighting
-- ---------------------------------------------------------------------------
Config.RequireNeonKit = false     -- true = neon tiles only work if the vehicle has any neon already installed
Config.AllowXenonToggle = true    -- lets the driver toggle xenon headlights (vehicle mod 22)

-- ---------------------------------------------------------------------------
--  Permissions
--  Driver = everything. Passenger / remote = only what's listed here.
--  Every action is re-checked on the server for synced controls.
-- ---------------------------------------------------------------------------
Config.PassengerAllowed = {
    seat = true,
    window = 'own',               -- 'own' = only the window next to their seat, true = all, false = none
    cabin = true,
}

Config.RemoteAllowed = {
    lock = true, remoteEngine = true, flash = true, horn = true, alarm = true,
    door = true, doorsAll = true, window = true, windowsAll = true,
    neon = true, neonAll = true,
}
