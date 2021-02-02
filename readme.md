
Tmux sysstat plugin
===================
Allow to print CPU usage, memory & swap, load average, net I/O metrics in Tmux status bar

![intro](/screenshots/intro.png)

You might checkout [tmux-config](https://github.com/samoshkin/tmux-config) repo to see this plugin in action.

Features
--------
- CPU usage
- Memory available/free, used, total (KiB,MiB,GiB), free/used %
- Swap used, free, total, free/used %
- load average for last 1,5,15 minutes
- configurable thresholds (low, medium, stress) with custom colors
- tweak each metric output using templates (e.g, 'used 10% out of 16G')
- configurable size scale (K,M,G)
- OSX, Linux support
- [ ] **TODO:** network I/O metric support

Tested on: OS X Big Sur 11.1, Ubuntu 14 LTS, CentOS 7, FreeBSD 11.1.
Note: on OSX it is necessary to use GNU CLI tools  

Installation
------------
Best installed through [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (TMP). Add following line to your `.tmux.conf` file:

```
set -g @plugin 'samoshkin/tmux-plugin-sysstat'
```

Use `prefix + I` from inside tmux to install all plugins and source them. If you prefer, same effect can be achieved from [command line](https://github.com/tmux-plugins/tpm/blob/master/docs/managing_plugins_via_cmd_line.md):

```
$ ~.tmux/plugins/tpm/bin/install_plugins
```

Basic usage
-----------

Once plugged in, tmux `status-left` or `status-right` options can be configured with following placeholders. Each placeholder will be expanded to metric's default output.

- `#{sysstat_cpu}`, CPU usage - `CPU:40.2%`
- `#{sysstat_mem}`, memory usage - `MEM:73%`
- `#{sysstat_swap}`, swap usage - `SW:66%`
- `#{sysstat_loadavg}`, system load average - `0.25 0.04 0.34`

For example:
```
set -g status-right "#{sysstat_cpu} | #{sysstat_mem} | #{sysstat_swap} | #{sysstat_loadavg} | #[fg=cyan]#(echo $USER)#[default]@#H"
```

Changing default output
------------------------

You can change default output for CPU and memory metrics, if you need more fields to show, or you want to provide custom template. In your `.tmux.conf`:

For example, to get `Used 4.5G out of 16G` output for memory metric:

```
set -g @sysstat_mem_view_tmpl '#Used [fg=#{mem.color}]#{mem.used}#[default] out of #{mem.total}'
```

If you don't want `CPU:` prefix and don't like colored output for CPU metric:

```
set -g @sysstat_cpu_view_tmpl '#{cpu.pused}'
```

### Supported fields

As you can see, each metric can be configured with template, containing fixed text (`CPU:`), color placeholder (`#[fg=#{mem.color}]`) and field placeholder (`#{mem.used}`). This approach gives you the ultimate control over the output for each metric. Following field placeholders are supported:

<table>
    <th>CPU</th>
    <tr>
        <td><code>#{cpu.color}</code></td>
        <td>main metric color</td>
    </tr>
    <tr>
        <td><code>#{cpu.pused}</code></td>
        <td>CPU usage percentage</td>
    </tr>
</table>

<table>
    <th>Memory</th>
    <tr>
        <td><code>#{mem.color}</code></td>
        <td>main metric color</td>
    </tr>
    <tr>
        <td><code>#{mem.free}</code></td>
        <td>free/available memory</td>
    </tr>
    <tr>
        <td><code>#{mem.pfree}</code></td>
        <td>free memory percentage against total</td>
    </tr>
    <tr>
        <td><code>#{mem.used}</code></td>
        <td>used memory</td>
    </tr>
    <tr>
        <td><code>#{mem.pused}</code></td>
        <td>used memory percentage against total</td>
    </tr>
    <tr>
        <td><code>#{mem.total}</code></td>
        <td>total installed memory</td>
    </tr>
</table>

<table>
    <th>Swap</th>
    <tr>
        <td><code>#{swap.color}</code></td>
        <td>main swap metric color</td>
    </tr>
    <tr>
        <td><code>#{swap.free}</code></td>
        <td>free swap memory</td>
    </tr>
    <tr>
        <td><code>#{swap.pfree}</code></td>
        <td>free swap memory percentage against total swap space</td>
    </tr>
    <tr>
        <td><code>#{swap.used}</code></td>
        <td>used swap memory</td>
    </tr>
    <tr>
        <td><code>#{swap.pused}</code></td>
        <td>used swap memory percentage against total swap space</td>
    </tr>
    <tr>
        <td><code>#{swap.total}</code></td>
        <td>total swap space</td>
    </tr>
</table>

### Change size scale

free/used/total memory can be shown both in absolute and relative units. When it comes to absolute units, you can choose *size scale factor* to choose between GiB, MiB, KiB. Default is GiB. If you have less than 3-4G memory installed, it makes sense to use MiB. KiB option is less practical, because it yields pretty lengthy output, which does not fit status bar limited estate.

```
set -g @sysstat_mem_size_unit "G"
```

If you choose `G` for size scale, output will have `%.1f` (1 digit after floating point), otherwise size is integer (4.5G, 1024M, 1232345K).

Thresholds and colored output
---------------
Each metric output is colored by default. Colors vary depending on metric value.

<table>
    <tr>
      <td><b>Threshold</b></td>
      <td><b>CPU</b></td>
      <td><b>Memory</b></td>
      <td><b>Swap</b></td>
      <td><b>Default color</b></td>
    </tr>
    <tr>
        <td>low</td>
        <td>x &lt; 30%</td>
        <td>x &lt; 75%</td>
        <td>x &lt; 25%</td>
        <td>green</td>
    </tr>
    <tr>
        <td>medium</td>
        <td>30% &lt; x &lt; 80%</td>
        <td>75% &lt; x &lt; 90%</td>
        <td>25% &lt; x &lt; 75%</td>
        <td>yellow</td>
    </tr>
    <tr>
        <td>high</td>
        <td>x &gt; 80%</td>
        <td>x &gt; 90%</td>
        <td>x &gt; 75%</td>
        <td>red</td>
    </tr>
</table>

You can change thresholds in your `.tmux.conf`:

```
set -g @sysstat_cpu_medium_threshold "75"
set -g @sysstat_cpu_stress_threshold "95"

set -g @sysstat_mem_medium_threshold "85"
set -g @sysstat_mem_stress_threshold "95"

set -g @sysstat_swap_medium_threshold "80"
set -g @sysstat_swap_stress_threshold "90"
```

You can change colors for each threshold individually. You can use ANSI basic colors (red, cyan, green) or if your terminal supports 256 colors (and most do nowadays), use `colourXXX` format.

```
set -g @sysstat_cpu_color_low "colour076"
set -g @sysstat_cpu_color_medium "colour220"
set -g @sysstat_cpu_color_stress "colour160"
set -g @sysstat_mem_color_low "green"
set -g @sysstat_mem_color_medium "blue"
set -g @sysstat_mem_color_stress "cyan"
```

`#{(mem|cpu|swap).color}` placeholder in your `@sysstat_(mem|cpu|swap)_view_tmpl` would be replaced by corresponding color, depending on whether metric value falls in particular threshold.

### 256 color palette support

For 256 color palette support, make sure that `tmux` and parent terminal are configured with correct terminal type. See [here](https://unix.stackexchange.com/questions/1045/getting-256-colors-to-work-in-tmux) and [there](https://github.com/tmux/tmux/wiki/FAQ)

```
# ~/.tmux.conf
set -g default-terminal "screen-256color"
```

```
# parent terminal
$ echo $TERM
xterm-256color

# jump into a tmux session
$ tmux new
$ echo $TERM
screen-256color
```



### Multiple colors for each threshold

You can have up to *3* colors configured for each threshold. To understand why you might need this, let tackle this task. Note, this is rather advanced use case.

> I want `CPU: #{cpu.pused}` metric output, have green and yellow text colors at "low" and "medium" threshold, and finally, for "high" threshold, I want to use red color, but reverse foreground and background, that is use red for background, and white for text. More over I want "CPU:" text colored apart in red

Like this:

![cpu threshold with custom colors](/screenshots/cpu_thresholds.png)

You can achieve the result using following configuration:

```
set -g @sysstat_cpu_view_tmpl '#[fg=#{cpu.color3}]CPU:#[default] #[fg=#{cpu.color},bg=#{cpu.color2}]#{cpu.pused}#[default]'

set -g @sysstat_cpu_color_low "$color_level_ok default default"
set -g @sysstat_cpu_color_medium "$color_level_warn default default"
set -g @sysstat_cpu_color_stress "white,bold $color_level_stress $color_level_stress"
```

Tmux status-interval setting
-----------------------------
You can configure status refresh interval, increasing or reducing frequency of `tmux-plugin-sysstat` command invocations.

```
set -g status-interval 5
```

It's adviced to set `status-interval` to some reasonable value, like 5-10 seconds. More frequent updates (1 second) are useless, because they distract, and results in extra resource stress spent on metrics calculation itself.



Internals: CPU calculation
--------------------------------------------------
<span style="color: blue">**NOTE:** Stop here if you want to just use this plugin without making your feet wet. If you're hardcore tmux user and are curious about internals, keep reading</span>

Internally, we use `iostat` and `top` on OSX, and `vmstat` and `top` on Linux to collect metric value. Neither requires you to install extra packages. These commands are run in sampling mode to report stats every N seconds M times. First sample include average values since the system start. Second one is the average CPU per second for last N seconds (exactly what we need)

For example:

```
$ iostat -c 2 -w 5
          disk0       cpu     load average
    KB/t tps  MB/s  us sy id   1m   5m   15m
   44.22   6  0.26   3  2 95  1.74 1.90 2.15
    5.47   8  0.04   4  5 91  1.84 1.92 2.16  << use this row, 2nd sample
```

We align CPU calculation intervals (`-w`) with tmux status bar refresh interval (`status-interval` setting).

Internals: memory calculation
----------------------------
You might ask what we treat as `free` memory and how it's calculated.

### OSX
Let's start with OSX. We use `vm_stat` command (not same as `vmstat` on Linux), which reports following data (number of memory pages, not KB):

```
$ vm_stat
Pages free:                               37279
Pages active:                           1514200
Pages inactive:                         1152997
Pages speculative:                         6214
Pages throttled:                              0
Pages wired down:                       1174408
Pages purgeable:                          15405
Pages stored in compressor:             1615663
Pages occupied by compressor:            306717
```

Total installed memory formula is:
```
Total = free + active + inactive + speculative + occupied by compressor + wired
```

where
- `free`, completely unused memory by the system
- `wired`, critical information stored in RAM by system, kernel and key applications. Never swapped to the hard drive, never replaced with user-level data.
- `active`, information currently in use or very recently used by applications. When this kind of memory is not used for long (or application is closed), it's move to inactive memory.
- `inactive`, like buffers/cached memory in Linux. Memory for applications, which recently exited, retained for faster start-up of same application in future.

So the question what constitutes `free` and `used` memory. It turns out, that various monitoring and system statistics tools on OSX each calculate it differently.

- htop: `used = active + wired`, `free` = `total - used`
- top. Used = `used = active + inactive + occupied by compressor + wired`; Free = `free + speculative` Resident set size (RSS) = `active`
- OSX activity Monitor. Used = `app memory + wired + compressor`. Note, it's not clear what is app memory.

In general, they either treat currently used memory, which can be reclaimed in case of need (cached, inactive, occupied by compressor), as `used` or `free`. 

It makes sense to talk about `available` memory rather than `free` one. Available memory is unused memory + any used memory which can be reclaimed for application needs.

So, `tmux-plugin-sysstat`, uses following formula:

```
used = active + wired
available/free = free/unused + inactive + speculative + occupied by compressor
```

### Linux

Same thinking can be applied to Linux systems.

Usually commands like `free` report free/unused, used, buffers, cache memory kinds.

```
$ free
             total       used       free     shared    buffers     cached
Mem:       1016464     900236     116228      21048      93448     241544
-/+ buffers/cache:     565244     451220
Swap:      1046524     141712     904812
```

Second line indicates available memory (free + buffers + cache), with an assumption that buffers and cache can be 100% reclaimed in case of need.

However, we're not using free, because its output varies per system. For example on RHEL7, there is no `-/+ buffers/cache`, and `available` memory is reported in different way. We read directly from `/proc/meminfo`

```
$ cat /proc/meminfo

MemTotal:        1016232 kB
MemFree:          152672 kB
MemAvailable:     637832 kB
Buffers:               0 kB
Cached:           529040 kB
```

`tmux-plugin-sysstat` uses following formula:

```
free/available = MemAvailable;  // if MemAvailable present
free/available = MemFree + Buffers + Cached;
used = MemTotal - free/avaialble 
```

Using `MemAvailable` is more accurate way of getting available memory, rather than manual calculation `free + buffers + cache`, because the assumption that `buffers + cache` can be 100% reclaimed for new application needs might be wrong. When using `MemAvailable`, OS calculates available memory for you, which is apparently better and accurate approach.

See [this topic](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773) on more reasoning about `MemAvailable` field.
