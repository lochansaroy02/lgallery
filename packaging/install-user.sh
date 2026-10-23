#!/usr/bin/env bash
# Install a launcher for a source checkout into ~/.local (no root needed).
# Run from anywhere:  ./packaging/install-user.sh      Undo:  ./packaging/install-user.sh --uninstall
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
bin="$HOME/.local/bin"

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$bin/lgallery" "$data/applications/lgallery.desktop" \
          "$data/icons/hicolor/scalable/apps/lgallery.svg"
    update-desktop-database "$data/applications" 2>/dev/null || true
    echo "Launcher removed (your index and settings were left in place)."
    exit 0
fi

python="$here/.venv/bin/python"
if [[ ! -x "$python" ]]; then
    python="$(command -v python3)"
    echo "No .venv found, using system $python"
fi

mkdir -p "$bin" "$data/applications" "$data/icons/hicolor/scalable/apps"
cat > "$bin/lgallery" <<SH
#!/bin/sh
exec "$python" "$here/main.py" "\$@"
SH
chmod +x "$bin/lgallery"
install -m644 "$here/packaging/icon.svg" "$data/icons/hicolor/scalable/apps/lgallery.svg"
sed -e "s|^Exec=.*|Exec=$bin/lgallery %F|" -e "s|^TryExec=.*|TryExec=$bin/lgallery|" \
    "$here/packaging/lgallery.desktop" > "$data/applications/lgallery.desktop"
update-desktop-database "$data/applications" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
echo "Installed. 'Gallery' is now in the application launcher (command: $bin/lgallery)."
echo "To open pictures from Dolphin in Gallery: Gallery > Settings > Set as default,"
echo "or in Dolphin right-click a picture > Open With > Gallery."
