#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"
NULL="/dev/null"

loadavg_per_cpu_core=$(get_tmux_option "@sysstat_loadavg_per_cpu_core" "true")

get_num_of_cores(){
  is_osx && sysctl -n hw.ncpu && return 0
  is_freebsd && sysctl -n hw.ncpu || nproc 2> ${NULL}
}

main(){
  local num_cores=$([ "$loadavg_per_cpu_core" == "true" ]  && get_num_of_cores || echo 1)

  uptime 2> ${NULL} | awk -v num_cores="$num_cores" '{
    sub(/,$/, "", $(NF-2));
    sub(/,$/, "", $(NF-1));
    sub(/,$/, "", $NF);
    printf "%.2f %.2f %.2f", $(NF-2)/num_cores, $(NF-1)/num_cores, $NF/num_cores
  }'
}

main
