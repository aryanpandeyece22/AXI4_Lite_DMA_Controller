#!/bin/bash

# Exit if any command fails
set -e

# Output simulation executable
OUTPUT=sim.out

# Source folders
SRC_DIR=$(pwd)/RTL

# Find all .v files in the directories
CODE_FILES=$(find $SRC_DIR -name "*.v")

# Combine all Verilog files
ALL_FILES="$CODE_FILES TB.v dma_soc.v"

# Compile all Verilog files
iverilog -o $OUTPUT $ALL_FILES 

# Run the simulation
vvp $OUTPUT

# Open waveform if available
if [ -f dma_dump.vcd ]; then
    echo "Opening waveform with GTKWave..."
    gtkwave dma_dump.vcd &
fi

