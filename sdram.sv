//
// sdram.v
//
// sdram controller implementation for the MiST board adaptation
// of Luddes NES core
// http://code.google.com/p/mist-board/
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram (

	// interface to the MT48LC16M16 chip
	inout [15:0]  	  sd_data,    // 16 bit bidirectional data bus
	output [12:0]	  sd_addr,    // 13 bit multiplexed address bus
	output [1:0] 	  sd_dqm,     // two byte masks
	output [1:0] 	  sd_ba,      // two banks
	output 			  sd_cs,      // a single chip select
	output 			  sd_we,      // write enable
	output 			  sd_ras,     // row address select
	output 			  sd_cas,     // columns address select

	// cpu/chipset interface
	input 		 	  init,			// init signal after FPGA config to initialize RAM
	input 		 	  clk,			// sdram is accessed at up to 128MHz
	input				  clkref,		// reference clock to sync to
	
	input [24:0]     addr,       // 25 bit byte address
	input 		 	  we,         // cpu/chipset requests write
	input [7:0]  	  din,			// data input from chipset/cpu
	input 		 	  oeA,        // cpu requests data
	output reg [7:0] doutA,	   // data output to cpu
	input 		 	  oeB,        // ppu requests data
	output reg [7:0] doutB, 	   // data output to ppu
	
	input	           bk_clk,
	input	    [14:0] bk_addr,
	input	     [7:0] bk_din,
	output     [7:0] bk_dout,
	input	           bk_we,
	input	    [14:0] bko_addr,
	input	     [7:0] bko_din,
	output     [7:0] bko_dout,
	input	           bko_we,
	input	           bk_override
);

// no burst configured
localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@85MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 


// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_FIRST     = 4'd0;   // first state in cycle
localparam STATE_CMD_START = 4'd1;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // 4 command can be continued
localparam STATE_CMD_READ  = 4'd7;   // read state
localparam STATE_LAST      = 4'd15;  // last state in cycle

reg [3:0] q;
always @(posedge clk) begin
	// SDRAM (state machine) clock is 85MHz. Synchronize this to systems 21.477 Mhz clock
   // force counter to pass state LAST->FIRST exactly after the rising edge of clkref
   if(((q == STATE_LAST) && ( clkref == 1)) ||
		((q == STATE_FIRST) && ( clkref == 0)) ||
      ((q != STATE_LAST) && (q != STATE_FIRST)))
			q <= q + 3'd1;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (85000 cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [16:0] reset;
always @(posedge clk) begin
	if(init)	reset <= 17'h14c08;
	else if((q == STATE_LAST) && (reset != 0))
		reset <= reset - 17'd1;
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

wire [3:0] sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign sd_cs  = sd_cmd[3];
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];

// drive ram data lines when writing, set them as inputs otherwise
// the eight bits are sent on both bytes ports. Which one's actually
// written depends on the state of dqm of which only one is active
// at a time when writing
assign sd_data = we?{din, din}:16'bZZZZZZZZZZZZZZZZ;

wire oe = oeA || oeB;

reg addr0;
always @(posedge clk)
	if((q == 1) && oe) addr0 <= addr[0];

wire    ovr_ena = (addr[24:15] == 10'b0001111000);
wire [7:0] dout = ovr_ena ? dpram_dout : addr0 ? sd_data[7:0] : sd_data[15:8];

always @(posedge clk) begin
	if(q == STATE_CMD_READ) begin
		if(oeA) doutA <= dout;
		if(oeB) doutB <= dout;
	end
end

wire [3:0] reset_cmd = 
	((q == STATE_CMD_START) && (reset == 13))?CMD_PRECHARGE:
	((q == STATE_CMD_START) && (reset ==  2))?CMD_LOAD_MODE:
	CMD_INHIBIT;

wire [3:0] run_cmd =
	((we || oe) && (q == STATE_CMD_START))?CMD_ACTIVE:
	(we && 			(q == STATE_CMD_CONT ))?CMD_WRITE:
	(!we &&  oe &&	(q == STATE_CMD_CONT ))?CMD_READ:
	(!we && !oe && (q == STATE_CMD_START))?CMD_AUTO_REFRESH:
	CMD_INHIBIT;
	
assign sd_cmd = (reset != 0)?reset_cmd:run_cmd;

wire [12:0] reset_addr = (reset == 13)?13'b0010000000000:MODE;
	
wire [12:0] run_addr = 
	(q == STATE_CMD_START)?addr[21:9]:{ 4'b0010, addr[24], addr[8:1]};

assign sd_addr = (reset != 0)?reset_addr:run_addr;

assign sd_ba = addr[23:22];

assign sd_dqm = we?{ addr[0], ~addr[0] }:2'b00;

reg dpram_we;
always @(posedge clk) begin
	reg old_we;
	
	old_we <= we;
	dpram_we <= ~old_we & we & ovr_ena;
end

reg [7:0] dpram_dout;
assign bko_dout = dpram_dout;

ovr_dpram ovr_ram
(
	.clock_a(clk),
	.address_a(bk_override ? bko_addr : addr[14:0]),
	.data_a(bk_override ? bko_din : din),
	.wren_a(bk_override ? bko_we : dpram_we),
	.q_a(dpram_dout),

	.clock_b(bk_clk),
	.address_b(bk_addr),
	.data_b(bk_din),
	.wren_b(bk_we),
	.q_b(bk_dout)
);

endmodule

//////////////////////////////////////////////

module ovr_dpram
(
	input	[14:0] address_a,
	input	[14:0] address_b,
	input	       clock_a,
	input	       clock_b,
	input	 [7:0] data_a,
	input	 [7:0] data_b,
	input	       wren_a,
	input	       wren_b,
	output [7:0] q_a,
	output [7:0] q_b
);

altsyncram	altsyncram_component
(
	.address_a (address_a),
	.address_b (address_b),
	.clock0 (clock_a),
	.clock1 (clock_b),
	.data_a (data_a),
	.data_b (data_b),
	.wren_a (wren_a),
	.wren_b (wren_b),
	.q_a (q_a),
	.q_b (q_b),
	.aclr0 (1'b0),
	.aclr1 (1'b0),
	.addressstall_a (1'b0),
	.addressstall_b (1'b0),
	.byteena_a (1'b1),
	.byteena_b (1'b1),
	.clocken0 (1'b1),
	.clocken1 (1'b1),
	.clocken2 (1'b1),
	.clocken3 (1'b1),
	.eccstatus (),
	.rden_a (1'b1),
	.rden_b (1'b1)
);
defparam
	altsyncram_component.address_reg_b = "CLOCK1",
	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_input_b = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.clock_enable_output_b = "BYPASS",
	altsyncram_component.indata_reg_b = "CLOCK1",
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.numwords_a = 32768,
	altsyncram_component.numwords_b = 32768,
	altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.outdata_aclr_b = "NONE",
	altsyncram_component.outdata_reg_a = "UNREGISTERED",
	altsyncram_component.outdata_reg_b = "UNREGISTERED",
	altsyncram_component.power_up_uninitialized = "FALSE",
	altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
	altsyncram_component.widthad_a = 15,
	altsyncram_component.widthad_b = 15,
	altsyncram_component.width_a = 8,
	altsyncram_component.width_b = 8,
	altsyncram_component.width_byteena_a = 1,
	altsyncram_component.width_byteena_b = 1,
	altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";


endmodule
