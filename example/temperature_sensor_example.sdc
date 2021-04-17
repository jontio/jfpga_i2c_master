## Generated SDC file "temperature_sensor_example.sdc"

## Copyright (C) 2020  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 20.1.1 Build 720 11/11/2020 SJ Lite Edition"

## DATE    "Sat Apr 17 22:16:51 2021"

##
## DEVICE  "10CL016YU484C8G"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {clk_50M} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_50M}]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {clk_50M}] -rise_to [get_clocks {clk_50M}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {clk_50M}] -fall_to [get_clocks {clk_50M}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_50M}] -rise_to [get_clocks {clk_50M}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {clk_50M}] -fall_to [get_clocks {clk_50M}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************

#not sure what I should do here. i2c is so slow it really doesn't matter but it would be nice to know how to deal with
#these bidirectional ports where the only thing that matters is the skew between the two pins
#set_input_delay -add_delay -max -clock [get_clocks {clk_50M}]  2.000 [get_ports {i2c_*}]
#set_input_delay -add_delay -min -clock [get_clocks {clk_50M}]  0.000 [get_ports {i2c_*}]

#**************************************************************
# Set Output Delay
#**************************************************************

#not sure what I should do here. i2c is so slow it really doesn't matter but it would be nice to know how to deal with
#these bidirectional ports where the only thing that matters is the skew between the two pins rather than relative to clk_50M
#set_output_delay -add_delay -max -clock [get_clocks {clk_50M}]  2.000 [get_ports {i2c_*}]
#set_output_delay -add_delay -min -clock [get_clocks {clk_50M}]  -2.000 [get_ports {i2c_*}]

#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {led segData[0] segData[1] segData[2] segData[3] segData[4] segData[5] segData[6] segData[7] segSelect[0] segSelect[1] segSelect[2]}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Max Skew
#**************************************************************

#not sure what I should do here. i2c is so slow it really doesn't matter but it would be nice to know how to deal with
#these bidirectional ports where the only thing that matters is the skew between the two pins rather than relative to clk_50M
set_max_skew -from [get_ports {i2c_scl_w i2c_sda_w}] -to * 20.000 
