vlib work

vlog sdram_controller.v
vlog sdram_controller_tb.v

vsim work.sdram_controller_tb

add wave sim:/sdram_controller_tb/clk
add wave sim:/sdram_controller_tb/reset_n

add wave sim:/sdram_controller_tb/write_req
add wave sim:/sdram_controller_tb/read_req
add wave sim:/sdram_controller_tb/address
add wave sim:/sdram_controller_tb/write_data
add wave sim:/sdram_controller_tb/read_data
add wave sim:/sdram_controller_tb/read_valid
add wave sim:/sdram_controller_tb/busy

add wave sim:/sdram_controller_tb/sdram_cs_n
add wave sim:/sdram_controller_tb/sdram_ras_n
add wave sim:/sdram_controller_tb/sdram_cas_n
add wave sim:/sdram_controller_tb/sdram_we_n
add wave sim:/sdram_controller_tb/sdram_addr
add wave sim:/sdram_controller_tb/sdram_dq
add wave sim:/sdram_controller_tb/sdram_cke

add wave sim:/sdram_controller_tb/dut/state

run -all

wave zoom full