// These are misc small one-off mappers. Some may end up being merged with Generic mappers.
// altera message_off 10027
// #15 -  100-in-1 Contra Function 16
module Mapper15(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;


// 15 bit  8 7  bit  0  Address bus
// ---- ---- ---- ----
// 1xxx xxxx xxxx xxSS
// |                ||
// |                ++- Select PRG ROM bank mode
// |                    0: 32K; 1: 128K (UNROM style); 2: 8K; 3: 16K
// +------------------- Always 1
// 7  bit  0  Data bus
// ---- ----
// bMBB BBBB
// |||| ||||
// ||++-++++- Select 16 KB PRG ROM bank
// |+-------- Select nametable mirroring mode (0=vertical; 1=horizontal)
// +--------- Select 8 KB half of 16 KB PRG ROM bank
//            (should be 0 except in bank mode 0)
reg [1:0] prg_rom_bank_mode;
reg prg_rom_bank_lowbit;
reg mirroring;
reg [5:0] prg_rom_bank;

always @(posedge clk) begin
	if (~enable) begin
		prg_rom_bank_mode <= 0;
		prg_rom_bank_lowbit <= 0;
		mirroring <= 0;
		prg_rom_bank <= 0;
	end else if (ce) begin
		if (prg_ain[15] && prg_write)
			{prg_rom_bank_mode, prg_rom_bank_lowbit, mirroring, prg_rom_bank} <= {prg_ain[1:0], prg_din[7:0]};
	end
end

reg [6:0] prg_bank;
always begin
	casez({prg_rom_bank_mode, prg_ain[14]})
		// Bank mode 0 ( 32K ) / CPU $8000-$BFFF: Bank B / CPU $C000-$FFFF: Bank (B OR 1)
		3'b00_0: prg_bank = {prg_rom_bank, prg_ain[13]};
		3'b00_1: prg_bank = {prg_rom_bank | 6'b1, prg_ain[13]};
		// Bank mode 1 ( 128K ) / CPU $8000-$BFFF: Switchable 16 KB bank B / CPU $C000-$FFFF: Fixed to last bank in the cart
		3'b01_0: prg_bank = {prg_rom_bank, prg_ain[13]};
		3'b01_1: prg_bank = {6'b111111, prg_ain[13]};
		// Bank mode 2 ( 8K ) / CPU $8000-$9FFF: Sub-bank b of 16 KB PRG ROM bank B / CPU $A000-$FFFF: Mirrors of $8000-$9FFF
		3'b10_?: prg_bank = {prg_rom_bank, prg_rom_bank_lowbit};
		// Bank mode 3 ( 16K ) / CPU $8000-$BFFF: 16 KB bank B / CPU $C000-$FFFF: Mirror of $8000-$BFFF
		3'b11_?: prg_bank = {prg_rom_bank, prg_ain[13]};
	endcase
end

assign prg_aout = {2'b00, prg_bank, prg_ain[12:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15]; // CHR RAM?
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];

endmodule


// Mapper 16, 153, 159 Bandai
module Mapper16(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// Special ports
	output [17:0] mapper_addr,
	input   [7:0] mapper_data_in,
	output  [7:0] mapper_data_out,
	output        mapper_prg_write,
	output        mapper_ovr,
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
reg vram_a10;
wire vram_ce;
reg irq;
wire [15:0] flags_out = {12'h0, 1'b1, 1'b0, prg_bus_write, 1'b0};
wire [7:0] prg_dout;

reg outer_prg_bank;
reg [3:0] inner_prg_bank;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
			chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
reg [3:0] prg_sel;
reg [1:0] mirroring;
reg irq_enable;
reg irq_up;
reg [15:0] irq_counter;
reg [15:0] irq_latch;
reg eeprom_scl, eeprom_sda;
wire submapper5 = (flags[24:21] == 5);
wire mapper153 = (flags[7:0] == 153);
wire mapper159 = (flags[7:0] == 159);
wire mapperalt = submapper5 | mapper159 | mapper153;

always @(posedge clk) begin
	if (~enable) begin
		outer_prg_bank <= 0;
		inner_prg_bank <= 0;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		chr_bank_2 <= 0;
		chr_bank_3 <= 0;
		chr_bank_4 <= 0;
		chr_bank_5 <= 0;
		chr_bank_6 <= 0;
		chr_bank_7 <= 0;
		mirroring <= 0;
		irq_counter <= 0;
		irq_latch <= 0;
		irq_up <= 0;
		eeprom_scl <= 0;
		eeprom_sda <= 0;
	end else if (SaveStateBus_load) begin
		chr_bank_0     <= SS_MAP1[ 7: 0];
		chr_bank_1     <= SS_MAP1[15: 8];
		chr_bank_2     <= SS_MAP1[23:16];
		chr_bank_3     <= SS_MAP1[31:24];
		chr_bank_4     <= SS_MAP1[39:32];
		chr_bank_5     <= SS_MAP1[47:40];
		chr_bank_6     <= SS_MAP1[55:48];
		chr_bank_7     <= SS_MAP1[63:56];
		outer_prg_bank <= SS_MAP2[    0];
		inner_prg_bank <= SS_MAP2[ 4: 1];
		irq            <= SS_MAP2[    5];
		prg_sel        <= SS_MAP2[ 9: 6];
		mirroring      <= SS_MAP2[11:10];
		irq_enable     <= SS_MAP2[   12];
		irq_up         <= SS_MAP2[   13];
		irq_counter    <= SS_MAP2[29:14];
		irq_latch      <= SS_MAP2[45:30];
		eeprom_scl     <= SS_MAP2[   46];
		eeprom_sda     <= SS_MAP2[   47];
	end else if (ce) begin
		irq_up <= 1'b0;
		if (prg_write)
			if(((prg_ain[14:13] == 2'b11) && (!mapperalt)) || (prg_ain[15])) // Cover all from $6000 to $FFFF to maximize compatibility
				case(prg_ain & 'hf) // Registers are mapped every 16 bytes
					'h0: if (!mapper153) chr_bank_0 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h1: if (!mapper153) chr_bank_1 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h2: if (!mapper153) chr_bank_2 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h3: if (!mapper153) chr_bank_3 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h4: if (!mapper153) chr_bank_4 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h5: if (!mapper153) chr_bank_5 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h6: if (!mapper153) chr_bank_6 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h7: if (!mapper153) chr_bank_7 <= prg_din[7:0]; else outer_prg_bank <= prg_din[0];
					'h8: inner_prg_bank <= prg_din[3:0];
					'h9: mirroring <= prg_din[1:0];
					'ha: {irq_up, irq_enable} <= {1'b1, prg_din[0]};
					'hb: begin
						if (mapperalt)
							irq_latch[7:0] <= prg_din[7:0];
						else
							irq_counter[7:0] <= prg_din[7:0];
					end

					'hc: begin
						if (mapperalt)
							irq_latch[15:8] <= prg_din[7:0];
						else
							irq_counter[15:8] <= prg_din[7:0];
					end

					'hd: {eeprom_sda, eeprom_scl} <= prg_din[6:5]; //RAM enable or EEPROM control
				endcase

		if (irq_enable)
			irq_counter <= irq_counter - 16'd1;

		if (irq_up) begin
			irq <= 1'b0; // IRQ ACK
			if (mapperalt)
				irq_counter <= irq_latch;
		end

		if ((irq_counter == 16'h0000) && (irq_enable))
			irq <= 1'b1; // IRQ
	end
end

assign SS_MAP1_BACK[ 7: 0] = chr_bank_0;
assign SS_MAP1_BACK[15: 8] = chr_bank_1;
assign SS_MAP1_BACK[23:16] = chr_bank_2;
assign SS_MAP1_BACK[31:24] = chr_bank_3;
assign SS_MAP1_BACK[39:32] = chr_bank_4;
assign SS_MAP1_BACK[47:40] = chr_bank_5;
assign SS_MAP1_BACK[55:48] = chr_bank_6;
assign SS_MAP1_BACK[63:56] = chr_bank_7;
assign SS_MAP2_BACK[    0] = outer_prg_bank;
assign SS_MAP2_BACK[ 4: 1] = inner_prg_bank;
assign SS_MAP2_BACK[    5] = irq;
assign SS_MAP2_BACK[ 9: 6] = prg_sel;
assign SS_MAP2_BACK[11:10] = mirroring;
assign SS_MAP2_BACK[   12] = irq_enable;
assign SS_MAP2_BACK[   13] = irq_up;
assign SS_MAP2_BACK[29:14] = irq_counter;
assign SS_MAP2_BACK[45:30] = irq_latch;
assign SS_MAP2_BACK[   46] = eeprom_scl;
assign SS_MAP2_BACK[   47] = eeprom_sda;
assign SS_MAP2_BACK[63:48] = 16'b0; // free to be used

always begin
	// mirroring
	casez(mirroring[1:0])
		2'b00:   vram_a10 = {chr_ain[10]};    // vertical
		2'b01:   vram_a10 = {chr_ain[11]};    // horizontal
		2'b1?:   vram_a10 = {mirroring[0]};   // single screen lower
	endcase
end

reg [4:0] prgsel;
always begin
	case(prg_ain[15:14])
		2'b10: 	 prgsel = {outer_prg_bank, inner_prg_bank};  // $8000 is swapable
		2'b11: 	 prgsel = {outer_prg_bank, 4'hF};            // $C000 is hardwired to last inner bank
		default: prgsel = 0;
	endcase
end

reg [7:0] chrsel;
always begin
	casez(chr_ain[12:10])
		0: chrsel = chr_bank_0;
		1: chrsel = chr_bank_1;
		2: chrsel = chr_bank_2;
		3: chrsel = chr_bank_3;
		4: chrsel = chr_bank_4;
		5: chrsel = chr_bank_5;
		6: chrsel = chr_bank_6;
		7: chrsel = chr_bank_7;
	endcase
end

assign chr_aout = mapper153 ? {9'b10_0000_000, chr_ain[12:0]} : {4'b10_00, chrsel, chr_ain[9:0]}; // 1kB banks or 8kb unbanked
wire [21:0] prg_aout_tmp = {3'b00_0, prgsel, prg_ain[13:0]};  // 16kB banks

wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
// EEPROM - not used - Could use write to EEPROM cycle for both reads and write accesses, but this is easier
assign prg_dout = (!mapper153 && prg_is_ram) ? prg_write ? mapper_data_out : {3'b111, sda_out, 4'b1111} : 8'hFF;
wire prg_bus_write = (!mapper153 && prg_is_ram);

assign prg_allow = (prg_ain[15] && !prg_write) || (prg_is_ram && eeprom_scl && mapper153);
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

wire sda_out;
wire [7:0] ram_addr;
wire ram_read;
assign mapper_addr[17:8] = 0;
assign mapper_addr[7:0] = ram_addr;
assign mapper_ovr = mapper159 || submapper5;

EEPROM_24C0x eeprom(
	.type_24C01(mapper159),         //24C01 is 128 bytes, 24C02 is 256 bytes
	.page_mask(4'h3),               //all NES appear to use 4 bytes in writing
	.no_test_state(mapper159),      //all 24C01 used by NES appear to be X24C01, which don't use test_state
	.address_write_only(!mapper159),//described in 24C0xA docs, appears 24C02 in mapper 16.5 uses this, which only specify address on write commands
	.clk(clk),
	.ce(ce),
	.reset(~enable),
	.SCL(eeprom_scl),               // Serial Clock
	.SDA_in(eeprom_sda),            // Serial Data (same pin as below, split for convenience)
	.SDA_out(sda_out),              // Serial Data (same pin as above, split for convenience)
	.E_id(3'b000),                  // Chip Enable
	.WC_n(1'b0),                    // ~Write Control
	.data_from_ram(mapper_data_in), // Data read from RAM
	.data_to_ram(mapper_data_out),  // Data written to RAM
	.ram_addr(ram_addr),            // RAM Address
	.ram_read(ram_read),            // RAM read
	.ram_write(mapper_prg_write),   // RAM write
	.ram_done(1'b1),                // RAM access done
	// savestates
	.SaveStateBus_Din  (SaveStateBus_Din ), 
	.SaveStateBus_Adr  (SaveStateBus_Adr ),
	.SaveStateBus_wren (SaveStateBus_wren),
	.SaveStateBus_rst  (SaveStateBus_rst ),
	.SaveStateBus_load (SaveStateBus_load ),
	.SaveStateBus_Dout (SaveStateBus_wired_or[2])
);

// savestate
localparam SAVESTATE_MODULES    = 3;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2];
	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

// Mapper 18, Jaleco SS88006
module Mapper18(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
reg vram_a10;
reg irq;
wire [7:0] prg_dout;
wire vram_ce;
reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};

reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
			chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
reg [1:0] mirroring;
reg irq_ack;
reg [3:0] irq_enable;
reg [15:0] irq_reload;
reg [15:0] irq_counter;
reg [1:0] ram_enable;

always @(posedge clk)
if (~enable) begin
	prg_bank_0 <= 8'hFF;
	prg_bank_1 <= 8'hFF;
	prg_bank_2 <= 8'hFF;
	chr_bank_0 <= 0;
	chr_bank_1 <= 0;
	chr_bank_2 <= 0;
	chr_bank_3 <= 0;
	chr_bank_4 <= 0;
	chr_bank_5 <= 0;
	chr_bank_6 <= 0;
	chr_bank_7 <= 0;
	mirroring <= 0;
	irq_reload <= 0;
	irq_counter <= 0;
	irq_enable <= 4'h0;
end else if (SaveStateBus_load) begin
	chr_bank_0         <= SS_MAP1[ 7: 0];
	chr_bank_1         <= SS_MAP1[15: 8];
	chr_bank_2         <= SS_MAP1[23:16];
	chr_bank_3         <= SS_MAP1[31:24];
	chr_bank_4         <= SS_MAP1[39:32];
	chr_bank_5         <= SS_MAP1[47:40];
	chr_bank_6         <= SS_MAP1[55:48];
	chr_bank_7         <= SS_MAP1[63:56];
	prg_bank_0         <= SS_MAP2[ 7: 0];
	prg_bank_1         <= SS_MAP2[15: 8];
	prg_bank_2         <= SS_MAP2[23:16];
	irq_reload         <= SS_MAP2[39:24];
	irq_counter        <= SS_MAP2[55:40];
	irq_enable         <= SS_MAP2[59:56];
	irq                <= SS_MAP2[   60];
	irq_ack            <= SS_MAP2[   61];
	mirroring          <= SS_MAP2[63:62];
	ram_enable         <= SS_MAP3[ 1: 0];
end else if (ce) begin
	irq_ack <= 1'b0;

	//Is this necessary? or even correct?  Just load number of needed bits into separate counter instead?
	if (irq_enable[0]) begin
		irq_counter[3:0] <= irq_counter[3:0] - 4'd1;
		if (irq_counter[3:0] == 4'h0) begin
			if (irq_enable[3]) begin
				irq <= 1'b1; // IRQ
			end else begin
				irq_counter[7:4] <= irq_counter[7:4] - 4'd1;
				if (irq_counter[7:4] == 4'h0) begin
					if (irq_enable[2]) begin
						irq <= 1'b1; // IRQ
					end else begin
						irq_counter[11:8] <= irq_counter[11:8] - 4'd1;
						if (irq_counter[11:8] == 4'h0) begin
							if (irq_enable[1]) begin
								irq <= 1'b1; // IRQ
							end else begin
								irq_counter[15:12] <= irq_counter[15:12] - 4'd1;
								if (irq_counter[15:12] == 4'h0) begin
									irq <= 1'b1; // IRQ
								end
							end
						end
					end
				end
			end
		end
	end

	if (prg_write)
		if(prg_ain[15]) // Cover all from $8000 to $FFFF to maximize compatibility
			case({prg_ain[14:12],prg_ain[1:0]})
				5'b000_00: prg_bank_0[3:0] <= prg_din[3:0];
				5'b000_01: prg_bank_0[7:4] <= prg_din[3:0];
				5'b000_10: prg_bank_1[3:0] <= prg_din[3:0];
				5'b000_11: prg_bank_1[7:4] <= prg_din[3:0];
				5'b001_00: prg_bank_2[3:0] <= prg_din[3:0];
				5'b001_01: prg_bank_2[7:4] <= prg_din[3:0];
				5'b001_10: ram_enable <= prg_din[1:0];
				5'b010_00: chr_bank_0[3:0] <= prg_din[3:0];
				5'b010_01: chr_bank_0[7:4] <= prg_din[3:0];
				5'b010_10: chr_bank_1[3:0] <= prg_din[3:0];
				5'b010_11: chr_bank_1[7:4] <= prg_din[3:0];
				5'b011_00: chr_bank_2[3:0] <= prg_din[3:0];
				5'b011_01: chr_bank_2[7:4] <= prg_din[3:0];
				5'b011_10: chr_bank_3[3:0] <= prg_din[3:0];
				5'b011_11: chr_bank_3[7:4] <= prg_din[3:0];
				5'b100_00: chr_bank_4[3:0] <= prg_din[3:0];
				5'b100_01: chr_bank_4[7:4] <= prg_din[3:0];
				5'b100_10: chr_bank_5[3:0] <= prg_din[3:0];
				5'b100_11: chr_bank_5[7:4] <= prg_din[3:0];
				5'b101_00: chr_bank_6[3:0] <= prg_din[3:0];
				5'b101_01: chr_bank_6[7:4] <= prg_din[3:0];
				5'b101_10: chr_bank_7[3:0] <= prg_din[3:0];
				5'b101_11: chr_bank_7[7:4] <= prg_din[3:0];
				5'b110_00: irq_reload[3:0] <= prg_din[3:0];
				5'b110_01: irq_reload[7:4] <= prg_din[3:0];
				5'b110_10: irq_reload[11:8] <= prg_din[3:0];
				5'b110_11: irq_reload[15:12] <= prg_din[3:0];
				5'b111_00: {irq_ack, irq_counter} <= {1'b1, irq_reload};
				5'b111_01: {irq_ack, irq_enable} <= {1'b1, prg_din[3:0]};
				5'b111_10: mirroring <= prg_din[1:0];

			endcase

	if (irq_ack)
		irq <= 1'b0; // IRQ ACK
end

assign SS_MAP1_BACK[ 7: 0] = chr_bank_0;
assign SS_MAP1_BACK[15: 8] = chr_bank_1;
assign SS_MAP1_BACK[23:16] = chr_bank_2;
assign SS_MAP1_BACK[31:24] = chr_bank_3;
assign SS_MAP1_BACK[39:32] = chr_bank_4;
assign SS_MAP1_BACK[47:40] = chr_bank_5;
assign SS_MAP1_BACK[55:48] = chr_bank_6;
assign SS_MAP1_BACK[63:56] = chr_bank_7;
assign SS_MAP2_BACK[ 7: 0] = prg_bank_0;
assign SS_MAP2_BACK[15: 8] = prg_bank_1;
assign SS_MAP2_BACK[23:16] = prg_bank_2;
assign SS_MAP2_BACK[39:24] = irq_reload;
assign SS_MAP2_BACK[55:40] = irq_counter;
assign SS_MAP2_BACK[59:56] = irq_enable;
assign SS_MAP2_BACK[   60] = irq;
assign SS_MAP2_BACK[   61] = irq_ack;
assign SS_MAP2_BACK[63:62] = mirroring;
assign SS_MAP3_BACK[ 1: 0] = ram_enable;
assign SS_MAP3_BACK[63: 2] = 62'b0; // free to be used

always begin
	// mirroring
	casez(mirroring[1:0])
		2'b00: vram_a10 = {chr_ain[11]};    // horizontal
		2'b01: vram_a10 = {chr_ain[10]};    // vertical
		2'b1?: vram_a10 = {mirroring[0]};   // single screen lower
	endcase
end

reg [7:0] prgsel;
always begin
	case(prg_ain[14:13])
		2'b00: prgsel = prg_bank_0;      // $8000 is swapable
		2'b01: prgsel = prg_bank_1;      // $A000 is swapable
		2'b10: prgsel = prg_bank_2;      // $C000 is swapable
		2'b11: prgsel = 8'hFF;           // $E000 is hardwired to last bank
	endcase
end

reg [7:0] chrsel;
always begin
	casez(chr_ain[12:10])
	0: chrsel = chr_bank_0;
	1: chrsel = chr_bank_1;
	2: chrsel = chr_bank_2;
	3: chrsel = chr_bank_3;
	4: chrsel = chr_bank_4;
	5: chrsel = chr_bank_5;
	6: chrsel = chr_bank_6;
	7: chrsel = chr_bank_7;
	endcase
end

assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};                 // 1kB banks
wire [21:0] prg_aout_tmp = {2'b00, prgsel[6:0], prg_ain[12:0]};     // 8kB banks

wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
assign prg_dout = 8'hFF;

assign prg_allow = (prg_ain[15] && !prg_write) || (prg_is_ram && ram_enable[0] && (ram_enable[1] || !prg_write));
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

// savestate
localparam SAVESTATE_MODULES    = 3;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2, SS_MAP3;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK, SS_MAP3_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1] | SaveStateBus_wired_or[2];
	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  
eReg_SavestateV #(SSREG_INDEX_MAP3, 64'h0000000000000000) iREG_SAVESTATE_MAP3 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[2], SS_MAP3_BACK, SS_MAP3);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

// 32 - IREM
module Mapper32(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
reg vram_a10;
wire vram_ce;
reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};

reg [4:0] prgreg0;
reg [4:0] prgreg1;
reg [7:0] chrreg0;
reg [7:0] chrreg1;
reg [7:0] chrreg2;
reg [7:0] chrreg3;
reg [7:0] chrreg4;
reg [7:0] chrreg5;
reg [7:0] chrreg6;
reg [7:0] chrreg7;
reg prgmode;
reg mirror;
wire submapper1 = (flags[21] == 1); // default (0) default submapper; (1) Major League
wire ram_support = (flags[29:26] == 4'd7); // Image Fight (Japan)
reg [4:0] prgsel;
reg [7:0] chrsel;

always @(posedge clk)
if (~enable) begin
		prgmode <= 1'b0;
end else if (SaveStateBus_load) begin
	chrreg0         <= SS_MAP1[ 7: 0];
	chrreg1         <= SS_MAP1[15: 8];
	chrreg2         <= SS_MAP1[23:16];
	chrreg3         <= SS_MAP1[31:24];
	chrreg4         <= SS_MAP1[39:32];
	chrreg5         <= SS_MAP1[47:40];
	chrreg6         <= SS_MAP1[55:48];
	chrreg7         <= SS_MAP1[63:56];
	prgreg0         <= SS_MAP2[ 4: 0];
	prgreg1         <= SS_MAP2[ 9: 5];
	prgmode         <= SS_MAP2[   10];
	mirror          <= SS_MAP2[   11];
end else if (ce) begin
	if ((prg_ain[15:14] == 2'b10) & prg_write) begin
		casez ({prg_ain[13:12], submapper1, prg_ain[2:0]})
			6'b00_?_???:  prgreg0            <= prg_din[4:0];
			6'b01_0_???:  {prgmode, mirror}  <= prg_din[1:0];
			6'b10_?_???:  prgreg1            <= prg_din[4:0];
			6'b11_?_000:  chrreg0            <= prg_din;
			6'b11_?_001:  chrreg1            <= prg_din;
			6'b11_?_010:  chrreg2            <= prg_din;
			6'b11_?_011:  chrreg3            <= prg_din;
			6'b11_?_100:  chrreg4            <= prg_din;
			6'b11_?_101:  chrreg5            <= prg_din;
			6'b11_?_110:  chrreg6            <= prg_din;
			6'b11_?_111:  chrreg7            <= prg_din;
		endcase
	end
end

assign SS_MAP1_BACK[ 7: 0] = chrreg0;
assign SS_MAP1_BACK[15: 8] = chrreg1;
assign SS_MAP1_BACK[23:16] = chrreg2;
assign SS_MAP1_BACK[31:24] = chrreg3;
assign SS_MAP1_BACK[39:32] = chrreg4;
assign SS_MAP1_BACK[47:40] = chrreg5;
assign SS_MAP1_BACK[55:48] = chrreg6;
assign SS_MAP1_BACK[63:56] = chrreg7;
assign SS_MAP2_BACK[ 4: 0] = prgreg0;
assign SS_MAP2_BACK[ 9: 5] = prgreg1;
assign SS_MAP2_BACK[   10] = prgmode;
assign SS_MAP2_BACK[   11] = mirror;
assign SS_MAP2_BACK[63:12] = 52'b0; // free to be used

always begin
	// mirroring mode
	casez({submapper1, mirror})
		2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
		2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
		2'b1?   :   vram_a10 = {1'b1};           // 1 screen lower
	endcase

	// PRG ROM bank size select
	casez({prg_ain[14:13], prgmode})
		3'b000  :  prgsel = prgreg0;
		3'b001  :  prgsel = {5'b11110};
		3'b01?  :  prgsel = prgreg1;
		3'b100  :  prgsel = {5'b11110};
		3'b101  :  prgsel = prgreg0;
		3'b11?  :  prgsel = {5'b11111};
	endcase

	// CHR ROM bank size select
	casez({chr_ain[12:10]})
		3'b000  :  chrsel = chrreg0;
		3'b001  :  chrsel = chrreg1;
		3'b010  :  chrsel = chrreg2;
		3'b011  :  chrsel = chrreg3;
		3'b100  :  chrsel = chrreg4;
		3'b101  :  chrsel = chrreg5;
		3'b110  :  chrsel = chrreg6;
		3'b111  :  chrsel = chrreg7;
	endcase
end

wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
wire prg_is_ram = (prg_ain[15:13] == 3'b011) && ram_support; // $6000-$7FFF

assign vram_ce = chr_ain[13];
assign prg_aout = prg_is_ram ? prg_ram : {4'b00_00, prgsel, prg_ain[12:0]};
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
assign chr_allow = flags[15];
assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};

// savestate
localparam SAVESTATE_MODULES    = 2;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1];
	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule

// Mapper 42, used for hacked FDS games converted to cartridge form
module Mapper42(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg irq;
reg [15:0] flags_out = 0;


reg [3:0] prg_bank;
reg [3:0] chr_bank;
reg [3:0] prg_sel;
reg mirroring;
reg irq_enable;
reg [14:0] irq_counter;

always @(posedge clk)
if (~enable) begin
	prg_bank <= 0;
	chr_bank <= 0;
	mirroring <= flags[14];
	irq_counter <= 0;
end else if (ce) begin
	if (prg_write)
		case(prg_ain & 16'he003)
			16'h8000: chr_bank <= prg_din[3:0];
			16'he000: prg_bank <= prg_din[3:0];
			16'he001: mirroring <= prg_din[3];
			16'he002: irq_enable <= prg_din[1];
		endcase

	if (irq_enable)
		irq_counter <= irq_counter + 15'd1;
	else begin
		irq <= 1'b0;	// ACK
		irq_counter <= 0;
	end

	if (irq_counter == 15'h6000)
		irq <= 1'b1;
end

always @* begin
	// PRG bank selection
	// 6000-7FFF: Selectable
	// 8000-9FFF: bank #0Ch
	// A000-BFFF: bank #0Dh
	// C000-DFFF: bank #0Eh
	// E000-FFFF: bank #0Fh
	case(prg_ain[15:13])
		3'b011: 	prg_sel = prg_bank;                // $6000-$7FFF
		3'b100: 	prg_sel = 4'hC;
		3'b101: 	prg_sel = 4'hD;
		3'b110: 	prg_sel = 4'hE;
		3'b111: 	prg_sel = 4'hF;
		default: prg_sel = 0;
	endcase
end

assign prg_aout = {5'b0, prg_sel, prg_ain[12:0]};       // 8kB banks
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]}; // 8kB banks

assign prg_allow = (prg_ain >= 16'h6000) && !prg_write;
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];
assign vram_a10 = mirroring ? chr_ain[10] : chr_ain[11];

endmodule


// Mapper 65, IREM H3001
module Mapper65(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
reg vram_a10;
wire vram_ce;
reg irq;
reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};

reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
	chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
reg mirroring;
reg irq_ack;
reg irq_enable;
reg [15:0] irq_reload;
reg [15:0] irq_counter;

always @(posedge clk)
if (~enable) begin
	prg_bank_0 <= 8'h00;
	prg_bank_1 <= 8'h01;
	prg_bank_2 <= 8'hFE;
	chr_bank_0 <= 0;
	chr_bank_1 <= 0;
	chr_bank_2 <= 0;
	chr_bank_3 <= 0;
	chr_bank_4 <= 0;
	chr_bank_5 <= 0;
	chr_bank_6 <= 0;
	chr_bank_7 <= 0;
	mirroring <= 0;
	irq_reload <= 0;
	irq_counter <= 0;
	irq_enable <= 0;
end else if (SaveStateBus_load) begin
	chr_bank_0         <= SS_MAP1[ 7: 0];
	chr_bank_1         <= SS_MAP1[15: 8];
	chr_bank_2         <= SS_MAP1[23:16];
	chr_bank_3         <= SS_MAP1[31:24];
	chr_bank_4         <= SS_MAP1[39:32];
	chr_bank_5         <= SS_MAP1[47:40];
	chr_bank_6         <= SS_MAP1[55:48];
	chr_bank_7         <= SS_MAP1[63:56];
	prg_bank_0         <= SS_MAP2[ 7: 0];
	prg_bank_1         <= SS_MAP2[15: 8];
	prg_bank_2         <= SS_MAP2[23:16];
	irq_reload         <= SS_MAP2[39:24];
	irq_counter        <= SS_MAP2[55:40];
	irq_enable         <= SS_MAP2[   56];
	irq                <= SS_MAP2[   57];
	irq_ack            <= SS_MAP2[   58];
	mirroring          <= SS_MAP2[   59];
end else if (ce) begin
	irq_ack <= 1'b0;
	if ((prg_write) && (prg_ain[15]))                   // Cover all from $8000 to $FFFF to maximize compatibility
		case({prg_ain[14:12],prg_ain[2:0]})
			6'b000_000: prg_bank_0 <= prg_din;
			6'b010_000: prg_bank_1 <= prg_din;
			6'b100_000: prg_bank_2 <= prg_din;
			6'b011_000: chr_bank_0 <= prg_din;
			6'b011_001: chr_bank_1 <= prg_din;
			6'b011_010: chr_bank_2 <= prg_din;
			6'b011_011: chr_bank_3 <= prg_din;
			6'b011_100: chr_bank_4 <= prg_din;
			6'b011_101: chr_bank_5 <= prg_din;
			6'b011_110: chr_bank_6 <= prg_din;
			6'b011_111: chr_bank_7 <= prg_din;
			6'b001_001: mirroring <= prg_din[7];
			6'b001_011: {irq_ack, irq_enable} <= {1'b1, prg_din[7]};
			6'b001_100: {irq_ack, irq_counter} <= {1'b1, irq_reload};
			6'b001_101: irq_reload[15:8] <= prg_din;
			6'b001_110: irq_reload[7:0] <= prg_din;
		endcase

	if (irq_enable) begin
		irq_counter <= irq_counter - 16'd1;
		if (irq_counter == 16'h0) begin
			irq <= 1'b1; // IRQ
			irq_enable <= 0;
			irq_counter <= 0;
		end
	end
	if (irq_ack)
		irq <= 1'b0; // IRQ ACK
end

assign SS_MAP1_BACK[ 7: 0] = chr_bank_0;
assign SS_MAP1_BACK[15: 8] = chr_bank_1;
assign SS_MAP1_BACK[23:16] = chr_bank_2;
assign SS_MAP1_BACK[31:24] = chr_bank_3;
assign SS_MAP1_BACK[39:32] = chr_bank_4;
assign SS_MAP1_BACK[47:40] = chr_bank_5;
assign SS_MAP1_BACK[55:48] = chr_bank_6;
assign SS_MAP1_BACK[63:56] = chr_bank_7;
assign SS_MAP2_BACK[ 7: 0] = prg_bank_0;
assign SS_MAP2_BACK[15: 8] = prg_bank_1;
assign SS_MAP2_BACK[23:16] = prg_bank_2;
assign SS_MAP2_BACK[39:24] = irq_reload;
assign SS_MAP2_BACK[55:40] = irq_counter;
assign SS_MAP2_BACK[   56] = irq_enable;
assign SS_MAP2_BACK[   57] = irq;
assign SS_MAP2_BACK[   58] = irq_ack;
assign SS_MAP2_BACK[   59] = mirroring;
assign SS_MAP2_BACK[63:60] = 4'b0; // free to be used

always begin
	vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];    // horizontal:vertical
end

reg [7:0] prgsel;
always begin
	case(prg_ain[14:13])
		2'b00: prgsel = prg_bank_0;      // $8000 is swapable
		2'b01: prgsel = prg_bank_1;      // $A000 is swapable
		2'b10: prgsel = prg_bank_2;      // $C000 is swapable
		2'b11: prgsel = 8'hFF;           // $E000 is hardwired to last bank
	endcase
end

reg [7:0] chrsel;
always begin
	casez(chr_ain[12:10])
		0: chrsel = chr_bank_0;
		1: chrsel = chr_bank_1;
		2: chrsel = chr_bank_2;
		3: chrsel = chr_bank_3;
		4: chrsel = chr_bank_4;
		5: chrsel = chr_bank_5;
		6: chrsel = chr_bank_6;
		7: chrsel = chr_bank_7;
	endcase
end
	assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};      // 1kB banks
	assign prg_aout = {2'b00, prgsel[6:0], prg_ain[12:0]};   // 8kB banks

assign prg_allow = (prg_ain[15] && !prg_write);
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];

// savestate
localparam SAVESTATE_MODULES    = 2;
wire [63:0] SaveStateBus_wired_or[0:SAVESTATE_MODULES-1];
wire [63:0] SS_MAP1, SS_MAP2;
wire [63:0] SS_MAP1_BACK, SS_MAP2_BACK;	
wire [63:0] SaveStateBus_Dout_active = SaveStateBus_wired_or[0] | SaveStateBus_wired_or[1];
	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[0], SS_MAP1_BACK, SS_MAP1);  
eReg_SavestateV #(SSREG_INDEX_MAP2, 64'h0000000000000000) iREG_SAVESTATE_MAP2 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_wired_or[1], SS_MAP2_BACK, SS_MAP2);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule


// 41 - Caltron 6-in-1
module Mapper41(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;


reg [2:0] prg_bank;
reg [1:0] chr_outer_bank, chr_inner_bank;
reg mirroring;

always @(posedge clk)
if (~enable) begin
	prg_bank <= 0;
	chr_outer_bank <= 0;
	chr_inner_bank <= 0;
	mirroring <= 0;
end else if (ce && prg_write) begin
	if (prg_ain[15:11] == 5'b01100) begin
		{mirroring, chr_outer_bank, prg_bank} <= prg_ain[5:0];
	end else if (prg_ain[15] && prg_bank[2]) begin
		// The Inner CHR Bank Select only can be written while the PRG ROM bank is 4, 5, 6, or 7
		chr_inner_bank <= prg_din[1:0];
	end
end

assign prg_aout = {4'b00_00, prg_bank, prg_ain[14:0]};
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_outer_bank, chr_inner_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
assign prg_allow = prg_ain[15] && !prg_write;

endmodule

// 218 - Magic Floor
module Mapper218(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	// savestates support - but no state in mapper needs saving
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};

assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
assign chr_allow =1'b1;
assign chr_aout = {9'b10_0000_000, chr_ain[12:11], vram_a10, chr_ain[9:0]};
assign vram_ce = 1'b1; //Always internal CHR RAM (no CHR ROM or RAM on cart)
assign vram_a10 = flags[16] ? (flags[14] ? chr_ain[13] : chr_ain[12]) : flags[14] ? chr_ain[10] : chr_ain[11]; // 11=1ScrB, 10=1ScrA, 01=vertical,00=horizontal
assign prg_allow = prg_ain[15] && !prg_write;

endmodule

// iNES Mapper 228 represents the board used by Active Enterprises for Action 52 and Cheetahmen II.
module Mapper228(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;


reg mirroring;
reg [1:0] prg_chip;
reg [4:0] prg_bank;
reg prg_bank_mode;
reg [5:0] chr_bank;
always @(posedge clk)
if (~enable) begin
	{mirroring, prg_chip, prg_bank, prg_bank_mode} <= 0;
	chr_bank <= 0;
end else if (ce) begin
	if (prg_ain[15] & prg_write) begin
		{mirroring, prg_chip, prg_bank, prg_bank_mode} <= prg_ain[13:5];
		chr_bank <= {prg_ain[3:0], prg_din[1:0]};
	end
end

assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
wire prglow = prg_bank_mode ? prg_bank[0] : prg_ain[14];
wire [1:0] addrsel = {prg_chip[1], prg_chip[1] ^ prg_chip[0]};
assign prg_aout = {1'b0, addrsel, prg_bank[4:1], prglow, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {3'b10_0, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];

endmodule


module Mapper234(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;


reg [2:0] block, inner_chr;
reg mode, mirroring, inner_prg;
always @(posedge clk)
if (~enable) begin
	block <= 0;
	{mode, mirroring} <= 0;
	inner_chr <= 0;
	inner_prg <= 0;
end else if (ce) begin
	if (prg_read && prg_ain[15:7] == 9'b1111_1111_1) begin
		// Outer bank control $FF80 - $FF9F
		if (prg_ain[6:0] < 7'h20 && (block == 0)) begin
			{mirroring, mode} <= prg_din[7:6];
			block <= prg_din[3:1];
			{inner_chr[2], inner_prg} <= {prg_din[0], prg_din[0]};
		end
		// Inner bank control ($FFE8-$FFF7)
		if (prg_ain[6:0] >= 7'h68 && prg_ain[6:0] < 7'h78) begin
			{inner_chr[2], inner_prg} <= mode ? {prg_din[6], prg_din[0]} : {inner_chr[2], inner_prg};
			inner_chr[1:0] <= prg_din[5:4];
		end
	end
end

assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
assign prg_aout = {3'b00_0, block, inner_prg, prg_ain[14:0]};
assign chr_aout = {3'b10_0, block, inner_chr, chr_ain[12:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

endmodule

module Mapper246(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [15:0] flags_out = 0;

reg [7:0] prg_bank0;
reg [7:0] prg_bank1;
reg [7:0] prg_bank2;
reg [7:0] prg_bank3;

reg [7:0] chr_bank0;
reg [7:0] chr_bank1;
reg [7:0] chr_bank2;
reg [7:0] chr_bank3;

reg [7:0] prgsel;
reg [7:0] chrsel;

always @(posedge clk)
if (~enable) begin
		prg_bank3 <= 8'hFF;
end else if (ce) begin
	if ((prg_ain[15:8] == 8'h60) && !prg_ain[7:5] && prg_write) begin
		case (prg_ain[2:0]) // $6000-$6007
			3'd0: prg_bank0 <= prg_din; // Select 8 KB PRG ROM bank at $8000-$9FFF
			3'd1: prg_bank1 <= prg_din; // Select 8 KB PRG ROM bank at $A000-$BFFF
			3'd2: prg_bank2 <= prg_din; // Select 8 KB PRG ROM bank at $C000-$DFFF
			3'd3: prg_bank3 <= prg_din; // Select 8 KB PRG ROM bank at $E000-$FFFF
			3'd4: chr_bank0 <= prg_din; // Select 2 KB CHR bank at PPU $0000-$07FF
			3'd5: chr_bank1 <= prg_din; // Select 2 KB CHR bank at PPU $0800-$0FFF
			3'd6: chr_bank2 <= prg_din; // Select 2 KB CHR bank at PPU $1000-$17FF
			3'd7: chr_bank3 <= prg_din; // Select 2 KB CHR bank at PPU $1800-$1FFF
		endcase
	end
end

always begin
	case(prg_ain[14:13])
		2'b00:  prgsel = prg_bank0;
		2'b01:  prgsel = prg_bank1;
		2'b10:  prgsel = prg_bank2;
		2'b11:  prgsel = prg_bank3;
	endcase

	case(chr_ain[12:11])
		2'b00: chrsel = chr_bank0;
		2'b01: chrsel = chr_bank1;
		2'b10: chrsel = chr_bank2;
		2'b11: chrsel = chr_bank3;
	endcase
end

wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
wire prg_is_ram = (prg_ain[15:11] == 5'b0110_1); // $6800-$6FFF

assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
assign vram_ce = chr_ain[13];
assign prg_aout = prg_is_ram ? prg_ram : {1'b0, prgsel, prg_ain[12:0]};
assign prg_allow = (prg_ain[15] & ~prg_write) | prg_is_ram;
assign chr_allow = flags[15];
assign chr_aout = {3'b10_0, chrsel, chr_ain[10:0]};

endmodule


// 92 - Jaleco JF-19 -- no audio samples
// 72 - Jaleco JF-17 -- no audio samples
module Mapper72(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};

reg [3:0] prg_bank;
reg [3:0] chr_bank;
wire [7:0] mapper = flags[7:0];
reg last_prg;
reg last_chr;
wire mapper72 = (mapper == 72);

always @(posedge clk)
if (~enable) begin
	prg_bank <= 0;
	chr_bank <= 0;
	last_prg <= 0;
	last_chr <= 0;
end else if (SaveStateBus_load) begin
	chr_bank <= SS_MAP1[ 3: 0];
	prg_bank <= SS_MAP1[ 7: 4];
	last_prg <= SS_MAP1[    8];
	last_chr <= SS_MAP1[    9];
end else if (ce) begin
	if (prg_ain[15] & prg_write) begin
		if ((!last_prg) && (prg_din[7]))
			{prg_bank} <= {prg_din[3:0]};

		if ((!last_chr) && (prg_din[6]))
			{chr_bank} <= {prg_din[3:0]};

		{last_prg, last_chr} <= prg_din[7:6];
	end
end

assign SS_MAP1_BACK[ 3: 0] = chr_bank;
assign SS_MAP1_BACK[ 7: 4] = prg_bank;
assign SS_MAP1_BACK[    8] = last_prg;
assign SS_MAP1_BACK[    9] = last_chr;
assign SS_MAP1_BACK[63:10] = 54'b0; // free to be used

assign prg_aout = {4'b00_00, prg_ain[14] ^ mapper72 ? prg_bank : mapper72 ? 4'b1111 : 4'b0000, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

// savestate
wire [63:0] SS_MAP1;
wire [63:0] SS_MAP1_BACK;	
wire [63:0] SaveStateBus_Dout_active;	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout_active, SS_MAP1_BACK, SS_MAP1);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule


// 162 Waixing - Zelda San Shen Zhi Li
module Mapper162(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;

wire [1:0] reg_a = flags[7:0] == 162 ? 2'd1 : 2'd2;
wire [1:0] reg_b = flags[7:0] == 162 ? 2'd2 : 2'd1;

reg [7:0] state[4];

// register 0x5000 to 0x5FFF
wire [7:0] prg_bank;

always_comb begin
	case ({state[3][2], 1'b0, state[3][0]})
		0: prg_bank = {state[reg_b][3:0], state[0][3:2], state[reg_a][1], 1'b0};
		1: prg_bank = {state[reg_b][3:0], state[0][3:2], 2'b0};
		4: prg_bank = {state[reg_b][3:0], state[0][3:1], state[reg_a][1]};
		5: prg_bank = {state[reg_b][3:0], state[0][3:0]};
	endcase
end

always @(posedge clk) begin
	if (~enable) begin
		state <= '{8'd3, 8'd0, 8'd0, 8'd7};
	end else if (ce) begin
		if (prg_ain[14:12] == 3'b101 && prg_write)
			state[prg_ain[9:8]] <= prg_din;
	end
end

wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};

assign prg_aout = prg_is_ram ? prg_ram : {prg_bank[5:0], prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
assign chr_allow = flags[15];
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule


// 164 Waixing - Final Fantasy V
module Mapper164(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;

reg [7:0] prg_bank;

always @(posedge clk) begin
	if (~enable) begin
		prg_bank <= 8'h0F;
	end else if (ce) begin
		if (prg_write) begin
			case (prg_ain & 16'h7300)
				'h5000: prg_bank[3:0] <= prg_din[3:0];
				'h5100: prg_bank[7:4] <= prg_din[3:0];
			endcase
		end
	end
end

wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};

assign prg_aout = prg_is_ram ? prg_ram : {prg_bank[5:0], prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
assign chr_allow = flags[15];
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule

// 163 Nanjing
module Nanjing(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	input [19:0] ppuflags,
	input        ppu_ce
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [7:0] prg_dout;
wire [15:0] flags_out = {14'd0, prg_bus_write, 1'b0};
reg prg_bus_write;

reg [7:0] prg_bank;
reg chr_bank;
reg chr_switch;
reg trigger;
reg trig_comp;

reg [7:0] security[4];

wire [8:0] scanline = ppuflags[19:11];
wire [8:0] cycle = ppuflags[10:2];

always @(posedge clk) begin
	if (~enable) begin
		prg_bank <= 8'h0F;
		trigger <= 0; // Initial value 0
		security <= '{8'h00, 8'h00, 8'h00, 8'h00};
		chr_switch <= 0;
		trig_comp <= 1; // Initial value 1
	end else if (ce) begin
		prg_dout <= prg_din;
		prg_bus_write <= 0;
		if (prg_write) begin
			if (prg_ain == 16'h5101) begin
				if (trig_comp && ~|prg_din)
					trigger <= ~trigger;
				trig_comp <= |prg_din;
			end else begin
				case (prg_ain & 16'h7300)
					// If the most significant bit of this register is set, it does automatic CHR RAM switching
					'h5000: begin
						prg_bank[3:0] <= prg_din[3:0];
						chr_switch <= prg_din[7];
						security[0] <= prg_din;
					end

					'h5100: begin
						security[1] <= prg_din;
						if (prg_din == 6)
							prg_bank <= 8'h3;
					end

					'h5200: begin
						prg_bank[7:4] <= prg_din[3:0];
						security[2] <= prg_din;
					end

					'h5300: security[3] <= prg_din;
				endcase
			end
		end else if (prg_read) begin // Security stuff as Mesen does it
			prg_bus_write <= 1'b1;
			case (prg_ain & 16'h7700)
				'h5100: prg_dout <= security[0] | security[1] | security[3] | (security[2] ^ 8'hFF);
				'h5500: prg_dout <= trigger ? (security[3] | security[0]) : 8'h0;
				default: begin
					prg_dout <= 8'hFF;
					prg_bus_write <= 0;
				end
			endcase
		end
	end

	// The exact way this works is unknown but is conjectured
	// to resemble iNES Mapper 096, latching PA9 at start of nametable reads.
	// When turned on, both 4K CHR RAM banks 0000-0FFF and 1000-1FFF map to 0000-0FFF 
	// for scanline 240 until scanline 128. Then at scanline 128, both 4K CHR banks 
	// point to 1000-1FFF.
	if(~enable) begin
		chr_bank <= 0;
	end else if (ppu_ce) begin
		if (cycle > 254) begin
			if (scanline == 239)
				chr_bank <= 0;
			else if(scanline == 127)
				chr_bank <= 1;
		end
	end
end

wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};

assign prg_aout = prg_is_ram ? prg_ram : {prg_bank[5:0], prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
assign chr_allow = flags[15];
assign chr_aout = {9'b10_0000_000, chr_switch ? chr_bank : chr_ain[12], chr_ain[11:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule
// Combine with other mapper (15?)
// #225 -  64-in-1
// #255 -  110-in-1 - This runs with buggy menu selection.  It runs correctly as mapper 225.
//  Unsure if any games require simulating missing 74-670 RAM (4 nybbles).
module Mapper225(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [7:0] prg_dout;
wire prg_bus_write = (~mapper255 & prg_ram);
wire prg_ram = (prg_ain[15:11] == 5'b01011);
wire [15:0] flags_out = {14'h0, prg_bus_write, 1'b0};

wire [7:0] mapper = flags[7:0];
wire mapper255 = (mapper == 8'd255);

// A~[1BMZ PPPP  PpCC CCCC]
//     ||| ||||  |||| ||||
//     +-----------++-++++ - Select 8 KiB CHR at PPU $0000
//     ||| ||||  ||
//     +---++++--++------- - Select 16 KiB PRG at CPU $8000 and $C000 if Z=1
//     +---++++--+-------- - Select 32 KiB PRG at CPU $8000 if Z=0
//      |+---------------- - Select PRG bank size: 0-32K 1-16K
//      +----------------- - Nametable mirroring: 0-PPUA10 ("vertical") 1-PPUA11 ("horizontal")
//74'670: (otherwise open bus)
//   $5800-5803:  [.... RRRR]  RAM  (readable/writable)
//                 (16 bits of RAM -- 4 bits in each of the 4 regs)
//   $5804-5FFF:    mirrors $5800-5803
reg [14:0] bank_mode;
wire mirroring = bank_mode[13];
wire prg_mode = bank_mode[12];
reg [3:0] ram [3:0];

always @(posedge clk) begin
	if (~enable) begin
		// resets?
	end else if (ce) begin
		if (prg_ain[15] && prg_write)
			bank_mode <= prg_ain[14:0];
		if (prg_ram && prg_write) // 5800-5FFF
			ram[prg_ain[1:0]] <= prg_din[3:0];
	end
end

assign prg_dout = {4'h0, ram[prg_ain[1:0]]};
assign prg_aout = {1'b0, bank_mode[14], bank_mode[11:7], prg_mode ? bank_mode[6] : prg_ain[14], prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15]; // CHR RAM?
assign chr_aout = {2'b10, bank_mode[14], bank_mode[5:0], chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];

endmodule

module Mapper227(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [15:0] flags_out = { 16'd0 };

// $8000-FFFF:  A~[.... .mLP  OPPP PPMS]
//   L = Last PRG Page Mode
//   P = PRG Reg
//   O = Mode
//   M = Mirroring (0=Vert, 1=Horz)
//   S = PRG Size
//   m = Menu list
reg [10:0] bank_reg;
wire menu = bank_reg[10];
wire last_bank = bank_reg[9];
wire prg_mode = bank_reg[7];
wire [5:0] prg_bank_t = { bank_reg[8], bank_reg[6:2] };
wire mirroring = bank_reg[1];
wire prg_size = bank_reg[0];

wire battery = flags[25];
wire [3:0] submapper = flags[24:21];

// Apparently all single games have the battery set and those lack CHR RAM write protection
wire chr_ram_wr_en = ~prg_mode | battery;

// From Nesdev, adapted:
//                   $8000   $A000   $C000   $E000
//                 +---------------+---------------+
// O=1, S=0:       |       P[5:0]  |    P[5:0]     |
//                 +-------------------------------+
// O=1, S=1:       |          P[5:1], A14          |
//                 +-------------------------------+
// O=0, S=0, L=0:  |    P[5:0]     | P[5:3], b000  |
//                 +---------------+---------------+
// O=0, S=1, L=0:  |  P[5:1], A14  | P[5:3], b000  |
//                 +---------------+---------------+
// O=0, S=0, L=1:  |    P[5:0]     | P[5:3], b111  |
//                 +---------------+---------------+
// O=0, S=1, L=1:  |  P[5:1], A14  | P[5:3], b111  |
//                 +---------------+---------------+
wire [5:0] prg_bank;

wire prg_bank_a0 = prg_size ? prg_ain[14] : prg_bank_t[0]; // 16/32KB banks select

assign prg_bank[5:3] = prg_bank_t[5:3];
assign prg_bank[2:0] = (prg_mode | ~prg_ain[14]) ? {prg_bank_t[2:1],prg_bank_a0} : {3{last_bank}};

always @(posedge clk) begin
	if (~enable) begin
		bank_reg <= 0;
	end else if (ce) begin
		if (prg_ain[15] && prg_write)
			bank_reg <= prg_ain[10:0];
	end
end

// "When the 'm' bit is set, one of the 74157s replaces
//  the 4 LSbits of the CPU's address bus with a fixed constant"
wire [3:0] prg_a3_0 = menu ? submapper : prg_ain[3:0];

assign prg_aout = {2'b00, prg_bank, prg_ain[13:4], prg_a3_0};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15] & chr_ram_wr_en;
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];

endmodule

// #31 -  NSF Player
module NSF(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	output [5:0] exp_audioe,  // Expansion Enabled (0x0=None, 0x1=VRC6, 0x2=VRC7, 0x4=FDS, 0x8=MMC5, 0x10=N163, 0x20=SS5B
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	input  [7:0] fds_din      // fds data in
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {audio_in[15:0]} : 16'hZ;
assign exp_audioe   = enable ? nsf_reg[3][5:0] : 6'h00;

wire [21:0] prg_aout, chr_aout;
wire [7:0] prg_dout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [15:0] flags_out = {14'd0, prg_bus_write, 1'b0};
reg prg_bus_write;

wire [3:0] submapper = flags[24:21];
reg [7:0] nsf_reg [15:0];
reg [15:0] counter;
reg [5:0] clk1MHz;

// Resuse MMC5 multiplier instead?
reg [7:0] multiplier_1;
reg [7:0] multiplier_2;
wire [15:0] multiply_result = multiplier_1 * multiplier_2;

/*
;----------------------------------
; NSF player for PowerPak
;
; Player rom is at $4100-4FFF (NSF header at $4100)
;
; PowerPak registers:
;
;  5FF0: timer latch LSB
;  5FF1: timer latch MSB
;  5FF2: timer status (Read: bit7=timer wrapped,  Write: clear status)
;  5FF3: Expansion audio control (copy header[0x7B] here)
;  5FF6-5FFF: banking registers (as described in NSF spec)
;
;  Timer details:
;      PowerPak NSF mapper has a 16bit 1MHz counter that counts down from [5FF1:5FF0] to 0.
;      After the counter reaches 0, it's automatically reloaded and timer status bit is set.
;      Clear the status bit by writing to $5FF2.
;
;-----------------------------------
*/
always @(posedge clk) begin
	// 21.477272MHz/1MHz
	// Using 21.5; Replace with actual pll?
	clk1MHz <= clk1MHz + 1'b1;
	if (clk1MHz == 6'd42)
		clk1MHz <= 6'd0;
	if (clk1MHz == 6'd21 || clk1MHz == 6'd42) begin
		counter <= counter - 1'b1;
		if (counter == 16'h0000)
		begin
			counter <= {nsf_reg[1], nsf_reg[0]};
			nsf_reg[2] <= 8'h80;
		end
	end


	if (~enable) begin
		nsf_reg[4'h3] <= 8'h00;
		nsf_reg[4'h6] <= 8'h06;
		nsf_reg[4'h7] <= 8'h07;
		nsf_reg[4'h8] <= 8'h00;
		nsf_reg[4'h9] <= 8'h01;
		nsf_reg[4'hA] <= 8'h02;
		nsf_reg[4'hB] <= 8'h03;
		nsf_reg[4'hC] <= 8'h04;
		nsf_reg[4'hD] <= 8'h05;
		nsf_reg[4'hE] <= 8'h06;
		nsf_reg[4'hF] <= 8'hFF;
	end else if (ce) begin
		if ((prg_ain[15:4]==12'h5FF) && prg_write)
			nsf_reg[prg_ain[3:0]] <= prg_din;
		if ((prg_ain==16'h5FF2) && prg_write)
			nsf_reg[2] <= 8'h00;
		if ((prg_ain==16'h5205) && prg_write)
			multiplier_1 <= prg_din;
		if ((prg_ain==16'h5206) && prg_write)
			multiplier_2 <= prg_din;
	end
end

wire [9:0] prg_bank;
always begin
	casez({prg_ain[15:12], exp_audioe[2]})
		5'b00???: prg_bank = 10'h0;//{10'b11_1110_0000};
		5'b0100?: prg_bank = 10'h0;//{10'b11_1110_0000};
		5'b0101?: prg_bank = {10'b11_1110_0000};
		5'b011?0: prg_bank = {9'b11_1100_000, prg_ain[12]};
		5'b011?1: prg_bank = {2'b01, nsf_reg[{3'b011, prg_ain[12]}]};
		5'b1????: prg_bank = {2'b01, nsf_reg[{1'b1, prg_ain[14:12]}]};
	endcase
end

always begin
	prg_bus_write = 1'b1;
	if (prg_ain == 16'h5205) begin
		prg_dout = multiply_result[7:0];
	end else if (prg_ain == 16'h5206) begin
		prg_dout = multiply_result[15:8];
	end else if (prg_ain[15:8] == 8'h40) begin
		prg_dout = fds_din;
	end else if (prg_ain == 16'h5FF2) begin
		prg_dout = nsf_reg[4'h2];
	end else begin
		prg_dout = prg_din;
		prg_bus_write = 0;
	end
end

assign prg_aout = ((submapper == 4'hF) && ({prg_ain[15:1],1'b0} == 16'hFFFC)) ? {10'h0, prg_ain[11:0]} : {prg_bank, prg_ain[11:0]};
assign prg_allow = (((prg_ain[15] || ((prg_ain>=16'h4080) && (prg_ain<16'h4FFF))) && !prg_write) || (prg_ain[15:13]==3'b011)
                   || (prg_ain[15:10]==6'b010111 && prg_ain[9:4]!=6'b111111) || ((prg_ain>=16'h8000) && (prg_ain<16'hDFFF) && exp_audioe[2]));
assign chr_allow = flags[15]; // CHR RAM always...
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule

// 111 - Cheapocabra/GTROM
// Supports all features except LED and self-reflashing support
module Mapper111(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b, // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	// savestates              
	input       [63:0]  SaveStateBus_Din,
	input       [ 9:0]  SaveStateBus_Adr,
	input               SaveStateBus_wren,
	input               SaveStateBus_rst,
	input               SaveStateBus_load,
	output      [63:0]  SaveStateBus_Dout
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire [7:0] prg_dout;
wire prg_allow, chr_allow;
wire vram_ce, vram_a10;
wire [15:0] audio = audio_in;
wire irq;

reg [15:0] flags_out = {12'h0, 1'b1, 3'b0};
reg [3:0] prgbank_reg;
reg chrbank_reg;
reg namebank_reg;

always@(posedge clk) begin // register mask: 01x1 xxxx xxxx xxxx
    if (~enable) begin
        {prgbank_reg, chrbank_reg, namebank_reg} <= 0;
    end else if (SaveStateBus_load) begin
        prgbank_reg  <= SS_MAP1[ 3: 0];
        chrbank_reg  <= SS_MAP1[    4];
        namebank_reg <= SS_MAP1[    5];
    end else if(ce & prg_write & prg_ain[12] & prg_ain[14] & !prg_ain[15]) begin
        prgbank_reg <= prg_din[3:0];
        chrbank_reg <= prg_din[4];
        namebank_reg <= prg_din[5];
    end
end

assign SS_MAP1_BACK[ 3: 0] = prgbank_reg;
assign SS_MAP1_BACK[    4] = chrbank_reg;
assign SS_MAP1_BACK[    5] = namebank_reg;
assign SS_MAP1_BACK[63: 6] = 58'b0; // free to be used

assign chr_aout[21:15] = 7'b11_1100_0;
assign chr_aout[14:13] = {chr_ain[13], chr_ain[13]?namebank_reg:chrbank_reg};
assign chr_aout[12:0] = chr_ain[12:0];
assign vram_a10 = chr_aout[10];
assign prg_aout[21:19] = 3'b000;
assign prg_aout[18:15] = prgbank_reg;
assign prg_aout[14:0] = prg_ain[14:0];
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = 1'b1;
assign prg_dout = 8'hFF;
assign vram_ce = 1'b0;
assign irq = 1'b0;

// savestate
wire [63:0] SS_MAP1;
wire [63:0] SS_MAP1_BACK;	
wire [63:0] SaveStateBus_Dout_active;	
eReg_SavestateV #(SSREG_INDEX_MAP1, 64'h0000000000000000) iREG_SAVESTATE_MAP1 (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout_active, SS_MAP1_BACK, SS_MAP1);  

assign SaveStateBus_Dout = enable ? SaveStateBus_Dout_active : 64'h0000000000000000;

endmodule


// 83 Cony/Yoko - Unlicensed fighting game bootlegs
// Street Fighter II Pro, Fatal Fury 2, World Heroes 2
module Mapper83(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? prg_dout : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio : 16'hZ;

wire [21:0] prg_aout, chr_aout;
reg [7:0] prg_dout;
wire prg_allow, chr_allow;
wire vram_ce, vram_a10;
wire [15:0] audio = audio_in;
wire [15:0] flags_out = {14'h0, prg_bus_write, 1'h0};
wire prg_bus_write;

wire submapper1 = flags[21];
wire submapper2 = flags[22];

// mode register bits
reg [1:0] prgbank_mode; // determines PRG banking mode
reg [1:0] mirroring;
reg prg_reg3_enable;    // if 1, maps 8 KiB PRG bank to 0x6000-0x7FFF for submapper 0 and 1
reg irq_mode, irq_latch;

reg irq;
reg irq_enable;
reg [15:0] irq_counter;

reg [4:0] prgbank_reg[3:0];
reg [3:0] prgbank_reg4;
reg [7:0] chrbank_reg[7:0];

reg [1:0] dipswitch; // alters title screen, wrong dipswitch can result in garbled graphics

reg [7:0] scratch_ram[3:0];

// Submapper 2 only
// outer 256 KiB PRG/CHR-ROM bank
reg [1:0] outer_bank;
// select 8 KiB WRAM bank
reg [1:0] wrambank;

always@(posedge clk) begin
    if (~enable) begin
        {irq, irq_mode, irq_latch, irq_enable, irq_counter} <= 0;
        {prg_reg3_enable, prgbank_mode, mirroring}          <= 0;
        outer_bank   <= 0;
        wrambank     <= 0;
        dipswitch    <= 0;
        chrbank_reg  <= '{default:0};
        prgbank_reg  <= '{default:0};
        prgbank_reg4 <= 0;
        scratch_ram  <= '{default:0};
    end else if(ce) begin
        if (prg_write) begin
            casez(prg_ain[15:8])
                8'b1???_??00 : begin
                    {wrambank, outer_bank} <= prg_din[7:4];
                    {prgbank_reg4}         <= prg_din[3:0];
                end
                8'b1???_??01 : begin
                    {irq_latch, irq_mode, prg_reg3_enable, prgbank_mode} <= prg_din[7:3];
                    mirroring <= prg_din[1:0];
                end
                8'b1???_??10 : begin
                    if (prg_ain[0]) begin
                        irq_counter[15:8] <= prg_din;
                        irq_enable        <= irq_latch;
                    end else begin
                        irq_counter[7:0]  <= prg_din;
                        irq               <= 1'b0; // IRQ ACK
                    end
                end
                8'b1???_??11 : begin
                    if (prg_ain[4]) begin
                        if (!prg_ain[3])
                            chrbank_reg[prg_ain[2:0]] <= prg_din;
                    end else
                        prgbank_reg[prg_ain[1:0]] <= prg_din[4:0];
                end
                8'b0101_???? : begin
                    if (|prg_ain[11:8])
                        scratch_ram[prg_ain[1:0]] <= prg_din;
                end
            endcase
        end

        if (irq_enable) begin
            if (irq_mode)
                irq_counter <= irq_counter - 16'd1;
            else
                irq_counter <= irq_counter + 16'd1;
        end

        if (irq_enable && (irq_counter == 16'h0000)) begin
            irq        <= 1'b1;
            irq_enable <= 1'b0;
        end
    end
end

always_comb begin
    // mirroring
    casez(mirroring[1:0])
        2'b00:   vram_a10 = {chr_ain[10]};    // vertical
        2'b01:   vram_a10 = {chr_ain[11]};    // horizontal
        2'b1?:   vram_a10 = {mirroring[0]};   // single screen
    endcase
end

// PRG address space mapping
reg [4:0] prgsel;
always_comb begin
    casez ({prgbank_mode, prg_ain[15:13]})
        // mode 0
        5'b00_10? : prgsel = {prgbank_reg4, prg_ain[13]}; // 0x8000-0xBFFF
        5'b00_11? : prgsel = {4'b1111,      prg_ain[13]}; // 0xC000-0xFFFF
        // mode 1
        5'b01_1?? : prgsel = {prgbank_reg4[3:1], prg_ain[14:13]}; // 0x8000-0xFFFF
        // mode 2 and 3
        5'b1?_100 : prgsel = prgbank_reg[0]; // 0x8000-0x9FFF
        5'b1?_101 : prgsel = prgbank_reg[1]; // 0xA000-0xBFFF
        5'b1?_110 : prgsel = prgbank_reg[2]; // 0xC000-0xDFFF
        5'b1?_111 : prgsel = 5'b11_111;      // 0xE000-0xFFFF
        // all modes
        5'b??_011 : prgsel = prgbank_reg[3]; // 0x6000-0x7FFF
        default   : prgsel = {2'd0, prg_ain[15:13]};
    endcase
end

// CHR address space mapping
reg [9:0] chrsel;
always_comb begin
    chrsel = 0;
    casez({submapper1, chr_ain[13:11]})
        // submapper 1
        4'b1_000 : chrsel = {1'b0, chrbank_reg[0], chr_ain[10]};
        4'b1_001 : chrsel = {1'b0, chrbank_reg[1], chr_ain[10]};
        4'b1_010 : chrsel = {1'b0, chrbank_reg[6], chr_ain[10]};
        4'b1_011 : chrsel = {1'b0, chrbank_reg[7], chr_ain[10]};
        // submapper 0 and 2
        4'b0_0?? : chrsel = {submapper2 ? outer_bank : 2'b00, chrbank_reg[chr_ain[12:10]]};
        // all submappers
        default   : chrsel = {6'd0, chr_ain[13:10]};
    endcase
end

// handle reads from scratch RAM and dipswitch
always_comb begin
    casez(prg_ain[15:12])
        4'h5 : begin
            if (|prg_ain[11:8]) begin
                prg_dout = scratch_ram[prg_ain[1:0]];
            end else
                prg_dout = {6'b1111_11, dipswitch};
        end
        default : begin
            prg_dout = 8'hFF;
        end
    endcase
end

wire prg_read_blocked = (prg_ain[15:13] == 3'b011) && !submapper2 && !prg_reg3_enable;
assign prg_bus_write  = (prg_ain[15:12] == 4'h5) || prg_read_blocked;

wire is_wram = submapper2 && (prg_ain[15:13] == 3'b011);

assign chr_aout[21:20] = 2'b10;
assign chr_aout[19:10] = chrsel;
assign chr_aout[9:0]   = chr_ain[9:0];

assign prg_aout[21:18] = is_wram ? 4'b11_11 : {2'b00, submapper2 ? outer_bank : 2'b00};
assign prg_aout[17:13] = is_wram ? {3'b00_0, wrambank} : prgsel;
assign prg_aout[12:0]  = prg_ain[12:0];

assign prg_allow = (prg_ain[15] && !prg_write) || is_wram;
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

endmodule

module Mapper91(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b,  // flags {0, 0, 0, 0, has_savestate, prg_conflict, prg_bus_write, has_chr_dout}
	input [13:0] chr_ain_o
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? {1'b0, audio_in[15:1]} : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire [15:0] flags_out = 0;

reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3;
reg [3:0] prg_bank_0, prg_bank_1;
reg outer_chr_bank;
reg [1:0] outer_prg_bank;
reg irq_enabled;
reg irq;
reg [5:0] irq_count, last_irq_count;
reg last_a12;

always @(posedge clk)
	if (~enable) begin
		irq_enabled <= 0;
		irq_count <= 0;
		irq <= 0;
		last_irq_count <= 0;
		outer_prg_bank <= 0;
		outer_chr_bank <= 0;
		last_a12 <= 0;
	end else if (ce) begin
		if (prg_write) begin
			if(prg_ain[15:13] == 3'b011) begin
				case({prg_ain[12],prg_ain[1:0]}) // $6000, $7000
					3'b0_00: chr_bank_0 <= prg_din; // Select 2 KiB CHR-ROM bank at PPU $0000-$07FF
					3'b0_01: chr_bank_1 <= prg_din; // Select 2 KiB CHR-ROM bank at PPU $0800-$0FFF
					3'b0_10: chr_bank_2 <= prg_din; // Select 2 KiB CHR-ROM bank at PPU $1000-$17FF
					3'b0_11: chr_bank_3 <= prg_din; // Select 2 KiB CHR-ROM bank at PPU $1800-$1FFF
					3'b1_00: prg_bank_0 <= prg_din[3:0]; // Select 8 KiB PRG-ROM bank at CPU $8000-$9FFF
					3'b1_01: prg_bank_1 <= prg_din[3:0]; // Select 8 KiB PRG-ROM bank at CPU $A000-$BFFF
					3'b1_10: begin // IRQ Stop/Acknowledge
						irq_enabled <= 0;
						irq <= 0;
					end
					3'b1_11: begin // IRQ start/reset
						irq_enabled <= 1'b1;
						irq_count <= 0;
						last_irq_count <= 0;
					end
				endcase
			end else if (prg_ain[15:13] == 3'b100) begin // $8000-$9FFF
				outer_chr_bank <= prg_din[0]; // Select outer 512 KiB CHR-ROM bank (CHR A19)
				outer_prg_bank <= prg_din[2:1]; // Select outer 128 KiB PRG-ROM bank (PRG A17-A18)
			end
		end

		// IRQ counts 64 rises of PPU A12
		last_a12 <= chr_ain_o[12];
		last_irq_count <= irq_count;
		if (irq_enabled) begin
			if (!last_a12 && chr_ain_o[12]) begin
				irq_count <= irq_count + 1'b1;
			end
			if (&last_irq_count && irq_count == 6'd00) begin
				irq <= 1'b1;
			end
		end

	end

// The PRG bank to load. Each increment here is 8KB. So valid values are 0..15.
reg [3:0] prgsel;
always @* begin
	case(prg_ain[14:13])
		2'b00: prgsel = prg_bank_0;
		2'b01: prgsel = prg_bank_1;
		2'b10: prgsel = 4'b1110; //$C000-$FFFF: 8+8 KiB PRG-ROM bank, hard-wired to last bank
		2'b11: prgsel = 4'b1111;
	endcase
end

// The CHR bank to load. Each increment here is 2 KB. So valid values are 0..255.
reg [7:0] chrsel;
always @* begin
	case(chr_ain[12:11])
		2'b00: chrsel = chr_bank_0;
		2'b01: chrsel = chr_bank_1;
		2'b10: chrsel = chr_bank_2;
		2'b11: chrsel = chr_bank_3;
	endcase
end

assign chr_aout = {2'b10, outer_chr_bank, chrsel, chr_ain[10:0]};
assign chr_allow = flags[15];

assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
assign vram_ce = chr_ain[13];

assign prg_allow = prg_ain[15] && !prg_write;
assign prg_aout = {3'b000, outer_prg_bank, prgsel, prg_ain[12:0]};

endmodule
