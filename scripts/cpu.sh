#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

cpu_tmp_dir=$(tmux show-option -gqv "@sysstat_cpu_tmp_dir")

cpu_view_tmpl=$(get_tmux_option "@sysstat_cpu_view_tmpl" '#[bg=#3e4452]U:#[fg=#{cpu.color},bg=#3e4452]#{cpu.pused}#[fg=#aab2bf,bg=#3e4452] #[default]')

cpu_medium_threshold=$(get_tmux_option "@sysstat_cpu_medium_threshold" "30")
cpu_stress_threshold=$(get_tmux_option "@sysstat_cpu_stress_threshold" "80")

cpu_color_low=$(get_tmux_option "@sysstat_cpu_color_low" "green")
cpu_color_medium=$(get_tmux_option "@sysstat_cpu_color_medium" "yellow")
cpu_color_stress=$(get_tmux_option "@sysstat_cpu_color_stress" "red")

refresh_interval=$(get_tmux_option_ex "status-interval" "3" "force")
samples_count="1"
cpu_usage_val=0
cpu_idle_val=0

get_cpu_color_old(){
	local cpu_used=$1

	if fcomp "$cpu_stress_threshold" "$cpu_used"; then
		echo "$cpu_color_stress";
	elif fcomp "$cpu_medium_threshold" "$cpu_used"; then
		echo "$cpu_color_medium";
	else
		echo "$cpu_color_low";
	fi
}

get_cpu_color(){
	local cpu_used=$1

	cpu_used=${cpu_used%.*}
	cpu_used_num=$((cpu_used / 10))
	if [[ $cpu_used_num -ge 10 ]]; then
		cpu_used_num=10
	fi
	echo "#${sysstat_color_map[$cpu_used_num]}"
}


get_cpu_usage() {
	if is_osx; then
		echo "======$LINENO"
		if command_exists "iostat"; then
			cpu_usage_val=$(iostat -w "$refresh_interval" -c "$samples_count" \
				| stdbuf -o0 awk 'NR > 2 { print 100-$(NF-3); }')
		else
			cpu_usage_val=$(top -l "$samples_count" -s "$refresh_interval" -n 0 \
				| sed -u -nr '/CPU usage/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*idle.*/\1/p' \
				| stdbuf -o0 awk '{ print 100-$0 }')
		fi
	elif is_linux ; then
		if [ ! `command_exists "iostat"` ]; then
			sar_output_val=$(env LANG=en_US iostat -c 1 2|grep idle -A 1|tail -n 2)
			for item in $sar_output_val;
			do
				cpu_idle_val=$item
			done
			cpu_usage_val=$(echo ${cpu_idle_val}|awk '{print 100-$NF}')
		elif [ ! `command_exists "sar"` ]; then
			sar_output_val=$(env LANG=en_US sar -u 1 1|grep idle -A 1)
			for item in $sar_output_val;
			do
				cpu_idle_val=$item
			done
			cpu_usage_val=$(echo ${cpu_idle_val}|awk '{print 100-$NF}')
		elif [ ! `command_exists "vmstat"` ]; then
			if is_freebsd; then
				cpu_usage_val=$(vmstat -n "$refresh_interval" -c "$samples_count" \
					| stdbuf -o0 awk 'NR>2 {print 100-$(NF-0)}')
			else
				cpu_usage_val=$(vmstat -n "$refresh_interval" "$samples_count" \
					| stdbuf -o0 awk 'NR>2 {print 100-$(NF-2)}')
			fi
		fi
	else
		if is_freebsd; then
			cpu_usage_val=$(top -d"$samples_count" \
					| sed -u -nr '/CPU:/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*id.*/\1/p' \
					| stdbuf -o0 awk '{ print 100-$0 }')
		else
			cpu_usage_val=$(top -b -n "$samples_count" -d "$refresh_interval" \
					| sed -u -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' \
					| stdbuf -o0 awk '{ print 100-$0 }')
		fi
	fi
}

print_cpu_usage() {
	local cpu_pused=$cpu_usage_val
	local cpu_color=$(get_cpu_color "$cpu_pused")

	local cpu_view="$cpu_view_tmpl"

	get_cpu_usage
	cpu_pused=$cpu_usage_val
	cpu_color=$(get_cpu_color "$cpu_pused")

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
	# get_cpu_color 120.44
}

main
