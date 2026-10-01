#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
TARGET="${1:-Web}"
export XDG_CONFIG_HOME="${GODOT_EXPORT_CONFIG_HOME:-$ROOT/build/.godot-config}"
export XDG_CACHE_HOME="${GODOT_EXPORT_CACHE_HOME:-$ROOT/build/.godot-cache}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
# Optional shared template cache, without changing export presets or user data.
if [[ -n "${GODOT_TEMPLATE_DIR:-}" ]]; then
  export XDG_DATA_HOME="${GODOT_EXPORT_DATA_HOME:-$ROOT/build/.godot-data}"
  mkdir -p "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
  cp -a "$GODOT_TEMPLATE_DIR/." "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/"
fi
mkdir -p "$ROOT/build/web" "$ROOT/build/linux"
touch "$ROOT/build/.gdignore"
"$GODOT_BIN" --headless --path "$ROOT" --editor --import --quit
case "$TARGET" in
  Web) "$GODOT_BIN" --headless --path "$ROOT" --export-release Web "$ROOT/build/web/index.html"; touch "$ROOT/build/web/.nojekyll" ;;
  Linux) "$GODOT_BIN" --headless --path "$ROOT" --export-release Linux "$ROOT/build/linux/hyouka.x86_64" ;;
  *) echo "Usage: $0 [Web|Linux]" >&2; exit 2 ;;
esac
