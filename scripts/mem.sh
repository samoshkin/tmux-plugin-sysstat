#!/usr/bin/env bash

# TODO: add option to choose size unit: M|G

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

mem_view_tmpl=$(get_tmux_option "@sysstat_mem_view_tmpl" '#[fg=#{mem.color2}]#{mem.pused}#[default]')

mem_stress_threshold=$(get_tmux_option "@sysstat_mem_stress_threshold" "80")
swap_stress_threshold=$(get_tmux_option "@sysstat_swap_stress_threshold" "80")

mem_color_ok=$(get_tmux_option "@sysstat_mem_color_ok" "green")
mem_color_stress=$(get_tmux_option "@sysstat_mem_color_stress" "yellow")
swap_color_ok=$(get_tmux_option "@sysstat_swap_color_ok" "green")
swap_color_stress=$(get_tmux_option "@sysstat_swap_color_stress" "yellow")

get_mem_color() {
  local mem_pused=$1

  if fcomp "$mem_stress_threshold" "$mem_pused"; then
    echo "$mem_color_stress";
  else 
    echo "$mem_color_ok";
  fi
}

get_swap_color(){
  local swap_pused=$1

  if fcomp "$swap_stress_threshold" "$swap_pused"; then
    echo "$swap_color_stress";
  else 
    echo "$swap_color_ok";
  fi
}

print_mem() {
  local mem_usage
  
  if is_osx; then
    mem_usage=$(get_mem_usage_osx)
  else 
    #  TODO: implement memory calculation for linux
    mem_usage="TODO"
  fi

  # Extract free and used memory in MiB, calculate total and percentage
  local mem_free=$(echo $mem_usage | awk '{ print $1/1024 }')
  local mem_used=$(echo $mem_usage | awk '{ print $2/1024 }')
  local mem_total=$(echo "$mem_free + $mem_used" | calc)
  local mem_pused=$(echo "($mem_used / $mem_total) * 100" | calc)
  local mem_pfree=$(echo "($mem_free / $mem_total) * 100" | calc)

  # Extract swap free and used in MiB, calculate total and percentage
  local swap_free=$(echo $mem_usage | awk '{ print $3/1024 }')
  local swap_used=$(echo $mem_usage | awk '{ print $4/1024 }')
  local swap_total=$(echo "$swap_free + $swap_used" | calc)
  local swap_pused=$(echo "($swap_used / $swap_total) * 100" | calc)
  local swap_pfree=$(echo "($swap_free / $swap_total) * 100" | calc)
  
  # Calculate colors for mem and swap
  local mem_color=$(get_mem_color "$mem_pused")
  local swap_color=$(get_swap_color "$swap_pused")
  
  local mem_view="$mem_view_tmpl"
  mem_view="${mem_view//'#{mem.used}'/$(printf "%.0fM" "$mem_used")}"
  mem_view="${mem_view//'#{mem.pused}'/$(printf "%.0f%%" "$mem_pused")}"
  mem_view="${mem_view//'#{mem.free}'/$(printf "%.0fM" "$mem_free")}"
  mem_view="${mem_view//'#{mem.pfree}'/$(printf "%.0f%%" "$mem_pfree")}"
  mem_view="${mem_view//'#{mem.total}'/$(printf "%.0fM" "$mem_total")}"  
  mem_view="${mem_view//'#{mem.color}'/$(echo "$mem_color" | awk '{ print $1 }')}"
  mem_view="${mem_view//'#{mem.color2}'/$(echo "$mem_color" | awk '{ print $2 }')}"
  mem_view="${mem_view//'#{mem.color3}'/$(echo "$mem_color" | awk '{ print $3 }')}"
  
  mem_view="${mem_view//'#{swap.used}'/$(printf "%.0fM" "$swap_used")}"
  mem_view="${mem_view//'#{swap.pused}'/$(printf "%.0f%%" "$swap_pused")}"
  mem_view="${mem_view//'#{swap.free}'/$(printf "%.0fM" "$swap_free")}"
  mem_view="${mem_view//'#{swap.pfree}'/$(printf "%.0f%%" "$swap_pfree")}"
  mem_view="${mem_view//'#{swap.total}'/$(printf "%.0fM" "$swap_total")}"
  mem_view="${mem_view//'#{swap.color}'/$(echo "$swap_color" | awk '{ print $1 }')}"
  mem_view="${mem_view//'#{swap.color2}'/$(echo "$swap_color" | awk '{ print $2 }')}"
  mem_view="${mem_view//'#{swap.color3}'/$(echo "$swap_color" | awk '{ print $3 }')}"

  echo "$mem_view"
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

  printf "%s %s %s" "$free_used" "$swap_free" "$swap_used"
}

main() {
  print_mem
}

main



