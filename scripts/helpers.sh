
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

is_freebsd() {
    [ $(uname) == FreeBSD ]
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

# get_mem_usage* function returns values in KiB
# 1 - scale to KiB
# 1024 - scale to MiB
# 1048576 - scale to GiB
function get_size_scale_factor(){
  local size_unit="$1"
  case "$size_unit" in 
    G) echo 1048576;;
    M) echo 1024;;
    K) echo 1;;
  esac
}

# Depending on scale factor, change precision
# 12612325K - no digits after floating point
# 1261M - no digits after floating point
# 1.1G  - 1 digit after floating point 
function get_size_format(){
  local size_unit="$1"
  case "$size_unit" in 
    G) echo '%.1f%s';;
    M) echo '%.0f%s';;
    K) echo '%.0f%s';;
  esac
}
  
  

