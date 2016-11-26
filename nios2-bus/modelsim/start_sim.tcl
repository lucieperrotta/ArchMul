#!/usr/local/bin/tclsh

# Get all the source files
set ignore_vhd {../vhdl/soc/clk_pll.vhd}
set subfolders {includes common core memory_hierarchy soc testbenches}

foreach subfolder $subfolders {
    set subfolder_path "../vhdl/${subfolder}"
    set vhd_files {}
    if {[file isdirectory  $subfolder_path]} {
        set vhd_files_all [glob -dir $subfolder_path -nocomplain *.vhd]
        # Filter ignored files out
        foreach vhd_file $vhd_files_all {
            if { [lsearch $ignore_vhd $vhd_file] < 0 } {
                lappend vhd_files $vhd_file
            }
        }
       }
    puts $vhd_files
    if { $vhd_files ne "" } {
           set fd [ open "${subfolder}.tmp" "w" ]
           puts $fd $vhd_files
           close $fd
    }
              
}


# Start a library
file delete -force -- work
vlib work

# Compile everything
foreach subfolder $subfolders {
    vcom -work work -2008 -check_synthesis -lint -f ${subfolder}.tmp
}

file delete {*} [glob -nocomplain *.tmp]
