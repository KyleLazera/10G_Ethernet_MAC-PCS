# 10G Ethernet PCS/MAC

This project implements a **10G Ethernet MAC/PCS** optimized for **minimal latency per byte of data**.  
It builds upon my previous [UDP/IP Ethernet stack](https://github.com/KyleLazera/udp-ip-mac-core) and focuses on 10G Ethernet architecture — including 64b/66b encoding, scrambling, and gearbox interfacing with GTY transceivers.

Project documentation can be found here: [10 Gbps Ethernet Project Documentation](https://docs.google.com/document/d/1BccegNxokFsk6skow2dmSL8w7UbbWKO5YEqboq8Fin8/edit?tab=t.0)

## Project Structure

10gbs_ethernet_pcs_mac/
├── build_project.tcl               # Vivado TCL build script
├── build_project.sh                # Bash script that runs the TCL script
├── rtl/                            # RTL source files (.sv)
├── xdc/                            # Constraint files (.xdc)
└── proj_dir/                       # Vivado project output directory (auto-generated)

## Requirements

To build and simulate this project, ensure the following tools are installed:

- **Vivado 2020.2** or later  
- **Git**  
- **Bash shell** (Linux/macOS; Windows users can use Git Bash or WSL)

## Overview

The build process is fully automated using a **TCL script** and a **Bash wrapper**.  
The TCL script creates a Vivado project, adds all RTL and constraint files, sets the top module, and prepares the design for synthesis and implementation.

## Build Instructions

Follow these steps to clone and build the project on your machine:

1. **Clone the Repository**
    Use the following instruction to clone the project onto your local machine:

        ```git clone git@github.com:KyleLazera/10G_Ethernet_MAC-PCS.git```

    Navigate to the scripts folder within the local repo:
    
        ```cd 10gbs_ethernet_pcs_mac/scripts```

2. **Build the Project**
    Run the following command in the top level folder of the project:

    ```./build_project.sh```

    This script will do the following: 

        Launch Vivado in batch mode

        Run the build_project.tcl script

        Create the Vivado project under proj_dir/

        Add all .sv and .xdc files

        Set the top-level module (pcs)

