#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

swap_view_tmpl=$(get_tmux_option "@sysstat_swap_view_tmpl" 'SW:#[fg=#{swap.color}]#{swap.pused}#[default]')

swap_medium_threshold=$(get_tmux_option "@sysstat_swap_medium_threshold" "25")
swap_stress_threshold=$(get_tmux_option "@sysstat_swap_stress_threshold" "75")

swap_color_low=$(get_tmux_option "@sysstat_swap_color_low" "green")
swap_color_medium=$(get_tmux_option "@sysstat_swap_color_medium" "yellow")
swap_color_stress=$(get_tmux_option "@sysstat_swap_color_stress" "red")

size_unit=$(get_tmux_option "@sysstat_swap_size_unit" "G")

get_swap_color() {
  local swap_pused=$1

  if fcomp "$swap_stress_threshold" "$swap_pused"; then
    echo "$swap_color_stress";
  elif fcomp "$swap_medium_threshold" "$swap_pused"; then
    echo "$swap_color_medium";
  else
    echo "$swap_color_low";
  fi
}

print_swap() {
  local swap_usage
  
  
  if is_osx; then
    swap_usage=$(get_swap_usage_osx)
  elif is_linux; then 
    swap_usage=$(get_swap_usage_linux)
  fi

  local size_scale="$(get_size_scale_factor "$size_unit")"
  local size_format="$(get_size_format "$size_unit")"

  # Extract swap free and used in MiB, calculate total and percentage
  local swap_free=$(echo $swap_usage | awk -v scale="$size_scale" '{ print $1/scale }')
  local swap_used=$(echo $swap_usage | awk -v scale="$size_scale" '{ print $2/scale }')
  local swap_total=$(echo "$swap_free + $swap_used" | calc)
  local swap_pused=$(echo "($swap_used / $swap_total) * 100" | calc)
  local swap_pfree=$(echo "($swap_free / $swap_total) * 100" | calc)
  
  # Calculate colors for mem and swap
  local swap_color=$(get_swap_color "$swap_pused")
  
  local swap_view="$swap_view_tmpl"
  swap_view="${swap_view//'#{swap.used}'/$(printf "$size_format" "$swap_used" "$size_unit")}"
  swap_view="${swap_view//'#{swap.pused}'/$(printf "%.0f%%" "$swap_pused")}"
  swap_view="${swap_view//'#{swap.free}'/$(printf "$size_format" "$swap_free" "$size_unit")}"
  swap_view="${swap_view//'#{swap.pfree}'/$(printf "%.0f%%" "$swap_pfree")}"
  swap_view="${swap_view//'#{swap.total}'/$(printf "$size_format" "$swap_total" "$size_unit")}"
  swap_view="${swap_view//'#{swap.color}'/$(echo "$swap_color" | awk '{ print $1 }')}"
  swap_view="${swap_view//'#{swap.color2}'/$(echo "$swap_color" | awk '{ print $2 }')}"
  swap_view="${swap_view//'#{swap.color3}'/$(echo "$swap_color" | awk '{ print $3 }')}"

  echo "$swap_view"
}

get_swap_usage_osx(){
  
  # assume swap size in MB
  local swap_used=$(sysctl -nq vm.swapusage | awk -F '  ' '{ print $2 }' | awk -F '=' '{gsub(/^[ ]|[M]$/, "", $2); printf "%d", $2 * 1024 }')
  local swap_free=$(sysctl -nq vm.swapusage | awk -F '  ' '{ print $3 }' | awk -F '=' '{gsub(/^[ ]|[M]$/, "", $2); printf "%d", $2 * 1024 }')

  printf "%s %s" "$swap_free" "$swap_used"
}

get_swap_usage_linux(){
  </proc/meminfo awk '
    BEGIN { total=0; free=0; }
      /SwapTotal:/ { total=$2; }
      /SwapFree:/ { free=$2; }
    END { print free, total-free }
  '
}

main() {
  print_swap
}

main



