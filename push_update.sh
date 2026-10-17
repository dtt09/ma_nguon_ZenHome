#!/usr/bin/env bash

# ==============================================================================
#  ZENHOME SMART HOME - OTA APP VERSION PUBLISHER (BASH SCRIPT)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_SCRIPT="$SCRIPT_DIR/scripts/push_update.cjs"

if ! command -v node &> /dev/null; then
    echo "❌ Lỗi: Node.js chưa được cài đặt!"
    exit 1
fi

node "$NODE_SCRIPT" "$@"
