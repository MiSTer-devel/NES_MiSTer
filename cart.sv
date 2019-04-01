// Mapper top level selection

// Notes by Kitrinx:
// This module uses bidirectional ports to handle the data out of each mapper.
// Although FPGA's do not use bidirectional wiring internally, the alternative is
// creating a tenticle-monster of wires for each mapper, and muxing them all together.
// As it stands, the compiler will efficiently do it for us with much more readable and
// manageable code if we do it this way, and since not more than one mapper can be active
// at a time, there will be no conflicts.

// SDRAM Locations for various RAM types:
// PRG       = 0....
// CHR       = 10...
// CHR-VRAM  = 1100
// CPU-RAM   = 1110
// CARTRAM   = 1111

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
	input      [15:0] audio_in,
	output reg [15:0] audio,          // External Audio
	input             fds_swap        // FDS Disk Swap Pause
);

tri prg_allow_b, vram_a10_b, vram_ce_b, chr_allow_b, irq_b;
tri [21:0] prg_addr_b, chr_addr_b;
tri [15:0] flags_out_b, audio_out_b;
tri [7:0] prg_dout_b, chr_dout_b;

// This mapper used to be default if no other mapper was found
// It seems MMC0 is handled by map28. Does it have any purpose?
MMC0 mmc0(
	.clk        (clk),
	.ce         (ce),
	.enable     (1'b0),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : MMC1                                                               //
// Mappers: 1                                                                  //
// Status : Working                                                            //
// Notes  :                                                                    //
// Games  : Simon's Quest                                                      //
//*****************************************************************************//
MMC1 mmc1(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[1]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : Tepples                                                            //
// Mappers: 0, 2, 3, 7, 28, 94, 180                                            //
// Status : Working                                                            //
// Notes  : This mapper relies on open bus and bus conflict behavior.          //
// Games  : Donkey Kong                                                        //
//*****************************************************************************//
wire mapper28_en = me[0] | me[2] | me[3] | me[7] | me[94] | me[180] | me[185] | me[28];
Mapper28 map28(
	.clk        (clk),
	.ce         (ce),
	.enable     (mapper28_en & ~reset),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_dout_b (chr_dout_b), // Special port
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : UNROM 512                                                          //
// Mappers: 30                                                                 //
// Status : No Self Flashing/Needs testing                                     //
// Notes  : Homebrew mapper                                                    //
// Games  : ?                                                                  //
//*****************************************************************************//
Mapper30 map30(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[30]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : Mapper 32                                                          //
// Mappers: 32                                                                 //
// Status : Needs evaluation                                                   //
// Notes  :                                                                    //
// Games  : Image Fight                                                        //
//*****************************************************************************//
Mapper32 map32(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[32]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : MMC2                                                               //
// Mappers: 9                                                                  //
// Status :                                                                    //
// Notes  : Working                                                            //
// Games  : Mike Tyson's Punch-Out                                             //
//*****************************************************************************//
MMC2 mmc2(
	.clk        (clk),
	.ce         (ppu_ce),
	.enable     (me[9]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : MMC3                                                               //
// Mappers: 4, 33, 37, 47, 48, 74, 76, 80, 82, 88, 95, 112, 118, 119, 154, 191,//
//          192, 194, 195, 206, 207                                            //
// Status : Working -- Blaarg IRQ timing test fails, but may be submapper      //
// Notes  : While currently working well, this mapper could use a full review. //
// Games  : Crystalis, Battletoads                                             //
//*****************************************************************************//
wire mmc3_en = me[118] | me[119] | me[47] | me[206] | me[112] | me[88] | me[154] | me[95]
	| me[76] | me[80] | me[82] | me[207] | me[48] | me[33] | me[37] | me[74] | me[191]
	| me[192] | me[194] | me[195] | me[4];

MMC3 mmc3 (
	.clk        (clk),
	.ce         (ppu_ce),
	.enable     (mmc3_en),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : MMC4                                                               //
// Mappers: 10                                                                 //
// Status : Working                                                            //
// Notes  :                                                                    //
// Games  : Fire Emblem                                                        //
//*****************************************************************************//
MMC4 mmc4(
	.clk        (clk),
	.ce         (ppu_ce),
	.enable     (me[10]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : MMC5                                                               //
// Mappers: 5                                                                  //
// Status : Fairly complete, but has some bugs. Check Rockman Minus Infinity.  //
// Notes  : Uses expansion audio and PPU hacks. Could use a thorough review.   //
// Games  : Castlevania III, Just Breed                                        //
//*****************************************************************************//
MMC5 mmc5(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[5]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b),
	// Special ports
	.chr_din    (chr_din),
	.chr_write  (chr_write),
	.chr_dout_b (chr_dout_b),
	.ppu_ce     (ppu_ce),
	.ppuflags   (ppuflags)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper13 map13(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[13]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper15 map15(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[15]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
wire map16_prg_write, map16_ovr;
wire [7:0] map16_data_out;
wire [14:0] map16_mapper_addr;
Mapper16 map16(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[159] | me[16]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b),
	// Special Ports
	.mapper_addr(map16_mapper_addr),
	.mapper_data_in(mapper_data_in),
	.mapper_data_out(map16_data_out),
	.mapper_prg_write(map16_prg_write),
	.mapper_ovr(map16_ovr)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper18 map18(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[18]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper34 map34(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[34]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper41 map41(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[41]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper42 map42(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[42]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper65 map65(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[65]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
wire mapper66_en = me[11] | me[38] | me[86] | me[87] | me[101] | me[140] | me[66];
Mapper66 map66(
	.clk        (clk),
	.ce         (ce),
	.enable     (mapper66_en),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper67 map67(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[67] | me[190]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper68 map68(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[68]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper69 map69(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[69]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper71 map71(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[71] | me[232]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper72 map72(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[92] | me[72]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper77 map77(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[77]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : Holy Diver                                                         //
// Mappers: 78, 70, 152                                                        //
// Status : /Needs testing overall                                             //
// Notes  : Submapper 1 Requires NES 2.0                                       //
// Games  : Holy Diver, Uchuusent                                              //
//*****************************************************************************//
Mapper78 map78(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[152] | me[70] | me[78]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper79 map79(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[79] | me[113]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper89 map89(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[89] | me[93] | me[184]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper107 map107(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[107]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper165 map165(
	.clk        (clk),
	.ce         (ppu_ce),
	.enable     (me[165]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper218 map218(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[218]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper228 map228(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[228]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Mapper234 map234(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[234]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
Rambo1 rambo1(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[64] | me[158]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
NesEvent nesev(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[105]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);	
	

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
VRC1 vrc1(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[75]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
VRC3 vrc3(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[73]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
VRC24 vrc24(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[21] | me[22] | me[23] | me[25]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
VRC6 vrc6(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[24] | me[26]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
VRC7 vrc7(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[85]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   :                                                                    //
// Mappers:                                                                    //
// Status :                                                                    //
// Notes  :                                                                    //
// Games  :                                                                    //
//*****************************************************************************//
N106 n106(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[210] | me[19]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b)
);

//*****************************************************************************//
// Name   : FDS                                                                //
// Mappers: 20                                                                 //
// Status : Audio good. Drive mechanics okay, but dated. Needs rewrite.        //
// Notes  : Uses a special wire to signal disk changes. Req. modified BIOS.    //
// Games  : Bio Miracle for audio, Various unlicensed games for compatibility. //
//*****************************************************************************//
MapperFDS mapfds(
	.clk        (clk),
	.ce         (ce),
	.enable     (me[20]),
	.flags      (flags),
	.prg_ain    (prg_ain),
	.prg_aout_b (prg_addr_b),
	.prg_read   (prg_read),
	.prg_write  (prg_write),
	.prg_din    (prg_din),
	.prg_dout_b (prg_dout_b),
	.prg_allow_b(prg_allow_b),
	.chr_ain    (chr_ain),
	.chr_aout_b (chr_addr_b),
	.chr_allow_b(chr_allow_b),
	.vram_a10_b (vram_a10_b),
	.vram_ce_b  (vram_ce_b),
	.irq_b      (irq_b),
	.flags_out_b(flags_out_b),
	.audio_in   (audio_in),
	.audio_b    (audio_out_b),
	// Special ports
	.fds_swap   (fds_swap)
);

// Mask
reg [5:0] prg_mask;
reg [6:0] chr_mask;



reg [255:0] me = 0;

always @(posedge clk) begin
	me <= 255'd0;
	me[flags[7:0]] <= 1'b1;
end

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

	{prg_conflict, prg_open_bus, has_chr_dout} = {flags_out_b[2], flags_out_b[1], flags_out_b[0]};
	chr_dout = flags_out_b[0] ? chr_dout_b : 8'hFF;

	// Currently only used for Mapper 16 EEPROM. Expand if needed.
	{mapper_addr, mapper_data_out, mapper_prg_write, mapper_ovr} = (me[159] | me[16]) ?
		{map16_mapper_addr, map16_data_out, map16_prg_write, map16_ovr} : 25'd0;

	{prg_aout,   prg_allow,   chr_aout,   vram_a10,   vram_ce,   chr_allow,   prg_dout,   irq,   audio} = 
	{prg_addr_b, prg_allow_b, chr_addr_b, vram_a10_b, vram_ce_b, chr_allow_b, prg_dout_b, irq_b, audio_out_b};

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
// 78 = 
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