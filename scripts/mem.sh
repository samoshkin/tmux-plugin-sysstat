#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

mem_view_tmpl=$(get_tmux_option "@sysstat_mem_view_tmpl" 'MEM:#[fg=#{mem.color}]#{mem.pused}#[default]')

mem_medium_threshold=$(get_tmux_option "@sysstat_mem_medium_threshold" "75")
mem_stress_threshold=$(get_tmux_option "@sysstat_mem_stress_threshold" "90")

mem_color_low=$(get_tmux_option "@sysstat_mem_color_low" "green")
mem_color_medium=$(get_tmux_option "@sysstat_mem_color_medium" "yellow")
mem_color_stress=$(get_tmux_option "@sysstat_mem_color_stress" "red")

size_unit=$(get_tmux_option "@sysstat_mem_size_unit" "G")

get_mem_color() {
  local mem_pused=$1

  if fcomp "$mem_stress_threshold" "$mem_pused"; then
    echo "$mem_color_stress";
  elif fcomp "$mem_medium_threshold" "$mem_pused"; then
    echo "$mem_color_medium";
  else
    echo "$mem_color_low";
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
  elif is_freebsd; then
    mem_usage=$(get_mem_usage_freebsd)
  fi

  local size_scale="$(get_size_scale_factor "$size_unit")"
  local size_format="$(get_size_format "$size_unit")"

  # Extract free and used memory in MiB, calculate total and percentage
  local mem_free=$(echo $mem_usage | awk -v scale="$size_scale" '{ print $1/scale }')
  local mem_used=$(echo $mem_usage | awk -v scale="$size_scale" '{ print $2/scale }')
  local mem_total=$(echo "$mem_free + $mem_used" | calc)
  local mem_pused=$(echo "($mem_used / $mem_total) * 100" | calc)
  local mem_pfree=$(echo "($mem_free / $mem_total) * 100" | calc)
  
  # Calculate colors for mem and swap
  local mem_color=$(get_mem_color "$mem_pused")
  
  local mem_view="$mem_view_tmpl"
  mem_view="${mem_view//'#{mem.used}'/$(printf "$size_format" "$mem_used" "$size_unit")}"
  mem_view="${mem_view//'#{mem.pused}'/$(printf "%.0f%%" "$mem_pused")}"
  mem_view="${mem_view//'#{mem.free}'/$(printf "$size_format" "$mem_free" "$size_unit")}"
  mem_view="${mem_view//'#{mem.pfree}'/$(printf "%.0f%%" "$mem_pfree")}"
  mem_view="${mem_view//'#{mem.total}'/$(printf "$size_format" "$mem_total" "$size_unit")}"  
  mem_view="${mem_view//'#{mem.color}'/$(echo "$mem_color" | awk '{ print $1 }')}"
  mem_view="${mem_view//'#{mem.color2}'/$(echo "$mem_color" | awk '{ print $2 }')}"
  mem_view="${mem_view//'#{mem.color3}'/$(echo "$mem_color" | awk '{ print $3 }')}"

  echo "$mem_view"
}


# Report like it does htop on OSX:
# used = active + wired
# free = free + inactive + speculative + occupied by compressor
# see `vm_stat` command
get_mem_usage_osx(){
  
  local page_size=$(sysctl -nq "vm.pagesize")
  vm_stat | awk -v page_size=$page_size -F ':' '
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
  '
}

# Relies on vmstat, but could also be done with top on FreeBSD
get_mem_usage_freebsd(){
  vmstat -H | tail -n 1 | awk '{ print $5, $4 }'
}

# Method #1. Sum up free+buffers+cached, treat it as "available" memory, assuming buff+cache can be reclaimed. Note, that this assumption is not 100% correct, buff+cache most likely cannot be 100% reclaimed, but this is how memory calculation is used to be done on Linux

# Method #2. If "MemAvailable" is provided by system, use it. This is more correct method, because we're not relying on fragile "free+buffer+cache" equation. 

# See: Interpreting /proc/meminfo and free output for Red Hat Enterprise Linux 5, 6 and 7 - Red Hat Customer Portal - https://access.redhat.com/solutions/406773

# See: kernel/git/torvalds/linux.git - /proc/meminfo: provide estimated available memory - https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773
get_mem_usage_linux(){
  </proc/meminfo awk '
    BEGIN { total=0; free=0; }
      /MemTotal:/ { total=$2; }
      
      /MemFree:/ { free+=$2; }
      /Buffers:/ { free+=$2; }
      /Cached:/ { free+=$2; }

      /MemAvailable:/ { free=$2; exit;}
    END { print free, total-free }
  '
}

main() {
  print_mem
}

main

