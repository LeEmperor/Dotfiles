# Hyprland + 43PR desktop: fresh-machine setup

The configs in `common/` assume these programs are installed. Written for
**Ubuntu 26.04**; the desktop was set up this way in October 2026.

## 1. Hyprland (PPA)

Ubuntu 26.04 ships Hyprland 0.53, which is too old for the Lua config. The
cppiber PPA has 0.56.x:

```bash
sudo add-apt-repository ppa:cppiber/hyprland
sudo apt install hyprland xdg-desktop-portal-hyprland hyprlock hyprpolkitagent
```

The config is Lua (`~/.config/hypr/hyprland.lua`). Check it with
`Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`.

## 2. Runtime tools

```bash
sudo apt install \
  rofi cliphist playerctl brightnessctl lm-sensors gammastep libnotify-bin \
  imagemagick zenity papirus-icon-theme fonts-jetbrains-mono fonts-iosevka \
  power-profiles-daemon grim slurp wl-clipboard swaybg jq foot \
  zsh zsh-autosuggestions zsh-syntax-highlighting eza starship
```

Nerd Fonts aren't packaged; install JetBrainsMono, NerdFontsSymbolsOnly and
Iosevka from https://github.com/ryanoasis/nerd-fonts/releases into
`~/.local/share/fonts/NerdFonts/`, then `fc-cache -f`.

## 3. Quickshell (bar, notifications, menus) — build from source

Not packaged. **Rebuild after any Qt version change** (it uses private Qt APIs).

```bash
sudo apt install build-essential cmake ninja-build pkg-config git \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
  qt6-shadertools-dev qt6-svg-dev qt6-wayland qt6-svg-plugins \
  libcli11-dev libjemalloc-dev libpipewire-0.3-dev libpam0g-dev \
  libpolkit-agent-1-dev libpolkit-gobject-1-dev libglib2.0-dev libdrm-dev libgbm-dev \
  libvulkan-dev libwayland-dev libwayland-bin wayland-protocols spirv-tools libxcb1-dev \
  libunwind-dev libdwarf-dev libegl-dev \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-effects \
  qml6-module-qtquick-shapes qml6-module-qtquick-layouts qml6-module-qt-labs-folderlistmodel \
  qml6-module-qtqml-workerscript qml6-module-qtquick-templates qml6-module-qtquick-window

git clone --depth 1 --branch v0.3.2 https://github.com/quickshell-mirror/quickshell.git ~/devel/quickshell
cd ~/devel/quickshell
cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=$HOME/.local \
  -DDISTRIBUTOR="Self-built (Ubuntu)" -DVENDOR_CPPTRACE=ON
cmake --build build && cmake --install build
```

## 4. Wallpaper picker + colors from wallpaper

```bash
sudo apt install cargo liblz4-dev
git clone --depth 1 --branch v0.12.1 https://codeberg.org/LGFae/awww.git ~/devel/awww
cd ~/devel/awww && cargo build --release
install -m755 target/release/awww target/release/awww-daemon ~/.local/bin/
cargo install --locked matugen@4.2.0 --root ~/.local
```

Wallpapers go in `~/Pictures/Wallpapers/` (`$mod+P` opens the picker).

## 5. zsh plugin not in apt

```bash
git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git \
  ~/.local/share/zsh/plugins/zsh-autocomplete
chsh -s /bin/zsh
```

## 6. Deploy

```bash
./install.sh <host>          # desktop | laptop
```

Then create `~/.bash_configs.local` from `common/bash/.bash_configs.local.example`.

## Known gotchas (all handled in the configs, noted for debugging)

- **Slow GTK apps at login**: the portal must get `WAYLAND_DISPLAY` before it
  starts. `hyprland.lua` imports the environment and restarts the portals first.
- **NVIDIA**: GPU env vars are in `hosts/desktop/hypr/host.lua` only.
- **Ghostty transparency**: the 43PR `gtk.css` targets `window.background`, not
  bare `window`, so transparent windows stay see-through.
- **Wispr Flow**: its dictation pill ("Flow Status Indicator", retitled "Status")
  needs the no-focus rule in `rules.lua` or pastes land in the pill.
- **Lua config**: `hl.dsp.window.resize({x, y})` is absolute unless `relative = true`.
- **Quickshell**: edits to singletons like `Marquee.qml` need a full `qs` restart.
