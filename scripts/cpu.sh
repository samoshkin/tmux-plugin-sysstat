#!/usr/bin/env bash

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

refresh_interval=$(get_tmux_option "status-interval" "5")

print_cpu_usage() {
  if is_osx; then
    if command_exists "iostat"; then
      iostat -c 2 -w "$refresh_interval" | tail -n 1 | awk '{ printf "%.1f%%", 100-$6 }'
    else
      top -l 2 -s "$refresh_interval" -n 0 | sed -nr '/CPU usage/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*idle.*/\1/p' | tail -n 1 | awk '{ printf "%.1f%%", 100-$0 }'
    fi
  else
    if command_exists "vmstat"; then
      vmstat -n "$refresh_interval" 2 | tail -n 1 | awk '{printf "%.1f%%", 100-$(NF-2)}'
    else
      top -b -n 2 -d "$refresh_interval" | sed -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' | tail -n 1 | awk '{ printf "%.1f%%", 100-$0 }'
    fi
  fi
}

main(){
  print_cpu_usage
}

main