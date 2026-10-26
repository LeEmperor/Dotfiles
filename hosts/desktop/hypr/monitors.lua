-- monitors.lua
-- https://wiki.hypr.land/Configuring/Monitors/
-- 4 across, left to right (was ~/.screenlayout/quad.sh under i3).
-- X names HDMI-0, DP-0, DP-2, DP-4 are HDMI-A-1, DP-1, DP-2, DP-3 on Wayland.
-- Check with `hyprctl monitors`. All four support 100Hz: change @60 to @100 to use it.

hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",     mode = "2560x1440@60", position = "2560x0", scale = 1 })
hl.monitor({ output = "DP-2",     mode = "2560x1440@60", position = "5120x0", scale = 1 })
hl.monitor({ output = "DP-3",     mode = "2560x1440@60", position = "7680x0", scale = 1 })
hl.monitor({ output = "",         mode = "preferred",    position = "auto",   scale = 1 })

-- Default workspace per monitor at login. Workspaces 1-4 open on these monitors
-- whenever they're created; 5-10 open on whichever monitor is focused.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1",     default = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-3",     default = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-2",     default = true })

-- Overrides written by Quickshell (Settings > Display)
pcall(function()
    local path = os.getenv("HOME") .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end)
