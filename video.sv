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
	input  [2:0] palette,

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

// Smooth palette from FirebrandX
wire [15:0] pal_smooth_lut[64] = '{
	'h35AD, 'h4040, 'h4403, 'h3C07, 'h280A, 'h0C0B, 'h0049, 'h0067,
	'h00C4, 'h00E0, 'h0100, 'h10E0, 'h28A0, 'h0000, 'h0000, 'h0000,
	'h5EF7, 'h6143, 'h70C9, 'h688E, 'h5472, 'h2CB3, 'h00D3, 'h012F,
	'h018B, 'h01C4, 'h01E0, 'h21C0, 'h45A0, 'h0000, 'h0000, 'h0000,
	'h7FFF, 'h7E8D, 'h7E71, 'h7E16, 'h7DDB, 'h5DDC, 'h363C, 'h167A,
	'h06B6, 'h0B0F, 'h232A, 'h4328, 'h6308, 'h2529, 'h0000, 'h0000,
	'h7FFF, 'h7FB9, 'h7F7B, 'h7F7D, 'h7F5F, 'h7B5F, 'h677F, 'h5B9F,
	'h57DE, 'h57FB, 'h5FF9, 'h6BF8, 'h7BD8, 'h5F17, 'h0000, 'h0000
};

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

// NES Classic by FirebrandX
wire [15:0] pal_nes_classic_lut[64] = '{
	'h318C, 'h4400, 'h4C23, 'h3C46, 'h304A, 'h080B, 'h002A, 'h0487,
	'h04C4, 'h0501, 'h0902, 'h0CE0, 'h28A0, 'h0000, 'h0000, 'h0000,
	'h56B5, 'h6121, 'h6C89, 'h644D, 'h5452, 'h2473, 'h00D2, 'h014E,
	'h09AB, 'h09E2, 'h0602, 'h25C2, 'h4983, 'h0000, 'h0000, 'h0000,
	'h7FFF, 'h7E6C, 'h7DF1, 'h7DB6, 'h79BB, 'h55DC, 'h2E1C, 'h1279,
	'h02D5, 'h030E, 'h272B, 'h4706, 'h66E9, 'h2108, 'h0000, 'h0000,
	'h7FFF, 'h7F57, 'h7F39, 'h7F1B, 'h7F1D, 'h731F, 'h633E, 'h533C,
	'h4F7B, 'h4F99, 'h5F97, 'h67B6, 'h7796, 'h56B5, 'h0000, 'h0000
};

// Composite Direct by FirebrandX
wire [15:0] pal_composite_direct_lut[64] = '{
	'h318C, 'h3C40, 'h4403, 'h4006, 'h2C0A, 'h0C0B, 'h0009, 'h0067,
	'h00C3, 'h00E0, 'h0100, 'h08E0, 'h28A0, 'h0000, 'h0000, 'h0000,
	'h56B5, 'h6523, 'h70A8, 'h686D, 'h5472, 'h2C73, 'h00D3, 'h012F,
	'h018B, 'h01E4, 'h0200, 'h1DE0, 'h45A0, 'h0000, 'h0000, 'h0000,
	'h7FFF, 'h7EAC, 'h7E31, 'h7DD6, 'h7DBC, 'h61BD, 'h361E, 'h167B,
	'h06D7, 'h0730, 'h1F4B, 'h3F49, 'h6709, 'h2529, 'h0000, 'h0000,
	'h7FFF, 'h7F98, 'h7F7B, 'h7F5D, 'h7F3F, 'h7B3F, 'h675F, 'h5B7F,
	'h53BD, 'h53DA, 'h5FF8, 'h6BD7, 'h7BD7, 'h5EF7, 'h0000, 'h0000
};

// PC-10 by FirebrandX
wire [15:0] pal_pc10_lut[64] = '{
	'h35AD, 'h4880, 'h6C00, 'h6D2D, 'h3412, 'h3416, 'h0096, 'h0132,
	'h012D, 'h0124, 'h11A0, 'h0240, 'h2520, 'h0000, 'h0000, 'h0000,
	'h5AD6, 'h6DA0, 'h7D20, 'h7C12, 'h7C16, 'h481F, 'h001F, 'h01BB,
	'h01B2, 'h0244, 'h0240, 'h36C0, 'h4A40, 'h1084, 'h0000, 'h0000,
	'h7FFF, 'h7ECD, 'h7E52, 'h7DBB, 'h7C1F, 'h7DBF, 'h025F, 'h02DF,
	'h037B, 'h036D, 'h03E0, 'h6FE9, 'h7FE0, 'h2529, 'h0000, 'h0000,
	'h7FFF, 'h7F76, 'h7EDB, 'h7EDF, 'h7E5F, 'h5ADF, 'h4B7F, 'h27FF,
	'h37FF, 'h27F6, 'h37F2, 'h6FE9, 'h7F72, 'h4A52, 'h0000, 'h0000
};

// PVM by FirebrandX
wire [15:0] pal_pvm_lut[64] = '{
	'h31AD, 'h3840, 'h4003, 'h3806, 'h280A, 'h080B, 'h006A, 'h0087,
	'h00C4, 'h00E0, 'h00E0, 'h0CE0, 'h24C0, 'h0000, 'h0000, 'h0000,
	'h5AF7, 'h5D42, 'h6CA9, 'h6C6C, 'h4C73, 'h2093, 'h00F4, 'h0151,
	'h01AC, 'h01E5, 'h0200, 'h21E0, 'h45E0, 'h0000, 'h0000, 'h0000,
	'h7FFF, 'h7EAD, 'h7E52, 'h7E36, 'h7DFD, 'h61FE, 'h2E3E, 'h12BC,
	'h033A, 'h0372, 'h1F8C, 'h3F88, 'h6F49, 'h2549, 'h0000, 'h0000,
	'h7FFF, 'h7FBA, 'h7F9C, 'h7F7D, 'h7F5E, 'h777F, 'h5F7F, 'h4FBF,
	'h47DE, 'h4BFA, 'h57F7, 'h67F5, 'h7BD9, 'h5F17, 'h0000, 'h0000
};

// Wavebeam by FirebrandX
wire [15:0] pal_wavebeam_lut[64] = '{
	'h35AD, 'h4460, 'h4C04, 'h4408, 'h300C, 'h0C0C, 'h002B, 'h0049,
	'h00C5, 'h0100, 'h0520, 'h0D00, 'h2CC0, 'h0000, 'h0000, 'h0000,
	'h5AD6, 'h6942, 'h74C8, 'h6C8E, 'h5C73, 'h3035, 'h00B5, 'h0131,
	'h01AC, 'h0204, 'h0220, 'h2200, 'h49C0, 'h0000, 'h0000, 'h0000,
	'h7FFF, 'h7ECC, 'h7E6F, 'h7DF8, 'h7DDD, 'h65DE, 'h363E, 'h169B,
	'h06F7, 'h0751, 'h1F6B, 'h4369, 'h6B29, 'h294A, 'h0000, 'h0000,
	'h7FFF, 'h7F77, 'h7F5A, 'h7F3C, 'h7F1D, 'h731F, 'h633F, 'h577E,
	'h539D, 'h53BA, 'h5BD7, 'h67D6, 'h7BB6, 'h5EF7, 'h0000, 'h0000
};

wire [14:0] pixel;

always @(posedge clk) begin
	case (palette)
		0: pixel = pal_smooth_lut[color][14:0];
		1: pixel = pal_unsat_lut[color][14:0];
		2: pixel = pal_fcelut[color][14:0];
		3: pixel = pal_nes_classic_lut[color][14:0];
		4: pixel = pal_composite_direct_lut[color][14:0];
		5: pixel = pal_pc10_lut[color][14:0];
		6: pixel = pal_pvm_lut[color][14:0];
		7: pixel = pal_wavebeam_lut[color][14:0];
		default:pixel = pal_smooth_lut[color][14:0];
	endcase
end


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
