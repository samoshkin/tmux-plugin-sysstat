#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

loadavg_per_cpu_core=$(get_tmux_option "@sysstat_loadavg_per_cpu_core" "true")

get_num_of_cores(){
  is_osx && sysctl -n hw.ncpu || nproc
}

main(){ 
  local num_cores=$([ "$loadavg_per_cpu_core" == "true" ]  && get_num_of_cores || echo 1)

  uptime | awk -v num_cores="$num_cores" '{ 
    sub(/,$/, "", $(NF-2));
    sub(/,$/, "", $(NF-1));
    sub(/,$/, "", $NF);
    printf "%.2f %.2f %.2f", $(NF-2)/num_cores, $(NF-1)/num_cores, $NF/num_cores
  }'
}

main
