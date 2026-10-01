#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_CONFIG_HOME=/tmp/hyouka-ui-config
export XDG_DATA_HOME=/tmp/hyouka-ui-final-capture
export XDG_CACHE_HOME=/tmp/hyouka-ui-cache
exec godot --audio-driver Dummy --quit-after 1200 --path . --script res://tests/capture_colors.gd > artifacts/ui-redesign/logs/color-capture.log 2>&1
