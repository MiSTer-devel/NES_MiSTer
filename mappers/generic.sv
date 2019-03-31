// These mappers are simple generic mappers which can eventually be combined into a single module with parameters

// No mapper chip
module MMC0(
	input clk,
	input ce,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read, 
	input prg_write,             // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                      // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      // Allow write
	output vram_a10,                       // Value for A10 address line
	output vram_ce                         // True if the address should be routed to the internal 2kB VRAM.
);

assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule

// #13 - CPROM - Used by Videomation
module Mapper13(
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
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      // Allow write
	output vram_a10,                       // Value for A10 address line
	output vram_ce                         // True if the address should be routed to the internal 2kB VRAM.
);

reg [1:0] chr_bank;
always @(posedge clk) begin
	if (reset) begin
		chr_bank <= 0;
	end else if (ce) begin
		if (prg_ain[15] && prg_write)
			chr_bank <= prg_din[1:0];
	end
end

assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {8'b01_0000_00, chr_ain[12] ? chr_bank : 2'b00, chr_ain[11:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule

// 30-UNROM512
module Mapper30(
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
	output reg vram_a10,               // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [4:0] prgbank;
reg [1:0] chrbank;
reg [2:0] mirror;
wire four_screen = (mirror[2:1] == 2'b11);

always @(posedge clk) begin
	if (reset) begin
		// Set value for mirroring
		mirror[2:1] <= {flags[16], flags[14]};
	end else if (ce) begin
		if (prg_ain[15] & prg_write) begin
			{mirror[0], chrbank, prgbank}   <= prg_din[7:0];
		end
	end
end

always begin
	// mirroring mode
	casez({mirror[2:1],chr_ain[13]})
		3'b001   :   vram_a10 = {chr_ain[11]};    // horizontal
		3'b011   :   vram_a10 = {chr_ain[10]};    // vertical
		3'b101   :   vram_a10 = {mirror[0]};      // 1 screen
		3'b111   :   vram_a10 = {chr_ain[10]};    // 4 screen
		default  :   vram_a10 = {chr_ain[10]};    // pattern table
	endcase
end

assign prg_aout = {3'b000, prg_ain[14] ? 5'b11111 : prgbank, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {flags[15] ? 7'b11_1111_1 : 7'b10_0000_0, (four_screen && (chr_ain[13])) ? 2'b11 : chrbank, chr_ain[12:11], vram_a10, chr_ain[9:0]};
assign vram_ce = chr_ain[13] && !four_screen;

endmodule


// 11 - Color Dreams
// 38 - Bit Corps
// 86 - Jaleco JF-13 -- no audio samples
// 87 - Jaleco JF-11,JF-14
// 101 - Jaleco JF-11,JF-14
// 140 - Jaleco JF-11,JF-14
// 66 - GxROM
module Mapper66(
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

reg [1:0] prg_bank;
reg [3:0] chr_bank;
wire [7:0] mapper = flags[7:0];
wire GXROM = (mapper == 66);
wire BitCorps = (mapper == 38);
wire Mapper140 = (mapper == 140);
wire Mapper101 = (mapper == 101);
wire Mapper86 = (mapper == 86);
wire Mapper87 = (mapper == 87);

always @(posedge clk) if (reset) begin
	prg_bank <= 0;
	chr_bank <= 0;
end else if (ce) begin
	if (prg_ain[15] & prg_write) begin
		if (GXROM)
			{prg_bank, chr_bank} <= {prg_din[5:4], 2'b0, prg_din[1:0]};
		else // Color Dreams
			{chr_bank, prg_bank} <= {prg_din[7:4], prg_din[1:0]};
	end else if ((prg_ain[15:12]==4'h7) & prg_write & BitCorps) begin
		{chr_bank, prg_bank} <= {prg_din[3:0]};
	end else if ((prg_ain[15:12]==4'h6) & prg_write) begin
		if (Mapper140) begin
			{prg_bank, chr_bank} <= {prg_din[5:4], prg_din[3:0]};
		end else if (Mapper101) begin
			{chr_bank} <= {prg_din[3:0]}; // All 8 bits instead?
		end else if (Mapper87) begin
			{chr_bank} <= {2'b00, prg_din[0], prg_din[1]};
		end else if (Mapper86) begin
			{prg_bank, chr_bank} <= {prg_din[5:4], 1'b0, prg_din[6], prg_din[1:0]};
		end
	end
end

assign prg_aout = {5'b00_000, prg_bank, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

endmodule


// 34 - BxROM or NINA-001
module Mapper34(
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
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      // Allow write
	output vram_a10,                       // Value for A10 address line
	output vram_ce                         // True if the address should be routed to the internal 2kB VRAM.
);

reg [5:0] prg_bank;
reg [3:0] chr_bank_0, chr_bank_1;

wire NINA = (flags[13:11] != 0); // NINA is used when there is more than 8kb of CHR
always @(posedge clk) if (reset) begin
	prg_bank <= 0;
	chr_bank_0 <= 0;
	chr_bank_1 <= 1; // To be compatible with BxROM
end else if (ce && prg_write) begin
	if (!NINA) begin // BxROM
		if (prg_ain[15])
			prg_bank <= prg_din[5:0]; //[1:0] offical, [5:0] oversize
	end else begin // NINA
		if (prg_ain == 16'h7ffd)
			prg_bank <= prg_din[5:0]; //[1:0] offical, [5:0] oversize
		else if (prg_ain == 16'h7ffe)
			chr_bank_0 <= prg_din[3:0];
		else if (prg_ain == 16'h7fff)
			chr_bank_1 <= prg_din[3:0];
	end
end

wire [21:0] prg_aout_tmp = {1'b0, prg_bank, prg_ain[14:0]};
assign chr_allow = flags[15];
assign chr_aout = {6'b10_0000, chr_ain[12] == 0 ? chr_bank_0 : chr_bank_1, chr_ain[11:0]};
assign vram_ce = chr_ain[13];
assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

wire prg_is_ram = (prg_ain >= 'h6000 && prg_ain < 'h8000) && NINA;
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;

wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;

endmodule


// #71,#232 - Camerica
module Mapper71(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,                    // Read / write signals
	input [7:0] prg_din,
	output prg_allow,                   // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                   // Allow write
	output vram_a10,                    // Value for A10 address line
	output vram_ce                      // True if the address should be routed to the internal 2kB VRAM.
);

reg [3:0] prg_bank;
reg ciram_select;
wire mapper232 = (flags[7:0] == 232);
always @(posedge clk) if (reset) begin
	prg_bank <= 0;
	ciram_select <= 0;
end else if (ce) begin
	if (prg_ain[15] && prg_write) begin
		if (!prg_ain[14] && mapper232) // $8000-$BFFF Outer bank select (only on iNES 232)
			prg_bank[3:2] <= prg_din[4:3];
		if (prg_ain[14:13] == 0)       // $8000-$9FFF Fire Hawk Mirroring
			ciram_select <= prg_din[4];
		if (prg_ain[14])               // $C000-$FFFF Bank select
			prg_bank <= {mapper232 ? prg_bank[3:2] : prg_din[3:2], prg_din[1:0]};
	end
end

reg [3:0] prgout;
always begin
	casez({prg_ain[14], mapper232})
		2'b0?: prgout = prg_bank;
		2'b10: prgout = 4'b1111;
		2'b11: prgout = {prg_bank[3:2], 2'b11};
	endcase
end

assign prg_aout = {4'b00_00, prgout, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
// XXX(ludde): Fire hawk uses flags[14] == 0 while no other game seems to do that.
// So when flags[14] == 0 we use ciram_select instead.
assign vram_a10 = flags[14] ? chr_ain[10] : ciram_select;

endmodule


// 77-IREM
module Mapper77(
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
	output reg vram_a10,               // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [3:0] prgbank;
reg [3:0] chrbank;

always @(posedge clk) begin
	if (reset) begin
		prgbank <= 0;
		chrbank <= 0;
	end else if (ce) begin
		if (prg_ain[15] & prg_write) begin
			{chrbank, prgbank}   <= prg_din[7:0];
		end
	end
end

always begin
	vram_a10 = {chr_ain[10]};    // four screen (consecutive)
end

assign prg_aout = {3'b000, prgbank, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = chrram;
wire chrram = (chr_ain[13:11]!=3'b000);
assign chr_aout[10:0] = {chr_ain[10:0]};
assign chr_aout[21:11] = chrram ? {8'b11_1111_11, chr_ain[13:11]} : {7'b10_0000_0, chrbank};
assign vram_ce = 0;

endmodule

// #78-IREM-HOLYDIVER/JALECO-JF-16
// #70,#152-Bandai
module Mapper78(
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
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,                      // Allow write
	output vram_a10,                       // Value for A10 address line
	output vram_ce                         // True if the address should be routed to the internal 2kB VRAM.
);

reg [3:0] prg_bank;
reg [3:0] chr_bank;
reg mirroring;  // See vram_a10_t
wire mapper70 = (flags[7:0] == 70);
wire mapper152 = (flags[7:0] == 152);
wire onescreen = (flags[22:21] == 1) | mapper152; // default (0 or 3) Holy Diver submapper; (1) JALECO-JF-16
always @(posedge clk) begin
	if (reset) begin
		prg_bank <= 0;
		chr_bank <= 0;
		mirroring <= flags[14];
	end else if (ce) begin
		if (prg_ain[15] == 1'b1 && prg_write) begin
			if (mapper70)
				{prg_bank, chr_bank} <= prg_din;
			else if (mapper152)
				{mirroring, prg_bank[2:0], chr_bank} <= prg_din;
			else
				{chr_bank, mirroring, prg_bank[2:0]} <= prg_din;
		end
	end
end

assign prg_aout = {4'b00_00, (prg_ain[14] ? 4'b1111 : prg_bank), prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];

// The a10 VRAM address line. (Used for mirroring)
reg vram_a10_t;
always begin
	case({onescreen, mirroring})
		2'b00: vram_a10_t = chr_ain[11];   // One screen, horizontal
		2'b01: vram_a10_t = chr_ain[10];   // One screen, vertical
		2'b10: vram_a10_t = 0;             // One screen, lower bank
		2'b11: vram_a10_t = 1;             // One screen, upper bank
	endcase
end

assign vram_a10 = vram_a10_t;

endmodule

// #79,#113 - NINA-03 / NINA-06
module Mapper79(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,               // Read / write signals
	input [7:0] prg_din,
	output prg_allow,              // Enable access to memory for the specified operation.
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,              // Allow write
	output vram_a10,               // Value for A10 address line
	output vram_ce                 // True if the address should be routed to the internal 2kB VRAM.
);

reg [2:0] prg_bank;
reg [3:0] chr_bank;
reg mirroring;  // 0: Horizontal, 1: Vertical
wire mapper113 = (flags[7:0] == 113); // NINA-06

always @(posedge clk) if (reset) begin
	prg_bank <= 0;
	chr_bank <= 0;
	mirroring <= 0;
end else if (ce) begin
	if (prg_ain[15:13] == 3'b010 && prg_ain[8] && prg_write)
		{mirroring, chr_bank[3], prg_bank, chr_bank[2:0]} <= prg_din;
end

assign prg_aout = {4'b00_00, prg_bank, prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
assign vram_ce = chr_ain[13];
wire mirrconfig = mapper113 ? mirroring : flags[14]; // Mapper #13 has mapper controlled mirroring
assign vram_a10 = mirrconfig ? chr_ain[10] : chr_ain[11]; // 0: horiz, 1: vert

endmodule


// #89,#93,#184 - Sunsoft mappers
module Mapper89(
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
	output reg vram_a10,               // Value for A10 address line
	output vram_ce                     // True if the address should be routed to the internal 2kB VRAM.
);

reg [2:0] prgsel;
reg [3:0] chrsel0;
reg [3:0] chrsel1;
reg [2:0] prg_temp;
reg [4:0] chr_temp;

reg mirror;

wire [7:0] mapper = flags[7:0];
wire mapper89 = (mapper == 8'd89);
wire mapper93 = (mapper == 8'd93);
wire mapper184 = (mapper == 8'd184);

always @(posedge clk) if (reset) begin
	prgsel <= 3'b110;
	chrsel0 <= 4'b1111;
	chrsel1 <= 4'b1111;
end else if (ce) begin
	if (prg_ain[15] & prg_write & mapper89) begin
		{chrsel0[3], prgsel, mirror, chrsel0[2:0]} <= prg_din;
	end else if (prg_ain[15] & prg_write & mapper93) begin
		prgsel <= prg_din[6:4];
		// chrrameanble <= prg_din[0];
	end else if ((prg_ain[15:13]==3'b011) & prg_write & mapper184) begin
		{chrsel1[3:0], chrsel0[3:0]}  <= {2'b01,prg_din[5:4],1'b0,prg_din[2:0]};
	end
end

always begin
	// mirroring mode
	casez({mapper89,flags[14]})
		2'b00   :   vram_a10 = {chr_ain[11]};    // horizontal
		2'b01   :   vram_a10 = {chr_ain[10]};    // vertical
		2'b1?   :   vram_a10 = {mirror};         // 1 screen
	endcase

	// PRG ROM bank size select
	casez({mapper184, prg_ain[14]})
		2'b00 :  prg_temp = {prgsel};            // 16K banks
		2'b01 :  prg_temp = {3'b111};            // 16K banks last
		2'b1? :  prg_temp = {2'b0,prg_ain[14]};  // 32K banks pass thru
	endcase

	// CHR ROM bank size select
	casez({mapper184, chr_ain[12]})
		2'b0? :  chr_temp = {chrsel0, chr_ain[12]};// 8K Bank
		2'b10 :  chr_temp = {1'b0,chrsel0};  // 4K Bank
		2'b11 :  chr_temp = {1'b0,chrsel1};  // 4K Bank
	endcase
end

assign vram_ce = chr_ain[13];
assign prg_aout = {5'b0, prg_temp, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {5'b10_000, chr_temp, chr_ain[11:0]};

endmodule



// 107 Magicseries Magic Dragon
module Mapper107(
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

reg [6:0] prg_bank;
reg [7:0] chr_bank;
always @(posedge clk) begin
	if (reset) begin
		prg_bank <= 0;
		chr_bank <= 0;
	end else if (ce) begin
		if (prg_ain[15] & prg_write) begin
			prg_bank <= prg_din[7:1];
			chr_bank <= prg_din[7:0];
		end
	end
end

assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
assign prg_aout = {1'b0, prg_bank[5:0], prg_ain[14:0]};
assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {2'b10, chr_bank[6:0], chr_ain[12:0]};
assign vram_ce = chr_ain[13];

endmodule