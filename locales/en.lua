local Translations = {
    notify = {
        ['no_vehicle'] = 'You are not in or near a vehicle you can control',
        ['no_permission'] = 'Only the driver can do that',
        ['seat_taken'] = 'That seat is taken',
        ['out_of_range'] = 'Vehicle is out of keyfob range',
        ['no_keys'] = 'You do not have keys for this vehicle',
        ['cruise_on'] = 'Cruise control set to %{speed} %{unit}',
        ['cruise_off'] = 'Cruise control off',
        ['cruise_slow'] = 'Too slow to engage cruise control',
        ['cruise_fuel'] = 'Fuel too low for cruise control',
        ['limiter_on'] = 'Speed limiter set to %{speed} %{unit}',
        ['limiter_off'] = 'Speed limiter off',
        ['launch_armed'] = 'Launch control armed - hold brake + throttle, then release the brake',
        ['launch_go'] = 'Launch!',
        ['mode'] = 'Drive mode: %{mode}',
        ['tcs_off'] = 'Traction control OFF',
        ['tcs_on'] = 'Traction control ON',
        ['locked'] = 'Vehicle locked',
        ['unlocked'] = 'Vehicle unlocked',
        ['no_neon'] = 'This vehicle has no neon kit installed',
        ['need_item'] = 'You need a %{item} for this',
    },
    keymap = {
        ['open'] = 'Open vehicle menu',
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
