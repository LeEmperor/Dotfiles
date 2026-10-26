#!/usr/bin/env bash
# Deploy the dotfiles onto this machine.
#
#   ./install.sh <host> [--dry-run] [--link] [--no-theme]
#
#   <host>      a folder under hosts/ (desktop, laptop)
#   --dry-run   show what would change, touch nothing
#   --link      symlink files into the repo instead of copying them
#               (edits then land in the repo directly; default is copy)
#   --no-theme  skip generating 43PR theme colors (theme.py also sets the
#               desktop-wide GTK theme/icons via gsettings)
#
# Live files that would be replaced are backed up first to
# ~/.dotfiles-backup/<timestamp>/<same path>. Files already identical are skipped.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

host=${1:-}; check_host "$host"; shift
dry=0; link=0; theme=1
for a in "$@"; do
    case $a in
        --dry-run) dry=1 ;;
        --link) link=1 ;;
        --no-theme) theme=0 ;;
        *) die "unknown option: $a" ;;
    esac
done

backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
changed=0 same=0

up_to_date() {   # $1 repo file, $2 live path
    if [[ $link == 1 ]]; then
        [[ -L $2 && $(readlink -f "$2") == "$1" ]]
    else
        [[ -f $2 && ! -L $2 ]] && cmp -s "$1" "$2"
    fi
}

while IFS=$'\t' read -r src dst; do
    if up_to_date "$src" "$dst"; then
        same=$((same + 1)); continue
    fi
    changed=$((changed + 1))
    if [[ -e $dst || -L $dst ]]; then
        printf 'update  %s\n' "${dst/#$HOME/\~}"
    else
        printf 'new     %s\n' "${dst/#$HOME/\~}"
    fi
    [[ $dry == 1 ]] && continue
    if [[ -e $dst || -L $dst ]]; then
        mkdir -p "$backup/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$backup/${dst#$HOME/}"
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ $link == 1 ]]; then ln -s "$src" "$dst"; else cp -p "$src" "$dst"; fi
done < <(mapped_files "$host")

printf '\n%d file(s) %s, %d already up to date.\n' "$changed" \
    "$([[ $dry == 1 ]] && echo 'would change' || echo 'changed')" "$same"
[[ $dry == 0 && -d $backup ]] && printf 'Replaced files backed up to %s\n' "${backup/#$HOME/\~}"

# Theme files (hypr/colors.lua, rofi/colors.rasi, hyprlock colors, GTK colors.css)
# are generated, not tracked: render them from the current palette.
if [[ $dry == 0 && $theme == 1 && -x $HOME/.config/43pr/bin/theme.py ]] && command -v python3 >/dev/null; then
    python3 "$HOME/.config/43pr/bin/theme.py" apply >/dev/null 2>&1 \
        && echo 'Generated 43PR theme colors.' \
        || echo 'note: theme.py apply failed; run it once Hyprland is running.'
fi

[[ $dry == 0 ]] && echo 'Private values go in ~/.bash_configs.local (see common/bash/.bash_configs.local.example).'
[[ $dry == 0 ]] && echo 'Fresh machine? Packages and builds are in docs/hyprland-setup.md.'
exit 0
