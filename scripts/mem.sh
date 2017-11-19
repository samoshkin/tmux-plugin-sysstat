#!/usr/bin/env bash

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

mem_view_tmpl=$(get_tmux_option "@sysstat_mem_view_tmpl" '#{mem.used} | #{mem.pused}')
swap_view_tmpl=$(get_tmux_option "@sysstat_swap_view_tmpl" '#{swap.used} | #{swap.pused}')

print_swap=0

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
      --swap) print_swap=1; shift;;
      *) shift;;
  esac
done

print_mem() {
  local mem_usage
  
  if is_osx; then
    mem_usage=$(get_mem_usage_osx)
  else 
    #  TODO:
    mem_usage="TODO"
  fi

  # Extract free and used memory in MiB, calculate total and percentage
  local mem_free=$(echo $mem_usage | awk '{ print $1/1024 }')
  local mem_used=$(echo $mem_usage | awk '{ print $2/1024 }')
  local mem_total=$(echo "$mem_free + $mem_used" | calc)
  local mem_pused=$(echo "($mem_used / $mem_total) * 100" | calc)
  local mem_pfree=$(echo "($mem_free / $mem_total) * 100" | calc)
  
  local mem_view="$mem_view_tmpl"
  mem_view="$(interpolate "$mem_view" '\#{mem.used}' "%.0fM" "$mem_used")"
  mem_view="$(interpolate "$mem_view" '\#{mem.pused}' "%.0f%%" "$mem_pused")"
  mem_view="$(interpolate "$mem_view" '\#{mem.free}' "%.0fM" "$mem_free")"
  mem_view="$(interpolate "$mem_view" '\#{mem.pfree}' "%.0f%%" "$mem_pfree")"
  mem_view="$(interpolate "$mem_view" '\#{mem.total}' "%.0fM" "$mem_total")"

  echo "$mem_view"
}

print_swap() {
  local mem_usage

  if is_osx; then
    mem_usage=$(get_mem_usage_osx)
  else 
    #  TODO:
    mem_usage="TODO"
  fi

  # Get free and used memory in MiB, calculate total and percentage
  local swap_free=$(echo $mem_usage | awk '{ print $3/1024 }')
  local swap_used=$(echo $mem_usage | awk '{ print $4/1024 }')
  local swap_total=$(echo "$swap_free + $swap_used" | calc)
  local swap_pused=$(echo "($swap_used / $swap_total) * 100" | calc)
  local swap_pfree=$(echo "($swap_free / $swap_total) * 100" | calc)
  
  local swap_view="$swap_view_tmpl"
  swap_view="$(interpolate "$swap_view" '\#{swap.used}' "%.0fM" "$swap_used")"
  swap_view="$(interpolate "$swap_view" '\#{swap.pused}' "%.0f%%" "$swap_pused")"
  swap_view="$(interpolate "$swap_view" '\#{swap.free}' "%.0fM" "$swap_free")"
  swap_view="$(interpolate "$swap_view" '\#{swap.pfree}' "%.0f%%" "$swap_pfree")"
  swap_view="$(interpolate "$swap_view" '\#{swap.total}' "%.0fM" "$swap_total")"

  echo "$swap_view"
}

# Report like it does htop on OSX:
# used = active + wired
# free = free + inactive + speculative + occupied by compressor
# see `vm_stat` command
get_mem_usage_osx(){
  
  local page_size=$(sysctl -nq "vm.pagesize")
  local free_used=$(vm_stat | awk -v page_size=$page_size -F ':' '
    BEGIN { free=0; used=0 }
    
    /Pages active/ || 
    /Pages wired/ { 
      gsub(/^[ \t]+|[ \t]+$/, "", $2); used+=$2;
    }
    /Pages free/ || 
    /Pages inactive/ || 
    /Pages speculative/ || 
    /Pages occupied by compressor/ { 
      gsub(/^[ \t]+|[ \t]+$/, "", $2); free+=$2;
    }

    END { print (free * page_size)/1024, (used * page_size)/1024 }
  ')

  # assume swap size in MB
  local swap_used=$(sysctl -nq vm.swapusage | awk -F '  ' '{ print $2 }' | awk -F '=' '{gsub(/^[ ]|[M]$/, "", $2); printf "%d", $2 * 1024 }')
  local swap_free=$(sysctl -nq vm.swapusage | awk -F '  ' '{ print $3 }' | awk -F '=' '{gsub(/^[ ]|[M]$/, "", $2); printf "%d", $2 * 1024 }')

  printf "%s %s %s %s" "$free_used" "$swap_free" "$swap_used"
}

main() {
  if [ $print_swap -eq 1 ]; then print_swap;
  else print_mem; fi
}

main



