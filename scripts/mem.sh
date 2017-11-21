#!/usr/bin/env bash

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

mem_view_tmpl=$(get_tmux_option "@sysstat_mem_view_tmpl" '#[fg=#{mem.color}]#{mem.pused}#[default]')

mem_stress_threshold=$(get_tmux_option "@sysstat_mem_stress_threshold" "80")
swap_stress_threshold=$(get_tmux_option "@sysstat_swap_stress_threshold" "80")

mem_color_ok=$(get_tmux_option "@sysstat_mem_color_ok" "green")
mem_color_stress=$(get_tmux_option "@sysstat_mem_color_stress" "yellow")
swap_color_ok=$(get_tmux_option "@sysstat_swap_color_ok" "green")
swap_color_stress=$(get_tmux_option "@sysstat_swap_color_stress" "yellow")

size_unit=$(get_tmux_option "@sysstat_mem_size_unit" "M")

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
  local scale
  local size_format
  
  if is_osx; then
    mem_usage=$(get_mem_usage_osx)
  elif is_linux; then 
    mem_usage=$(get_mem_usage_linux)
  fi

  # get_mem_usage* function returns values in KiB
  # 1 - scale to KiB
  # 1024 - scale to MiB
  # 1048576 - scale to GiB
  case "$size_unit" in 
    G) scale=1048576;;
    M) scale=1024;;
    K) scale=1;;
  esac

  # Depending on scale factor, change precision
  # 12612325K - no digits after floating point
  # 1261M - no digits after floating point
  # 1.1G  - 1 digit after floating point 
  case "$size_unit" in 
    G) size_format='%.1f%s';;
    M) size_format='%.0f%s';;
    K) size_format='%.0f%s';;
  esac

  # Extract free and used memory in MiB, calculate total and percentage
  local mem_free=$(echo $mem_usage | awk -v scale="$scale" '{ print $1/scale }')
  local mem_used=$(echo $mem_usage | awk -v scale="$scale" '{ print $2/scale }')
  local mem_total=$(echo "$mem_free + $mem_used" | calc)
  local mem_pused=$(echo "($mem_used / $mem_total) * 100" | calc)
  local mem_pfree=$(echo "($mem_free / $mem_total) * 100" | calc)

  # Extract swap free and used in MiB, calculate total and percentage
  local swap_free=$(echo $mem_usage | awk -v scale="$scale" '{ print $3/scale }')
  local swap_used=$(echo $mem_usage | awk -v scale="$scale" '{ print $4/scale }')
  local swap_total=$(echo "$swap_free + $swap_used" | calc)
  local swap_pused=$(echo "($swap_used / $swap_total) * 100" | calc)
  local swap_pfree=$(echo "($swap_free / $swap_total) * 100" | calc)
  
  # Calculate colors for mem and swap
  local mem_color=$(get_mem_color "$mem_pused")
  local swap_color=$(get_swap_color "$swap_pused")
  
  local mem_view="$mem_view_tmpl"
  mem_view="${mem_view//'#{mem.used}'/$(printf "$size_format" "$mem_used" "$size_unit")}"
  mem_view="${mem_view//'#{mem.pused}'/$(printf "%.0f%%" "$mem_pused")}"
  mem_view="${mem_view//'#{mem.free}'/$(printf "$size_format" "$mem_free" "$size_unit")}"
  mem_view="${mem_view//'#{mem.pfree}'/$(printf "%.0f%%" "$mem_pfree")}"
  mem_view="${mem_view//'#{mem.total}'/$(printf "$size_format" "$mem_total" "$size_unit")}"  
  mem_view="${mem_view//'#{mem.color}'/$(echo "$mem_color" | awk '{ print $1 }')}"
  mem_view="${mem_view//'#{mem.color2}'/$(echo "$mem_color" | awk '{ print $2 }')}"
  mem_view="${mem_view//'#{mem.color3}'/$(echo "$mem_color" | awk '{ print $3 }')}"
  
  mem_view="${mem_view//'#{swap.used}'/$(printf "$size_format" "$swap_used" "$size_unit")}"
  mem_view="${mem_view//'#{swap.pused}'/$(printf "%.0f%%" "$swap_pused")}"
  mem_view="${mem_view//'#{swap.free}'/$(printf "$size_format" "$swap_free" "$size_unit")}"
  mem_view="${mem_view//'#{swap.pfree}'/$(printf "%.0f%%" "$swap_pfree")}"
  mem_view="${mem_view//'#{swap.total}'/$(printf "$size_format" "$swap_total" "$size_unit")}"
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


# Method #1. Sum up free+buffers+cached, treat it as "available" memory, assuming buff+cache can be reclaimed. Note, that this assumption is not 100% correct, buff+cache most likely cannot be 100% reclaimed, but this is how memory calculation is used to be done on Linux

# Method #2. If "MemAvailable" is provided by system, use it. This is more correct method, because we're not relying on fragile "free+buffer+cache" equation. 

# See: Interpreting /proc/meminfo and free output for Red Hat Enterprise Linux 5, 6 and 7 - Red Hat Customer Portal - https://access.redhat.com/solutions/406773

# See: kernel/git/torvalds/linux.git - /proc/meminfo: provide estimated available memory - https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773
get_mem_usage_linux(){
  local mem_free_used=$( </proc/meminfo awk '
    BEGIN { total=0; free=0; }
      /MemTotal:/ { total=$2; }
      
      /MemFree:/ { free+=$2; }
      /Buffers:/ { free+=$2; }
      /Cached:/ { free+=$2; }

      /MemAvailable:/ { free=$2; exit;}
    END { print free, total-free }
  ')

  local swap_free_used=$( </proc/meminfo awk '
    BEGIN { total=0; free=0; }
      /SwapTotal:/ { total=$2; }
      /SwapFree:/ { free=$2; }
    END { print free, total-free }
  ')

  printf "%s %s" "$mem_free_used" "$swap_free_used"
}

main() {
  print_mem
}

main



