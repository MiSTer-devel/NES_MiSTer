// These are misc small one-off mappers. Some may end up being merged with Generic mappers.

// #15 -  100-in-1 Contra Function 16
module Mapper15(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

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
	if (reset) begin
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


// Mapper 16, 159 Bandai
module Mapper16(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                    // Read / write signals
	input [7:0] prg_din,
	output [7:0] prg_dout,
	output prg_allow,                   // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                   // Allow write
	output reg vram_a10,                // Value for A10 address line
	output vram_ce,                     // True if the address should be routed to the internal 2kB VRAM.
	output [14:0] mapper_addr,
	input [7:0] mapper_data_in,
	output [7:0] mapper_data_out,
	output mapper_prg_write,
	output mapper_ovr,
	output reg irq
);

reg [3:0] prg_bank;
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
wire mapper159 = (flags[7:0] == 159);
wire mapperalt = submapper5 | mapper159;

always @(posedge clk) begin
	if (reset) begin
		prg_bank <= 4'hF;
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
	end else if (ce) begin
		irq_up <= 1'b0;
		if (prg_write)
			if(((prg_ain[14:13] == 2'b11) && (!mapperalt)) || (prg_ain[15])) // Cover all from $6000 to $FFFF to maximize compatibility
				case(prg_ain & 'hf) // Registers are mapped every 16 bytes
					'h0: chr_bank_0 <= prg_din[7:0];
					'h1: chr_bank_1 <= prg_din[7:0];
					'h2: chr_bank_2 <= prg_din[7:0];
					'h3: chr_bank_3 <= prg_din[7:0];
					'h4: chr_bank_4 <= prg_din[7:0];
					'h5: chr_bank_5 <= prg_din[7:0];
					'h6: chr_bank_6 <= prg_din[7:0];
					'h7: chr_bank_7 <= prg_din[7:0];
					'h8: prg_bank <= prg_din[3:0];
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

always begin
	// mirroring
	casez(mirroring[1:0])
		2'b00:   vram_a10 = {chr_ain[10]};    // vertical
		2'b01:   vram_a10 = {chr_ain[11]};    // horizontal
		2'b1?:   vram_a10 = {mirroring[0]};   // single screen lower
	endcase
end

reg [3:0] prgsel;
always begin
	case(prg_ain[15:14])
		2'b10: 	prgsel = prg_bank;    // $8000 is swapable
		2'b11: 	prgsel = 4'hF;        // $C000 is hardwired to last bank
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

assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};            // 1kB banks
wire [21:0] prg_aout_tmp = {4'b00_00, prgsel, prg_ain[13:0]};  // 16kB banks

wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
// EEPROM - not used - Could use write to EEPROM cycle for both reads and write accesses, but this is easier
assign prg_dout = prg_is_ram ? prg_write ? mapper_data_out : {3'b111, sda_out, 4'b1111} : 8'hFF;

assign prg_allow = (prg_ain[15] && !prg_write);
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

wire sda_out;
wire [7:0] ram_addr;
wire ram_read;
assign mapper_addr[14:8] = 0;
assign mapper_addr[7:0] = ram_addr;
assign mapper_ovr = 1'b1;

EEPROM_24C0x eeprom(
	.type_24C01(mapper159),         //24C01 is 128 bytes, 24C02 is 256 bytes
	.clk(clk),
	.ce(ce),
	.reset(reset),
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
	.ram_done(1'b1)                 // RAM access done
);

endmodule

// Mapper 18, Jaleco SS88006
module Mapper18(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output [7:0] prg_dout,
	output prg_allow,                            // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      		// Allow write
	output reg vram_a10,                         // Value for A10 address line
	output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
	output reg irq
);

reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
			chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
reg [3:0] prg_sel;
reg [1:0] mirroring;
reg irq_ack;
reg [3:0] irq_enable;
reg [15:0] irq_reload;
reg [15:0] irq_counter;
reg [1:0] ram_enable;

always @(posedge clk)
if (reset) begin
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
end else if (ce) begin
	irq_ack <= 1'b0;
	if (prg_write)
		if(prg_ain[15]) // Cover all from $8000 to $FFFF to maximize compatibility
			case({prg_ain[14:12],prg_ain[1:0]})
				5'b000_00: prg_bank_0[3:0] <= prg_din[3:0];
				5'b000_01: prg_bank_0[7:4] <= prg_din[3:0];
				5'b000_10: prg_bank_1[3:0] <= prg_din[3:0];
				5'b000_11: prg_bank_1[7:4] <= prg_din[3:0];
				5'b001_00: prg_bank_2[3:0] <= prg_din[3:0];
				5'b001_01: prg_bank_2[7:4] <= prg_din[3:0];
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
				5'b111_11: ram_enable <= prg_din[1:0];
			endcase

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
	if (irq_ack)
		irq <= 1'b0; // IRQ ACK
end

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

endmodule

// Tepples/Multi-discrete mapper
// This mapper can emulate other mappers,  such as mapper #0, mapper #2
module Mapper28(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                       // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                      // Enable access to memory for the specified operation.
	output prg_open_bus,                   // PRG Data not driven
	output prg_conflict,                   // PRG Bus Conflict
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output reg [7:0] chr_dout,
	output has_chr_dout,
	output chr_allow,                      // Allow write
	output reg vram_a10,                   // Value for A10 address line
	output vram_ce                         // True if the address should be routed to the internal 2kB VRAM.
);

reg [6:0] a53prg;    // output PRG ROM (A14-A20 on ROM)
reg [1:0] a53chr;    // output CHR RAM (A13-A14 on RAM)

reg [3:0] inner;    // "inner" bank at 01h
reg [5:0] mode;     // mode register at 80h
reg [5:0] outer;    // "outer" bank at 81h
reg [2:0] selreg;   // selector register
reg [3:0] security; // selector register

// Allow writes to 0x5000 only when launching through the proper mapper ID.
wire [7:0] mapper = flags[7:0];
wire allow_select = (mapper == 8'd28);
wire extend_bit = (mapper == 97);

always @(posedge clk)
if (reset) begin
	mode[5:2] <= 0;         // NROM mode, 32K mode
	outer[5:0] <= 6'h3f;    // last bank
	inner <= 0;
	selreg <= 1;

	// Set value for mirroring
	if (mapper == 2 || mapper == 0 || mapper == 3 || mapper == 94 || mapper == 180 || mapper == 185)
		mode[1:0] <= flags[14] ? 2'b10 : 2'b11;

	// UNROM #2 - Current bank in $8000-$BFFF and fixed top half of outer bank in $C000-$FFFF
	if (mapper == 2) begin
		mode[5:2] <= 4'b1111; // 256K banks, UNROM mode
	end

	// CNROM #3 - Fixed PRG bank, switchable CHR bank.
	if (mapper == 3)
		selreg <= 0;

	// CNROM #185 - Fixed PRG bank, Fixed CHR Bank, Security.
	if (mapper == 185)
		selreg <= 4;

	// UNROM #180 - Fixed first PRG bank, Fixed CHR Bank.
	if (mapper == 180) begin
		selreg <= 1;
		mode[5:2] <= 4'b1110;
		outer[5:0] <= 6'h00;
	end

	// IREM TAM-S1 IC #97 - Fixed first PRG bank, Fixed CHR Bank, Mirroring.
	if (mapper == 97) begin
		selreg <= 6;
		mode[5:2] <= 4'b1110;
		outer[5:0] <= 6'h3F;
	end

	// IREM TAM-S1 IC #94 - Fixed last PRG bank, Fixed CHR Bank
	if (mapper == 94) begin
		selreg <= 7;
		mode[5:2] <= 4'b1111;
	end

	// AxROM #7 - Switch 32kb rom bank + switchable nametables
	if (mapper == 7) begin
		mode[1:0] <= 2'b00;   // Switchable VRAM page.
		mode[5:2] <= 4'b1100; // 256K banks, (B)NROM mode
		outer[5:0] <= 6'h00;
	end
end else if (ce) begin
	if ((prg_ain[15:12] == 4'h5) & prg_write && allow_select)
			selreg <= {1'b0,prg_din[7], prg_din[0]};        // select register
	if (prg_ain[15] & prg_write) begin
		casez (selreg)
			3'b000:  {mode[0], a53chr}  <= {(mode[1] ? mode[0] : prg_din[4]), prg_din[1:0]};     // CHR RAM bank
			3'b001:  {mode[0], inner}   <= {(mode[1] ? mode[0] : prg_din[4]), prg_din[3:0]};     // "inner" bank
			3'b010:  {mode}             <= {prg_din[5:0]};                                       // mode register
			3'b011:  {outer}            <= {prg_din[5:0]};                                       // "outer" bank
			3'b10?:  {security}         <= {prg_din[5:4],prg_din[1:0]};                          // security
			3'b110:  {mode[1:0],inner}  <= {prg_din[7] ^ prg_din[6], prg_din[6], prg_din[3:0]};  // "inner" bank
			3'b111:  {inner}            <= {prg_din[5:2]};                                       // "inner" bank
		endcase
	end
end

always begin
	// mirroring mode
	casez(mode[1:0])
		2'b0? : vram_a10 = {mode[0]};        // 1 screen lower
		2'b10 : vram_a10 = {chr_ain[10]};    // vertical
		2'b11 : vram_a10 = {chr_ain[11]};    // horizontal
	endcase

	// PRG ROM bank size select
	casez({mode[5:2], prg_ain[14]})
		5'b00_0?_?: a53prg = {outer[5:0],             prg_ain[14]};  // 32K banks, (B)NROM mode
		5'b01_0?_?: a53prg = {outer[5:1], inner[0],   prg_ain[14]};  // 64K banks, (B)NROM mode
		5'b10_0?_?: a53prg = {outer[5:2], inner[1:0], prg_ain[14]};  // 128K banks, (B)NROM mode
		5'b11_0?_?: a53prg = {outer[5:3], inner[2:0], prg_ain[14]};  // 256K banks, (B)NROM mode

		5'b00_10_1,
		5'b00_11_0: a53prg = {outer[5:0], inner[0]};                 // 32K banks, UNROM mode
		5'b01_10_1,
		5'b01_11_0: a53prg = {outer[5:1], inner[1:0]};               // 64K banks, UNROM mode
		5'b10_10_1,
		5'b10_11_0: a53prg = {outer[5:2], inner[2:0]};               // 128K banks, UNROM mode
		5'b11_10_1,
		5'b11_11_0: a53prg = {outer[5:3], inner[3:0]};               // 256K banks, UNROM mode

		default: a53prg = {outer[5:0], extend_bit ? outer[0] : prg_ain[14]};  // 16K fixed bank
	endcase

	chr_dout = 8'hFF;//chr_ain[7:0]; // return open bus = LSB of address? below when CHR disabled by security
end

assign vram_ce = chr_ain[13];
assign prg_aout = {1'b0, (a53prg & 7'b0011111), prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign prg_conflict = prg_ain[15] && (mapper == 3) && (submapper != 1);
assign prg_open_bus = (prg_ain[15:13] == 3'b011) && (mapper == 7);
assign chr_allow = flags[15];
assign chr_aout = {7'b10_0000_0, a53chr, chr_ain[12:0]};
wire [4:0] submapper = flags[24:21];
assign has_chr_dout = (mapper == 185) && (((submapper == 0) && (security[1:0] == 2'b00))
		|| ((submapper == 4) && (security[1:0] != 2'b00))
		|| ((submapper == 5) && (security[1:0] != 2'b01))
		|| ((submapper == 6) && (security[1:0] != 2'b10))
		|| ((submapper == 7) && (security[1:0] != 2'b11)));

endmodule


// 32 - IREM
module Mapper32(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                            // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      // Allow write
	output reg vram_a10,                         // Value for A10 address line
	output vram_ce                             // True if the address should be routed to the internal 2kB VRAM.
);

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
reg [4:0] prgsel;
reg [7:0] chrsel;

always @(posedge clk)
if (reset) begin
		prgmode <= 1'b0;
end else if (ce) begin
	if ((prg_ain[15:14] == 2'b10) & prg_write) begin
		casez ({prg_ain[13:12], submapper1, prg_ain[2:0]})
			6'b00_?_???:  prgreg0            <= prg_din[4:0];
			6'b01_0_???:  {prgmode, mirror}  <= prg_din[1:0];
			6'b10_0_???:  prgreg1            <= prg_din[4:0];
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

assign vram_ce = chr_ain[13];
assign prg_aout = {4'b00_00, prgsel, prg_ain[12:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};

endmodule

// Mapper 42, used for hacked FDS games converted to cartridge form
module Mapper42(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                     // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                    // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                    // Allow write
	output vram_a10,                     // Value for A10 address line
	output vram_ce,                      // True if the address should be routed to the internal 2kB VRAM.
	output reg irq
);

reg [3:0] prg_bank;
reg [3:0] chr_bank;
reg [3:0] prg_sel;
reg mirroring;
reg irq_enable;
reg [14:0] irq_counter;

always @(posedge clk)
if (reset) begin
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
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                             // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                            // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                            // Allow write
	output reg vram_a10,                         // Value for A10 address line
	output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
	output reg irq
);

reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
	chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
reg mirroring;
reg irq_ack;
reg irq_enable;
reg [15:0] irq_reload;
reg [15:0] irq_counter;

always @(posedge clk)
if (reset) begin
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
endmodule


// 41 - Caltron 6-in-1
module Mapper41(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [2:0] prg_bank;
reg [1:0] chr_outer_bank, chr_inner_bank;
reg mirroring;

always @(posedge clk) if (reset) begin
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


// #105 - NES-EVENT. Retrofits an MMC3 with lots of extra logic.
module NesEvent(
	input clk,
	input ce,
	input reset,
	input [15:0] prg_ain,
	output reg [21:0] prg_aout,
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	input [3:0] mmc1_chr,                   // Upper 4 CHR output control bits from MMC chip
	input [21:0] mmc1_aout,                 // PRG output address from MMC chip
	output irq
);

// $A000-BFFF:   [...I OAA.]
//      I = IRQ control / initialization toggle
//      O = PRG Mode/Chip select
//      A = PRG Reg 'A'
// Mapper gets "initialized" by setting I bit to 0 then to 1.
// On powerup and reset, the first 32k of PRG (from the first PRG chip) is selected at $8000 *no matter what*.
// PRG cannot be swapped until the mapper has been "initialized" by setting the 'I' bit to 0, then to '1'.  This
// toggling will "unlock" PRG swapping on the mapper.
reg unlocked, old_val;
reg [29:0] counter;

reg [3:0] oldbits;
always @(posedge clk) if (reset) begin
	old_val <= 0;
	unlocked <= 0;
	counter <= 0;
end else if (ce) begin
	// Handle unlock.
	if (mmc1_chr[3] && !old_val) unlocked <= 1;
	old_val <= mmc1_chr[3];
	// The 'I' bit in $A000 controls the IRQ counter.  When cleared, the IRQ counter counts up every cycle. When
	// set, the IRQ counter is reset to 0 and stays there (does not count), and the pending IRQ is acknowledged.
	counter <= mmc1_chr[3] ? 1'd0 : counter + 1'd1;

	if (mmc1_chr != oldbits) begin
	oldbits <= mmc1_chr;
	end
end

// In the official tournament, 'C' was closed, and the others were open, so the counter had to reach $2800000.
assign irq = (counter[29:25] == 5'b10100);

always begin
	if (!prg_ain[15]) begin
		// WRAM is always routed as usual.
		prg_aout = mmc1_aout;
	end else if (!unlocked) begin
		// Not initialized yet, mapper switch disabled.
		prg_aout = {7'b00_0000_0, prg_ain[14:0]};
	end else if (mmc1_chr[2] == 0) begin
		// O=0: Use first PRG chip (first 128k), use 'A' PRG Reg, 32k swap
		prg_aout = {5'b00_000, mmc1_chr[1:0], prg_ain[14:0]};
	end else begin
		// O=1: Use second PRG chip (second 128k), use 'B' PRG Reg, MMC1 style swap
		prg_aout = mmc1_aout;
	end
end

// 8kB CHR RAM.
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};

endmodule


// 218 - Magic Floor
module Mapper218(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
assign chr_allow =1'b1;
assign chr_aout = {9'b10_0000_000, chr_ain[12:11], vram_a10, chr_ain[9:0]};
assign vram_ce = 1'b1; //Always internal CHR RAM (no CHR ROM or RAM on cart)
assign vram_a10 = flags[16] ? (flags[14] ? chr_ain[13] : chr_ain[12]) : flags[14] ? chr_ain[10] : chr_ain[11]; // 11=1ScrB, 10=1ScrA, 01=vertical,00=horizontal
assign prg_allow = prg_ain[15] && !prg_write;

endmodule

// iNES Mapper 228 represents the board used by Active Enterprises for Action 52 and Cheetahmen II.
module Mapper228(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg mirroring;
reg [1:0] prg_chip;
reg [4:0] prg_bank;
reg prg_bank_mode;
reg [5:0] chr_bank;
always @(posedge clk)
if (reset) begin
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
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [2:0] block, inner_chr;
reg mode, mirroring, inner_prg;
always @(posedge clk)
if (reset) begin
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


// 92 - Jaleco JF-19 -- no audio samples
// 72 - Jaleco JF-17 -- no audio samples
module Mapper72(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                   // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                  // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                  // Allow write
	output vram_a10,                   // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [3:0] prg_bank;
reg [3:0] chr_bank;
wire [7:0] mapper = flags[7:0];
reg last_prg;
reg last_chr;
wire mapper72 = (mapper == 72);

always @(posedge clk)
if (reset) begin
	prg_bank <= 0;
	chr_bank <= 0;
	last_prg <= 0;
	last_chr <= 0;
end else if (ce) begin
	if (prg_ain[15] & prg_write) begin
		if ((!last_prg) && (prg_din[7]))
			{prg_bank} <= {prg_din[3:0]};

		if ((!last_chr) && (prg_din[6]))
			{chr_bank} <= {prg_din[3:0]};

		{last_prg, last_chr} <= prg_din[7:6];
	end
end

assign prg_aout = {4'b00_00, prg_ain[14] ^ mapper72 ? prg_bank : mapper72 ? 4'b1111 : 4'b0000, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule
