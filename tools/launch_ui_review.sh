#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_CONFIG_HOME=/tmp/hyouka-ui-config
export XDG_DATA_HOME=/tmp/hyouka-ui-gui-data
export XDG_CACHE_HOME=/tmp/hyouka-ui-cache
exec godot --audio-driver Dummy --path . --resolution 1280x720 --position 20,20 -- --ui-review > artifacts/ui-redesign/logs/gui.log 2>&1
