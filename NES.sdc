
create_generated_clock -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                       -name SYS_CLK [get_nets emu|clkdiv[1]] -divide_by 4 -duty_cycle 50.00

derive_pll_clocks
derive_clock_uncertainty
