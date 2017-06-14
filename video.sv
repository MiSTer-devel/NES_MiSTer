// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

module video
(
	input        clk,
	input  [5:0] color,
	input  [8:0] count_h,
	input  [8:0] count_v,
	input        forced_scandoubler,
	input  [1:0] scale,
	input        hide_overscan,
	input        palette,
	
	output       ce_pix,

	output       VGA_HS,
	output       VGA_VS,
	output       VGA_DE,
	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B
);

reg pix_ce, pix_ce_n;

always @(negedge clk) begin
	reg [3:0] cnt = 0;
	
	cnt <= cnt + 1'd1;
	pix_ce   <= !cnt[3] & !cnt[2:0];
	pix_ce_n <=  cnt[3] & !cnt[2:0];
end

// NTSC UnsaturatedV6 palette
//see: http://www.firebrandx.com/nespalette.html
wire [15:0] pal_unsat_lut[64] = '{
	'h35ad, 'h4060, 'h4823, 'h4027, 'h302b, 'h140b, 'h004a, 'h0068,
	'h00c6, 'h0121, 'h0120, 'h0d00, 'h2ce0, 'h0000, 'h0000, 'h0000,
	'h5ad6, 'h6943, 'h74c9, 'h748e, 'h5873, 'h3074, 'h0cb4, 'h0130,
	'h01ac, 'h0205, 'h0220, 'h2200, 'h49e0, 'h0000, 'h0000, 'h0000,
	'h7fff, 'h7eac, 'h7e32, 'h7dd7, 'h7ddc, 'h65be, 'h361e, 'h167b,
	'h02f7, 'h0350, 'h1f6b, 'h3f49, 'h6729, 'h294a, 'h0000, 'h0000,
	'h7fff, 'h7f98, 'h7f5a, 'h7f3c, 'h7f3f, 'h7b3f, 'h635f, 'h577e,
	'h4fbd, 'h4fda, 'h5bd7, 'h67d6, 'h77d6, 'h5ef7, 'h0000, 'h0000
};

// FCEUX palette
wire [15:0] pal_fcelut[64] = '{
	'h39ce, 'h4464, 'h5400, 'h4c08, 'h3811, 'h0815, 'h0014, 'h002f,
	'h00a8, 'h0100, 'h0140, 'h08e0, 'h2ce3, 'h0000, 'h0000, 'h0000,
	'h5ef7, 'h75c0, 'h74e4, 'h7810, 'h5c17, 'h2c1c, 'h00bb, 'h0539,
	'h01d1, 'h0240, 'h02a0, 'h1e40, 'h4600, 'h0000, 'h0000, 'h0000,
	'h7fff, 'h7ee7, 'h7e4b, 'h7e28, 'h7dfe, 'h59df, 'h31df, 'h1e7f,
	'h1efe, 'h0b50, 'h2769, 'h4feb, 'h6fa0, 'h3def, 'h0000, 'h0000,
	'h7fff, 'h7f95, 'h7f58, 'h7f3a, 'h7f1f, 'h6f1f, 'h5aff, 'h577f,
	'h539f, 'h53fc, 'h5fd5, 'h67f6, 'h7bf3, 'h6318, 'h0000, 'h0000
};

wire [14:0] pixel = palette ?  pal_unsat_lut[color][14:0] : pal_fcelut[color][14:0];

reg  HBlank, VBlank, HSync, VSync;
reg  [9:0] h, v;
reg  [1:0] free_sync = 0;
wire [9:0] hc = (&free_sync) ? h : count_h;
wire [9:0] vc = (&free_sync) ? v : count_v;

always @(posedge clk) begin
	reg [8:0] old_count_v;

	if(pix_ce_n) begin
		if((old_count_v == 511) && (count_v == 0)) begin
			h <= 0;
			v <= 0;
			free_sync <= 0;
		end else begin
			if(h == 340) begin
				h <= 0;
				if(v == 261) begin
					v <= 0;
					if(~&free_sync) free_sync <= free_sync + 1'd1;
				end else begin
					v <= v + 1'd1;
				end
			end else begin
				h <= h + 1'd1;
			end
		end

		old_count_v <= count_v;
	end

	if(pix_ce) begin
		if(hide_overscan) begin
			HBlank <= (hc > (256-8)) || (hc<10);
			VBlank <= (vc > (240-10)) || (vc<6);
		end else begin
			HBlank <= (hc >= 256);
			VBlank <= (vc >= 240);
		end
		HSync  <= ((hc >= 277) && (hc <  318));
		VSync  <= ((vc >= 245) && (vc <  254));
	end
end

wire [14:0] pixel_v = (HBlank | VBlank) ? 5'd0 : pixel;
wire  [4:0] vga_r   = pixel_v[4:0];
wire  [4:0] vga_g   = pixel_v[9:5];
wire  [4:0] vga_b   = pixel_v[14:10];

video_mixer #(.LINE_LENGTH(350), .HALF_DEPTH(0)) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_pix(pix_ce),
	.ce_pix_out(ce_pix),

	.scanlines({scale==3, scale==2}),
	.hq2x(scale==1),
	.scandoubler(scale || forced_scandoubler),
	.mono(0),

	.R({vga_r, vga_r[4:2]}),
	.G({vga_g, vga_g[4:2]}),
	.B({vga_b, vga_b[4:2]})
);

endmodule
