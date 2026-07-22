#!/usr/bin/env bash
set -o pipefail

TARGET="${WAYBAR_DISK_PATH:-$HOME}"
line=$(df -h --output=size,used,avail,pcent,target "$TARGET" 2>/dev/null | tail -n1)

if [ -z "$line" ]; then
  echo '{"text":" n/a","tooltip":"Disk usage unavailable"}'
  exit 0
fi

read -r size used avail pct mount <<<"$line"

if [ -z "$pct" ]; then
  echo '{"text":" n/a","tooltip":"Disk usage unavailable"}'
  exit 0
fi

printf '{"text":" %s","tooltip":"%s: %s used / %s total (%s)\\nFree: %s"}\n' \
  "$pct" "$mount" "$used" "$size" "$pct" "$avail"
