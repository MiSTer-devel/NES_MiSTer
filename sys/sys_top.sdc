create_clock -period "50.0 MHz" [get_ports FPGA_CLK1_50]
create_clock -period "50.0 MHz" [get_ports FPGA_CLK2_50]
create_clock -period "50.0 MHz" [get_ports FPGA_CLK3_50]
create_clock -period "100.0 MHz" [get_pins -compatibility_mode *|h2f_user0_clk] 

derive_pll_clocks

create_generated_clock -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                      -name clk_dram_ext [get_ports {SDRAM_CLK}]


derive_clock_uncertainty


set_input_delay -max -clock clk_dram_ext 1.0ns [get_ports SDRAM_DQ[*]]
set_input_delay -min -clock clk_dram_ext 1.1ns [get_ports SDRAM_DQ[*]]

set_output_delay -max -clock clk_dram_ext -1.6ns [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -min -clock clk_dram_ext -1.5ns [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_false_path -from * -to [get_ports {LED_*}]
set_false_path -from * -to [get_ports {BTN_*}]
set_false_path -from * -to [get_ports {VGA_*}]
set_false_path -from * -to [get_ports {AUDIO_L}]
set_false_path -from * -to [get_ports {AUDIO_R}]
