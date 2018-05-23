// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
// 
// MiSTer port: Copyright (C) 2017 Sorgelig 

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE
);

assign AUDIO_S   = 0;
assign AUDIO_L   = sample;
assign AUDIO_R   = sample;
assign AUDIO_MIX = 0;

assign LED_USER  = downloading | saving | (loader_fail & led_blink);
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[8] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[8] ? 8'd9  : 8'd3;

assign CLK_VIDEO = clk85;

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;


`include "build_id.v"
parameter CONF_STR = {
	"NES;;",
	"F,NES;",
	"S,SAV;",
	"T7,Save RAM Write;",
	"O8,Aspect ratio,4:3,16:9;",
	"O12,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"O4,Hide overscan,OFF,ON;",
	"O5,Palette,FCEUX,Unsaturated-V6;",
	"-;",
	"O9,Swap joysticks,NO,YES;",
	"-;",
	"O3,Invert mirroring,OFF,ON;",
	"R0,Reset;",
	"J,A,B,Select,Start;",
	"V,v0.83.",`BUILD_DATE
};

wire [7:0] joyA;
wire [7:0] joyB;
wire [1:0] buttons;

wire [31:0] status;

wire arm_reset = status[0];
wire mirroring_osd = status[3];
wire hide_overscan = status[4];
wire palette2_osd = status[5];
wire uploading = status[7];
wire joy_swap = status[9];

wire forced_scandoubler;
wire ps2_kbd_clk, ps2_kbd_data;
wire [10:0] ps2_key;

wire saver_mounted;
wire saver_readonly;
wire [63:0] saver_size;
wire [31:0] saver_sd_lba;
wire saver_sd_rd;
wire saver_sd_wr;
wire saver_sd_ack;
wire [8:0] saver_sd_buff_addr;
wire [7:0] saver_sd_buff_dout;
wire [7:0] saver_sd_buff_din;
wire saver_sd_buff_wr;

hps_io #(.STRLEN(($size(CONF_STR)>>3))) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),
   .conf_str(CONF_STR),

   .buttons(buttons),
   .forced_scandoubler(forced_scandoubler),

   .joystick_0(joyA),
   .joystick_1(joyB),

   .status(status),

	.img_mounted(saver_mounted),   // signaling that new image has been mounted
	.img_readonly(saver_readonly), // mounted as read only. valid only for active bit in img_mounted
	.img_size(saver_size),         // size of image in bytes. valid only for active bit in img_mounted

	// SD block level access
	.sd_lba(saver_sd_lba),
	.sd_rd(saver_sd_rd),
	.sd_wr(saver_sd_wr),
	.sd_ack(saver_sd_ack),
	
	.sd_buff_addr(saver_sd_buff_addr),
	.sd_buff_dout(saver_sd_buff_dout),
	.sd_buff_din(saver_sd_buff_din),
	.sd_buff_wr(saver_sd_buff_wr),

	.ioctl_download(downloading),
	.ioctl_wr(loader_clk),
	.ioctl_dout(loader_input),
	.ioctl_wait(0),
	//.ioctl_index(loader_index),

   .ps2_key(ps2_key),
	
	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),
	
	.sd_conf(0)
);


wire [7:0] nes_joy_A = (reset_nes) ? 8'd0 : 
							  { joyB[0], joyB[1], joyB[2], joyB[3], joyB[7], joyB[6], joyB[5], joyB[4] } | kbd_joy0;
wire [7:0] nes_joy_B = (reset_nes) ? 8'd0 : 
							  { joyA[0], joyA[1], joyA[2], joyA[3], joyA[7], joyA[6], joyA[5], joyA[4] } | kbd_joy1;
 
wire clock_locked;
wire clk85;
wire clk;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk85),
	.outclk_1(SDRAM_CLK),
	.outclk_2(clk),
	.locked(clock_locked)
);


// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge CLK_50M) begin
	if(downloading || saving) download_reset_cnt <= 8'd255;
	else if(download_reset_cnt != 0) download_reset_cnt <= download_reset_cnt - 8'd1;
end

// hold machine in reset until first download starts
reg init_reset;
always @(posedge CLK_50M) begin
	if(!clock_locked) init_reset <= 1'b1;
	else if(downloading) init_reset <= 1'b0;
end
  
wire  [8:0] cycle;
wire  [8:0] scanline;
wire [15:0] sample;
wire  [5:0] color;
wire        joypad_strobe;
wire  [1:0] joypad_clock;
wire [21:0] memory_addr;
wire        memory_read_cpu, memory_read_ppu;
wire        memory_write;
wire  [7:0] memory_din_cpu, memory_din_ppu;
wire  [7:0] memory_dout;
reg   [7:0] joypad_bits, joypad_bits2;
reg   [7:0] powerpad_d3, powerpad_d4;
reg   [1:0] last_joypad_clock;

reg [1:0] nes_ce;

always @(posedge clk) begin
	if (reset_nes) begin
		joypad_bits <= 8'd0;
		joypad_bits2 <= 8'd0;
		powerpad_d3 <= 8'd0;
		powerpad_d4 <= 8'd0;
		last_joypad_clock <= 2'b00;
	end else begin
		if (joypad_strobe) begin
			joypad_bits  <= joy_swap ? nes_joy_B : nes_joy_A;
			joypad_bits2 <= joy_swap ? nes_joy_A : nes_joy_B;
			powerpad_d4 <= {4'b0000, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
			powerpad_d3 <= {powerpad[6], powerpad[10], powerpad[9], powerpad[5], powerpad[8], powerpad[4], powerpad[0], powerpad[1]};
		end
		if (!joypad_clock[0] && last_joypad_clock[0]) begin
			joypad_bits <= {1'b0, joypad_bits[7:1]};
		end	
		if (!joypad_clock[1] && last_joypad_clock[1]) begin
			joypad_bits2 <= {1'b0, joypad_bits2[7:1]};
			powerpad_d4 <= {1'b0, powerpad_d4[7:1]};
			powerpad_d3 <= {1'b0, powerpad_d3[7:1]};
		end	
		last_joypad_clock <= joypad_clock;
	end
end
  
// Loader
wire [7:0] loader_input;
wire       loader_clk;
wire [21:0] loader_addr;
wire [7:0] loader_write_data;
wire loader_reset = !download_reset; //loader_conf[0];
wire loader_write;
wire [31:0] loader_flags;
reg [31:0] mapper_flags;
wire loader_done, loader_fail;

GameLoader loader
(
	clk, loader_reset, loader_input, loader_clk, mirroring_osd,
	loader_addr, loader_write_data, loader_write,
	loader_flags, loader_done, loader_fail
);

always @(posedge clk) begin
	if (loader_done) mapper_flags <= loader_flags;
end

// Saver
wire saving;
wire [21:0] saver_addr;
wire [7:0] saver_mem_dout;
wire [7:0] saver_mem_din;
wire saver_reset; //loader_conf[0];
wire saver_mem_write;
wire saver_mem_read;
wire saver_done;
wire saver_fail;
wire saver_rd;
wire saver_wr;
assign saving = saver_mounted || !saver_done;
assign saver_reset = init_reset || downloading || (!saver_mounted && !uploading && saver_done);
assign saver_rd = saver_mounted;
assign saver_wr = uploading;
assign saver_mem_dout = memory_din_ppu; //Saver shares PPU lines

SaveHandler saver
(
	clk, saver_reset, saver_rd, saver_wr,
	run_nes, saver_done, saver_fail,
	saver_mounted, saver_readonly, saver_size,
	saver_sd_lba, saver_sd_rd, saver_sd_wr, saver_sd_ack,
	saver_sd_buff_addr, saver_sd_buff_dout, saver_sd_buff_din, saver_sd_buff_wr,
	saver_addr, saver_mem_din, saver_mem_write, saver_mem_read, saver_mem_dout
);

reg led_blink;
always @(posedge clk) begin
	int cnt = 0;
	cnt <= cnt + 1;
	if(cnt == 10000000) begin
		cnt <= 0;
		led_blink <= ~led_blink;
	end;
end
 
wire reset_nes = (init_reset || buttons[1] || arm_reset || download_reset || loader_fail);
//wire run_nes = (!saving && (nes_ce == 3));	// keep running even when reset, so that the reset can actually do its job!
wire run_nes = (nes_ce == 3);	// keep running even when reset, so that the reset can actually do its job!

// NES is clocked at every 4th cycle.
always @(posedge clk) nes_ce <= nes_ce + 1'd1;

NES nes
(
	clk, reset_nes, run_nes,
	mapper_flags,
	sample, color,
	joypad_strobe, joypad_clock, {powerpad_d4[0],powerpad_d3[0],joypad_bits2[0],joypad_bits[0]},
	5'b11111,  // enable all channels
	memory_addr,
	memory_read_cpu, memory_din_cpu,
	memory_read_ppu, memory_din_ppu,
	memory_write, memory_dout,
	cycle, scanline
);

assign SDRAM_CKE         = 1'b1;

// loader_write -> clock when data available
reg loader_read_mem;
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [21:0] loader_addr_mem;

reg loader_write_triggered;
reg loader_read_triggered;

always @(posedge clk) begin
	if(loader_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
		loader_write_data_mem <= loader_write_data;
	end

	if(saver_mem_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= saver_addr;
		loader_write_data_mem <= saver_mem_din;
	end

	if(saver_mem_read) begin
		loader_read_triggered <= 1'b1;
		loader_addr_mem <= saver_addr;
	end

	if(nes_ce == 3) begin
		loader_write_mem <= loader_write_triggered;
		if(loader_write_triggered)
			loader_write_triggered <= 1'b0;
		loader_read_mem <= loader_read_triggered;
		if(loader_read_triggered)
			loader_read_triggered <= 1'b0;
	end
end

sdram sdram
(
	// interface to the MT48LC16M16 chip
	.sd_data     	( SDRAM_DQ                 ),
	.sd_addr     	( SDRAM_A                  ),
	.sd_dqm      	( {SDRAM_DQMH, SDRAM_DQML} ),
	.sd_cs       	( SDRAM_nCS                ),
	.sd_ba       	( SDRAM_BA                 ),
	.sd_we       	( SDRAM_nWE                ),
	.sd_ras      	( SDRAM_nRAS               ),
	.sd_cas      	( SDRAM_nCAS               ),

	// system interface
	.clk      		( clk85         				),
	.clkref      	( nes_ce[1]         			),
	.init         	( !clock_locked     			),

	// cpu/chipset interface
	.addr     		( downloading || saving	? {3'b000, loader_addr_mem} : {3'b000, memory_addr} ),
	
	.we       		( memory_write || loader_write_mem	),
	.din       		( downloading || saving ? loader_write_data_mem : memory_dout ),
	
	.oeA         	( memory_read_cpu ),
	.doutA       	( memory_din_cpu	),
	
	.oeB         	( memory_read_ppu || loader_read_mem ),
	.doutB       	( memory_din_ppu	)
);

wire downloading;

video video
(
	.*,
	.clk(clk85),

	.count_v(scanline),
	.count_h(cycle),
	.forced_scandoubler(forced_scandoubler),
	.scale(status[2:1]),
	.hide_overscan(hide_overscan),
	.palette(palette2_osd),

	.ce_pix(CE_PIXEL)
);

wire [7:0] kbd_joy0;
wire [7:0] kbd_joy1;
wire [11:0] powerpad;

keyboard keyboard
(
	.clk(clk),
	.reset(reset_nes),

	.ps2_key(ps2_key),

	.joystick_0(kbd_joy0),
	.joystick_1(kbd_joy1),
	
	.powerpad(powerpad)
);
			
endmodule



// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader
(
	input         clk,
	input         reset,
	input   [7:0] indata,
	input         indata_clk,
	input         invert_mirroring,
	output reg [21:0] mem_addr,
	output [7:0]  mem_data,
	output        mem_write,
	output [31:0] mapper_flags,
	output reg    done,
	output reg    error
);

reg [1:0] state = 0;
reg [7:0] prgsize;
reg [3:0] ctr;
reg [7:0] ines[0:15]; // 16 bytes of iNES header
reg [21:0] bytes_left;
  
wire [7:0] prgrom = ines[4];	// Number of 16384 byte program ROM pages
wire [7:0] chrrom = ines[5];	// Number of 8192 byte character ROM pages (0 indicates CHR RAM)
wire has_chr_ram = (chrrom == 0);
assign mem_data = indata;
assign mem_write = (bytes_left != 0) && (state == 1 || state == 2) && indata_clk;
  
wire [2:0] prg_size = prgrom <= 1  ? 3'd0 :		// 16KB
                      prgrom <= 2  ? 3'd1 : 		// 32KB
                      prgrom <= 4  ? 3'd2 : 		// 64KB
                      prgrom <= 8  ? 3'd3 : 		// 128KB
                      prgrom <= 16 ? 3'd4 : 		// 256KB
                      prgrom <= 32 ? 3'd5 : 		// 512KB
                      prgrom <= 64 ? 3'd6 : 3'd7;// 1MB/2MB
                        
wire [2:0] chr_size = chrrom <= 1  ? 3'd0 : 		// 8KB
                      chrrom <= 2  ? 3'd1 : 		// 16KB
                      chrrom <= 4  ? 3'd2 : 		// 32KB
                      chrrom <= 8  ? 3'd3 : 		// 64KB
                      chrrom <= 16 ? 3'd4 : 		// 128KB
                      chrrom <= 32 ? 3'd5 : 		// 256KB
                      chrrom <= 64 ? 3'd6 : 3'd7;// 512KB/1MB
  
// detect iNES2.0 compliant header
wire is_nes20 = (ines[7][3:2] == 2'b10);
// differentiate dirty iNES1.0 headers from proper iNES2.0 ones
wire is_dirty = !is_nes20 && ((ines[8]  != 0) 
								  || (ines[9]  != 0)
								  || (ines[10] != 0)
								  || (ines[11] != 0)
								  || (ines[12] != 0)
								  || (ines[13] != 0)
								  || (ines[14] != 0)
								  || (ines[15] != 0));
  
// Read the mapper number
wire [7:0] mapper = {is_dirty ? 4'b0000 : ines[7][7:4], ines[6][7:4]};
  
// ines[6][0] is mirroring
// ines[6][3] is 4 screen mode
assign mapper_flags = {15'b0, ines[6][3], has_chr_ram, ines[6][0] ^ invert_mirroring, chr_size, prg_size, mapper};
  
always @(posedge clk) begin
	if (reset) begin
		state <= 0;
		done <= 0;
		ctr <= 0;
		mem_addr <= 0;  // Address for PRG
	end else begin
		case(state)
		// Read 16 bytes of ines header
		0: if (indata_clk) begin
			  error <= 0;
			  ctr <= ctr + 1'd1;
			  ines[ctr] <= indata;
			  bytes_left <= {prgrom, 14'b0};
			  if (ctr == 4'b1111)
				 // Check the 'NES' header. Also, we don't support trainers.
				 state <= (ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2] ? 1 : 3;
			end
		1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else if (state == 1) begin
				state <= 2;
				mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
				bytes_left <= {1'b0, chrrom, 13'b0};
			 end else if (state == 2) begin
				done <= 1;
			 end
			end
		3: begin
				done <= 1;
				error <= 1;
			end
		endcase
	end
end
endmodule

module SaveHandler
(
	input         clk,
	input         reset,
	input         rd_req,          // i/o read
	input         wr_req,          // i/o write
	input         indata_clk,
	output reg    done,
	output reg    error,

	// SD config
	input             img_mounted,  // signaling that new image has been mounted
	input             img_readonly, // mounted as read only. valid only for active bit in img_mounted
	input      [63:0] img_size,     // size of image in bytes. valid only for active bit in img_mounted

	// SD block level access
	output     [31:0] sd_lba,
	output            sd_rd,       // only single sd_rd can be active at any given time
	output            sd_wr,       // only single sd_wr can be active at any given time
	input             sd_ack,
	
	// SD byte level access. Signals for 2-PORT altsyncram.
	input      [AW:0] sd_buff_addr,
	input      [DW:0] sd_buff_dout,
	output     [DW:0] sd_buff_din,
	input             sd_buff_wr,

	// RAM access
	output reg [21:0] buff_addr,	  // buffer RAM address
	output      [7:0] buff_dout,	  // buffer RAM data output
	output            mem_write,    // buffer RAM read enable
	output            mem_read,     // buffer RAM write enable
	input       [7:0] buff_din      // buffer RAM data input
);
reg [2:0] state = 0;
reg [10:0] bytes_left;   // One extra bit
reg [7:0] sectors_left;  // One extra bit
reg [6:0] buffer_lba;
wire sd_busy;
reg sd_save = 0;
reg sd_read = 0;
reg rd = 0;
reg wr = 0;
reg old_rd = 0;
reg old_wr = 0;
reg old_mounted;
reg old_readonly;
reg [63:0] old_size;
reg wrclk;
wire buff_wr;

localparam WIDE = 0;
localparam DW = (WIDE) ? 15 : 7;
localparam AW = (WIDE) ?  7 : 8;

sd_card sd_image
(
	.clk(clk),
	.reset(reset),
	
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),

	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.save_sector(sd_save),
	.read_sector(sd_read),
	.req_lba(buffer_lba),
	.buff_addr(buff_addr[8:0]),
	.buff_dout(buff_dout),
	.buff_din(buff_din),
	.buff_we(buff_wr),
	.busy(sd_busy)
);

assign mem_write = (bytes_left != 0) && (state == 6) && indata_clk && wrclk;
assign mem_read = (bytes_left != 0) && (state == 3) && !wrclk;
assign buff_wr = (bytes_left != 0) && (state == 3) && wrclk;
  
always @(posedge clk) begin
	if (reset) begin
		state <= 0;
		done <= 1;
		error <= 0;

		rd <= 0;
		wr <= 0;
		old_rd <= 0;
		old_wr <= 0;
		old_mounted <= img_mounted;
		//old_readonly <= 0;
		//old_size <= 64'h0;
		bytes_left <=0;
		sd_save <= 0;
		sd_read <= 0;
		buff_addr <= 22'b11_1100_0000_0000_0000_0000;  // Address for RAM
		wrclk <= 0;
		bytes_left <= 11'h000;
		sectors_left <= 8'h00;
		buffer_lba <= 7'h0;
		
	end else begin

		old_rd <= rd_req;
		old_wr <= wr_req;
		old_mounted <= img_mounted;
		if (~old_mounted && img_mounted) begin
		  old_readonly <= img_readonly;
		  old_size <= img_size;
		end;
		
		case(state)
		0: begin
			  if (~old_wr && wr_req && ~img_readonly && ((old_size == 16'h8000) || (old_size == 16'h2000))) begin
			    wr <= 1;
			    state <= 1;
			  end else
			  if (~old_rd && rd_req && ~img_readonly && ((old_size == 16'h8000) || (old_size == 16'h2000))) begin
			    rd <= 1;
			    state <= 1;
			  end;
			end
		1: if ((wr) || (rd)) begin
			  buff_addr <= 22'b11_1100_0000_0000_0000_0000;  // Address for RAM
			  bytes_left <= 11'h000;
			  sectors_left <= {1'b0,old_size[15:9]};
			  state <= img_mounted ? 1: 2; // Wait for notification clear
			  done <= 0;
			end
		2: if (sectors_left == 0) begin
			  state <= 7;
			end else begin
			  bytes_left <= 11'h200;
			  buffer_lba <= buff_addr[15:9];
			  if ((wr) && (indata_clk)) begin
			    wrclk <= 0;
			    state <= 3;
			  end else if (rd) begin
			    sd_read <= 1;
			    state <= 5;
			  end
			end
		3: begin // Read the next |bytes_left| bytes from |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  wrclk <= ~wrclk;
				  if (wrclk) begin
				    bytes_left <= bytes_left - 1'd1;
				    buff_addr <= buff_addr + 1'd1;
				  end
				end
			 end else begin
				sd_save <= 1;
				state <= 4;
			 end
			end
		4: begin
			 if (sd_busy) begin
			  sd_save <= 0;
			 end else if (!sd_save) begin
		     sectors_left <= sectors_left - 1'd1;
			  state <= 2;
			 end
			end
		5: begin
			 if (sd_busy) begin
			  sd_read <= 0;
			 end else if ((!sd_read) && (indata_clk)) begin
			  wrclk <= 0;
			  state <= 6;
			 end
			end
		6: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  wrclk <= ~wrclk;
				  if (wrclk) begin
				    bytes_left <= bytes_left - 1'd1;
				    buff_addr <= buff_addr + 1'd1;
				  end
				end
			 end else begin
			  sectors_left <= sectors_left - 1'd1;
			  state <= 2;
			 end
			end
		7: begin
			 done <= 1;
			 state <= 0;
			 rd <= 0;
			 wr <= 0;
			end
		endcase
	end
end
endmodule

module sd_card
(
	input         clk,
	input         reset,

	output [31:0] sd_lba,
	output reg    sd_rd,
	output reg    sd_wr,
	input         sd_ack,

	input   [8:0] sd_buff_addr,
	input   [7:0] sd_buff_dout,
	output  [7:0] sd_buff_din,
	input         sd_buff_wr,

	input         save_sector,
	input         read_sector,
	input   [6:0] req_lba,
	input   [8:0] buff_addr,
	output  [7:0] buff_dout,
	input   [7:0] buff_din,
	input         buff_we,
	output reg    busy
);

assign sd_lba = lba;

sd_dpram buffer_dpram
(
	.clock(clk),

	.address_a(sd_buff_addr),
	.data_a(sd_buff_dout),
	.wren_a(sd_ack & sd_buff_wr),
	.q_a(sd_buff_din),

	.address_b(buff_addr),
	.data_b(buff_din),
	.wren_b(buff_we),
	.q_b(buff_dout)
);

reg [31:0] lba;

always @(posedge clk) begin
	reg old_ack;

	old_ack <= sd_ack;
	if(sd_ack) {sd_rd,sd_wr} <= 0;

	if(reset) begin
		busy  <= 0;
		sd_rd <= 0;
		sd_wr <= 0;
	end
	else
	if(busy) begin
		if(old_ack && ~sd_ack) begin
			busy <= 0;
		end
	end
	else
	if(save_sector) begin
		lba <= {25'd0, req_lba};
		sd_wr <= 1;
		busy <= 1;
	end
	else
	if(read_sector) begin
		lba <= {25'd0, req_lba};
		sd_rd <= 1;
		busy <= 1;
	end
end

endmodule

module sd_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=9)
(
	input	                     clock,

	input	     [ADDRWIDTH-1:0] address_a,
	input	     [DATAWIDTH-1:0] data_a,
	input	                     wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	     [ADDRWIDTH-1:0] address_b,
	input	     [DATAWIDTH-1:0] data_b,
	input	                     wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

logic [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always_ff@(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always_ff@(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule
