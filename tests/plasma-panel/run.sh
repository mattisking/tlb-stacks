#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "$0")" && pwd)
python=${KWIN_MCP_PYTHON:-"$HOME/.local/share/uv/tools/kwin-mcp/bin/python"}
sandbox=$(mktemp -d /tmp/tlb-panel-run.XXXXXX)
trap 'rm -rf -- "$sandbox"' EXIT
mkdir -m 700 "$sandbox/runtime" "$sandbox/home"
env -i PATH=/usr/bin:/bin HOME="$sandbox/home" TMPDIR="$sandbox" XDG_RUNTIME_DIR="$sandbox/runtime" \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$sandbox/no-system-bus" LANG=C.UTF-8 \
    "$python" "$here/run.py" "$@"
