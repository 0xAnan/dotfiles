#!/usr/bin/env bash
set -o pipefail
shopt -s nullglob

icon="󰢮"

if command -v nvidia-smi >/dev/null 2>&1; then
  line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
  IFS=',' read -r util mem_used mem_total temp <<<"$line"
  util=${util//[[:space:]]/}
  mem_used=${mem_used//[[:space:]]/}
  mem_total=${mem_total//[[:space:]]/}
  temp=${temp//[[:space:]]/}

  if [ -n "$util" ] && [ -n "$mem_used" ] && [ -n "$mem_total" ]; then
    tooltip="GPU: ${util}%\\nVRAM: ${mem_used}/${mem_total} MiB"
    if [ -n "$temp" ]; then
      tooltip="${tooltip}\\nTemp: ${temp}°C"
    fi

    printf '{"text":"%s %s%%","tooltip":"%s"}\n' "$icon" "$util" "$tooltip"
    exit 0
  fi
fi

for device in /sys/class/drm/card*/device; do
  [ -r "$device/gpu_busy_percent" ] || continue

  busy=$(cat "$device/gpu_busy_percent")
  if ! [[ "$busy" =~ ^[0-9]+$ ]]; then
    continue
  fi

  mem_used_file="$device/mem_info_vram_used"
  mem_total_file="$device/mem_info_vram_total"
  tooltip="GPU: ${busy}%"

  if [ -r "$mem_used_file" ] && [ -r "$mem_total_file" ]; then
    mem_used_bytes=$(cat "$mem_used_file")
    mem_total_bytes=$(cat "$mem_total_file")

    if [[ "$mem_used_bytes" =~ ^[0-9]+$ ]] && [[ "$mem_total_bytes" =~ ^[0-9]+$ ]] && [ "$mem_total_bytes" -gt 0 ]; then
      mem_used=$((mem_used_bytes / 1024 / 1024))
      mem_total=$((mem_total_bytes / 1024 / 1024))
      tooltip="${tooltip}\\nVRAM: ${mem_used}/${mem_total} MiB"
    fi
  fi

  printf '{"text":"%s %s%%","tooltip":"%s"}\n' "$icon" "$busy" "$tooltip"
  exit 0
done

echo '{"text":"󰢮 n/a","tooltip":"GPU metrics unavailable"}'
