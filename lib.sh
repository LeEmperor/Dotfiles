# Shared helpers for install.sh and snapshot.sh (sourced, not run).

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

check_host() {
    [[ -n ${1:-} ]] || die "usage: $(basename "$0") <host> [options]   (hosts: $(ls "$REPO/hosts" | tr '\n' ' '))"
    [[ -d $REPO/hosts/$1 ]] || die "unknown host '$1' (hosts: $(ls "$REPO/hosts" | tr '\n' ' '))"
}

# Print "repo_file<TAB>live_file" for every file the manifest maps for host $1.
# Directory entries expand to the files currently in the repo directory.
mapped_files() {
    local host=$1 src dst rel
    while read -r src dst; do
        [[ -z $src || $src == \#* ]] && continue
        src=${src//@/$host}
        dst=${dst/#\~/$HOME}
        if [[ $src == */ ]]; then
            [[ -d $REPO/$src ]] || continue
            while IFS= read -r -d '' f; do
                rel=${f#"$REPO/$src"}
                printf '%s\t%s\n' "$f" "$dst$rel"
            done < <(find "$REPO/$src" -type f -print0 | sort -z)
        else
            [[ -f $REPO/$src ]] || continue
            printf '%s\t%s\n' "$REPO/$src" "$dst"
        fi
    done < "$REPO/manifest"
}
