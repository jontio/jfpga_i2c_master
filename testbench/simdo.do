
transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work
vlog -sv -work work +incdir+../lib/i2c +incdir+../lib/common +incdir+../lib/segment_display {i2c_master_testbench.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclone10lp_ver -L rtl_work -L work -voptargs="+acc"  i2c_master_testbench

#add wave -position end -radix hexadecimal sim:/i2c_master_testbench/*
add wave -position end -radix hexadecimal sim:/i2c_master_testbench/i2c_master0/*
run -all
wave zoom full
