
set proj_name   10gbs_ethernet_pcs_mac
set proj_dir    ./proj_dir
set top_module  eth_10g_top.sv
set part        xc7a35tcsg324-1

# Create project in Vivado
create_project $proj_name $proj_dir -part $part -force

# Get the directory of the running script
set script_dir [file dirname [file normalize [info script]]]
set proj_root [file dirname $script_dir]

# RTL files
foreach file [glob -nocomplain "$proj_root/rtl/*.sv"] {
    puts "Adding RTL File $file"
    add_files $file
}

# Get the constraints fileset
set constr_fs [get_filesets constrs_1]

# Add each XDC file to that fileset
foreach file [glob -nocomplain "$proj_root/xdc/*.xdc"] {
    puts "Adding XDC File $file to constraints fileset"
    add_files -fileset $constr_fs $file
}

# Set top module
set_property top $top_module [get_filesets sources_1]

puts "Project creation and bitstream generation complete!"