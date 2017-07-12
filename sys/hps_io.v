//
// hps_io.v
//
// mist_io-like module for the Terasic DE10 board
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
// Copyright (c) 2017 Sorgelig (port to DE10-nano)
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
///////////////////////////////////////////////////////////////////////

//
// Use buffer to access SD card. It's time-critical part.
//
// for synchronous projects default value for PS2DIV is fine for any frequency of system clock.
// clk_ps2 = CLK_SYS/(PS2DIV*2)
//

// WIDE=1 for 16 bit file I/O
// VDNUM 1-4
module hps_io #(parameter STRLEN=0, PS2DIV=1000, WIDE=0, VDNUM=1)
(
	input             clk_sys,
	inout      [37:0] HPS_BUS,

	// parameter STRLEN and the actual length of conf_str have to match
	input [(8*STRLEN)-1:0] conf_str,

	output reg [15:0] joystick_0,
	output reg [15:0] joystick_1,
	output reg [15:0] joystick_analog_0,
	output reg [15:0] joystick_analog_1,

	output      [1:0] buttons,
	output            forced_scandoubler,

	output reg [31:0] status,

	// SD config
	output reg [VD:0] img_mounted,  // signaling that new image has been mounted
	output reg        img_readonly, // mounted as read only. valid only for active bit in img_mounted
	output reg [63:0] img_size,     // size of image in bytes. valid only for active bit in img_mounted

	// SD block level access
	input      [31:0] sd_lba,
	input      [VD:0] sd_rd,       // only single sd_rd can be active at any given time
	input      [VD:0] sd_wr,       // only single sd_wr can be active at any given time
	output reg        sd_ack,
	
	// do not use in new projects.
	// CID and CSD are fake except CSD image size field.
	input             sd_conf,
	output reg        sd_ack_conf,

	// SD byte level access. Signals for 2-PORT altsyncram.
	output reg [AW:0] sd_buff_addr,
	output reg [DW:0] sd_buff_dout,
	input      [DW:0] sd_buff_din,
	output reg        sd_buff_wr,

	// ARM -> FPGA download
	output reg        ioctl_download = 0, // signal indicating an active download
	output reg  [7:0] ioctl_index,        // menu index used to upload the file
	output reg        ioctl_wr,
	output reg [24:0] ioctl_addr,         // in WIDE mode address will be incremented by 2
	output reg [DW:0] ioctl_dout,
	input             ioctl_wait,

	// ps2 keyboard emulation
	output            ps2_kbd_clk,
	output reg        ps2_kbd_data,
	input       [2:0] ps2_kbd_led_status,
	input       [2:0] ps2_kbd_led_use,

	output            ps2_mouse_clk,
	output reg        ps2_mouse_data
);

localparam DW = (WIDE) ? 15 : 7;
localparam AW = (WIDE) ?  7 : 8;
localparam VD = VDNUM-1;

wire        io_wait  = ioctl_wait;
wire        io_enable= |HPS_BUS[35:34];
wire        io_strobe= HPS_BUS[33];
wire        io_wide  = (WIDE) ? 1'b1 : 1'b0;
wire [15:0] io_din   = HPS_BUS[31:16];
reg  [15:0] io_dout;

assign HPS_BUS[37]   = io_wait;
assign HPS_BUS[36]   = clk_sys;
assign HPS_BUS[32]   = io_wide;
assign HPS_BUS[15:0] = io_dout;

reg [7:0] cfg;
assign buttons = cfg[1:0];
//cfg[2] - vga_scaler handled in sys_top
//cfg[3] - csync handled in sys_top
assign forced_scandoubler = cfg[4];
//cfg[5] - ypbpr handled in sys_top

// command byte read by the io controller
wire [15:0] sd_cmd = 
{
	2'b00,
	(VDNUM>=4) ? sd_wr[3] : 1'b0,
	(VDNUM>=3) ? sd_wr[2] : 1'b0,
	(VDNUM>=2) ? sd_wr[1] : 1'b0,

	(VDNUM>=4) ? sd_rd[3] : 1'b0,
	(VDNUM>=3) ? sd_rd[2] : 1'b0,
	(VDNUM>=2) ? sd_rd[1] : 1'b0,
	
	4'h5, sd_conf, 1'b1,
	sd_wr[0],
	sd_rd[0]
};

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg  [9:0] byte_cnt;   // counts bytes
	reg  [2:0] b_wr;
	reg  [2:0] stick_idx;

	sd_buff_wr <= b_wr[0];
	if(b_wr[2] && (~&sd_buff_addr)) sd_buff_addr <= sd_buff_addr + 1'b1;
	b_wr <= (b_wr<<1);

	if(~io_enable) begin
		byte_cnt <= 0;
		sd_ack <= 0;
		sd_ack_conf <= 0;
		io_dout <= 0;
	end else begin
		if(io_strobe) begin

			io_dout <= 0;
			if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

			if(byte_cnt == 0) begin
				cmd <= io_din;

				case(io_din)
					'h19: sd_ack_conf <= 1;
					'h17,
					'h18: sd_ack <= 1;
				endcase

				sd_buff_addr <= 0;
				img_mounted <= 0;
			end else begin

				case(cmd)
					// buttons and switches
					'h01: cfg        <= io_din[7:0]; 
					'h02: joystick_0 <= io_din;
					'h03: joystick_1 <= io_din;

					// store incoming ps2 mouse bytes 
					'h04: begin
							ps2_mouse_fifo[ps2_mouse_wptr] <= io_din[7:0]; 
							ps2_mouse_wptr <= ps2_mouse_wptr + 1'd1;
						end

					// store incoming ps2 keyboard bytes 
					'h05: begin
							ps2_kbd_fifo[ps2_kbd_wptr] <= io_din[7:0]; 
							ps2_kbd_wptr <= ps2_kbd_wptr + 1'd1;
						end

					// reading config string
					'h14: begin
							// returning a byte from string
							if(byte_cnt < STRLEN + 1) io_dout[7:0] <= conf_str[(STRLEN - byte_cnt)<<3 +:8];
						end

					// reading sd card status
					'h16: begin
							case(byte_cnt)
								1: io_dout <= sd_cmd;
								2: io_dout <= sd_lba[15:0];
								3: io_dout <= sd_lba[31:16];
							endcase
						end

					// send SD config IO -> FPGA
					// flag that download begins
					// sd card knows data is config if sd_dout_strobe is asserted
					// with sd_ack still being inactive (low)
					'h19,
					// send sector IO -> FPGA
					// flag that download begins
					'h17: begin
							sd_buff_dout <= io_din[DW:0];
							b_wr <= 1;
						end

					// reading sd card write data
					'h18: begin
							if(~&sd_buff_addr) sd_buff_addr <= sd_buff_addr + 1'b1;
							io_dout <= sd_buff_din;
						end

					// joystick analog
					'h1a: begin
							// first byte is joystick index
							if(byte_cnt == 1) stick_idx <= io_din[2:0];
							if(byte_cnt == 2) begin
								if(stick_idx == 0) joystick_analog_0 <= io_din;
								if(stick_idx == 1) joystick_analog_1 <= io_din;
							end
						end

					// notify image selection
					'h1c: begin
							img_mounted  <= io_din[VD:0] ? io_din[VD:0] : 1'b1;
							img_readonly <= io_din[7];
						end

					// send image info
					'h1d: if(byte_cnt<5) img_size[{byte_cnt-1'b1, 4'b0000} +:16] <= io_din;

					// status, 32bit version
					'h1e: if(byte_cnt==1) status[15:0] <= io_din;
								else if(byte_cnt==2) status[31:16] <= io_din;

					// reading keyboard LED status
					'h1f: io_dout[7:0] <= { 2'b01, ps2_kbd_led_status[2], ps2_kbd_led_use[2], ps2_kbd_led_status[1], ps2_kbd_led_use[1], ps2_kbd_led_status[0], ps2_kbd_led_use[0]};

					default: ;
				endcase
			end
		end
	end
end


///////////////////////////////   PS2   ///////////////////////////////
// 16 byte fifos to store ps2 bytes
localparam PS2_FIFO_BITS = 3;

reg clk_ps2;
always @(negedge clk_sys) begin
	integer cnt;
	cnt <= cnt + 1'd1;
	if(cnt == PS2DIV) begin
		clk_ps2 <= ~clk_ps2;
		cnt <= 0;
	end
end

// keyboard
(* ramstyle = "logic" *) reg [7:0] ps2_kbd_fifo[1<<PS2_FIFO_BITS];
reg [PS2_FIFO_BITS-1:0] ps2_kbd_wptr;
reg [PS2_FIFO_BITS-1:0] ps2_kbd_rptr;

// ps2 transmitter state machine
reg [3:0] ps2_kbd_tx_state;
reg [7:0] ps2_kbd_tx_byte;
reg ps2_kbd_parity;

assign ps2_kbd_clk = clk_ps2 || (ps2_kbd_tx_state == 0);

// ps2 transmitter
// Takes a byte from the FIFO and sends it in a ps2 compliant serial format.
reg ps2_kbd_r_inc;
always@(posedge clk_sys) begin
	reg old_clk;
	old_clk <= clk_ps2;
	if(~old_clk & clk_ps2) begin
		ps2_kbd_r_inc <= 0;

		if(ps2_kbd_r_inc) ps2_kbd_rptr <= ps2_kbd_rptr + 1'd1;

		// transmitter is idle?
		if(ps2_kbd_tx_state == 0) begin
			// data in fifo present?
			if(ps2_kbd_wptr != ps2_kbd_rptr) begin
				// load tx register from fifo
				ps2_kbd_tx_byte <= ps2_kbd_fifo[ps2_kbd_rptr];
				ps2_kbd_r_inc <= 1;

				// reset parity
				ps2_kbd_parity <= 1;

				// start transmitter
				ps2_kbd_tx_state <= 1;

				// put start bit on data line
				ps2_kbd_data <= 0;			// start bit is 0
			end
		end else begin

			// transmission of 8 data bits
			if((ps2_kbd_tx_state >= 1)&&(ps2_kbd_tx_state < 9)) begin
				ps2_kbd_data <= ps2_kbd_tx_byte[0];	          // data bits
				ps2_kbd_tx_byte[6:0] <= ps2_kbd_tx_byte[7:1]; // shift down
				if(ps2_kbd_tx_byte[0]) 
					ps2_kbd_parity <= !ps2_kbd_parity;
			end

			// transmission of parity
			if(ps2_kbd_tx_state == 9) ps2_kbd_data <= ps2_kbd_parity;

			// transmission of stop bit
			if(ps2_kbd_tx_state == 10) ps2_kbd_data <= 1;    // stop bit is 1

			// advance state machine
			if(ps2_kbd_tx_state < 11) ps2_kbd_tx_state <= ps2_kbd_tx_state + 1'd1;
				else ps2_kbd_tx_state <= 0;
		end
	end
end

// mouse
(* ramstyle = "logic" *) reg [7:0] ps2_mouse_fifo[1<<PS2_FIFO_BITS];
reg [PS2_FIFO_BITS-1:0] ps2_mouse_wptr;
reg [PS2_FIFO_BITS-1:0] ps2_mouse_rptr;

// ps2 transmitter state machine
reg [3:0] ps2_mouse_tx_state;
reg [7:0] ps2_mouse_tx_byte;
reg ps2_mouse_parity;

assign ps2_mouse_clk = clk_ps2 || (ps2_mouse_tx_state == 0);

// ps2 transmitter
// Takes a byte from the FIFO and sends it in a ps2 compliant serial format.
reg ps2_mouse_r_inc;
always@(posedge clk_sys) begin
	reg old_clk;
	old_clk <= clk_ps2;
	if(~old_clk & clk_ps2) begin
		ps2_mouse_r_inc <= 0;

		if(ps2_mouse_r_inc) ps2_mouse_rptr <= ps2_mouse_rptr + 1'd1;

		// transmitter is idle?
		if(ps2_mouse_tx_state == 0) begin
			// data in fifo present?
			if(ps2_mouse_wptr != ps2_mouse_rptr) begin
				// load tx register from fifo
				ps2_mouse_tx_byte <= ps2_mouse_fifo[ps2_mouse_rptr];
				ps2_mouse_r_inc <= 1;

				// reset parity
				ps2_mouse_parity <= 1;

				// start transmitter
				ps2_mouse_tx_state <= 1;

				// put start bit on data line
				ps2_mouse_data <= 0;			// start bit is 0
			end
		end else begin

			// transmission of 8 data bits
			if((ps2_mouse_tx_state >= 1)&&(ps2_mouse_tx_state < 9)) begin
				ps2_mouse_data <= ps2_mouse_tx_byte[0];			  // data bits
				ps2_mouse_tx_byte[6:0] <= ps2_mouse_tx_byte[7:1]; // shift down
				if(ps2_mouse_tx_byte[0]) 
					ps2_mouse_parity <= !ps2_mouse_parity;
			end

			// transmission of parity
			if(ps2_mouse_tx_state == 9) ps2_mouse_data <= ps2_mouse_parity;

			// transmission of stop bit
			if(ps2_mouse_tx_state == 10) ps2_mouse_data <= 1;	  // stop bit is 1

			// advance state machine
			if(ps2_mouse_tx_state < 11) ps2_mouse_tx_state <= ps2_mouse_tx_state + 1'd1;
				else ps2_mouse_tx_state <= 0;
		end
	end
end


///////////////////////////////   DOWNLOADING   ///////////////////////////////

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg        has_cmd;
	reg [24:0] addr;
	reg        wr;

	ioctl_wr <= wr;
	wr <= 0;

	if(~io_enable) has_cmd <= 0;
	else begin
		if(io_strobe) begin

			if(!has_cmd) begin
				cmd <= io_din;
				has_cmd <= 1;
			end else begin

				case(cmd)
					UIO_FILE_INDEX:
						begin
							ioctl_index <= io_din[7:0];
						end

					UIO_FILE_TX:
						begin
							if(io_din[7:0]) begin
								addr <= 0;
								ioctl_download <= 1; 
							end else begin
								ioctl_addr <= addr;
								ioctl_download <= 0;
							end
						end

					UIO_FILE_TX_DAT:
						begin
							ioctl_addr <= addr;
							ioctl_dout <= io_din[DW:0];
							wr   <= 1;
							addr <= addr + (WIDE ? 2'd2 : 2'd1);
						end
				endcase
			end
		end
	end
end

endmodule
