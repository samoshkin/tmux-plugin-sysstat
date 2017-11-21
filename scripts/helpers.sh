
get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value="$(tmux show-option -gqv "$option")"
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

set_tmux_option() {
  local option="$1"
  local value="$2"
  tmux set-option -gq "$option" "$value"
}

is_osx() {
  [ $(uname) == "Darwin" ]
}

is_linux(){
  [ $(uname -s) == "Linux" ]
}


command_exists() {
  local command="$1"
  type "$command" >/dev/null 2>&1
}

# because bash does not support floating-point math
# but awk does
calc() {
  local stdin;
  read -d '' -u 0 stdin;
  awk "BEGIN { print $stdin }";
}

# "<" math operator which works with floats, once again based on awk
fcomp() {
  awk -v n1="$1" -v n2="$2" 'BEGIN {if (n1<n2) exit 0; exit 1}'
}

