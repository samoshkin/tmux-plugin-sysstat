#!/usr/bin/env bash

LC_NUMERIC=C

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

refresh_interval=$(get_tmux_option_ex "status-interval" "3" "force")
samples_count="60"
cpu_metric_file="$(get_tmux_option "@sysstat_cpu_tmp_dir" "/dev/null")/cpu_collect.metric"

get_cpu_usage() {
	if is_osx; then
	if command_exists "iostat"; then
		iostat -w "$refresh_interval" -c "$samples_count" \
		| gstdbuf -o0 awk 'NR > 2 { print 100-$(NF-3); }'
	else
		top -l "$samples_count" -s "$refresh_interval" -n 0 \
		| sed -u -nr '/CPU usage/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*idle.*/\1/p' \
		| gstdbuf -o0 awk '{ print 100-$0 }'
	fi
	elif [ `command_exists "sar"` -a is_linux ]; then
		GET_IDLE_STAT=`sar -u 1 1|awk '{ print $9}'`
		case "$GET_IDLE_STAT" in
		  *"idle"*) ret=0 ;;
			  *) ret=1 ;;
		  esac
		SAR_STAT=$ret
		if [[ $SAR_STAT == 0 ]]; then
		  sar -u "$refresh_interval" "$samples_count" \
			  |stdbuf -o0 grep all |stdbuf -o0 awk '{print 100-$(9)}'
		else
		  sar -u "$refresh_interval" "$samples_count" \
			  |stdbuf -o0 grep all |stdbuf -o0 awk '{print 100-$(8)}'
		fi
	elif [ ! `command_exists "vmstat"` ]; then
		if is_freebsd; then
		  vmstat -n "$refresh_interval" -c "$samples_count" \
			| stdbuf -o0 awk 'NR>2 {print 100-$(NF-0)}'
		else
		  vmstat -n "$refresh_interval" "$samples_count" \
			| stdbuf -o0 awk 'NR>2 {print 100-$(NF-2)}'
		fi
	else
		if is_freebsd; then
		  top -d"$samples_count" \
			| sed -u -nr '/CPU:/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*id.*/\1/p' \
			| stdbuf -o0 awk '{ print 100-$0 }'
		else
		  top -b -n "$samples_count" -d "$refresh_interval" \
			| sed -u -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' \
			| stdbuf -o0 awk '{ print 100-$0 }'
		fi
	fi
	echo "FF"
}

main() {
  i0=0
  CURENT_PROCESS_INFO=`ps ux |grep cpu_collect.sh|grep -v grep|grep -v vim`
  if [[ $CURENT_PROCESS_INFO == "" ]]; then
  	exit
  fi
  get_cpu_usage | while read -r value; do
	TMUX_PROCESS_INFO=`ps ux|grep " tmux"|grep -v grep`
    echo "$value" | tee "$cpu_metric_file"
	if [[ $TMUX_PROCESS_INFO == "" ]]; then
		exit
	fi
	i0=$((i0+1))
	# echo "value $value loop $i0 $(date)" >> ~/cpu.log
  done
}

main

