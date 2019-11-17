// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
// 
// MiSTer port: Copyright (C) 2017,2018 Sorgelig

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

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
	output        VGA_F1,
	output  [1:0] VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
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
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;

assign AUDIO_S   = 1'b1;
assign AUDIO_L   = |mute_cnt ? 16'd0 : sample_signed[15:0];
assign AUDIO_R   = AUDIO_L;
assign AUDIO_MIX = 0;

assign LED_USER  = downloading | (loader_fail & led_blink) | (bk_state != S_IDLE) | (bk_pending & status[17]);
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS [1] = 0;

assign VIDEO_ARX = status[8] ? 8'd16 : (hide_overscan ? 8'd64 : 8'd128);
assign VIDEO_ARY = status[8] ? 8'd9  : (hide_overscan ? 8'd49 : 8'd105);

assign VGA_F1 = 0;
//assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;


`define DEBUG_AUDIO

// Status Bit Map:
// 0         1         2         3 
// 01234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXX XXXXXXXXXXXXXXXXX XX

`include "build_id.v"
parameter CONF_STR = {
	"NES;;",
	"-;",
	"FS,NESFDSNSF;",
	"H1F2,BIN,Load FDS BIOS;",
	"-;",
	"ONO,System Type,NTSC,PAL,Dendy;",
	"-;",
	"OG,Disk Swap ("
	};
parameter CONF_STR2 = {
	"),Auto,FDS button;",	
	"O5,Invert Mirroring,Off,On;",
	"-;",
	"C,Cheats;",
	"H2OK,Cheats Enabled,On,Off;",
	"-;",
	"D0R6,Load Backup RAM;",
	"D0R7,Save Backup RAM;",
	"D0OH,Autosave,Off,On;",
	"-;",
	"O8,Aspect Ratio,4:3,16:9;",
	"O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O4,Hide Overscan,Off,On;",
	"ORS,Mask Edges,Off,Left,Both,Auto;",
	"OP,Extra Sprites,Off,On;",
	"OCF,Palette,Smooth,Unsat.,FCEUX,NES Classic,Composite,PC-10,PVM,Wavebeam,Real,Sony CXA,YUV,Greyscale,Rockman9,Ninten.,Custom;",
	"H3F3,PAL,Custom Palette;",
	"-;",
	"O9,Swap Joysticks,No,Yes;",
	"OIJ,Peripheral,Powerpad,Zapper(Mouse),Zapper(Joy1),Zapper(Joy2);",
	"OL,Zapper Trigger,Mouse,Joystick;",
	"OM,Crosshairs,On,Off;",
	"OA,Multitap,Disabled,Enabled;",
	"OQ,Serial Mode,None,SNAC;",
`ifdef DEBUG_AUDIO
	"-;",
	"OUV,Audio Enable,Both,Internal,Cart Expansion,None;",
`endif
	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start,FDS,Mic,Trigger,PP 1,PP 2,PP 3,PP 4,PP 5,PP 6,PP 7,PP 8,PP 9,PP 10,PP 11,PP 12;",
	"jn,A,B,Select,Start,L,R;",
	"jp,B,Y,Select,Start,L,R;",
	"V,v",`BUILD_DATE
};

wire [22:0] joyA,joyB,joyC,joyD;
wire [1:0] buttons;

wire [31:0] status;

wire arm_reset = status[0];
wire mirroring_osd = status[5];
wire pal_video = |status[24:23];
wire hide_overscan = status[4] && ~pal_video;
wire [3:0] palette2_osd = status[15:12];
wire joy_swap = status[9] ^ (raw_serial || piano); // Controller on port 2 for Miracle Piano/SNAC
wire fds_swap_invert = status[16];
`ifdef DEBUG_AUDIO
wire ext_audio = ~status[30];
wire int_audio = ~status[31];
`else
wire ext_audio = 1;
wire int_audio = 1;
`endif

// Figure out file types
reg type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading;

always_ff @(posedge clk) begin
	loader_reset <= !download_reset || ((old_filetype != filetype) && |filetype && ~type_gg && ~type_palette); //loader_conf[0];
	ioctl_download <= ioctl_downloading;
	{type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading} <= 0;
	if (~|filetype[5:0])
		case(filetype[7:6])
			2'b00: begin type_bios <= 1; is_bios <= 1; downloading <= ioctl_downloading; end
			2'b01: begin type_nes <= 1; downloading <= ioctl_downloading; end
			2'b10: begin type_fds <= 1; downloading <= ioctl_downloading; end
			2'b11: begin type_nsf <= 1; downloading <= ioctl_downloading; end
		endcase
	else if(&filetype)
		type_gg <= 1;
	else if (filetype[1:0] == 2'b01)
		case (filetype[7:6])
			2'b00: begin type_nes <= 1; downloading <= ioctl_downloading; end
			2'b01: begin type_fds <= 1; downloading <= ioctl_downloading; end
			2'b10: begin type_nsf <= 1; downloading <= ioctl_downloading; end
		endcase
	else if (filetype[1:0] == 2'b10) begin
		type_bios <= 1;
		downloading <= ioctl_downloading;
	end else if (filetype[1:0] == 2'b11)
		type_palette <= 1;

end

assign BUTTONS[0] = osd_btn;

// Pop OSD menu if no rom has been loaded automatically
wire rom_loaded;

reg osd_btn = 0;
always @(posedge clk) begin : osd_block
	integer timeout = 0;
	
	if(!RESET) begin
		osd_btn <= 0;
		if(timeout < 61000000) begin
			timeout <= timeout + 1;
			if (timeout > 50000000)
				osd_btn <= ~rom_loaded;
		end
	end
end


// Remove DC offset and convert to signed
// At this CE rate, it also slightly lowers the bass to
// better imitate the real high pass of the system.
jt49_dcrm2 #(.sw(16)) dc_filter (
	.clk  (clk),
	.cen  (apu_ce & &filter_cnt),
	.rst  (reset_nes),
	.din  (sample),
	.dout (sample_signed)
);

wire apu_ce;
wire signed [15:0] sample_signed;

reg [20:0] mute_cnt = 21'h1FFFFF;

// Pause audio to avoid loud "POP"
always_ff @(posedge clk) begin
	if (reset_nes)
		mute_cnt <= 21'h1FFFFF;
	else if (|mute_cnt)
		mute_cnt <= mute_cnt - 1'b1;
end

// Filter CE impacts frequency response
reg [2:0] filter_cnt;
always_ff @(posedge clk) begin
	if (apu_ce)
		filter_cnt<= filter_cnt + 1'b1;
end

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire  [7:0] filetype;
wire        ioctl_downloading;
reg         ioctl_download;
wire [24:0] ioctl_addr;
reg         ioctl_wait;

wire [24:0] ps2_mouse;
wire [15:0] joy_analog0, joy_analog1;
wire        forced_scandoubler;

wire [21:0] gamma_bus;

hps_io #(.STRLEN(($size(CONF_STR)>>3) + ($size(CONF_STR2)>>3) + 1)) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),
	.conf_str({CONF_STR, diskside==3?"3":diskside==2?"2":diskside==1?"1":"0", CONF_STR2}),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joyA),
	.joystick_1(joyB),
	.joystick_2(joyC),
	.joystick_3(joyD),
	.joystick_analog_0(joy_analog0),
	.joystick_analog_1(joy_analog1),

	.status(status),
	.status_menumask({(palette2_osd != 4'd14), ~gg_avail, bios_loaded, ~bk_ena}),

	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_downloading),
	.ioctl_addr(ioctl_addr),
	.ioctl_wr(loader_clk),
	.ioctl_dout(file_input),
	.ioctl_wait(ioctl_wait | save_wait),
	.ioctl_index(filetype),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ps2_mouse(ps2_mouse),
	
	.uart_mode(16'b000_11111_000_11111)
);


wire clock_locked;
wire clk85;
wire clk;

assign SDRAM_CLK = ~clk85;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk85),
	.outclk_1(CLK_VIDEO),
	.outclk_2(clk),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(clock_locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= status[23];
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 7;
					cfg_data <= pald2 ? 2201376898 : 2537933971;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end


// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge clk) begin
	if(downloading) download_reset_cnt <= 8'hFF;
	else if(!loader_busy && download_reset_cnt) download_reset_cnt <= download_reset_cnt - 1'd1;
end

// hold machine in reset until first download starts
reg init_reset_n = 0;
always @(posedge clk) if(downloading) init_reset_n <= 1;

wire  [8:0] cycle;
wire  [8:0] scanline;
wire [15:0] sample;
wire  [5:0] color;
wire        joypad_strobe;
wire  [1:0] joypad_clock;
reg  [23:0] joypad_bits, joypad_bits2;
reg   [7:0] powerpad_d3, powerpad_d4;
reg   [1:0] last_joypad_clock;

wire [11:0] powerpad = joyA[22:11] | joyB[22:11] | joyC[22:11] | joyD[22:11];

wire [7:0] nes_joy_A = { joyA[0], joyA[1], joyA[2], joyA[3], joyA[7], joyA[6], joyA[5], joyA[4] };
wire [7:0] nes_joy_B = { joyB[0], joyB[1], joyB[2], joyB[3], joyB[7], joyB[6], joyB[5], joyB[4] };
wire [7:0] nes_joy_C = { joyC[0], joyC[1], joyC[2], joyC[3], joyC[7], joyC[6], joyC[5], joyC[4] };
wire [7:0] nes_joy_D = { joyD[0], joyD[1], joyD[2], joyD[3], joyD[7], joyD[6], joyD[5], joyD[4] };

wire mic_button = joyA[9] | joyB[9];
wire fds_btn = joyA[8] | joyB[8];

reg [22:0] clkcount;
always@(posedge clk) begin
	if (nes_ce == 3) begin
		clkcount<=clkcount+1'd1;
	end
end

wire fds_eject = swap_delay[2] | fds_swap_invert ? fds_btn : (clkcount[21] | fds_btn);

reg [1:0] nes_ce;

wire raw_serial = status[26];

// Indexes:
// 0 = D+
// 1 = D-
// 2 = TX-
// 3 = GND_d
// 4 = RX+
// 5 = RX-

assign USER_OUT[2] = 1'b1;
assign USER_OUT[3] = 1'b1;
assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

always_comb begin
	if (raw_serial) begin
		USER_OUT[0] = joypad_strobe;
		USER_OUT[1] = ~joy_swap ? ~joypad_clock[1] : ~joypad_clock[0];
		joy_data = {~USER_IN[4], ~USER_IN[2], ~joy_swap ? ~USER_IN[5] : joypad_bits2[0], ~joy_swap ? joypad_bits[0] : ~USER_IN[5]};
	end else begin
		USER_OUT[0] = 1'b1;
		USER_OUT[1] = 1'b1;
		joy_data = {lightgun_en ? trigger : powerpad_d4[0],lightgun_en ? light : powerpad_d3[0],joypad_bits2[0],joypad_bits[0]};
	end
end

wire [3:0] joy_data;

reg [7:0] mic_cnt;

wire mic = (mic_cnt < 8'd215) && mic_button;
always @(posedge clk)
	mic_cnt <= (mic_cnt == 8'd250) ? 8'd0 : mic_cnt + 1'b1;

assign {UART_RTS, UART_DTR} = 1;
wire [15:0] uart_data;
miraclepiano miracle(
	.clk(clk),
	.reset(reset_nes || !piano),
	.strobe(joypad_strobe),
	.joypad_o(),
	.joypad_clock(joypad_clock[0]),
	.data_o(uart_data),
	.txd(UART_TXD),
	.rxd(UART_RXD)
);

zapper zap (
	.clk(clk),
	.reset(reset_nes | ~lightgun_en),
	.mode(status[19]),
	.trigger_mode(status[21]),
	.ps2_mouse(ps2_mouse),
	.analog(~status[18] ? joy_analog0 : joy_analog1),
	.analog_trigger(~status[18] ? joyA[10] : joyB[10]),
	.cycle(cycle),
	.scanline(scanline),
	.color(color),
	.reticle(reticle),
	.light(light),
	.trigger(trigger)
);

always @(posedge clk) begin
	if (reset_nes) begin
		joypad_bits <= 0;
		joypad_bits2 <= 0;
		powerpad_d3 <= 0;
		powerpad_d4 <= 0;
		last_joypad_clock <= 0;
	end else begin
		if (joypad_strobe) begin
			joypad_bits  <= piano ? {15'h0000, uart_data[8:0]}
			               : {status[10] ? {8'h08, nes_joy_C} : 16'hFFFF, joy_swap ? nes_joy_B : nes_joy_A};
			joypad_bits2 <= {status[10] ? {8'h04, nes_joy_D} : 16'hFFFF, joy_swap ? nes_joy_A : nes_joy_B};
			powerpad_d4 <= {4'b0000, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
			powerpad_d3 <= {powerpad[6], powerpad[10], powerpad[9], powerpad[5], powerpad[8], powerpad[4], powerpad[0], powerpad[1]};
		end
		if (!joypad_clock[0] && last_joypad_clock[0]) begin
			joypad_bits <= {1'b0, joypad_bits[23:1]};
		end	
		if (!joypad_clock[1] && last_joypad_clock[1]) begin
			joypad_bits2 <= {1'b0, joypad_bits2[23:1]};
			powerpad_d4 <= {1'b0, powerpad_d4[7:1]};
			powerpad_d3 <= {1'b0, powerpad_d3[7:1]};
		end	
		last_joypad_clock <= joypad_clock;
	end
end

// Loader
wire [7:0] file_input;
wire [7:0] loader_input = (loader_busy && !downloading) ? !nsf ? bios_data : nsf_data : file_input;
wire       loader_clk;
wire [21:0] loader_addr;
wire [7:0] loader_write_data;
reg  [7:0] old_filetype;
reg loader_reset;
wire loader_write;
wire [31:0] loader_flags;
reg  [31:0] mapper_flags;
wire fds = (mapper_flags[7:0] == 8'h14);
wire nsf = (loader_flags[7:0] == 8'h1F);
wire piano = (mapper_flags[30]);
wire loader_busy, loader_done, loader_fail;
wire bios_download;

GameLoader loader
(
	.clk              ( clk               ),
	.reset            ( loader_reset      ),
	.downloading      ( downloading       ),
	.filetype         ( {4'b0000, type_nsf, type_fds, type_nes, type_bios} ),
	.is_bios          ( is_bios           ),
	.indata           ( loader_input      ),
	.indata_clk       ( loader_clk        ),
	.invert_mirroring ( mirroring_osd     ),
	.mem_addr         ( loader_addr       ),
	.mem_data         ( loader_write_data ),
	.mem_write        ( loader_write      ),
	.bios_download    ( bios_download     ),
	.mapper_flags     ( loader_flags      ),
	.busy             ( loader_busy       ),
	.done             ( loader_done       ),
	.error            ( loader_fail       ),
	.rom_loaded       ( rom_loaded        )
);

reg [24:0] rom_sz;
always @(posedge clk) begin : flags_block
	reg done = 0;
	
	done <= loader_done;
	if(~done & loader_done) rom_sz <= ioctl_addr - 1'd1;
	
	if (loader_done) mapper_flags <= loader_flags;
	old_filetype <= filetype;
end

reg led_blink;
always @(posedge clk) begin : blink_block
	int cnt = 0;
	cnt <= cnt + 1;
	if(cnt == 10000000) begin
		cnt <= 0;
		led_blink <= ~led_blink;
	end;
end
 
wire reset_nes = 
	~init_reset_n  ||
	buttons[1]     ||
	arm_reset      ||
	download_reset ||
	loader_fail    ||
	bk_loading     ||
	bk_loading_req ||
	hold_reset     ||
	(old_sys_type != status[24:23]);

reg [1:0] old_sys_type;
always @(posedge clk) old_sys_type <= status[24:23];

wire [17:0] bram_addr;
wire [7:0] bram_din;
wire [7:0] bram_dout;
wire bram_write;
wire bram_en;
wire trigger;
wire light;

wire [1:0] diskside_req;
reg [1:0] diskside;

wire lightgun_en = |status[19:18];

wire gg_reset = (type_fds | type_gg | type_nes | type_nsf) && ioctl_download;

NES nes (
	.clk             (clk),
	.reset_nes       (reset_nes),
	.sys_type        (status[24:23]),
	.nes_div         (nes_ce),
	.mapper_flags    (downloading ? 32'd0 : mapper_flags),
	.gg              (status[20]),
	.gg_code         (gg_code),
	.gg_reset        (gg_reset && loader_clk && !ioctl_addr),
	.gg_avail        (gg_avail),
	// Audio
	.sample          (sample),
	.audio_channels  (5'b11111),
	.int_audio       (int_audio),
	.ext_audio       (ext_audio),
	.apu_ce          (apu_ce),
	// Video
	.ex_sprites      (status[25]),
	.color           (color),
	.emphasis        (emphasis),
	.cycle           (cycle),
	.scanline        (scanline),
	.mask            (status[28:27]),
	// User Input
	.joypad_strobe   (joypad_strobe),
	.joypad_clock    (joypad_clock),
	.joypad_data     (joy_data),
	.mic             (mic),
	.diskside_req    (diskside_req),
	.diskside        (diskside),
	.fds_busy        (fds_busy),
	.fds_eject       (fds_eject),

	// Memory transactions
	.cpumem_addr     (cpu_addr ),
	.cpumem_read     (cpu_read ),
	.cpumem_write    (cpu_write),
	.cpumem_dout     (cpu_dout ),
	.cpumem_din      (cpu_din  ),
	.ppumem_addr     (ppu_addr ),
	.ppumem_read     (ppu_read ),
	.ppumem_write    (ppu_write),
	.ppumem_dout     (ppu_dout ),
	.ppumem_din      (ppu_din  ),

	.bram_addr       (bram_addr),
	.bram_din        (bram_din),
	.bram_dout       (bram_dout),
	.bram_write      (bram_write),
	.bram_override   (bram_en),
	.save_written    (save_written)
);

wire [21:0] cpu_addr, ppu_addr;
wire        cpu_read, cpu_write, ppu_read, ppu_write;
wire  [7:0] cpu_dout, cpu_din, ppu_dout, ppu_din;

wire [2:0] emphasis;

wire [7:0] xor_data;
wire [7:0] bios_data;
wire bios_write = (loader_write && bios_download && ~bios_loaded);
reg bios_loaded = 0; // Only load bios once
reg last_bios_download = 0;

always @(posedge clk) begin
	last_bios_download <= bios_download;
	if(last_bios_download && ~bios_download) begin
		bios_loaded = 1;
	end
end

dpram #("fdspatch.mif", 13) biospatch
(
	.clock_a(clk),
	.address_a(ioctl_addr[12:0]),
	.wren_a(bios_write),
	.data_a(bios_data ^ loader_write_data),
	.q_a(xor_data),
	
	.clock_b(clk),
	.address_b(loader_addr[12:0]),
	.q_b(bios_data)
);

wire [7:0] nsf_data;
spram #(12, 8, "loopy_NSF.mif") nsfplayrom
(
	.clock(clk),
	.address(loader_addr[11:0]),
	.q(nsf_data)
);

// loader_write -> clock when data available
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [21:0] loader_addr_mem;

reg loader_write_triggered;

always @(posedge clk) begin
	if(loader_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
		loader_write_data_mem <= bios_download ? loader_write_data ^ xor_data : loader_write_data;
		ioctl_wait <= 1;
	end

	if(nes_ce == 3) begin
		loader_write_mem <= loader_write_triggered;
		if(loader_write_triggered) begin
			loader_write_triggered <= 1'b0;
		end else if(ioctl_wait) begin
			ioctl_wait <= 0;
		end
	end
end

sdram sdram
(
	.SDRAM_DQ   ( SDRAM_DQ   ),
	.SDRAM_A    ( SDRAM_A    ),
	.SDRAM_DQML ( SDRAM_DQML ),
	.SDRAM_DQMH ( SDRAM_DQMH ),
	.SDRAM_BA   ( SDRAM_BA   ),
	.SDRAM_nCS  ( SDRAM_nCS  ),
	.SDRAM_nWE  ( SDRAM_nWE  ),
	.SDRAM_nRAS ( SDRAM_nRAS ),
	.SDRAM_nCAS ( SDRAM_nCAS ),
	.SDRAM_CKE  ( SDRAM_CKE  ),

	// system interface
	.clk        ( clk85           ),
	.init       ( !clock_locked   ),

	// cpu/chipset interface
	.ch0_addr   (  (downloading | loader_busy) ? loader_addr_mem       : ppu_addr  ),
	.ch0_wr     (                                loader_write_mem      | ppu_write ),
	.ch0_din    (  (downloading | loader_busy) ? loader_write_data_mem : ppu_dout  ),
	.ch0_rd     ( ~(downloading | loader_busy)                         & ppu_read  ),
	.ch0_dout   ( ppu_din   ),

	.ch1_addr   ( cpu_addr  ),
	.ch1_wr     ( cpu_write ),
	.ch1_din    ( cpu_dout  ),
	.ch1_rd     ( cpu_read  ),
	.ch1_dout   ( cpu_din   ),

	// reserved for backup ram save/load
	.ch2_addr   ( {4'b1111, save_addr} ),
	.ch2_wr     ( save_wr ),
	.ch2_din    ( sd_buff_dout ),
	.ch2_rd     ( save_rd ),
	.ch2_dout   ( save_dout ),
	.ch2_busy   ( save_busy )
);

wire  [7:0] save_dout;
assign sd_buff_din = bram_en ? eeprom_dout : save_dout;

wire [7:0] eeprom_dout;
dpram #(" ", 11) eeprom
(
	.clock_a(clk85),
	.address_a(bram_addr),
	.data_a(bram_dout),
	.wren_a(bram_write),
	.q_a(bram_din),

	.clock_b(clk),
	.address_b({sd_lba[1:0],sd_buff_addr}),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr & sd_ack),
	.q_b(eeprom_dout)
);

wire save_busy;
reg save_rd, save_wr;
reg save_wait;
reg [17:0] save_addr;

always @(posedge clk) begin

	if(~save_busy & ~save_rd & ~save_wr) save_wait <= 0;

	if(~bk_busy) begin
		save_addr <= '1;
		save_wait <= 0;
	end
	else if(sd_ack & ~save_busy ) begin
		if(~bk_loading && (save_addr != {sd_lba[8:0], sd_buff_addr})) begin
			save_rd <= 1;
			save_addr <= {sd_lba[8:0], sd_buff_addr};
			save_wait <= 1;
		end
		if(bk_loading && sd_buff_wr) begin
			save_wr <= 1;
			save_addr <= {sd_lba[8:0], sd_buff_addr};
			save_wait <= 1;
		end
	end
	if(~bk_busy | save_busy | bram_en) {save_rd, save_wr} <= 0;
end

reg bk_pending;
wire save_written;
always @(posedge clk) begin
	if ((mapper_flags[25] || fds) && ~OSD_STATUS && save_written)
		bk_pending <= 1'b1;
	else if (bk_state)
		bk_pending <= 1'b0;
end

///////////////////////////////////////////////////

wire hit_x = (9'h027 >= cycle && 9'h020 <= cycle);
wire hit_y = (9'h0D7 >= scanline && 9'hD0 <= scanline);
reg displayp;
reg [1:0] disksidepixel;

always @(posedge clk) begin
if (reset_nes) begin
	disksidepixel <= 0;
	displayp <= 0;
end else begin
	if (swap_delay == {1'b0, ~clkcount[22:21]})
		displayp = 1'b0;
	if (swap_delay[2] || (fds_eject && fds_swap_invert))
		displayp = 1'b1;
	if (hit_x && hit_y && displayp)
		disksidepixel[0] <= 1'b1;
	else
		disksidepixel[0] <= 1'b0;
	
	disksidepixel[1] <= ((cycle[0] == 1'b1) && (cycle[2:1] <= diskside));
end
end

///////////////////////////////////////////////////
// palette loader
reg [14:0] pal_color;
reg [5:0] pal_index;
reg [1:0] pal_count;

wire pal_write = ioctl_download && type_palette ? ~|pal_count : 1'b0;

always @(posedge clk) begin
	if (ioctl_download && loader_clk && type_palette && ioctl_addr < 192) begin
		pal_count <= pal_count == 2 ? 2'd0 : pal_count + 2'd1;
		case (pal_count)
			0: begin 
				pal_color[4:0] <= file_input[7:3];
				//pal_write <= 0;
				pal_index <= ioctl_addr > 0 ? pal_index + 1'd1 : pal_index;
			end

			1: begin
				pal_color[9:5] <= file_input[7:3];
			end

			2: begin
				pal_color[14:10] <= file_input[7:3];
				//pal_write <= 1;
			end
		endcase
	end

	if (!ioctl_download) begin
		//pal_write <= 0;
		pal_count <= 0;
		pal_index <= 0;
	end
end

///////////////////////////////////////////////////
wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
assign VGA_SL = sl[1:0];

wire [1:0] reticle;
wire hold_reset;
wire ce_pix;

video video
(
	.*,
	.clk(clk),
	.reset(reset_nes),
	.cnt(nes_ce),
	.hold_reset(hold_reset),
	.count_v(scanline),
	.count_h(cycle),
	.forced_scandoubler(forced_scandoubler),
	.scale(scale),
	.hide_overscan(hide_overscan),
	.palette(palette2_osd),
	.load_color(pal_write && ioctl_download),
	.load_color_data(pal_color),
	.load_color_index(pal_index),
	.emphasis(emphasis),
	.reticle(displayp ? disksidepixel : ~status[22] ? reticle : 2'b00),
	.pal_video(pal_video),
	.ce_pix(ce_pix)
);

reg ce_out;
always @(posedge CLK_VIDEO) begin : video_align
	reg old_pix;
	old_pix <= ce_pix;
	ce_out <= 0;

	if (~old_pix & ce_pix)
		ce_out <= 1;
end

assign CE_PIXEL = ce_out;

////////////////////////////  CODES  ///////////////////////////////////

reg [128:0] gg_code;
wire gg_avail;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk) begin
	gg_code[128] <= 1'b0;

	if (ioctl_download & type_gg & loader_clk) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= file_input;  // Flags Bottom Word
			1:  gg_code[119:112] <= file_input;  // Flags Bottom Word
			2:  gg_code[127:120] <= file_input;  // Flags Top Word
			3:  gg_code[127:112] <= file_input;  // Flags Top Word
			4:  gg_code[71:64]   <= file_input;  // Address Bottom Word
			5:  gg_code[79:72]   <= file_input;  // Address Bottom Word
			6:  gg_code[87:80]   <= file_input;  // Address Top Word
			7:  gg_code[95:88]   <= file_input;  // Address Top Word
			8:  gg_code[39:32]   <= file_input;  // Compare Bottom Word
			9:  gg_code[47:40]   <= file_input;  // Compare Bottom Word
			10: gg_code[55:48]   <= file_input;  // Compare top Word
			11: gg_code[63:56]   <= file_input;  // Compare top Word                                       
			12: gg_code[7:0]     <= file_input;  // Replace Bottom Word
			13: gg_code[15:8]    <= file_input;  // Replace Bottom Word
			14: gg_code[23:16]   <= file_input;  // Replace Top Word
			15: begin
				gg_code[31:24]   <= file_input;  // Replace Top Word
				gg_code[128]     <=  1'b1;       // Clock it in
			end
		endcase
	end
end

/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

reg bk_ena = 0;
reg old_downloading = 0;
reg [1:0] last_diskside = 2'd3;
always @(posedge clk) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;
	
	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;
	if(~bk_ena && loader_write_triggered) last_diskside <= loader_addr_mem[17:16];
end

wire bk_load    = status[6];
wire bk_save    = status[7] | (bk_pending & OSD_STATUS && status[17]);
reg  bk_loading = 0;
reg  bk_loading_req = 0;
reg  bk_request = 0;
wire bk_busy = (bk_state == S_COPY);
reg  fds_busy;
reg  old_fds_btn;
reg [2:0] swap_delay;
reg [1:0] diskside_btn;
wire [8:0] save_sz = fds ? rom_sz[17:9] : bram_en ? 9'd3 : 9'd63;
wire [1:0] diskside_req_use = fds_swap_invert ? diskside_btn : diskside_req;
wire [1:0] next_btn_diskside = (last_diskside == diskside_btn) ? 2'd0 : diskside_btn + 2'd1;

typedef enum bit [1:0] { S_IDLE, S_COPY } mystate;
mystate bk_state = S_IDLE;

always @(posedge clk) begin : save_block
	reg old_load = 0, old_save = 0, old_ack;
	reg old_downloading = 0;
	
	old_downloading <= downloading;

	old_load <= bk_load & bk_ena;
	old_save <= bk_save & bk_ena;
	old_ack  <= sd_ack;
	fds_busy <= (bk_state != S_IDLE) || bk_request;
	old_fds_btn <= fds_btn;
	
	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;
	if (swap_delay == {1'b1, clkcount[22:21]}) begin
		swap_delay[2] <= 0;
	end
	if(~old_fds_btn & fds_btn & ~fds_busy & ~swap_delay[2]) diskside_btn <= next_btn_diskside;

	if (downloading) begin
		diskside <= 2'd0;
		bk_state <= S_IDLE;
		bk_request <= 0;
		diskside_btn <= 2'd0;
	end else if(bk_state == S_IDLE) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_loading <= bk_load;
			bk_request <= 1;
		end else if((diskside_req_use != diskside) && ~downloading && ~bk_request && fds) begin		
			diskside <= diskside_req_use;
			swap_delay <= {1'b1, ~clkcount[22:21]};
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_loading <= 1;
			bk_request <= 1;
		end
		if (bk_request && !loader_busy) begin
			bk_request <= 0;
			bk_state <= S_COPY;
			sd_lba <= 0;
			sd_rd <=  bk_loading;
			sd_wr <= ~bk_loading;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(sd_lba[8:0] == save_sz) begin
				bk_loading <= 0;
				bk_state <= S_IDLE;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

endmodule


/////////////////////////////////////////////////////////////////////////

// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader
(
	input         clk,
	input         reset,
	input         downloading,
	input   [7:0] filetype,
	input         is_bios,
	input   [7:0] indata,
	input         indata_clk,
	input         invert_mirroring,
	output reg [21:0] mem_addr,
	output [7:0]  mem_data,
	output        mem_write,
	output reg    bios_download,
	output [31:0] mapper_flags,
	output reg    busy,
	output reg    done,
	output reg    error,
	output reg    rom_loaded
);

initial begin
	rom_loaded <= 0;
end

reg [7:0] prgsize;
reg [3:0] ctr;
reg [7:0] ines[0:15]; // 16 bytes of iNES header
reg [21:0] bytes_left;
  
wire [7:0] prgrom = ines[4];	// Number of 16384 byte program ROM pages
wire [7:0] chrrom = ines[5];	// Number of 8192 byte character ROM pages (0 indicates CHR RAM)
wire has_chr_ram = (chrrom == 0);
assign mem_data = (state == S_CLEARRAM || (~copybios && state == S_COPYBIOS)) ? 8'h00 : indata;
assign mem_write = (((bytes_left != 0) && (state == S_LOADPRG || state == S_LOADCHR)
                    || (downloading && (state == S_LOADHEADER || state == S_LOADFDS || state == S_LOADNSFH || state == S_LOADNSFD))) && indata_clk)
						 || ((bytes_left != 0) && ((state == S_CLEARRAM) || (state == S_COPYBIOS) || (state == S_COPYPLAY)) && clearclk == 4'h2);
  
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
wire is_dirty = !is_nes20 && ((ines[9][7:1] != 0)
								  || (ines[10] != 0)
								  || (ines[11] != 0)
								  || (ines[12] != 0)
								  || (ines[13] != 0)
								  || (ines[14] != 0)
								  || (ines[15] != 0));

// Read the mapper number
wire [7:0] mapper = {is_dirty ? 4'b0000 : ines[7][7:4], ines[6][7:4]};
wire [7:0] ines2mapper = {is_nes20 ? ines[8] : 8'h00};
wire [3:0] prgram = {is_nes20 ? ines[10][3:0] : 4'h0};
wire       piano = is_nes20 && (ines[15][5:0] == 6'h19);
wire has_saves = ines[6][1];

// ines[6][0] is mirroring
// ines[6][3] is 4 screen mode
// ines[8][7:4] is NES 2.0 submapper
// ines[10][3:0] is NES 2.0 PRG RAM shift size (64 << size)
assign mapper_flags = {1'b0, piano, prgram, has_saves, ines2mapper, ines[6][3], has_chr_ram, ines[6][0] ^ invert_mirroring, chr_size, prg_size, mapper};

reg [3:0] clearclk; //Wait for SDRAM
reg copybios;

typedef enum bit [3:0] { S_LOADHEADER, S_LOADPRG, S_LOADCHR, S_LOADFDS, S_ERROR, S_CLEARRAM, S_COPYBIOS, S_LOADNSFH, S_LOADNSFD, S_COPYPLAY, S_DONE } mystate;
mystate state;

wire type_bios = filetype[0];
wire type_nes = filetype[1];
wire type_fds = filetype[2];
wire type_nsf = filetype[3];

always @(posedge clk) begin
	if (downloading && (type_fds || type_nes || type_nsf))
		rom_loaded <= 1;

	if (reset) begin
		state <= S_LOADHEADER;
		busy <= 0;
		done <= 0;
		ctr <= 0;
		mem_addr <= type_fds ? 22'b11_1100_0000_0000_0001_0000 :
		            type_nsf ? 22'b00_0000_0000_0001_0000_0000   // Address for NSF Header (0x80 bytes)
									: 22'b00_0000_0000_0000_0000_0000;  // Address for FDS : BIOS/PRG
		bios_download <= 0;
		copybios <= 0;
	end else begin
		case(state)
		// Read 16 bytes of ines header
		S_LOADHEADER:
			if (indata_clk) begin
			  error <= 0;
			  ctr <= ctr + 1'd1;
			  mem_addr <= mem_addr + 1'd1;
			  ines[ctr] <= indata;
			  bytes_left <= {prgrom, 14'b0};
			  if (ctr == 4'b1111) begin
				 // Check the 'NES' header. Also, we don't support trainers.
				 busy <= 1;
				 if ((ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2]) begin
					mem_addr <= 0;  // Address for PRG
					state <= S_LOADPRG;
				 //FDS
				 end else if ((ines[0] == 8'h46) && (ines[1] == 8'h44) && (ines[2] == 8'h53) && (ines[3] == 8'h1A)) begin
					mem_addr <= 22'b11_1100_0000_0000_0001_0000;  // Address for FDS skip Header
					state <= S_LOADFDS;
					bytes_left <= 21'b1;
				 end else if (type_bios) begin // Bios
					state <= S_LOADFDS;
					mem_addr <= 22'b00_0000_0000_0000_0001_0000;  // Address for BIOS skip Header
					bytes_left <= 21'b1;
					bios_download <= 1;
				 end else if(type_fds) begin // FDS
					state <= S_LOADFDS;
					mem_addr <= 22'b11_1100_0000_0000_0010_0000;  // Address for FDS no Header
					bytes_left <= 21'b1;
				 end else if(type_nsf) begin // NFS
					state <= S_LOADNSFH;
					//mem_addr <= 22'b00_0000_0000_0001_0001_0000;  // Just keep copying
					bytes_left <= 21'h70; // Rest of header
				 end else begin
					state <= S_ERROR;
				 end
			  end
			end
		S_LOADPRG, S_LOADCHR: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else if (state == S_LOADPRG) begin
				state <= S_LOADCHR;
				mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
				bytes_left <= {1'b0, chrrom, 13'b0};
			 end else if (state == S_LOADCHR) begin
				done <= 1;
				busy <= 0;
			 end
			end
		S_ERROR: begin
				done <= 1;
				error <= 1;
				busy <= 0;
			end
		S_LOADFDS: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (downloading) begin
				if (indata_clk) begin
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
//				mem_addr <= 22'b11_1000_0000_0000_0000_0000;
//				bytes_left <= 21'h800;
				mem_addr <= 22'b11_1000_0000_0001_0000_0010; // FDS - Clear these two RAM addresses to restart BIOS
				bytes_left <= 21'h2;
				ines[4] <= 8'hFF;//no masking
				ines[5] <= 8'h00;//0x2000
				ines[6] <= 8'h40;
				ines[7] <= 8'h10;
				ines[8] <= 8'h00;
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h00;
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h00;
				state <= S_CLEARRAM;
				clearclk <= 4'h0;
				copybios <= ~is_bios; // Don't copybios for bootrom0
			 end
			end
		S_CLEARRAM: begin // Read the next |bytes_left| bytes into |mem_addr|
			 clearclk <= clearclk + 4'h1;
			 if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				mem_addr <= 22'b00_0000_0000_0000_0000_0000;
				bytes_left <= 21'h2000;
				state <= S_COPYBIOS;
				clearclk <= 4'h0;
			 end
			end
		S_COPYBIOS: begin // Read the next |bytes_left| bytes into |mem_addr|
			 clearclk <= clearclk + 4'h1;
			 if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				state <= S_DONE;
			 end
			end
		S_LOADNSFH: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				state <= S_LOADNSFD;
				//mem_addr <= {22'b01_0000_0000_0000_0000_0000; // Address for NSF Data
				mem_addr <= {10'b01_0000_0000,ines[9][3:0],ines[8]};//_0000_0000_0000; // Address for NSF Data
				bytes_left <= 21'b1;
			 end
			end
		S_LOADNSFD: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (downloading) begin
				if (indata_clk) begin
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				mem_addr <= 22'b00_0000_0000_0001_1000_0000; // Address for NSF Player (0x180)
				bytes_left <= 21'h0E80;
				ines[4] <= 8'hFF;//no masking
				ines[5] <= 8'h00;//0x2000
				ines[6] <= 8'hF0;//Use Mapper 31
				ines[7] <= 8'h18;//Use NES 2.0
				ines[8] <= 8'hF0;//Use Submapper 15
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h00;
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h00;
				state <= S_COPYPLAY;
				clearclk <= 4'h0;
			 end
			end
		S_COPYPLAY: begin // Read the next |bytes_left| bytes into |mem_addr|
			 clearclk <= clearclk + 4'h1;
			 if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				state <= S_DONE;
			 end
			end
		S_DONE: begin // Read the next |bytes_left| bytes into |mem_addr|
			 done <= 1;
			 busy <= 0;
			 bios_download <= 0;
			end
		endcase
	end
end
endmodule
