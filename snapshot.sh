#!/usr/bin/env bash
# Copy this machine's live configs back into the repo.
#
#   ./snapshot.sh <host> [--yes] [--new]
#
#   <host>   a folder under hosts/ (desktop, laptop)
#   --yes    take every changed file without asking
#   --new    also list live files in mapped directories that the repo doesn't track
#
# Only files the repo already tracks are compared (via the manifest). For each
# one that differs you see the diff and choose: y = take the live version,
# n = skip, q = stop. Shared files (common/) affect every machine, so read the
# diff before taking one: machine-specific lines belong in hosts/<host>/.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

host=${1:-}; check_host "$host"; shift
yes=0; new=0
for a in "$@"; do
    case $a in
        --yes) yes=1 ;;
        --new) new=1 ;;
        *) die "unknown option: $a" ;;
    esac
done

taken=0 skipped=0
while IFS=$'\t' read -r -u 3 src dst; do
    [[ -f $dst ]] || continue
    cmp -s "$src" "$dst" && continue
    rel=${src#"$REPO/"}
    if [[ $yes == 0 ]]; then
        printf '\n\033[1m=== %s  <-  %s\033[0m\n' "$rel" "${dst/#$HOME/\~}"
        diff -u --label "repo: $rel" --label "live" "$src" "$dst" | head -60 || true
        read -r -p "take live version? [y/N/q] " ans || ans=q
        case $ans in
            y|Y) ;;
            q|Q) break ;;
            *) skipped=$((skipped + 1)); continue ;;
        esac
    fi
    cp -p "$dst" "$src"
    taken=$((taken + 1))
    printf 'took    %s\n' "$rel"
done 3< <(mapped_files "$host")

printf '\n%d file(s) updated in the repo, %d skipped.\n' "$taken" "$skipped"

if [[ $new == 1 ]]; then
    echo 'Untracked live files in mapped directories (add them to the repo by hand if wanted):'
    while read -r s d; do
        [[ -z $s || $s == \#* || $s != */ ]] && continue
        s=${s//@/$host}; d=${d/#\~/$HOME}
        [[ -d $d ]] || continue
        while IFS= read -r -d '' f; do
            rel=${f#"$d"}
            [[ -e $REPO/common/${s#common/}$rel || -e $REPO/$s$rel ]] && continue
            # skip generated and runtime files
            case $rel in colors.lua|hyprlock-colors.conf|colors.rasi|colors.css|state/*|*.orig|*.pre-*) continue ;; esac
            printf '  %s\n' "${f/#$HOME/\~}"
        done < <(find "$d" -maxdepth 3 -type f -print0 | sort -z)
    done < "$REPO/manifest" | sort -u
fi
echo 'Review with: git -C "'"$REPO"'" diff'
