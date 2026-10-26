# Dotfiles

Configs for my machines: a 4-monitor desktop and a laptop, both heading to
Hyprland with the [43PR](https://github.com/43PR/dotfiles) Quickshell desktop,
plus zsh/bash, tmux, Neovim, Doom Emacs and Ghostty.

## Layout

```
common/      shared by every machine
  bash/        .bashrc, .bash_configs (also sourced by zsh), .local example
  zsh/         .zshrc (43PR setup), .zprofile
  hypr/        Hyprland Lua config, hyprlock, helper scripts
  quickshell/  43PR bar, notifications, menus, wallpaper picker (customized)
  43pr/        43PR theme engine (presets + colors from wallpaper)
  ghostty/ foot/ tmux/ nvim/ doom/ starship/ rofi/ gtk-3.0/ gtk-4.0/ matugen/
hosts/<name>/  only what differs per machine
  desktop/     monitors + default workspaces, NVIDIA env, bar on DP-3,
               ghostty opacity, i3 fallback + quad.sh monitor script
  laptop/      eDP-1 monitors, brightness/xrandr helpers, ghostty opacity,
               i3 + i3blocks (current session until it moves to Hyprland)
archive/     superseded configs kept for reference (kitty, sway, waybar,
             the pre-Lua hyprlang config, old wallpapers)
docs/        fresh-machine setup, nvim -> Doom migration notes
misc/        things that aren't deployed (Vivado init script)
third_party/ licenses for vendored configs (43PR, MIT)
manifest     repo path -> live path table used by both scripts
```

## Deploy onto a machine

```bash
./install.sh desktop --dry-run   # see what would change
./install.sh desktop             # copy files into place
./install.sh laptop --link       # or symlink, so edits land in the repo
```

Anything replaced is backed up to `~/.dotfiles-backup/<timestamp>/` first.
For a fresh machine, install the packages in
[docs/hyprland-setup.md](docs/hyprland-setup.md) before deploying.

Private values (server addresses, license paths, hardware IDs) never go in
the repo: put them in `~/.bash_configs.local`, starting from
`common/bash/.bash_configs.local.example`.

## Back up changes from a machine

```bash
./snapshot.sh desktop            # shows each changed file's diff, y/N to take it
./snapshot.sh desktop --new      # also list live files the repo doesn't track
git diff                         # review, then commit
```

Files in `common/` are shared, so when a change only makes sense on one
machine, move those lines into `hosts/<name>/` instead of taking the file.

### Shell config load order

`~/.bashrc` / `~/.zshrc` → `~/.bash_configs` (shared aliases, functions, tool
environments) → `~/.bash_configs.host` (`hosts/<name>/bash/`) →
`~/.bash_configs.local` (private, untracked).
