// Mapper top level selection

module cart_top (
	input             clk,
	input             ce,
	input             ppu_ce,
	input             reset,
	input      [19:0] ppuflags,       // Misc flags from PPU for MMC5 cheating
	input      [31:0] flags,          // Misc flags from ines header {prg_size(3), chr_size(3), mapper(8)}
	input      [15:0] prg_ain,
	output reg [21:0] prg_aout,       // PRG Input / Output Address Lines
	input             prg_read,       // PRG Read / write signals
	input             prg_write,
	input       [7:0] prg_din,
	output reg  [7:0] prg_dout,       // PRG Data
	input       [7:0] prg_from_ram,   // PRG Data from RAM
	output reg        prg_allow,      // PRG Allow write access
	output reg        prg_open_bus,   // PRG Data Not Driven
	output reg        prg_conflict,   // PRG Data is ROM & prg_din
	input             chr_read,       // Read from CHR
	input             chr_write,      // Write to CHR
	input       [7:0] chr_din,
	input      [13:0] chr_ain,
	output reg [21:0] chr_aout,       // CHR Input / Output Address Lines
	output reg  [7:0] chr_dout,       // Value to override CHR data with
	output reg        has_chr_dout,   // True if CHR data should be overridden
	output reg        chr_allow,      // CHR Allow write
	output reg        vram_a10,       // CHR Value for A10 address line
	output reg        vram_ce,        // CHR True if the address should be routed to the internal 2kB VRAM.
	output reg [14:0] mapper_addr,
	input       [7:0] mapper_data_in,
	output reg  [7:0] mapper_data_out,
	output reg        mapper_prg_write,
	output reg        mapper_ovr,
	output reg        irq,
	output reg [15:0] audio,          // External Audio
	input             fds_swap        // FDS Disk Swap Pause
);

wire mmc0_prg_allow, mmc0_vram_a10, mmc0_vram_ce, mmc0_chr_allow;
wire [21:0] mmc0_prg_addr, mmc0_chr_addr;
MMC0 mmc0(clk, ce, flags, prg_ain, mmc0_prg_addr, prg_read, prg_write, prg_din, mmc0_prg_allow, chr_ain, mmc0_chr_addr,
	mmc0_chr_allow, mmc0_vram_a10, mmc0_vram_ce);

wire mmc1_prg_allow, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow;
wire [21:0] mmc1_prg_addr, mmc1_chr_addr;
MMC1 mmc1(clk, ce, reset, flags, prg_ain, mmc1_prg_addr, prg_read, prg_write, prg_din, mmc1_prg_allow, chr_ain, mmc1_chr_addr,
	mmc1_chr_allow, mmc1_vram_a10, mmc1_vram_ce);

wire map28_prg_allow, map28_open_bus, map28_conflict, map28_vram_a10, map28_vram_ce, map28_chr_allow;
wire [21:0] map28_prg_addr, map28_chr_addr;
wire [7:0]  map28_chr_dout;
wire  map28_has_chr_dout;
Mapper28 map28(clk, ce, reset, flags, prg_ain, map28_prg_addr, prg_read, prg_write, prg_din, map28_prg_allow, map28_open_bus, map28_conflict,
	chr_ain, map28_chr_addr, map28_chr_dout, map28_has_chr_dout, map28_chr_allow, map28_vram_a10, map28_vram_ce);

wire map30_prg_allow, map30_vram_a10, map30_vram_ce, map30_chr_allow;
wire [21:0] map30_prg_addr, map30_chr_addr;
Mapper30 map30(clk, ce, reset, flags, prg_ain, map30_prg_addr, prg_read, prg_write, prg_din, map30_prg_allow,
	chr_ain, map30_chr_addr, map30_chr_allow, map30_vram_a10, map30_vram_ce);

wire map32_prg_allow, map32_vram_a10, map32_vram_ce, map32_chr_allow;
wire [21:0] map32_prg_addr, map32_chr_addr;
Mapper32 map32(clk, ce, reset, flags, prg_ain, map32_prg_addr, prg_read, prg_write, prg_din, map32_prg_allow,
	chr_ain, map32_chr_addr, map32_chr_allow, map32_vram_a10, map32_vram_ce);

wire mmc2_prg_allow, mmc2_vram_a10, mmc2_vram_ce, mmc2_chr_allow;
wire [21:0] mmc2_prg_addr, mmc2_chr_addr;
MMC2 mmc2(clk, ppu_ce, reset, flags, prg_ain, mmc2_prg_addr, prg_read, prg_write, prg_din, mmc2_prg_allow,
	chr_read, chr_ain, mmc2_chr_addr, mmc2_chr_allow, mmc2_vram_a10, mmc2_vram_ce);

wire mmc3_prg_allow, mmc3_vram_a10, mmc3_vram_ce, mmc3_chr_allow, mmc3_irq;
wire [21:0] mmc3_prg_addr, mmc3_chr_addr;
MMC3 mmc3(clk, ppu_ce, reset, flags, prg_ain, mmc3_prg_addr, prg_read, prg_write, prg_din, mmc3_prg_allow,
	chr_ain, mmc3_chr_addr, mmc3_chr_allow, mmc3_vram_a10, mmc3_vram_ce, mmc3_irq);

wire mmc4_prg_allow, mmc4_vram_a10, mmc4_vram_ce, mmc4_chr_allow;
wire [21:0] mmc4_prg_addr, mmc4_chr_addr;
MMC4 mmc4(clk, ppu_ce, reset, flags, prg_ain, mmc4_prg_addr, prg_read, prg_write, prg_din, mmc4_prg_allow,
	chr_read, chr_ain, mmc4_chr_addr, mmc4_chr_allow, mmc4_vram_a10, mmc4_vram_ce);

wire mmc5_prg_allow, mmc5_vram_a10, mmc5_vram_ce, mmc5_chr_allow, mmc5_irq;
wire [21:0] mmc5_prg_addr, mmc5_chr_addr;
wire [7:0] mmc5_chr_dout, mmc5_prg_dout;
wire mmc5_has_chr_dout;
wire [15:0] mmc5_audio;
MMC5 mmc5(clk, ce, ppu_ce, reset, flags, ppuflags, prg_ain, mmc5_prg_addr, prg_read, prg_write, prg_din, mmc5_prg_dout, mmc5_prg_allow,
	chr_read, chr_write, chr_din, chr_ain, mmc5_chr_addr, mmc5_chr_dout, mmc5_has_chr_dout, mmc5_chr_allow, mmc5_vram_a10,
	mmc5_vram_ce, mmc5_irq, mmc5_audio);

wire map13_prg_allow, map13_vram_a10, map13_vram_ce, map13_chr_allow;
wire [21:0] map13_prg_addr, map13_chr_addr;
Mapper13 map13(clk, ce, reset, flags, prg_ain, map13_prg_addr, prg_read, prg_write, prg_din, map13_prg_allow,
	chr_ain, map13_chr_addr, map13_chr_allow, map13_vram_a10, map13_vram_ce);

wire map15_prg_allow, map15_vram_a10, map15_vram_ce, map15_chr_allow;
wire [21:0] map15_prg_addr, map15_chr_addr;
Mapper15 map15(clk, ce, reset, flags, prg_ain, map15_prg_addr, prg_read, prg_write, prg_din, map15_prg_allow,
	chr_ain, map15_chr_addr, map15_chr_allow, map15_vram_a10, map15_vram_ce);

wire map16_prg_allow, map16_vram_a10, map16_vram_ce, map16_chr_allow, map16_irq, map16_prg_write, map16_ovr;
wire [21:0] map16_prg_addr, map16_chr_addr;
wire [7:0] map16_prg_dout, map16_data_out;
wire [14:0] map16_mapper_addr;
Mapper16 map16(clk, ce, reset, flags, prg_ain, map16_prg_addr, prg_read, prg_write, prg_din, map16_prg_dout, map16_prg_allow,
	chr_ain, map16_chr_addr, map16_chr_allow, map16_vram_a10, map16_vram_ce, map16_mapper_addr, mapper_data_in,
	map16_data_out, map16_prg_write, map16_ovr, map16_irq);

wire map18_prg_allow, map18_vram_a10, map18_vram_ce, map18_chr_allow, map18_irq;
wire [21:0] map18_prg_addr, map18_chr_addr;
wire [7:0] map18_prg_dout;
Mapper18 map18(clk, ce, reset, flags, prg_ain, map18_prg_addr, prg_read, prg_write, prg_din, map18_prg_dout, map18_prg_allow,
	chr_ain, map18_chr_addr, map18_chr_allow, map18_vram_a10, map18_vram_ce, map18_irq);

wire map34_prg_allow, map34_vram_a10, map34_vram_ce, map34_chr_allow;
wire [21:0] map34_prg_addr, map34_chr_addr;
Mapper34 map34(clk, ce, reset, flags, prg_ain, map34_prg_addr, prg_read, prg_write, prg_din, map34_prg_allow,
	chr_ain, map34_chr_addr, map34_chr_allow, map34_vram_a10, map34_vram_ce);

wire map41_prg_allow, map41_vram_a10, map41_vram_ce, map41_chr_allow;
wire [21:0] map41_prg_addr, map41_chr_addr;
Mapper41 map41(clk, ce, reset, flags, prg_ain, map41_prg_addr, prg_read, prg_write, prg_din, map41_prg_allow,
	chr_ain, map41_chr_addr, map41_chr_allow, map41_vram_a10, map41_vram_ce);

wire map42_prg_allow, map42_vram_a10, map42_vram_ce, map42_chr_allow, map42_irq;
wire [21:0] map42_prg_addr, map42_chr_addr;
Mapper42 map42(clk, ce, reset, flags, prg_ain, map42_prg_addr, prg_read, prg_write, prg_din, map42_prg_allow,
	chr_ain, map42_chr_addr, map42_chr_allow, map42_vram_a10, map42_vram_ce, map42_irq);

wire map65_prg_allow, map65_vram_a10, map65_vram_ce, map65_chr_allow, map65_irq;
wire [21:0] map65_prg_addr, map65_chr_addr;
Mapper65 map65(clk, ce, reset, flags, prg_ain, map65_prg_addr, prg_read, prg_write, prg_din, map65_prg_allow,
	chr_ain, map65_chr_addr, map65_chr_allow, map65_vram_a10, map65_vram_ce, map65_irq);

wire map66_prg_allow, map66_vram_a10, map66_vram_ce, map66_chr_allow;
wire [21:0] map66_prg_addr, map66_chr_addr;
Mapper66 map66(clk, ce, reset, flags, prg_ain, map66_prg_addr, prg_read, prg_write, prg_din, map66_prg_allow,
	chr_ain, map66_chr_addr, map66_chr_allow, map66_vram_a10, map66_vram_ce);

wire map67_prg_allow, map67_vram_a10, map67_vram_ce, map67_chr_allow, map67_irq;
wire [21:0] map67_prg_addr, map67_chr_addr;
Mapper67 map67(clk, ce, reset, flags, prg_ain, map67_prg_addr, prg_read, prg_write, prg_din, map67_prg_allow,
	chr_ain, map67_chr_addr, map67_chr_allow, map67_vram_a10, map67_vram_ce, map67_irq);

wire map68_prg_allow, map68_vram_a10, map68_vram_ce, map68_chr_allow;
wire [21:0] map68_prg_addr, map68_chr_addr;
Mapper68 map68(clk, ce, reset, flags, prg_ain, map68_prg_addr, prg_read, prg_write, prg_din, map68_prg_allow,
	chr_ain, map68_chr_addr, map68_chr_allow, map68_vram_a10, map68_vram_ce);

wire map69_prg_allow, map69_vram_a10, map69_vram_ce, map69_chr_allow, map69_irq;
wire [21:0] map69_prg_addr, map69_chr_addr;
wire [15:0] map69_audio;
Mapper69 map69(clk, ce, reset, flags, prg_ain, map69_prg_addr, prg_read, prg_write, prg_din, map69_prg_allow,
	chr_ain, map69_chr_addr, map69_chr_allow, map69_vram_a10, map69_vram_ce, map69_irq, map69_audio);

wire map71_prg_allow, map71_vram_a10, map71_vram_ce, map71_chr_allow;
wire [21:0] map71_prg_addr, map71_chr_addr;
Mapper71 map71(clk, ce, reset, flags, prg_ain, map71_prg_addr, prg_read, prg_write, prg_din, map71_prg_allow,
	chr_ain, map71_chr_addr, map71_chr_allow, map71_vram_a10, map71_vram_ce);

wire map72_prg_allow, map72_vram_a10, map72_vram_ce, map72_chr_allow;
wire [21:0] map72_prg_addr, map72_chr_addr;
Mapper72 map72(clk, ce, reset, flags, prg_ain, map72_prg_addr, prg_read, prg_write, prg_din, map72_prg_allow,
	chr_ain, map72_chr_addr, map72_chr_allow, map72_vram_a10, map72_vram_ce);

wire map77_prg_allow, map77_vram_a10, map77_vram_ce, map77_chr_allow;
wire [21:0] map77_prg_addr, map77_chr_addr;
Mapper77 map77(clk, ce, reset, flags, prg_ain, map77_prg_addr, prg_read, prg_write, prg_din, map77_prg_allow,
	chr_ain, map77_chr_addr, map77_chr_allow, map77_vram_a10, map77_vram_ce);

wire map78_prg_allow, map78_vram_a10, map78_vram_ce, map78_chr_allow;
wire [21:0] map78_prg_addr, map78_chr_addr;
Mapper78 map78(clk, ce, reset, flags, prg_ain, map78_prg_addr, prg_read, prg_write, prg_din, map78_prg_allow,
	chr_ain, map78_chr_addr, map78_chr_allow, map78_vram_a10, map78_vram_ce);

wire map79_prg_allow, map79_vram_a10, map79_vram_ce, map79_chr_allow;
wire [21:0] map79_prg_addr, map79_chr_addr;
Mapper79 map79(clk, ce, reset, flags, prg_ain, map79_prg_addr, prg_read, prg_write, prg_din, map79_prg_allow,
	chr_ain, map79_chr_addr, map79_chr_allow, map79_vram_a10, map79_vram_ce);

wire map89_prg_allow, map89_vram_a10, map89_vram_ce, map89_chr_allow;
wire [21:0] map89_prg_addr, map89_chr_addr;
Mapper89 map89(clk, ce, reset, flags, prg_ain, map89_prg_addr, prg_read, prg_write, prg_din, map89_prg_allow,
	chr_ain, map89_chr_addr, map89_chr_allow, map89_vram_a10, map89_vram_ce);

wire map107_prg_allow, map107_vram_a10, map107_vram_ce, map107_chr_allow;
wire [21:0] map107_prg_addr, map107_chr_addr;
Mapper107 map107(clk, ce, reset, flags, prg_ain, map107_prg_addr, prg_read, prg_write, prg_din, map107_prg_allow,
	chr_ain, map107_chr_addr, map107_chr_allow, map107_vram_a10, map107_vram_ce);

wire map165_prg_allow, map165_vram_a10, map165_vram_ce, map165_chr_allow, map165_irq;
wire [21:0] map165_prg_addr, map165_chr_addr;
Mapper165 map165(clk, ppu_ce, reset, flags, prg_ain, map165_prg_addr, prg_read, prg_write, prg_din, map165_prg_allow,
	chr_read, chr_ain, map165_chr_addr, map165_chr_allow, map165_vram_a10, map165_vram_ce, map165_irq);

wire map218_prg_allow, map218_vram_a10, map218_vram_ce, map218_chr_allow;
wire [21:0] map218_prg_addr, map218_chr_addr;
Mapper218 map218(clk, ce, reset, flags, prg_ain, map218_prg_addr, prg_read, prg_write, prg_din, map218_prg_allow,
	chr_ain, map218_chr_addr, map218_chr_allow, map218_vram_a10, map218_vram_ce);

wire map228_prg_allow, map228_vram_a10, map228_vram_ce, map228_chr_allow;
wire [21:0] map228_prg_addr, map228_chr_addr;
Mapper228 map228(clk, ce, reset, flags, prg_ain, map228_prg_addr, prg_read, prg_write, prg_din, map228_prg_allow,
	chr_ain, map228_chr_addr, map228_chr_allow, map228_vram_a10, map228_vram_ce);


wire map234_prg_allow, map234_vram_a10, map234_vram_ce, map234_chr_allow;
wire [21:0] map234_prg_addr, map234_chr_addr;
Mapper234 map234(clk, ce, reset, flags, prg_ain, map234_prg_addr, prg_read, prg_write, prg_from_ram, map234_prg_allow,
	chr_ain, map234_chr_addr, map234_chr_allow, map234_vram_a10, map234_vram_ce);

wire rambo1_prg_allow, rambo1_vram_a10, rambo1_vram_ce, rambo1_chr_allow, rambo1_irq;
wire [21:0] rambo1_prg_addr, rambo1_chr_addr;
Rambo1 rambo1(clk, ce, reset, flags, prg_ain, rambo1_prg_addr, prg_read, prg_write, prg_din, rambo1_prg_allow,
	chr_ain, rambo1_chr_addr, rambo1_chr_allow, rambo1_vram_a10, rambo1_vram_ce, rambo1_irq);

wire [21:0] nesev_prg_addr, nesev_chr_addr;
wire nesev_irq;
NesEvent nesev(clk, ce, reset, prg_ain, nesev_prg_addr, chr_ain, nesev_chr_addr, mmc1_chr_addr[16:13], mmc1_prg_addr, nesev_irq);

wire vrc1_prg_allow, vrc1_vram_a10, vrc1_vram_ce, vrc1_chr_allow;
wire [21:0] vrc1_prg_addr, vrc1_chr_addr;
VRC1 vrc1(clk, ce, reset, flags, prg_ain, vrc1_prg_addr, prg_read, prg_write, prg_din, vrc1_prg_allow,
	chr_ain, vrc1_chr_addr, vrc1_chr_allow, vrc1_vram_a10, vrc1_vram_ce);

wire vrc3_prg_allow, vrc3_vram_a10, vrc3_vram_ce, vrc3_chr_allow, vrc3_irq;
wire [21:0] vrc3_prg_addr, vrc3_chr_addr;
VRC3 vrc3(clk, ce, reset, flags, prg_ain, vrc3_prg_addr, prg_read, prg_write, prg_din, vrc3_prg_allow,
	chr_ain, vrc3_chr_addr, vrc3_chr_allow, vrc3_vram_a10, vrc3_vram_ce, vrc3_irq);

wire vrc24_prg_allow, vrc24_vram_a10, vrc24_vram_ce, vrc24_chr_allow, vrc24_irq;
wire [21:0] vrc24_prg_addr, vrc24_chr_addr;
VRC24 vrc24(clk, ce, reset, flags, prg_ain, vrc24_prg_addr, prg_read, prg_write, prg_din, vrc24_prg_allow,
	chr_ain, vrc24_chr_addr, vrc24_chr_allow, vrc24_vram_a10, vrc24_vram_ce, vrc24_irq);

wire vrc6_prg_allow, vrc6_vram_a10, vrc6_vram_ce, vrc6_chr_allow, vrc6_irq;
wire [21:0] vrc6_prg_addr, vrc6_chr_addr;
wire [15:0] vrc6_audio;
wire [7:0] vrc6_prg_dout;
VRC6 vrc6(clk, ce, reset, flags, prg_ain, vrc6_prg_addr, prg_read, prg_write, prg_din, vrc6_prg_dout, vrc6_prg_allow,
	chr_ain, vrc6_chr_addr, vrc6_chr_allow, vrc6_vram_a10, vrc6_vram_ce, vrc6_irq, vrc6_audio);

wire vrc7_prg_allow, vrc7_vram_a10, vrc7_vram_ce, vrc7_chr_allow, vrc7_irq;
wire [21:0] vrc7_prg_addr, vrc7_chr_addr;
wire [15:0] vrc7_audio;
VRC7 vrc7(clk, ce, reset, flags, prg_ain, vrc7_prg_addr, prg_read, prg_write, prg_din, vrc7_prg_allow,
	chr_ain, vrc7_chr_addr, vrc7_chr_allow, vrc7_vram_a10, vrc7_vram_ce, vrc7_irq, vrc7_audio);

wire map19_prg_allow, map19_vram_a10, map19_vram_ce, map19_chr_allow, map19_irq;
wire [21:0] map19_prg_addr, map19_chr_addr;
wire [15:0] map19_audio;
wire [7:0] map19_prg_dout;
N106 n106(clk, ce, reset, flags, prg_ain, map19_prg_addr, prg_read, prg_write, prg_din, map19_prg_dout, map19_prg_allow,
	chr_ain, map19_chr_addr, map19_chr_allow, map19_vram_a10, map19_vram_ce, map19_irq, map19_audio);

wire mapfds_prg_allow, mapfds_vram_a10, mapfds_vram_ce, mapfds_chr_allow, mapfds_irq;
wire [21:0] mapfds_prg_addr, mapfds_chr_addr;
wire [15:0] mapfds_audio;
wire [7:0] mapfds_chr_dout, mapfds_prg_dout;
MapperFDS mapfds(clk, ce, reset, flags, prg_ain, mapfds_prg_addr, prg_read, prg_write, prg_din, mapfds_prg_dout, mapfds_prg_allow,
	chr_ain, mapfds_chr_addr, mapfds_chr_allow, mapfds_vram_a10, mapfds_vram_ce, mapfds_irq, mapfds_audio, fds_swap);

// Mask
reg [5:0] prg_mask;
reg [6:0] chr_mask;

always @* begin
	case(flags[10:8])
		0: prg_mask = 6'b000000;
		1: prg_mask = 6'b000001;
		2: prg_mask = 6'b000011;
		3: prg_mask = 6'b000111;
		4: prg_mask = 6'b001111;
		5: prg_mask = 6'b011111;
		default: prg_mask = 6'b111111;
	endcase

	case(flags[13:11])
		0: chr_mask = 7'b0000000;
		1: chr_mask = 7'b0000001;
		2: chr_mask = 7'b0000011;
		3: chr_mask = 7'b0000111;
		4: chr_mask = 7'b0001111;
		5: chr_mask = 7'b0011111;
		6: chr_mask = 7'b0111111;
		7: chr_mask = 7'b1111111;
	endcase

	irq = 0;
	prg_dout = 8'hff;
	has_chr_dout = 0;
	chr_dout = mmc5_chr_dout;
	audio = 16'h0000;
	mapper_addr = 14'h0000;
	mapper_data_out = 8'h00;
	mapper_prg_write = 1'b0;
	mapper_ovr = 1'b0;
	prg_open_bus = map28_open_bus; // Expand to other mappers?
	prg_conflict = map28_conflict; // Expand to other mappers?

	case(flags[7:0])
	155,
	1:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc1_prg_addr, mmc1_prg_allow, mmc1_chr_addr, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow};
	9:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc2_prg_addr, mmc2_prg_allow, mmc2_chr_addr, mmc2_vram_a10, mmc2_vram_ce, mmc2_chr_allow};
	118, // TxSROM connects A17 to CIRAM A10.
	119, // TQROM  uses the Nintendo MMC3 like other TxROM boards but uses the CHR bank number specially.
	47,  // Mapper 047 is a MMC3 multicart
	206, // MMC3 w/o IRQ or WRAM support
	112, // Like 206 with different layout
	88,  // NAMCOT-3433 is mapper 206-like, but connects PPU-A12 to CHROM A16.
	154, // NAMCOT-3453 is mapper 88-like, but with one screen mirroring.
	95,  // NAMCOT-3425 is mapper 206-like, but connects A16 to CIRAM A10.
	76,  // NAMCOT-3446 is mapper 206-like, but coarser chr banking.
	80,  // Taito X01-005 is MMC3-like with Internal RAM and no IRQ
	82,  // Tatio X01-017 is mapper 80-like with more Internal RAM
	207, // Tatio X01-005 is mapper 80-like with one screen mirroring
	48,  // MMC3-like with delayed IRQ
	33,  // Mapper 48 without IRQ and different mirroring location
	37,  // European Triple Cart (Super Mario, Tetris, Nintendo World Cup)
	74,  // MMC3 like but uses the CHR RAM.
	191, // MMC3 like but uses the CHR RAM.
	192, // MMC3 like but uses the CHR RAM.
	194, // MMC3 like but uses the CHR RAM.
	195, // MMC3 like but uses the CHR RAM.
	4:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {mmc3_prg_addr, mmc3_prg_allow, mmc3_chr_addr, mmc3_vram_a10, mmc3_vram_ce, mmc3_chr_allow, mmc3_irq};

	10: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc4_prg_addr, mmc4_prg_allow, mmc4_chr_addr, mmc4_vram_a10, mmc4_vram_ce, mmc4_chr_allow};

	5:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, has_chr_dout, prg_dout, irq, audio} = {mmc5_prg_addr, mmc5_prg_allow, mmc5_chr_addr, mmc5_vram_a10, mmc5_vram_ce, mmc5_chr_allow, mmc5_has_chr_dout, mmc5_prg_dout, mmc5_irq, mmc5_audio};

	0,
	2,
	3,
	7,
	94,
	97,
	180,
	185,
	28: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, chr_dout, has_chr_dout}      = {map28_prg_addr, map28_prg_allow, map28_chr_addr, map28_vram_a10, map28_vram_ce, map28_chr_allow, map28_chr_dout, map28_has_chr_dout};

	89,
	93,
	184: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map89_prg_addr, map89_prg_allow, map89_chr_addr, map89_vram_a10, map89_vram_ce, map89_chr_allow};

	30: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map30_prg_addr, map30_prg_allow, map30_chr_addr, map30_vram_a10, map30_vram_ce, map30_chr_allow};

	32: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map32_prg_addr, map32_prg_allow, map32_chr_addr, map32_vram_a10, map32_vram_ce, map32_chr_allow};

	13: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map13_prg_addr, map13_prg_allow, map13_chr_addr, map13_vram_a10, map13_vram_ce, map13_chr_allow};
	15: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map15_prg_addr, map15_prg_allow, map15_chr_addr, map15_vram_a10, map15_vram_ce, map15_chr_allow};

	159,
	16: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, mapper_addr, mapper_data_out, mapper_prg_write, mapper_ovr, irq}
	= {map16_prg_addr, map16_prg_allow, map16_chr_addr, map16_vram_a10, map16_vram_ce, map16_chr_allow, map16_prg_dout, map16_mapper_addr, map16_data_out, map16_prg_write, map16_ovr, map16_irq};

	18: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq} = {map18_prg_addr, map18_prg_allow, map18_chr_addr, map18_vram_a10, map18_vram_ce, map18_chr_allow, map18_prg_dout, map18_irq};

	34: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map34_prg_addr, map34_prg_allow, map34_chr_addr, map34_vram_a10, map34_vram_ce, map34_chr_allow};
	41: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map41_prg_addr, map41_prg_allow, map41_chr_addr, map41_vram_a10, map41_vram_ce, map41_chr_allow};

	64,
	158: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {rambo1_prg_addr, rambo1_prg_allow, rambo1_chr_addr, rambo1_vram_a10, rambo1_vram_ce, rambo1_chr_allow, rambo1_irq};

	42: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map42_prg_addr, map42_prg_allow, map42_chr_addr, map42_vram_a10, map42_vram_ce, map42_chr_allow, map42_irq};

	65: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map65_prg_addr, map65_prg_allow, map65_chr_addr, map65_vram_a10, map65_vram_ce, map65_chr_allow, map65_irq};
	190,
	67: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map67_prg_addr, map67_prg_allow, map67_chr_addr, map67_vram_a10, map67_vram_ce, map67_chr_allow, map67_irq};

	11,
	38,
	86,
	87,
	101,
	140,
	66: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map66_prg_addr, map66_prg_allow, map66_chr_addr, map66_vram_a10, map66_vram_ce, map66_chr_allow};
	68: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map68_prg_addr, map68_prg_allow, map68_chr_addr, map68_vram_a10, map68_vram_ce, map68_chr_allow};
	69: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq, audio} = {map69_prg_addr, map69_prg_allow, map69_chr_addr, map69_vram_a10, map69_vram_ce, map69_chr_allow, map69_irq, map69_audio};

	71,
	232: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map71_prg_addr, map71_prg_allow, map71_chr_addr, map71_vram_a10, map71_vram_ce, map71_chr_allow};

	92,
	72: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map72_prg_addr, map72_prg_allow, map72_chr_addr, map72_vram_a10, map72_vram_ce, map72_chr_allow};

	77: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map77_prg_addr, map77_prg_allow, map77_chr_addr, map77_vram_a10, map77_vram_ce, map77_chr_allow};

	152,
	70,
	78: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map78_prg_addr, map78_prg_allow, map78_chr_addr, map78_vram_a10, map78_vram_ce, map78_chr_allow};

	79,
	113: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map79_prg_addr, map79_prg_allow, map79_chr_addr, map79_vram_a10, map79_vram_ce, map79_chr_allow};

	105: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq}= {nesev_prg_addr, mmc1_prg_allow, nesev_chr_addr, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow, nesev_irq};

	107: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map107_prg_addr, map107_prg_allow, map107_chr_addr, map107_vram_a10, map107_vram_ce, map107_chr_allow};

	165: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map165_prg_addr, map165_prg_allow, map165_chr_addr, map165_vram_a10, map165_vram_ce, map165_chr_allow, map165_irq};

	218: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map218_prg_addr, map218_prg_allow, map218_chr_addr, map218_vram_a10, map218_vram_ce, map218_chr_allow};

	228: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map228_prg_addr, map228_prg_allow, map228_chr_addr, map228_vram_a10, map228_vram_ce, map228_chr_allow};
	234: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map234_prg_addr, map234_prg_allow, map234_chr_addr, map234_vram_a10, map234_vram_ce, map234_chr_allow};
	75: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {vrc1_prg_addr, vrc1_prg_allow, vrc1_chr_addr, vrc1_vram_a10, vrc1_vram_ce, vrc1_chr_allow};
	20: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {mapfds_prg_addr, mapfds_prg_allow, mapfds_chr_addr, mapfds_vram_a10, mapfds_vram_ce, mapfds_chr_allow, mapfds_prg_dout, mapfds_irq, mapfds_audio};
	21,
	22,
	23,
	25: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {vrc24_prg_addr, vrc24_prg_allow, vrc24_chr_addr, vrc24_vram_a10, vrc24_vram_ce, vrc24_chr_allow, vrc24_irq};
	73: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {vrc3_prg_addr, vrc3_prg_allow, vrc3_chr_addr, vrc3_vram_a10, vrc3_vram_ce, vrc3_chr_allow, vrc3_irq};
	24,
	26: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {vrc6_prg_addr, vrc6_prg_allow, vrc6_chr_addr, vrc6_vram_a10, vrc6_vram_ce, vrc6_chr_allow, vrc6_prg_dout, vrc6_irq, vrc6_audio};
	85: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq, audio} = {vrc7_prg_addr, vrc7_prg_allow, vrc7_chr_addr, vrc7_vram_a10, vrc7_vram_ce, vrc7_chr_allow, vrc7_irq, vrc7_audio};
	210,
	19: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {map19_prg_addr, map19_prg_allow, map19_chr_addr, map19_vram_a10, map19_vram_ce, map19_chr_allow, map19_prg_dout, map19_irq, map19_audio};
	default: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow} = {mmc0_prg_addr, mmc0_prg_allow, mmc0_chr_addr, mmc0_vram_a10, mmc0_vram_ce, mmc0_chr_allow};
	endcase

	if (prg_aout[21:20] == 2'b00)
		prg_aout[19:0] = {prg_aout[19:14] & prg_mask, prg_aout[13:0]};

	if (chr_aout[21:20] == 2'b10)
		chr_aout[19:0] = {chr_aout[19:13] & chr_mask, chr_aout[12:0]};

	// Remap the CHR address into VRAM, if needed.
	chr_aout = vram_ce ? {11'b11_0000_0000_0, vram_a10, chr_ain[9:0]} : chr_aout;
	prg_aout = (prg_ain < 'h2000) ? {11'b11_1000_0000_0, prg_ain[10:0]} : prg_aout;
	prg_allow = prg_allow || (prg_ain < 'h2000);
end

endmodule

// PRG       = 0....
// CHR       = 10...
// CHR-VRAM  = 1100
// CPU-RAM   = 1110
// CARTRAM   = 1111



// 0 = Working
// 1 = Working
// 2 = Working
// 3 = Working
// 4 = Working
// 5 = Working/Audio needs testing/Some games graphics corruption (Just Breed)
// 7 = Working
// 9 = Working
// 10 = Working
// 11 = Working
// 13 = Working
// 15 = Working
// 16 = Working/EEPROM needs testing
// 18 = Needs testing
// 19 = Needs testing
// 20 = Needs testing
// 21 = Needs testing
// 22 = Needs testing
// 23 = Needs testing
// 24 = Needs testing
// 25 = Needs testing
// 26 = Needs testing
// 28 = Working
// 30 = No Self Flashing/Needs testing
// 32 = Needs testing
// 33 = Needs testing
// 34 = Working
// 37 = Needs testing
// 38 = Needs testing
// 41 = Working
// 42 = Working
// 47 = Working
// 48 = Needs testing
// 64 = Tons of GFX bugs
// 65 = Needs testing
// 66 = Working
// 67 = Needs testing
// 68 = Working
// 69 = Working
// 70 = Needs testing
// 71 = Working
// 72 = Needs testing/No Audio Samples
// 73 = Needs testing
// 74 = Needs testing
// 75 = Needs testing
// 76 = Needs testing
// 77 = Needs testing
// 78 = Submapper 1 Requires NES 2.0/Needs testing overall
// 79 = Working
// 80 = Needs testing
// 82 = Needs testing
// 85 = Needs testing/Audio needs testing
// 86 = Needs testing/No Audio Samples
// 87 = Needs testing
// 88 = Needs testing
// 89 = Needs testing
// 92 = Needs testing/No Audio Samples
// 93 = Needs testing
// 94 = Needs testing
// 95 = Needs testing
// 97 = Needs testing
// 101 = Needs testing
// 105 = Working
// 107 = Needs testing
// 112 = Needs testing
// 113 = Working
// 118 = Working
// 119 = Working
// 140 = Needs testing
// 152 = Needs testing
// 154 = Needs testing
// 155 = Needs testing
// 158 = Tons of GFX bugs
// 159 = Needs testing
// 165 = GFX corrupted
// 180 = Needs testing
// 184 = Needs testing
// 185 = Needs testing
// 190 = Not Tested
// 191 = Not Tested
// 192 = Not Tested
// 194 = Not Tested
// 195 = Not Tested
// 206 = Not Tested
// 207 = Needs testing
// 210 = Needs testing
// 218 = Working
// 228 = Working
// 234 = Not Tested