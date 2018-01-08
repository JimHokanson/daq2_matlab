# Introduction

This code:
1) Handles downsampling of data to allow "sampling" different inputs at different rates. (Almost complete ...)
2) Handles saving of data to disk using a non-blocking save to disk function. See below for more details.
3) Runs output generation on a separate process to allow for dynamic signal generation.
4) Supports plotting acquired signals as they are collected (Requires Interactive Matlab Plot repo).

# Dependencies

1) Matlab DAQ Toolbox
2) Parallel Computing Toolbox
3) https://github.com/JimHokanson/interactive_matlab_plot
4) https://github.com/JimHokanson/plotBig_Matlab
5) (this one will be removed soon) https://github.com/JimHokanson/matlab_standard_library

# Examples

TODO

# Limitations

TODO

# Features in Depth

## Saving to Disk

- Saves to a .mat file using matfile() interface
- Saves data using a separate process so that saving to disk doesn't block your code execution
- Automatically saves the DAQ data
- Allows saving additional data to the file

## Dynamic Signal Generation

TODO

## Interactive Plotting

TODO