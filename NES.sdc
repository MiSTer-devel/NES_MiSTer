derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from {emu|sdram|*} -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -start -setup 2
set_multicycle_path -from {emu|sdram|*} -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -start -hold 1

set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -to {emu|sdram|*} -setup 2
set_multicycle_path -from [get_clocks {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] -to {emu|sdram|*} -hold 1

set_false_path -from {emu|mapper_flags*}
set_false_path -from {emu|downloading*}
