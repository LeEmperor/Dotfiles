-- ~/.config/hypr/hyprland.lua
-- Wayne's i3-ported keybinds + the 43PR desktop (github.com/43PR/dotfiles).
-- Docs: https://wiki.hypr.land/Configuring/Start/
-- Previous hyprlang config: hyprland.conf.pre-43pr (ignored while this file exists)

---- MY PROGRAMS ----

mainMod     = "SUPER"
terminal    = "ghostty"
menu        = "rofi -show drun"
browser     = "brave-browser"

-- Overrides written by Quickshell (Settings > Configs): mainMod, browser.
-- Must load before keybinds.lua, which reads these globals when binding.
do
    local f = os.getenv("HOME") .. "/.config/quickshell/state/prefs.lua"
    local fh = io.open(f, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, f)
        if not ok then print("state/prefs.lua failed: " .. tostring(err)) end
    end
end

---- AUTOSTART ----

hl.on("hyprland.start", function()
    -- Hand the display to systemd/dbus services BEFORE anything can wake a portal.
    -- Otherwise xdg-desktop-portal-gtk starts without a display, fails, and every
    -- GTK app (ghostty) stalls ~2 min at login waiting on it.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
        .. " && systemctl --user reset-failed"
        .. " && systemctl --user restart xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-desktop-portal"
        .. " ; dex --autostart --environment Hyprland")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- wallpaper: awww (43PR picker, $mod+P) restores the last pick; swaybg if awww isn't installed
    hl.exec_cmd("if command -v awww-daemon >/dev/null; then awww-daemon & ~/.config/hypr/scripts/wallpaper-restore.sh;"
        .. " else swaybg -m fill -i ~/Pictures/Wallpapers/pink_galaxy.jpeg; fi")
    -- Wispr Flow dictation (hotkeys are set in the app; it reads /dev/input directly)
    hl.exec_cmd("sleep 2; wispr-flow")
    -- 43PR shell: bar, notifications, OSDs, power menu, settings
    hl.exec_cmd("sleep 2 && QSG_RENDER_LOOP=basic QS_ICON_THEME=Papirus qs")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Machine-specific settings (GPU env, etc.) live in host.lua, deployed from
-- hosts/<name>/hypr/host.lua in the dotfiles repo.
pcall(require, "host")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "us",
        kb_options = "caps:super",   -- caps lock acts as super (was setxkbmap under i3)
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

local f = os.getenv("HOME") .. "/.config/quickshell/state/devices.lua"
if io.open(f, "r") then dofile(f) end

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
do
    local f = os.getenv("HOME") .. "/.config/quickshell/state/look.lua"
    local fh = io.open(f, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, f)
        if not ok then print("state/look.lua failed: " .. tostring(err)) end
    end
end
require("rules")
