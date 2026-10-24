#!/usr/bin/env bash
# Recompile the shaders after editing a .frag file (needs PySide6's qsb):
#   qml/shaders/build.sh
# The .qsb files are committed, so building or installing Gallery never needs this.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
QSB="${QSB:-$(command -v pyside6-qsb || command -v qsb || echo ../../.venv/bin/pyside6-qsb)}"
for frag in *.frag; do
    "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$frag.qsb" "$frag"
    echo "built $frag.qsb"
done
