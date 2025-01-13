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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

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

assign AUDIO_S   = 0;
assign AUDIO_L   = sample[15:0];
assign AUDIO_R   = AUDIO_L;
assign AUDIO_MIX = 0;

assign LED_USER  = downloading | (loader_fail & led_blink) | (bk_state != S_IDLE) | (bk_pending & ~status[50]);
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS [1] = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;

assign VGA_F1 = 0;
//assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [1:0] ar       = status[19:18];
wire       vcrop_en = status[5];
wire [3:0] vcopt    = status[38:35];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? (hide_overscan ? 12'd64 : 12'd128) : (ar - 1'd1)),
	.ARY((!ar) ? (hide_overscan ? 12'd49 : 12'd105) : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[40:39])
);

// If video mode (NTSC/PAL/DANDY) changes, force vmode update
reg [1:0] video_status;
reg new_vmode = 0;
always @(posedge clk) begin
    if (video_status != status[24:23]) begin
        video_status <= status[24:23];
        new_vmode <= ~new_vmode;
    end
end

// Status Bit Map:
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXX XX     XXXXXXXXXXXXX XX XXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"NES;SS3E000000:200000,UART31250,MIDI;",
	"FS,NESFDSNSF;",
	"H1F2,BIN,Load FDS BIOS;",
	"-;",
	"ONO,System Type,NTSC,PAL,Dendy;",
	"-;",
	"C,Cheats;",
	"H2OK,Cheats Enabled,On,Off;",
	"-;",
	"oI,Autosave,On,Off;",
	"H5D0R6,Load Backup RAM;",
	"H5D0R7,Save Backup RAM;",
	"-;",
	"oC,Savestates to SDCard,On,Off;",
	"oDE,Savestate Slot,1,2,3,4;",
	"d7rA,Save state(Alt+F1-F4);",
	"d7rB,Restore state(F1-F4);",
	"-;",
	"P1,Audio & Video;",
	"P1-;",
	"P1oFH,Palette,Kitrinx,Smooth,Wavebeam,Sony CXA,PC-10 Better,Custom;",
	"H3P1FC3,PAL,Custom Palette;",
	"P1-;",
	"P1OIJ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"d6P1O5,Vertical Crop,Disabled,216p(5x);",
	"d6P1o36,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1o78,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O4,Hide Overscan,Off,On;",
	"P1ORS,Mask Edges,Off,Left,Both,Auto;",
	"P1OP,Extra Sprites,Off,On;",
	"P1-;",
	"P1OUV,Audio Enable,Both,Internal,Cart Expansion,None;",
	"P2,Input Options;",
	"P2-;",
	"P2O9,Swap Joysticks,No,Yes;",
	"P2OA,Multitap,Disabled,Enabled;",
	"P2oJK,SNAC,Off,Controllers,Zapper,3D Glasses;",
	"P2o02,Periphery,None,Zapper(Mouse),Zapper(Joy1),Zapper(Joy2),Vaus,Vaus(A-Trigger),Powerpad,Family Trainer;",
	"P2oL,Famicom Keyboard,No,Yes;",
	"P2-;",
	"P2OL,Zapper Trigger,Mouse,Joystick;",
	"P2OM,Crosshairs,On,Off;",
	"P3,Miscellaneous;",
	"P3-;",
	"P3OG,Disk Swap,Auto,FDS button;",
	"P3O[17],Disk Speed,Fast,Original;",
	"P3o9,Pause when OSD is open,Off,On;",
	"P4,Advanced;",
	"P4-;",
	"P4OQ,Video Dijitter,Enabled,Disabled;",
	"- ;",
	"R0,Reset;",
	"J1,A,B,Select,Start,FDS,Mic,Zapper/Vaus Btn,PP/Mat 1,PP/Mat 2,PP/Mat 3,PP/Mat 4,PP/Mat 5,PP/Mat 6,PP/Mat 7,PP/Mat 8,PP/Mat 9,PP/Mat 10,PP/Mat 11,PP/Mat 12,Savestates;",
	"jn,A,B,Select,Start,L,,R|P;",
	"jp,B,Y,Select,Start,L,,R|P;",
	"I,",
	"Disk 1A,",
	"Disk 1B,",
	"Disk 2A,",
	"Disk 2B,",
	"Slot=DPAD|Save/Load=Start+DPAD,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4;",
	"V,v",`BUILD_DATE
};

wire [23:0] joyA,joyB,joyC,joyD;
wire [23:0] joyA_unmod;
wire [10:0] ps2_key;
wire [1:0] buttons;

wire [63:0] status;

wire arm_reset = status[0];
wire pal_video = |status[24:23];
wire hide_overscan = status[4] && ~pal_video;
wire [3:0] palette2_osd = status[49:47];
wire joy_swap = status[9] ^ (raw_serial || piano); // Controller on port 2 for Miracle Piano/SNAC
wire fds_auto_eject = ~status[16];
wire fds_fast = ~status[17];
wire ext_audio = ~status[30];
wire int_audio = ~status[31];

// Figure out file types
reg type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading;
reg [24:0] rom_sz;

always_ff @(posedge clk) begin
	reg old_downld;

	old_downld <= downloading;
	loader_reset <= !download_reset || (~old_downld && downloading);

	ioctl_download <= ioctl_downloading;
	{type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading} <= 0;
	if (~|filetype[5:0])
		case(filetype[7:6])
			2'b00: begin type_bios <= 1; is_bios <= 1; downloading <= ioctl_downloading; end
			2'b01: begin type_nes <= 1; downloading <= ioctl_downloading; end
			2'b10: begin type_fds <= 1; downloading <= ioctl_downloading; end
			//2'b11: begin type_palette <= 1; end
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

	if(old_downld && ~downloading & (type_fds|type_nsf|type_nes)) rom_sz <= ioctl_addr - 1'd1;
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

wire apu_ce;

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
wire  [7:0] pdl[4];
wire        forced_scandoubler;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.joystick_0(joyA_unmod),
	.joystick_1(joyB),
	.joystick_2(joyC),
	.joystick_3(joyD),
	.joystick_l_analog_0(joy_analog0),
	.joystick_l_analog_1(joy_analog1),
	.paddle_0(pdl[0]),
	.paddle_1(pdl[1]),
	.paddle_2(pdl[2]),
	.paddle_3(pdl[3]),

	.status(status),
	.status_menumask({(rom_loaded && mapper_has_savestate), en216p, ~status[50], ~raw_serial, (palette2_osd != 3'd5), ~gg_avail, bios_loaded, ~bk_ena}),
	.status_in({status[63:47],ss_slot,status[44:0]}),
	.status_set(statusUpdate),
	.info_req(info_req),
	.info(info),

	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_downloading),
	.ioctl_addr(ioctl_addr),
	.ioctl_wr(loader_clk),
	.ioctl_dout(file_input),
	.ioctl_wait(ioctl_wait | save_wait),
	.ioctl_index(filetype),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ps2_key(ps2_key),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ps2_mouse(ps2_mouse)

	//.uart_mode(16'b000_11111_000_11111)
);

assign joyA = joyA_unmod[23] ? 23'b0 : joyA_unmod;

wire       info_req = diskside_info || ss_info_req;
wire [7:0] info     = ss_info_req ? ss_info : {1'b0,diskside} + 3'd1;

wire clock_locked;
wire clk85;
wire clk;

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
wire  [2:0] joypad_out;
wire  [1:0] joypad_clock;
reg  [23:0] joypad_bits, joypad_bits2;
reg   [7:0] joypad_d3, joypad_d4;
reg   [1:0] last_joypad_clock;

wire [11:0] powerpad = joyA[22:11] | joyB[22:11] | joyC[22:11] | joyD[22:11];

wire [3:0] famtr;
assign famtr[0] = (~joypad_out[2] & powerpad[3]) | (~joypad_out[1] & powerpad[7]) | (~joypad_out[0] & powerpad[11]);
assign famtr[1] = (~joypad_out[2] & powerpad[2]) | (~joypad_out[1] & powerpad[6]) | (~joypad_out[0] & powerpad[10]);
assign famtr[2] = (~joypad_out[2] & powerpad[1]) | (~joypad_out[1] & powerpad[5]) | (~joypad_out[0] & powerpad[9] );
assign famtr[3] = (~joypad_out[2] & powerpad[0]) | (~joypad_out[1] & powerpad[4]) | (~joypad_out[0] & powerpad[8] );

wire [7:0] nes_joy_A = { joyA[0], joyA[1], joyA[2], joyA[3], joyA[7], joyA[6], joyA[5], ~paddle_atr & joyA[4] };
wire [7:0] nes_joy_B = { joyB[0], joyB[1], joyB[2], joyB[3], joyB[7], joyB[6], joyB[5], ~paddle_atr & joyB[4] };
wire [7:0] nes_joy_C = { joyC[0], joyC[1], joyC[2], joyC[3], joyC[7], joyC[6], joyC[5], ~paddle_atr & joyC[4] };
wire [7:0] nes_joy_D = { joyD[0], joyD[1], joyD[2], joyD[3], joyD[7], joyD[6], joyD[5], ~paddle_atr & joyD[4] };

wire mic_button = joyA[9] | joyB[9];
wire fds_btn = joyA[8] | joyB[8];

reg [1:0] nes_ce;

wire raw_serial = |status[52:51];

// Extend SNAC zapper high signal to be closer to original NES
wire extend_serial_d4 = status[52:51] == 2'b10;
wire snac_3d_glasses = &status[52:51];

wire serial_d4 = extend_serial_d4 ? |serial_d4_sr : ~USER_IN[4];
reg [7:0] serial_d4_sr;
reg snac_p2 = 0;

always @(posedge clk) begin
	reg [17:0] clk_cnt;

	if (raw_serial) begin
		if (~USER_IN[6])
			snac_p2 <= 1;
	end else begin
		snac_p2 <= 0;
	end

	clk_cnt <= clk_cnt + 1'b1;
	serial_d4_sr[0] <= ~USER_IN[4];

	// Shift every 10ms
	if (clk_cnt == 18'd214772) begin
		serial_d4_sr <= serial_d4_sr << 1;
		clk_cnt <= 0;
	end
end

// Indexes:
// IDXDIR   Function    USBPIN
// 0  OUT   Strobe      D+
// 1  OUT   Clk (P2)    D-
// 2  BI    Glasses/D3  TX-
// 3  OUT   CLK (P2)    GND_d
// 4  IN    D4          RX+
// 5  IN    P1D0        RX-
// 6  IN    P2D0        TX+

assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

reg [4:0] joypad1_data, joypad2_data;

wire joy0_d0 = snac_p2 ? ~USER_IN[6] : joypad_bits[0];
wire joy1_d0 = snac_p2 ? ~USER_IN[6] : joypad_bits2[0];

always_comb begin
	if (raw_serial) begin
		USER_OUT[0]  = joypad_out[0];
		USER_OUT[1]  = ~joy_swap ? ~joypad_clock[1] : ~joypad_clock[0];
		USER_OUT[2]  = snac_3d_glasses ? joypad_out[1] : 1'b1;
		USER_OUT[3]  = ~joy_swap ? ~joypad_clock[0] : ~joypad_clock[1];
		joypad1_data = {2'b0, mic, 1'b0, ~joy_swap ? joy0_d0 : ~USER_IN[5]};
		joypad2_data = {serial_d4, snac_3d_glasses ? 1'b1 : ~USER_IN[2], 2'b00, ~joy_swap ? ~USER_IN[5] : joy1_d0};
	end else begin
		USER_OUT[0]  = 1'b1;
		USER_OUT[1]  = 1'b1;
		USER_OUT[2]  = 1'b1;
		USER_OUT[3]  = 1'b1;

		joypad1_data = {2'b0, mic, paddle_en & paddle_btn, joypad_bits[0]};
		joypad2_data = joypad_bits2[0];

		// periphery on port 2
		if (lightgun_en)        joypad2_data[4:3] = {trigger,light};
		if (paddle_en)          joypad2_data[4:1] = {joypad_d4[0], paddle_btn, 1'b0, joypad_d4[0]};
		if (status[34:32] == 6) joypad2_data[4:3] = {joypad_d4[0], joypad_d3[0]};
		if (status[34:32] == 7) joypad2_data[4:1] = ~famtr;
		if (fkeyb)              joypad2_data[4:1] = key_out;
	end
end

wire mic = (mic_cnt < 8'd215) && mic_button;
reg [7:0] mic_cnt;
always @(posedge clk) mic_cnt <= (mic_cnt == 8'd250) ? 8'd0 : mic_cnt + 1'b1;

wire fkeyb = status[53];
wire [3:0] key_out;
keyboard fkey(
	.clk(clk),
	.reset(reset_nes || !fkeyb),
	.posit(1'd1),
	.ps2_key(ps2_key),
	.reg_4016(joypad_out),
	.reg_4017(key_out)
);

assign {UART_RTS, UART_DTR} = 1;
wire [15:0] uart_data;
miraclepiano miracle(
	.clk(clk),
	.reset(reset_nes || !piano),
	.strobe(joypad_out[0]),
	.joypad_o(),
	.joypad_clock(joypad_clock[0]),
	.data_o(uart_data),
	.txd(UART_TXD),
	.rxd(UART_RXD)
);

wire lightgun_en = ~status[34] & |status[33:32];

zapper zap (
	.clk(clk),
	.reset(reset_nes | ~lightgun_en),
	.mode(status[33]),
	.trigger_mode(status[21]),
	.ps2_mouse(ps2_mouse),
	.analog(~status[32] ? joy_analog0 : joy_analog1),
	.analog_trigger(~status[32] ? joyA[10] : joyB[10]),
	.cycle(cycle),
	.scanline(scanline),
	.color(color),
	.reticle(reticle),
	.light(light),
	.trigger(trigger)
);

reg [7:0] paddle = 0;
always @(posedge clk) begin
	reg [7:0] old_pdl[4];
	reg [1:0] num = 0;

	for(reg [2:0] i=0; i<4; i++) begin
		old_pdl[i] <= pdl[i];
		if($signed((pdl[i] - old_pdl[i])) > 4) num <= i[1:0];
	end

	paddle <= pdl[num];
end

localparam [7:0] paddle_off = 32; //middle point for Chase HQ

wire [7:0] paddle_adj = paddle_off + ((paddle < 40) ? 8'd40 : (paddle > 216) ? 8'd216 : paddle);
wire [7:0] paddle_nes = ~{paddle_adj[0],paddle_adj[1],paddle_adj[2],paddle_adj[3],paddle_adj[4],paddle_adj[5],paddle_adj[6],paddle_adj[7]};
wire       paddle_en  = (status[34:33] == 2);
wire       paddle_atr = paddle_en & status[32];
wire       paddle_btn = paddle_atr ? (joyA[4] | joyB[4] | joyC[4] | joyD[4]) : (joyA[10] | joyB[10] | joyC[10] | joyD[10]);

always @(posedge clk) begin
	if (reset_nes) begin
		joypad_bits <= 0;
		joypad_bits2 <= 0;
		joypad_d3 <= 0;
		joypad_d4 <= 0;
		last_joypad_clock <= 0;
	end else begin
		if (joypad_out[0]) begin
			joypad_bits  <= piano ? {15'h0000, uart_data[8:0]}
				: {status[10] ? {8'h08, nes_joy_C} : 16'hFFFF, joy_swap ? nes_joy_B : nes_joy_A};
			joypad_bits2 <= {status[10] ? {8'h04, nes_joy_D} : 16'hFFFF, joy_swap ? nes_joy_A : nes_joy_B};
			joypad_d4 <= paddle_en ? paddle_nes : {4'b1111, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
			joypad_d3 <= {powerpad[6], powerpad[10], powerpad[9], powerpad[5], powerpad[8], powerpad[4], powerpad[0], powerpad[1]};
		end
		if (!joypad_clock[0] && last_joypad_clock[0]) begin
			joypad_bits <= {1'b0, joypad_bits[23:1]};
		end
		if (!joypad_clock[1] && last_joypad_clock[1]) begin
			joypad_bits2 <= {1'b0, joypad_bits2[23:1]};
			joypad_d4 <= {~paddle_en, joypad_d4[7:1]};
			joypad_d3 <= {1'b1, joypad_d3[7:1]};
		end
		last_joypad_clock <= joypad_clock;
	end
end

// Loader
wire [7:0] file_input;
wire [7:0] loader_input = (loader_busy && !downloading) ? !nsf ? bios_data : nsf_data : file_input;
wire       loader_clk;
wire [24:0] loader_addr;
wire [7:0] loader_write_data;
reg loader_reset;
wire loader_write;
wire [63:0] loader_flags;
reg  [63:0] mapper_flags;
wire fds = (mapper_flags[7:0] == 8'h14);
wire nsf = (loader_flags[7:0] == 8'h1F);
wire piano = (mapper_flags[30]);
wire [3:0] prg_nvram = mapper_flags[34:31];
wire loader_busy, loader_done, loader_fail;
wire [9:0] prg_mask, chr_mask;

GameLoader loader
(
	.clk              ( clk               ),
	.reset            ( loader_reset      ),
	.downloading      ( downloading       ),
	.filetype         ( {4'b0000, type_nsf, type_fds, type_nes, type_bios} ),
	.is_bios          ( is_bios           ), // boot0 bios
	.indata           ( loader_input      ),
	.indata_clk       ( loader_clk        ),
	.mem_addr         ( loader_addr       ),
	.mem_data         ( loader_write_data ),
	.mem_write        ( loader_write      ),
	.mapper_flags     ( loader_flags      ),
	.prg_mask         ( prg_mask          ),
	.chr_mask         ( chr_mask          ),
	.busy             ( loader_busy       ),
	.done             ( loader_done       ),
	.error            ( loader_fail       ),
	.rom_loaded       ( rom_loaded        )
);

always @(posedge clk) if (loader_done) mapper_flags <= loader_flags;

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

wire [1:0] diskside;
reg       diskside_info;
always @(posedge clk) begin
	reg [1:0] old_diskside;

	old_diskside <= diskside;
	diskside_info <= (old_diskside != diskside);
end

wire gg_reset = (type_fds | type_gg | type_nes | type_nsf) && ioctl_download;

// pause
reg       pausecore;
reg [1:0] videopause_ce;
wire      corepaused;
wire      refresh;
wire      sleep_savestate;

assign HDMI_FREEZE = corepaused;

always_ff @(posedge clk) begin
	pausecore <= sleep_savestate | (status[41] && OSD_STATUS && !ioctl_download && !reset_nes);

	if (!corepaused) begin
		videopause_ce <= nes_ce + 1'd1;
	end else begin
		videopause_ce <= videopause_ce + 1'd1;
	end
end

NES nes (
	.clk             (clk),
	.reset_nes       (reset_nes),
	.cold_reset      (downloading & (type_fds | type_nes)),
	.pausecore       (pausecore),
	.corepaused      (corepaused),
	.sys_type        (status[24:23]),
	.nes_div         (nes_ce),
	.mapper_flags    (downloading ? 64'd0 : mapper_flags),
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
	.dejitter_timing(status[26]),
	// User Input
	.joypad_out      (joypad_out),
	.joypad_clock    (joypad_clock),
	.joypad1_data    (joypad1_data),
	.joypad2_data    (joypad2_data),

	.diskside        (diskside),
	.fds_busy        (fds_busy),
	.fds_eject       (fds_btn),
	.fds_auto_eject  (fds_auto_eject),
	.max_diskside    (max_diskside),
	.fds_fast        (fds_fast),

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
	.refresh         (refresh  ),

	.prg_mask        (prg_mask ),
	.chr_mask        (chr_mask ),

	.bram_addr       (bram_addr),
	.bram_din        (bram_din),
	.bram_dout       (bram_dout),
	.bram_write      (bram_write),
	.bram_override   (bram_en),
	.save_written    (save_written),

	// savestates
	.mapper_has_savestate    (mapper_has_savestate),
	.increaseSSHeaderCount   (!status[44]),
	.save_state              (ss_save),
	.load_state              (ss_load),
	.savestate_number        (ss_slot),
	.sleep_savestate         (sleep_savestate),

	.Savestate_SDRAMAddr     (Savestate_SDRAMAddr     ),
	.Savestate_SDRAMRdEn     (Savestate_SDRAMRdEn     ),
	.Savestate_SDRAMWrEn     (Savestate_SDRAMWrEn     ),
	.Savestate_SDRAMWriteData(Savestate_SDRAMWriteData),
	.Savestate_SDRAMReadData (Savestate_SDRAMReadData ),

	.SaveStateExt_Din        (SaveStateBus_Din),
	.SaveStateExt_Adr        (SaveStateBus_Adr),
	.SaveStateExt_wren       (SaveStateBus_wren),
	.SaveStateExt_rst        (SaveStateBus_rst),
	.SaveStateExt_Dout       (SaveStateBus_Dout),
	.SaveStateExt_load       (savestate_load),

	.SAVE_out_Din            (ss_din),           // data read from savestate
	.SAVE_out_Dout           (ss_dout),          // data written to savestate
	.SAVE_out_Adr            (ss_addr),          // all addresses are DWORD addresses!
	.SAVE_out_rnw            (ss_rnw),           // read = 1, write = 0
	.SAVE_out_ena            (ss_req),           // one cycle high for each action
	.SAVE_out_be             (ss_be),
	.SAVE_out_done           (ss_ack)            // should be one cycle high when write is done or read value is valid
);

wire [24:0] cpu_addr;
wire [21:0] ppu_addr;
wire        cpu_read, cpu_write, ppu_read, ppu_write;
wire  [7:0] cpu_dout, cpu_din, ppu_dout, ppu_din;

wire [2:0] emphasis;

wire [7:0] bios_data;
wire bios_download = downloading & type_bios;
wire bios_write = (loader_write && bios_download && ~bios_loaded);

reg bios_loaded = 0; // Only load bios once
reg last_bios_download = 0;

always @(posedge clk) begin
	last_bios_download <= bios_download;
	if(last_bios_download && ~bios_download) begin
		bios_loaded <= 1;
	end
end

spram #(.addr_width(13)) fds_bios
(
	.clock(clk),
	.address(loader_addr[12:0]),
	.wren(bios_write),
	.data(loader_write_data),
	.q(bios_data)
);

wire [7:0] nsf_data;
spram #(12, 8, "rtl/loopy_NSF.mif") nsfplayrom
(
	.clock(clk),
	.address(loader_addr[11:0]),
	.q(nsf_data)
);

// loader_write -> clock when data available
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [24:0] loader_addr_mem;

reg loader_write_triggered;

always @(posedge clk) begin
	if(loader_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
		loader_write_data_mem <= loader_write_data;
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

wire [24:0] ch2_addr = sleep_savestate ? Savestate_SDRAMAddr      : {7'b0001111, save_addr};
wire        ch2_wr   = sleep_savestate ? Savestate_SDRAMWrEn      : save_wr;
wire  [7:0] ch2_din  = sleep_savestate ? Savestate_SDRAMWriteData : sd_buff_dout;
wire        ch2_rd   = sleep_savestate ? Savestate_SDRAMRdEn      : save_rd;

assign Savestate_SDRAMReadData = save_dout;

sdram sdram
(
	.*,

	// system interface
	.clk        ( clk85           ),
	.init       ( !clock_locked   ),

	// cpu/chipset interface
	.ch0_addr   (  (downloading | loader_busy) ? loader_addr_mem       : {3'b0, ppu_addr}  ),
	.ch0_wr     (                                loader_write_mem      | ppu_write ),
	.ch0_din    (  (downloading | loader_busy) ? loader_write_data_mem : ppu_dout  ),
	.ch0_rd     ( ~(downloading | loader_busy)                         & ppu_read  ),
	.ch0_dout   ( ppu_din   ),
	.ch0_busy   ( ),

	.ch1_addr   ( cpu_addr  ),
	.ch1_wr     ( cpu_write ),
	.ch1_din    ( cpu_dout  ),
	.ch1_rd     ( cpu_read  ),
	.ch1_dout   ( cpu_din   ),
	.ch1_busy   ( ),

	// reserved for backup ram save/load
	.ch2_addr   ( ch2_addr ),
	.ch2_wr     ( ch2_wr ),
	.ch2_din    ( ch2_din ),
	.ch2_rd     ( ch2_rd ),
	.ch2_dout   ( save_dout ),
	.ch2_busy   ( save_busy ),

	.refresh    (refresh  ),
	.ss_in      (sdram_ss_in),
	.ss_load    (savestate_load),
	.ss_out     (sdram_ss_out)
);

wire [7:0] save_dout;
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
// palette loader
reg [23:0] pal_color;
reg [5:0] pal_index;
reg [1:0] pal_count;

wire pal_write = ioctl_download && type_palette ? ~|pal_count : 1'b0;

always @(posedge clk) begin
	if (ioctl_download && loader_clk && type_palette && ioctl_addr < 192) begin
		pal_count <= pal_count == 2 ? 2'd0 : pal_count + 2'd1;
		case (pal_count)
			0: begin
				pal_color[23:16] <= file_input;
				//pal_write <= 0;
				pal_index <= ioctl_addr > 0 ? pal_index + 1'd1 : pal_index;
			end

			1: begin
				pal_color[15:8] <= file_input;
			end

			2: begin
				pal_color[7:0] <= file_input;
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
wire HSync,VSync,HBlank,VBlank;
wire [7:0] R,G,B;

wire [1:0] nes_ce_video = corepaused ? videopause_ce : nes_ce;

video video
(
	.*,
	.clk(clk),
	.reset(reset_nes),
	.cnt(nes_ce_video),
	.hold_reset(hold_reset),
	.count_v(scanline),
	.count_h(cycle),
	.hide_overscan(hide_overscan),
	.palette(palette2_osd),
	.load_color(pal_write && ioctl_download),
	.load_color_data(pal_color),
	.load_color_index(pal_index),
	.emphasis(emphasis),
	.reticle(~status[22] ? reticle : 2'b00),
	.pal_video(pal_video)
);

video_mixer #(260, 0, 1) video_mixer
(
	.*,
	.freeze_sync(),
	.VGA_DE(vga_de),
	.hq2x(scale==1),
	.scandoubler(scale || forced_scandoubler)
);

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
reg [1:0] max_diskside = 2'd3;
always @(posedge clk) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;
	if(~bk_ena && loader_write_triggered) max_diskside <= loader_addr_mem[17:16];
end

wire bk_load    = status[6];
wire bk_save    = status[7] | (bk_pending & OSD_STATUS && ~status[50]);
reg  bk_loading = 0;
reg  bk_loading_req = 0;
reg  bk_request = 0;
wire bk_busy = (bk_state == S_COPY);
reg  fds_busy;

wire [8:0] save_sz = fds ? rom_sz[17:9] : bram_en ? 9'd3 : (prg_nvram == 4'd7) ? 9'd15 : 9'd63;

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

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if (downloading) begin
		bk_state <= S_IDLE;
		bk_request <= 0;
	end else if(bk_state == S_IDLE) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_loading <= bk_load;
			bk_request <= 1;
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

///////////////////////////// savestates /////////////////////////////////

wire [63:0] ss_dout, ss_din;
wire [27:2] ss_addr;
wire  [7:0] ss_be;
wire        ss_rnw, ss_req, ss_ack;

wire [24:0] Savestate_SDRAMAddr;
wire        Savestate_SDRAMRdEn;
wire        Savestate_SDRAMWrEn;
wire [7:0]  Savestate_SDRAMWriteData;
wire [7:0]  Savestate_SDRAMReadData;

wire [63:0] SaveStateBus_Din;
wire [9:0]  SaveStateBus_Adr;
wire        SaveStateBus_wren;
wire        SaveStateBus_rst;
wire [63:0] SaveStateBus_Dout;
wire        savestate_load;

wire [15:0] sdram_ss_in = SS_Ext[15:0];
wire [15:0] sdram_ss_out;

wire [63:0] SS_Ext;
wire [63:0] SS_Ext_BACK;
eReg_SavestateV #(SSREG_INDEX_EXT, SSREG_DEFAULT_EXT) iREG_SAVESTATE_Ext (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_Ext_BACK, SS_Ext);

assign SS_Ext_BACK[15: 0] = sdram_ss_out;
assign SS_Ext_BACK[63:16] = 48'b0; // free to be used

assign DDRAM_CLK = clk;
ddram ddram
(
	.*,

	.ch1_addr({ss_addr, 1'b0}),
	.ch1_din(ss_din),
	.ch1_dout(ss_dout),
	.ch1_req(ss_req),
	.ch1_rnw(ss_rnw),
	.ch1_be(ss_be),
	.ch1_ready(ss_ack)
);

// saving with keyboard/OSD/gamepad
wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire mapper_has_savestate;
wire statusUpdate;

//Ignore F1-F4 when famicom keyboard is enabled
wire skip_ps2 = (ps2_key[7:0] == 'h04) || (ps2_key[7:0] == 'h05) || (ps2_key[7:0] == 'h06) || (ps2_key[7:0] == 'h0C);
wire [10:0] ps2_key_adjust = skip_ps2 && fkeyb ? 'h0 : ps2_key[10:0];

savestate_ui savestate_ui
(
	.clk            (clk           ),
	.ps2_key        (ps2_key_adjust),
	.allow_ss       (rom_loaded & mapper_has_savestate),
	.joySS          (joyA_unmod[23]),
	.joyRight       (joyA_unmod[0] ),
	.joyLeft        (joyA_unmod[1] ),
	.joyDown        (joyA_unmod[2] ),
	.joyUp          (joyA_unmod[3] ),
	.joyStart       (joyA_unmod[7] ),
	.status_slot    (status[46:45] ),
	.OSD_saveload   (status[43:42] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

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
	output reg [24:0] mem_addr,
	output [7:0]  mem_data,
	output        mem_write,
	output [63:0] mapper_flags,
	output reg [9:0]  prg_mask,
	output reg [9:0]  chr_mask,
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
reg [24:0] bytes_left;

wire [7:0] prgrom = ines[4];	// Number of 16384 byte program ROM pages
wire [7:0] chrrom = ines[5];	// Number of 8192 byte character ROM pages (0 indicates CHR RAM)
wire [3:0] chrram = ines[11][3:0]; // NES 2.0 CHR-RAM size shift count (64 << count)
wire has_chr_ram = ~is_nes20 ? (chrrom == 0) : |chrram;

assign mem_data = (state == S_CLEARRAM || (~copybios && state == S_COPYBIOS)) ? 8'h00 : indata;
assign mem_write = (((bytes_left != 0) && (state == S_LOADPRG || state == S_LOADCHR || state == S_LOADEXTRA)
	|| (downloading && (state == S_LOADHEADER || state == S_LOADFDS || state == S_LOADNSFH || state == S_LOADNSFD))) && indata_clk)
	|| ((bytes_left != 0) && ((state == S_CLEARRAM) || (state == S_COPYBIOS) || (state == S_COPYPLAY)) && clearclk == 4'h2);

// detect iNES2.0 compliant header
wire is_nes20 = (ines[7][3:2] == 2'b10);
wire is_nes20_prg = (is_nes20 && (ines[9][3:0] == 4'hF));
wire is_nes20_chr = (is_nes20 && (ines[9][7:4] == 4'hF));

// NES 2.0 PRG & CHR sizes
reg [21:0] prg_size2, chr_size2, chr_ram_size;

function [9:0] mask;
	input [10:0] size;
	integer i;
	begin
		for (i=0;i<10;i=i+1) mask[i] = ( size > (11'd1 << i) );
	end
endfunction

always @(posedge clk) begin
	// PRG
	// ines[4][1:0]: Multiplier, actual value is MM*2+1 (1,3,5,7)
	// ines[4][7:2]: Exponent (2^E), 0-63
	prg_size2 <= is_nes20_prg ? ({19'b0, ines[4][1:0], 1'b1} << ines[4][7:2]) : {prgrom, 14'b0};
	prg_mask <= mask(prg_size2[21:11]);

	// CHR
	chr_size2 <= is_nes20_chr ? ({19'b0, ines[5][1:0], 1'b1} << ines[5][7:2]) : {1'b0, chrrom, 13'b0};
	chr_ram_size <= is_nes20 ? (22'd64 << chrram) : 22'h2000;
	chr_mask <= mask(|chr_size2 ? chr_size2[21:11] : chr_ram_size[21:11]);
end

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
wire [3:0] prg_nvram = (is_nes20 ? ines[10][7:4] : 4'h0);
wire       piano = is_nes20 && (ines[15][5:0] == 6'h19);
wire has_saves = ines[6][1];

assign mapper_flags[63:36] = 'd0;
assign mapper_flags[35]    = is_nes20;
assign mapper_flags[34:31] = prg_nvram; //NES 2.0 Save RAM shift size (64 << size)
assign mapper_flags[30]    = piano;
assign mapper_flags[29:26] = prgram; //NES 2.0 PRG RAM shift size (64 << size)
assign mapper_flags[25]    = has_saves;
assign mapper_flags[24:17] = ines2mapper; //NES 2.0 submapper
assign mapper_flags[16]    = ines[6][3]; // 4 screen mode
assign mapper_flags[15]    = has_chr_ram;
assign mapper_flags[14]    = ines[6][0]; // mirroring
assign mapper_flags[13:11] = chr_size;
assign mapper_flags[10:8]  = prg_size;
assign mapper_flags[7:0]   = mapper;

reg [3:0] clearclk; //Wait for SDRAM
reg copybios;
reg cleardone;

typedef enum bit [3:0] { S_LOADHEADER, S_LOADPRG, S_LOADCHR, S_LOADEXTRA, S_LOADFDS, S_ERROR, S_CLEARRAM, S_COPYBIOS, S_LOADNSFH, S_LOADNSFD, S_COPYPLAY, S_DONE } mystate;
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
		mem_addr <= type_fds ? 25'b0_0011_1100_0000_0000_0001_0000 :
			type_nsf ? 25'b0_0000_0000_0000_0001_0000_0000   // Address for NSF Header (0x80 bytes)
			: 25'b0_0000_0000_0000_0000_0000_0000;           // Address for FDS : BIOS/PRG
		copybios <= 0;
		cleardone <= 0;
	end else begin
		case(state)
		// Read 16 bytes of ines header
		S_LOADHEADER:
			if (indata_clk) begin
				error <= 0;
				ctr <= ctr + 1'd1;
				mem_addr <= mem_addr + 1'd1;
				ines[ctr] <= indata;
				bytes_left <= prg_size2;
				if (ctr == 4'b1111) begin
					// Check the 'NES' header. Also, we don't support trainers.
					busy <= 1;
					if ((ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2]) begin
						mem_addr <= 0;  // Address for PRG
						state <= S_LOADPRG;
					//FDS
					end else if ((ines[0] == 8'h46) && (ines[1] == 8'h44) && (ines[2] == 8'h53) && (ines[3] == 8'h1A)) begin
						mem_addr <= 25'b0_0011_1100_0000_0000_0001_0000;  // Address for FDS skip Header
						state <= S_LOADFDS;
						bytes_left <= 21'b1;
					end else if (type_bios) begin // Bios
						state <= S_LOADFDS;
						mem_addr <= 25'b0_0000_0000_0000_0000_0001_0000;  // Address for BIOS skip Header
						bytes_left <= 21'b1;
					end else if(type_fds) begin // FDS
						state <= S_LOADFDS;
						mem_addr <= 25'b0_0011_1100_0000_0000_0010_0000;  // Address for FDS no Header
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
			// Abort when downloading stops and there are bytes left (invalid header)
			if (downloading && bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			end else if (state == S_LOADPRG) begin
				state <= S_LOADCHR;
				mem_addr <= 25'b0_0010_0000_0000_0000_0000_0000; // Address for CHR
				bytes_left <= chr_size2;
			end else if (state == S_LOADCHR) begin
				state <= S_LOADEXTRA;
				mem_addr <= 25'b1_0000_0000_0000_0000_0000_0000; // Address for Extra
				//Replace with calculation based on file size requires actual file size?
				bytes_left <= ({ines2mapper[1:0],mapper} == 10'd413) ? 25'b0_1000_0000_0000_0000_0000_0000 : 25'd0;
			end
		end
		S_LOADEXTRA: begin
			if (downloading &&  bytes_left != 0) begin
				if (indata_clk) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			end else if (mapper == 8'd232) begin
				mem_addr <= 25'b0_0011_1000_0000_0111_1111_1110; // Quattro - Clear these two RAM address to restart game menu
				bytes_left <= 21'h2;
				state <= S_CLEARRAM;
				clearclk <= 4'h0;
				cleardone <= 1;
			end else begin
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
//				mem_addr <= 25'b0_0011_1000_0000_0000_0000_0000;
//				bytes_left <= 21'h800;
				mem_addr <= 25'b0_0011_1000_0000_0001_0000_0010; // FDS - Clear these two RAM addresses to restart BIOS
				bytes_left <= 21'h2;
				ines[4] <= 8'h80;//no masking
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
			end else if (!cleardone) begin
				mem_addr <= 25'b0_0000_0000_0000_0000_0000_0000;
				bytes_left <= 21'h2000;
				state <= S_COPYBIOS;
				clearclk <= 4'h0;
			end else begin
				state <= S_DONE;
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
				//mem_addr <= {25'b0_0001_0000_0000_0000_0000_0000; // Address for NSF Data
				mem_addr <= {13'b0_0001_0000_0000,ines[9][3:0],ines[8]};//_0000_0000_0000; // Address for NSF Data
				bytes_left <= 21'b1;
			end
		end
		S_LOADNSFD: begin // Read the next |bytes_left| bytes into |mem_addr|
			if (downloading) begin
				if (indata_clk) begin
					mem_addr <= mem_addr + 1'd1;
				end
			end else begin
				mem_addr <= 25'b0_0000_0000_0000_0001_1000_0000; // Address for NSF Player (0x180)
				bytes_left <= 21'h0E80;
				ines[4] <= 8'h80;//no masking
				ines[5] <= 8'h00;//no CHR ROM
				ines[6] <= 8'hF0;//Use Mapper 31
				ines[7] <= 8'h18;//Use NES 2.0
				ines[8] <= 8'hF0;//Use Submapper 15
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h07;//NES 2.0 8KB CHR RAM
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h19;//miracle piano; controllers swapped
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
		end
		endcase
	end
end
endmodule
