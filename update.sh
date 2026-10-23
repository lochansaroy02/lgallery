#!/usr/bin/env bash
# Update LGallery: pull the latest commits and refresh the installed app.
#
#   ./update.sh              pull + update whatever is installed (user install or Arch package)
#   ./update.sh --no-pull    only refresh the installed app from the current checkout
#   ./update.sh --install    also install the launcher if nothing is installed yet
#   ./update.sh --restart    restart Gallery afterwards if it is running
#
# Your settings, library index, favorites and saved originals live outside this folder
# (~/.config/lgallery, ~/.local/share/lgallery) and are never touched by an update.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

pull=1 install=0 restart=0
old=""
for arg in "$@"; do
    case "$arg" in
        --no-pull) pull=0 ;;
        --install) install=1 ;;
        --restart) restart=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# ---- 1. pull --------------------------------------------------------------------------------
if [[ $pull -eq 1 ]]; then
    bold "Updating the source code"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "$here is not a git checkout"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        git status --short --untracked-files=no
        fail "you have local changes to the files above. Commit them, or run 'git stash', then try again."
    fi
    branch="$(git rev-parse --abbrev-ref HEAD)"
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
        || fail "branch '$branch' has no upstream (run: git branch -u origin/$branch)"
    old="$(git rev-parse HEAD)"
    git fetch --quiet || fail "could not reach the git remote (offline?)"
    if [[ "$(git rev-parse HEAD)" == "$(git rev-parse "$upstream")" ]]; then
        info "Already up to date ($(git log -1 --format='%h %s'))."
    else
        git merge --ff-only --quiet "$upstream" \
            || fail "your branch and $upstream have diverged; resolve it with 'git pull --rebase'"
        info "Updated $(git rev-parse --short "$old") → $(git rev-parse --short HEAD):"
        git log --format='    • %s' "$old..HEAD"
    fi
    changed() { [[ "$old" != "$(git rev-parse HEAD)" ]] && ! git diff --quiet "$old" HEAD -- "$@"; }
else
    changed() { return 0; }
fi

# ---- 2. what is installed? ------------------------------------------------------------------
data="${XDG_DATA_HOME:-$HOME/.local/share}"
user_launcher="$HOME/.local/bin/lgallery"
mode=none
if command -v pacman >/dev/null 2>&1 && pacman -Q lgallery >/dev/null 2>&1; then
    mode=package
elif [[ -f "$user_launcher" ]] && grep -q "$here/main.py" "$user_launcher" 2>/dev/null; then
    mode=user
elif [[ -f "$user_launcher" ]]; then
    mode=user-other   # installed from a different checkout (folder moved or renamed)
fi

# ---- 3. python environment (source / user installs) -----------------------------------------
ensure_venv() {
    local py="$here/.venv/bin/python"
    if [[ -x "$py" ]] && "$py" -c 'import PySide6, PIL' >/dev/null 2>&1; then
        if changed requirements.txt; then
            bold "Updating Python packages"
            "$py" -m pip install --quiet --disable-pip-version-check -r requirements.txt
        fi
        return
    fi
    bold "Setting up the Python environment (.venv)"
    local system_site=""
    if [[ -f "$here/.venv/pyvenv.cfg" ]] && grep -qi 'include-system-site-packages *= *true' "$here/.venv/pyvenv.cfg"; then
        system_site="--system-site-packages"   # keep using pacman's pyside6 if that was the setup
    fi
    [[ -d "$here/.venv" ]] && info "The old .venv no longer works (Python was probably upgraded); recreating it."
    rm -rf "$here/.venv"
    python3 -m venv $system_site "$here/.venv"
    "$here/.venv/bin/python" -m pip install --quiet --disable-pip-version-check -r requirements.txt
}

check_imports() {
    if ! "$1" -c "import sys; sys.path.insert(0, sys.argv[1]); import backend.controller, backend.editor, backend.external" "$here"; then
        if [[ -n "$old" ]]; then
            fail "the new version does not start (see above). Go back with: git checkout ${old:0:8} && ./update.sh --no-pull"
        fi
        fail "the code does not start (see above)."
    fi
}

# ---- 4. update the installed app --------------------------------------------------------------
case "$mode" in
    package)
        bold "Rebuilding the Arch package (you may be asked for your password)"
        check_imports /usr/bin/python3
        ( cd "$here/packaging" && makepkg -sif --noconfirm -c )
        rm -f "$here"/packaging/lgallery-*.pkg.tar.*
        ;;
    user)
        ensure_venv
        check_imports "$here/.venv/bin/python"
        bold "Refreshing the launcher, menu entry and icon"
        "$here/packaging/install-user.sh" >/dev/null
        info "Done."
        ;;
    user-other)
        ensure_venv
        check_imports "$here/.venv/bin/python"
        bold "Your launcher points to another folder; switching it to this checkout"
        info "was: $(grep -o '"[^"]*main.py"' "$user_launcher" | head -1)"
        "$here/packaging/install-user.sh" >/dev/null
        info "now: $here/main.py"
        ;;
    none)
        ensure_venv
        check_imports "$here/.venv/bin/python"
        if [[ $install -eq 1 ]]; then
            bold "Installing the launcher"
            "$here/packaging/install-user.sh"
        else
            bold "Gallery is not installed as an app"
            info "Run it with: $here/.venv/bin/python $here/main.py"
            info "Or install it into the app launcher: ./update.sh --install"
        fi
        ;;
esac

# ---- 5. running instance ----------------------------------------------------------------------
escape() { printf '%s' "$1" | sed 's/[][\.*^$()+?{}|]/\\&/g'; }
pids="$(pgrep -f -- "$(escape "$here/main.py")|/usr/share/lgallery/main\.py" 2>/dev/null || true)"
if [[ -n "$pids" ]]; then
    if [[ $restart -eq 1 ]]; then
        bold "Restarting Gallery"
        kill $pids 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            kill -0 $pids 2>/dev/null || break
            sleep 0.3
        done
        if [[ $mode == package ]]; then launcher=/usr/bin/lgallery; else launcher="$user_launcher"; fi
        [[ -x "$launcher" ]] || launcher="$here/.venv/bin/python $here/main.py"
        nohup $launcher >/dev/null 2>&1 &
        info "Gallery restarted."
    else
        bold "Gallery is running"
        info "Close and reopen it to use the new version (or run: ./update.sh --no-pull --restart)."
    fi
fi

bold "Update complete."
