#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

cpu_tmp_dir=$(tmux show-option -gqv "@sysstat_cpu_tmp_dir")

cpu_view_tmpl=$(get_tmux_option "@sysstat_cpu_view_tmpl" 'CPU:#[fg=#{cpu.color}]#{cpu.pused}#[default]')

cpu_medium_threshold=$(get_tmux_option "@sysstat_cpu_medium_threshold" "30")
cpu_stress_threshold=$(get_tmux_option "@sysstat_cpu_stress_threshold" "80")

cpu_color_low=$(get_tmux_option "@sysstat_cpu_color_low" "green")
cpu_color_medium=$(get_tmux_option "@sysstat_cpu_color_medium" "yellow")
cpu_color_stress=$(get_tmux_option "@sysstat_cpu_color_stress" "red")

get_cpu_color(){
  local cpu_used=$1

  if fcomp "$cpu_stress_threshold" "$cpu_used"; then
    echo "$cpu_color_stress";
  elif fcomp "$cpu_medium_threshold" "$cpu_used"; then
    echo "$cpu_color_medium";
  else
    echo "$cpu_color_low";
  fi
}

print_cpu_usage() {
  local cpu_pused=$(get_cpu_usage_or_collect)
  local cpu_color=$(get_cpu_color "$cpu_pused")
  
  local cpu_view="$cpu_view_tmpl"
  cpu_view="${cpu_view//'#{cpu.pused}'/$(printf "%.1f%%" "$cpu_pused")}"
  cpu_view="${cpu_view//'#{cpu.color}'/$(echo "$cpu_color" | awk '{ print $1 }')}"
  cpu_view="${cpu_view//'#{cpu.color2}'/$(echo "$cpu_color" | awk '{ print $2 }')}"
  cpu_view="${cpu_view//'#{cpu.color3}'/$(echo "$cpu_color" | awk '{ print $3 }')}"

  echo "$cpu_view"
}

get_cpu_usage_or_collect() {
  local collect_cpu_metric="$cpu_tmp_dir/cpu_collect.metric"

  # read cpu metric from file, otherwise 0 as a temporary null value, until first cpu metric is collected
  [ -f "$collect_cpu_metric" ] && cat "$collect_cpu_metric" || echo "0.0"

  start_cpu_collect_if_required >/dev/null 2>&1
}

start_cpu_collect_if_required() {
  local collect_cpu_pidfile="$cpu_tmp_dir/cpu_collect.pid"

  # check if cpu collect process is running, otherwise start it in background
  if [ -f "$collect_cpu_pidfile" ] && ps -p "$(cat "$collect_cpu_pidfile")" > /dev/null 2>&1; then
    return;
  fi
  
  jobs >/dev/null 2>&1
  "$CURRENT_DIR/cpu_collect.sh" &>/dev/null &
  if [ -n "$(jobs -n)" ]; then
    echo "$!" > "${collect_cpu_pidfile}"
  else
    echo "Failed to start CPU collect job" >&2
    exit 1
  fi
}

main(){
  print_cpu_usage
}

main
