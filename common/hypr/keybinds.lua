-- ~/.config/hypr/keybinds.lua
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/
--
-- The i3-ported binds come first and win every conflict; 43PR binds are added
-- only on keys that were free. 43PR's Settings > Keybinds page is not wired
-- up here (state/binds.lua is not loaded).

-- A single bad key string must not take the rest of the config down with it.
local function bind(keys, ...)
    local ok, err = pcall(hl.bind, keys, ...)
    if not ok then
        print("keybinds.lua: skipped bind '" .. tostring(keys) .. "': " .. tostring(err))
    end
end

local mod  = mainMod
local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"

-------------------------------------------------------------------------------
-- i3-style "tabbed" workspaces via the monocle layout
-- $mod+w/s toggle the current workspace between dwindle and monocle,
-- $mod+h/l cycle windows while in monocle, $mod+e goes back to split.
-- These are runtime workspace rules, so a config reload resets them.
-------------------------------------------------------------------------------

local function set_layout(ws, layout)
    hl.workspace_rule({ workspace = tostring(ws.id), layout = layout })
end

local function tabbed_toggle()
    local ws = hl.get_active_workspace()
    if ws then set_layout(ws, ws.tiled_layout == "monocle" and "dwindle" or "monocle") end
end

local function split_toggle()
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "monocle" then
        set_layout(ws, "dwindle")
    else
        hl.dispatch(hl.dsp.layout("togglesplit"))
    end
end

local function focus_lr(dir)
    return function()
        local ws = hl.get_active_workspace()
        if ws and ws.tiled_layout == "monocle" then
            hl.dispatch(hl.dsp.window.cycle_next({ next = dir == "right", tiled = true }))
        else
            hl.dispatch(hl.dsp.focus({ direction = dir }))
        end
    end
end

-------------------------------------------------------------------------------
-- i3-ported binds
-------------------------------------------------------------------------------

bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
bind(mod .. " + D", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu))

-- drag floating windows with $mod+left mouse, resize with $mod+right mouse
bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- change focus
bind(mod .. " + H", focus_lr("left"))
bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
bind(mod .. " + L", focus_lr("right"))
bind(mod .. " + Left",  focus_lr("left"))
bind(mod .. " + Down",  hl.dsp.focus({ direction = "down" }))
bind(mod .. " + Up",    hl.dsp.focus({ direction = "up" }))
bind(mod .. " + Right", focus_lr("right"))

-- move focused window (same shifted j/k/l/; layout as the i3 config)
bind(mod .. " + SHIFT + J",         hl.dsp.window.move({ direction = "left" }))
bind(mod .. " + SHIFT + K",         hl.dsp.window.move({ direction = "down" }))
bind(mod .. " + SHIFT + L",         hl.dsp.window.move({ direction = "up" }))
bind(mod .. " + SHIFT + semicolon", hl.dsp.window.move({ direction = "right" }))
bind(mod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "left" }))
bind(mod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "down" }))
bind(mod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "up" }))
bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))

-- split h / split v: choose where the NEXT window opens
bind(mod .. " + B", hl.dsp.layout("preselect r"))
bind(mod .. " + V", hl.dsp.layout("preselect d"))
-- layout toggle split (from tabbed, goes back to split like i3)
bind(mod .. " + E", split_toggle)

bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- tabbed/stacked -> monocle (see above)
bind(mod .. " + W", tabbed_toggle)
bind(mod .. " + S", tabbed_toggle)

-- toggle floating; a newly floated window is centred at 70% of the monitor (43PR)
bind(mod .. " + SHIFT + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7)
            local target_h = math.floor(mon.height * 0.7)
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))
            local target_x = (mon.x or 0) + math.floor((mon.width - target_w) / 2)
            local target_y = (mon.y or 0) + math.floor((mon.height - target_h) / 2)
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)
-- focus mode_toggle (tiling <-> floating) has no direct equivalent; cycle windows instead
bind(mod .. " + Space", hl.dsp.window.cycle_next())

-- workspaces; moving a window doesn't follow it, like i3
for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
end

-- reload / "restart" (both just reload; saving a config file also reloads)
-- shows a toast so you know it happened; config errors still show Hyprland's red error bar
local reload = "hyprctl reload && hyprctl notify 5 1500 'rgb(ffffff)' 'Config reloaded'"
bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(reload))
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(reload))

-- exit: 43PR power menu (logout / reboot / shutdown / lock)
bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("qs ipc call powermenu toggle"))

-- lock screen: 43PR hyprlock
bind(mod .. " + SHIFT + X", hl.dsp.exec_cmd("hyprlock"))

-- region screenshot: 43PR script (~/Pictures/Screenshots, clipboard, on-screen preview)
bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(scripts .. "/screenshot-area.sh"))

-- volume / mic
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-"), { locked = true, repeating = true })
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- resizing (like tmux)
bind(mod .. " + CTRL + Right", hl.dsp.window.resize({ x = 100,  y = 0,    relative = true }), { repeating = true })
bind(mod .. " + CTRL + Left",  hl.dsp.window.resize({ x = -100, y = 0,    relative = true }), { repeating = true })
bind(mod .. " + CTRL + Up",    hl.dsp.window.resize({ x = 0,    y = -100, relative = true }), { repeating = true })
bind(mod .. " + CTRL + Down",  hl.dsp.window.resize({ x = 0,    y = 100,  relative = true }), { repeating = true })

-- resize mode ($mod+r, then j/k/l/; or arrows; Enter/Escape/$mod+r to leave)
bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local function grow(x, y) return hl.dsp.window.resize({ x = x, y = y, relative = true }) end
    bind("J",         grow(-100, 0),  { repeating = true })
    bind("K",         grow(0, 100),   { repeating = true })
    bind("L",         grow(0, -100),  { repeating = true })
    bind("semicolon", grow(100, 0),   { repeating = true })
    bind("Left",      grow(-100, 0),  { repeating = true })
    bind("Down",      grow(0, 100),   { repeating = true })
    bind("Up",        grow(0, -100),  { repeating = true })
    bind("Right",     grow(100, 0),   { repeating = true })
    bind("Return",    hl.dsp.submap("reset"))
    bind("Escape",    hl.dsp.submap("reset"))
    bind(mod .. " + R", hl.dsp.submap("reset"))
end)

-------------------------------------------------------------------------------
-- 43PR binds (only on keys the i3 binds don't use)
-------------------------------------------------------------------------------

bind(mod .. " + T",         hl.dsp.exec_cmd(terminal))
bind(mod .. " + I",         hl.dsp.exec_cmd("qs ipc call settings toggle"))
bind(mod .. " + N",         hl.dsp.exec_cmd("qs ipc call notifications toggle"))
bind(mod .. " + C",         hl.dsp.exec_cmd("qs ipc call todo toggle"))
bind(mod .. " + GRAVE",     hl.dsp.exec_cmd("qs ipc call powermenu toggle"))
bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call bar toggle"))
bind(mod .. " + Tab",       hl.dsp.exec_cmd("hyprlock"))
bind(mod .. " + O",         hl.dsp.exec_cmd(scripts .. "/opacity.sh"))
-- "identify": flash each monitor's workspace number for ~2s
bind(mod .. " + A",         hl.dsp.exec_cmd("pgrep -f '^qs -p .*ws-identify' >/dev/null || qs -p " .. scripts .. "/ws-identify.qml"))
bind(mod .. " + period",    hl.dsp.exec_cmd("python3 " .. home .. "/.config/43pr/bin/theme.py toggle"))
-- wallpaper picker (43PR uses $mod+W, which is tabbed mode here); images in ~/Pictures/Wallpapers
bind(mod .. " + P",         hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))
-- clipboard history (43PR uses $mod+V, which is split-vertical here)
bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy"))

-- full-screen / area screenshots
bind("Delete", hl.dsp.exec_cmd("sh -c 'mkdir -p " .. home .. "/Pictures/Screenshots; file=" .. home .. "/Pictures/Screenshots/$(date +%F_%H-%M-%S).png; grim \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'"))
bind("SHIFT + Delete", hl.dsp.exec_cmd(scripts .. "/screenshot-area.sh"))

-- move window left (the i3 layout has no $mod+Shift+H)
bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))

-- resize with vim keys
bind(mod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0,  relative = true }), { repeating = true })
bind(mod .. " + CTRL + L", hl.dsp.window.resize({ x = 40,  y = 0,  relative = true }), { repeating = true })
bind(mod .. " + CTRL + K", hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true })
bind(mod .. " + CTRL + J", hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true })

-- zoom with $mod+scroll / $mod+keypad -/+
local function zoom(delta)
    return function()
        local z = hl.get_config("cursor:zoom_factor") + delta
        hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(1.5, z)) } })
    end
end
bind(mod .. " + mouse_down", zoom(-0.5), { repeating = true })
bind(mod .. " + mouse_up",   zoom(0.5),  { repeating = true })
bind(mod .. " + code:82",    zoom(-0.3), { repeating = true })
bind(mod .. " + code:86",    zoom(0.3),  { repeating = true })

-- media / brightness keys
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
