#!/usr/bin/env bash

set -u
set -e

onedark_comment_grey="#5c6370"
onedark_visual_grey="#3e4452"
onedark_blue="#61afef"

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

loadavg_per_cpu_core=$(get_tmux_option "@sysstat_loadavg_per_cpu_core" "true")
loadavg_color_low=$(get_tmux_option "@sysstat_cpu_color_low" "green")
loadavg_color_medium=$(get_tmux_option "@sysstat_cpu_color_medium" "yellow")
loadavg_color_stress=$(get_tmux_option "@sysstat_cpu_color_stress" "red")
loadavg_view_tmpl=$(get_tmux_option "@sysstat_cpu_view_tmpl" '#[fg=#{cpu.color},bg=#3e4452]#{cpu.pused}#[default]')

loadavg_medium_threshold=$(get_tmux_option "@sysstat_cpu_medium_threshold" "0.8")
loadavg_stress_threshold=$(get_tmux_option "@sysstat_cpu_stress_threshold" "1.0")

get_num_of_cores(){
  is_osx && sysctl -n hw.ncpu || nproc
}

get_loadavg_color_old(){
  local loadavg_used=$1

  if fcomp "$loadavg_stress_threshold" "$loadavg_used"; then
    echo "$loadavg_color_stress";
  elif fcomp "$loadavg_medium_threshold" "$loadavg_used"; then
    echo "$loadavg_color_medium";
  else
    echo "$loadavg_color_low";
  fi
}
get_loadavg_color(){
	local loadavg_used=$1

	loadavg_used=$(echo ${loadavg_used}|awk '{print 10*$NF}')
	loadavg_used=${loadavg_used%.*}
	loadavg_used_num=$((loadavg_used / 1))
	if [[ $loadavg_used_num -ge 10 ]]; then
		loadavg_used_num=10
	fi
	echo "#${sysstat_color_map[$loadavg_used_num]}"
}


main(){
  local num_cores=$([ "$loadavg_per_cpu_core" == "true" ]  && get_num_of_cores || echo 1)

  # num_cores=1

  UPTIME_INFO=`uptime`
  UPTIME_INFO=${UPTIME_INFO##*load average:}
  load_15min=`echo ${UPTIME_INFO}|cut -f 1 -d ","`
  load_5min=`echo ${UPTIME_INFO}|cut -f 2 -d ","`
  load_1min=`echo ${UPTIME_INFO}|cut -f 3 -d ","`
  load_15min=`echo $load_15min|awk -v num_cores="$num_cores" '{ printf "%.2f", $0/num_cores }'`
  load_5min=`echo $load_5min|awk -v num_cores="$num_cores" '{ printf "%.2f", $0/num_cores }'`
  load_1min=`echo $load_1min|awk -v num_cores="$num_cores" '{ printf "%.2f", $0/num_cores }'`

  local loadavg_view="${loadavg_view_tmpl}"

  loadavg_color_15min=$(get_loadavg_color "$load_15min")
  loadavg_view_15min="${loadavg_view//'#{cpu.color}'/$(echo "$loadavg_color_15min" | awk '{ print $1 }')}"
  loadavg_view_15min="${loadavg_view_15min//'#{cpu.pused}'/$(echo "$load_15min" | awk '{ print $1" " }')}"

  loadavg_color_5min=$(get_loadavg_color "$load_5min")
  loadavg_view_5min="${loadavg_view//'#{cpu.color}'/$(echo "$loadavg_color_5min" | awk '{ print $1 }')}"
  loadavg_view_5min="${loadavg_view_5min//'#{cpu.pused}'/$(echo "$load_5min" | awk '{ print $1" " }')}"

  loadavg_color_1min=$(get_loadavg_color "$load_1min")
  loadavg_view_1min="${loadavg_view//'#{cpu.color}'/$(echo "$loadavg_color_1min" | awk '{ print $1 }')}"
  loadavg_view_1min="${loadavg_view_1min//'#{cpu.pused}'/$(echo "$load_1min" | awk '{ print $1"" }')}"

  printf "${loadavg_view_15min}${loadavg_view_5min}${loadavg_view_1min}#[bg=#3e4452]"
  # printf "$load_15min $load_5min $load_1min"

  # uptime | awk -v num_cores="$num_cores" '{
  #   sub(/,$/, "", $(NF-2));
  #   sub(/,$/, "", $(NF-1));
  #   sub(/,$/, "", $NF);
  #   printf "%.2f %.2f %.2f", $(NF-2), $(NF-1), $NF
  # }'
}

main

