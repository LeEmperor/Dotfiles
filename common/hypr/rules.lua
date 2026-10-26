-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- To check class name, open the app and run:
-- hyprctl clients

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Opacity rules for all windows except fullscreen
-- ($mod+O / scripts/opacity.sh rewrites the first "override" line below)
hl.window_rule({
    match = { class = ".*" },
    opacity = "0.9 override",
})

hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 override",
})

-- Ghostty does its own background transparency (background-opacity in its
-- config), which keeps text fully opaque; don't stack window opacity on top.
hl.window_rule({
    name = "ghostty-opaque",
    match = { class = "^(com\\.mitchellh\\.ghostty)$" },
    opacity = "1.0 override",
})

-- Wispr Flow's dictation pill ("Flow Status Indicator") is a transparent macOS-style
-- overlay that positions itself and asks to stay on top; Wayland ignores both, so
-- Hyprland would tile it and focus it, and the dictation paste (Ctrl+V) would land
-- in the pill instead of your app. Float it, never focus it, pin it to every
-- workspace, and park it bottom-centre with no decorations.
hl.window_rule({
    name = "wispr-status-pill",
    match = { class = "^(wispr-flow)$", title = "^(Flow Status Indicator|Status)$" },  -- retitles itself to "Status" once loaded
    float = true,
    pin = true,
    no_focus = true,
    no_initial_focus = true,
    border_size = 0,
    no_shadow = true,
    no_blur = true,
    no_anim = true,
    opacity = "1.0 override",
    move = "((monitor_w-window_w)*0.5) (monitor_h-window_h)",
})

-- Wispr's other overlays (context menu, accessibility drop panel) behave the same way
hl.window_rule({
    name = "wispr-overlays",
    match = { class = "^(wispr-flow)$", title = "^(Flow Context Menu|Accessibility)$" },
    float = true,
    no_focus = true,
    no_initial_focus = true,
    border_size = 0,
    no_shadow = true,
    no_blur = true,
    opacity = "1.0 override",
})

hl.window_rule({
    name = "file-picker-float",
    match = { class = "^(xdg-desktop-portal-gtk)$" },
    float = true,
    center = true,
    size = "900 600",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})
