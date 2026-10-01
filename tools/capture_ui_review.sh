#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_CONFIG_HOME=/tmp/hyouka-ui-config
export XDG_DATA_HOME=/tmp/hyouka-ui-capture-data
export XDG_CACHE_HOME=/tmp/hyouka-ui-cache
exec godot --audio-driver Dummy --path . --resolution 1280x720 --script res://tests/capture_ui.gd > artifacts/ui-redesign/logs/capture.log 2>&1
