-- monitors.lua (laptop)
-- https://wiki.hypr.land/Configuring/Monitors/
-- Built-in panel first, anything plugged in extends to the right.
-- Check names with `hyprctl monitors` once Hyprland is running here.

hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0",  scale = 1 })
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = 1 })

-- Overrides written by Quickshell (Settings > Display)
pcall(function()
    local path = os.getenv("HOME") .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end)
