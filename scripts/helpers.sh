
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

command_exists() {
  local command="$1"
  type "$command" >/dev/null 2>&1
}

# because bash does not support math with floating-point numbers
# so awk does
calc() {
  local stdin;
  read -d '' -u 0 stdin;
  awk "BEGIN { print $stdin }";
}

# interpolate placeholder in template with value, applying printf formatting
interpolate(){
  local template="$1"
  local placeholder="$2"
  local value="$(printf "$3" "$4")"
  
  echo "${template//$placeholder/$value}"
}

