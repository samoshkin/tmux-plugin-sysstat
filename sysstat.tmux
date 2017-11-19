#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/scripts/helpers.sh"

placeholders=(
  "\#{cpu_percentage}"
  "\#{mem}"
  "\#{mem_percentage}"
  "\#{loadavg}"
)

commands=(
	"#($CURRENT_DIR/scripts/cpu.sh cpu)"
  "#($CURRENT_DIR/scripts/mem.sh mem)"
  "#($CURRENT_DIR/scripts/mem.sh --percentage)"
  "#($CURRENT_DIR/scripts/loadavg.sh)"
)

do_interpolation() {
	local all_interpolated="$1"
	for ((i=0; i<${#commands[@]}; i++)); do
		all_interpolated=${all_interpolated//${placeholders[$i]}/${commands[$i]}}
	done
	echo "$all_interpolated"
}

update_tmux_option() {
	local option="$1"
	local option_value="$(get_tmux_option "$option")"
	local new_option_value="$(do_interpolation "$option_value")"
	set_tmux_option "$option" "$new_option_value"
}

main() {
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}

main