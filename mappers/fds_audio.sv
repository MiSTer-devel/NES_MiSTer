// FDS Audio module by Kitrinx
// Based on the amazing research by Loopy from Jan, 2019

module fds_audio(
	input         clk,
	input         m2,
	input         reset,
	input         wr,
	input  [15:0] addr_in,
	input   [7:0] data_in,
	output  [7:0] data_out,
	output [11:0] audio_out
);

// Volume Envelope
reg  [5:0] vol_speed;
reg  [5:0] vol_gain;
reg  [5:0] vol_pwm_lat;
reg        vol_dir;
reg        vol_disable;

// Sweep Envelope
reg [5:0]  sweep_speed;
reg [5:0]  sweep_gain;
reg        sweep_dir;
reg        sweep_disable;

// Modulator
reg [11:0] mod_frequency;
reg [17:0] mod_accum;
reg        mod_step;
reg  [2:0] mod_table[0:31];
reg signed [6:0] mod_bias;
reg        mod_disable;

// Wave Table
reg        wave_wren;
reg [23:0] wave_accum;
reg  [5:0] wave_table[0:63];
reg  [5:0] wave_latch;
reg [11:0] wave_frequency;
reg        wave_disable; // high: Envelopes 4x faster and stops mod table accum.

// Timing
reg        env_disable;
reg  [7:0] env_speed = 8'hE8;
reg [11:0] vol_env_ticks, sweep_env_ticks;
reg  [6:0] vol_ticks, sweep_ticks;
reg  [1:0] master_vol;

// Master timer
reg [3:0] cycles;

(* keep = 1 *) wire signed [11:0] temp = mod_bias * $signed({1'b0, sweep_gain});

// Loopy's magical modulation math
(* keep = 1 *) wire signed [11:0] temp2 = $signed((|temp[3:0] & ~temp[11]) ? temp + 12'sh20 : temp);
(* keep = 1 *) wire signed [11:0] temp3 = temp2 + 12'sh400;
(* keep = 1 *) wire [19:0] wave_pitch = $unsigned(temp3) * wave_frequency;

// Rainwarrior's formula of doom
// wire signed [12:0] frequency_signed = wave_frequency;
// (* keep = 1 *) wire signed [8:0] temp2 = (|temp[3:0] & ~temp[11]) ? ((mod_bias < 0) ? temp[11:4] - 2'sd1 : temp[11:4] + 3'sd2) : temp[11:4];
// (* keep = 1 *) wire signed [19:0] temp3 = (temp2 >= 'd192 ? temp2 - 11'sd256 : temp2 < -11'sd64 : temp2 + 11'sd256 : temp2);
// (* keep = 1 *) wire signed [19:0] temp4 = temp3 * frequency_signed;
// (* keep = 1 *) wire [19:0] wave_pitch = temp4[5:0] >= 6'd32 ? (temp4 + 2'sd1) >> 5'sd2 : temp4 >> 4'sd2;

// Volume math
// Clamp volume at 32 and hold wave if write is enabled.
wire [10:0] mul_out = (~wave_wren ? wave_table[wave_accum[23:18]] : wave_latch) * (vol_pwm_lat[5] ? 6'd32 : vol_pwm_lat);

wire [11:0] level_out;
assign audio_out = level_out; // Make audio level right. FDS audio is aproximately 2.4x as loud as APU

always_comb begin
	case (master_vol)
		2'b00: level_out = mul_out;
		2'b01: level_out = {mul_out, 1'b0} / 2'd3;
		2'b10: level_out = mul_out[10:1];
		2'b11: level_out = {mul_out, 1'b0} / 3'd5;
		default: level_out = mul_out;
	endcase

	if (addr_in >= 'h4040 && addr_in < 'h4080) begin
		if (wave_wren)
			data_out = wave_table[addr_in[5:0]];
		else
			data_out = wave_table[wave_accum[23:18]];
	end else begin
		case (addr_in)
			'h4090: data_out = {2'b01, vol_gain};
			'h4091: data_out = wave_accum[19:12];
			'h4092: data_out = {2'b01, sweep_gain};
			'h4093: data_out = {1'b0, mod_accum[11:5]};
			'h4094: data_out = wave_pitch[11:4];
			'h4095: data_out = {cycles, 1'b0, mod_table[mod_accum[17:13]]}; // not right, but oh well
			'h4096: data_out = {2'b01, wave_table[wave_accum[23:18]]};
			'h4097: data_out = {1'b0, mod_bias};
			default: data_out = 8'hFF;
		endcase
	end
end

always_ff @(posedge clk) begin
reg old_m_accum, old_cycles, old_m2;

old_m2 <= m2;
if (reset) begin
	sweep_disable <= 1'b1;
	env_disable <= 1'b1;
	wave_disable <= 1'b1;
	mod_disable <= 1'b1;
	wave_accum <= 0;
	mod_accum <= 0;
	cycles <= 0;
end else if (~old_m2 & m2) begin
	//**** Timings ****//
	cycles <= wave_disable ? 4'h0 : cycles + 1'b1;

	if (~|cycles && ~wave_disable) begin
		wave_accum <= wave_accum + wave_pitch;
		if (~mod_disable)
			mod_accum <= mod_accum + mod_frequency;
	end

	//**** Envelopes ****//
	if (~env_disable && env_speed) begin

		//**** Volume Envelope ****//
		if ((vol_env_ticks >> 2'd3) == env_speed) begin
			vol_env_ticks <= 0;
			if (~vol_disable && vol_speed) begin
				if (vol_ticks == vol_speed) begin
					vol_ticks <= 0;
					if (vol_dir && ~vol_gain[5])
						vol_gain <= vol_gain + 1'b1;
					else if (~vol_dir && vol_gain)
						vol_gain <= vol_gain - 1'b1;
				end else
					vol_ticks <= vol_ticks + 1'b1;
			end
		end else
			vol_env_ticks <= vol_env_ticks + (~wave_disable ? 1'b1 : 4'd3);

		//**** Sweep Envelope ****//
		if ((sweep_env_ticks >> 2'd3) == env_speed) begin
			sweep_env_ticks <= 0;
			if (~sweep_disable && sweep_speed) begin
				if (sweep_ticks == sweep_speed) begin
					sweep_ticks <= 0;
					if (sweep_dir && ~sweep_gain[5])
						sweep_gain <= sweep_gain + 1'b1;
					else if (~sweep_dir && sweep_gain != 0)
						sweep_gain <= sweep_gain - 1'b1;
				end else
					sweep_ticks <= sweep_ticks + 1'b1;
			end

		end else
			sweep_env_ticks <= sweep_env_ticks + (~wave_disable ? 1'b1 : 4'd3);
	end

	//**** Modulation ****//
	old_m_accum <= mod_accum[12];
	if ((old_m_accum != mod_accum[12]) || mod_step) begin
		case (mod_table[mod_accum[17:13]])
			3'h0: mod_bias <= mod_bias;
			3'h1: mod_bias <= mod_bias + 4'sd1;
			3'h2: mod_bias <= mod_bias + 4'sd2;
			3'h3: mod_bias <= mod_bias + 4'sd4;
			3'h4: mod_bias <= 7'h0;
			3'h5: mod_bias <= mod_bias + -4'sd4;
			3'h6: mod_bias <= mod_bias + -4'sd2;
			3'h7: mod_bias <= mod_bias + -4'sd1;
		endcase
	end

	//**** Latches ****//
	if (~|wave_accum[23:18])
		vol_pwm_lat <= vol_gain;

	if (~wave_wren)
		wave_latch <= wave_table[wave_accum[23:18]];

	//**** Registers ****//
	if (wr) begin
		if (addr_in >= 'h4040 && addr_in < 'h4080) begin
			if (wave_wren)
				wave_table[addr_in[5:0]] <= data_in[5:0];
		end
		case (addr_in)
			16'h4080: begin
				{vol_disable, vol_dir, vol_speed} <= data_in;
				if (data_in[7]) vol_gain <= data_in[5:0];
				vol_ticks <= 0;
				vol_env_ticks <= 0;
			end

			16'h4082: wave_frequency[7:0] <= data_in;

			16'h4083: begin
				wave_frequency[11:8] <= data_in[3:0];
				wave_disable <= data_in[7];
				env_disable <= data_in[6];

				if (data_in[7])
					wave_accum <= 0;

				if (data_in[6]) begin // Reset envelopes
					vol_ticks <= 0;
					sweep_ticks <= 0;
					vol_env_ticks <= 0;
					sweep_env_ticks <= 0;
				end
			end

			16'h4084: begin
				{sweep_disable, sweep_dir, sweep_speed} <= data_in;
				if (data_in[7]) sweep_gain <= data_in[5:0];
				sweep_ticks <= 0;
				sweep_env_ticks <= 0;
			end

			16'h4085: mod_bias <= data_in[6:0];

			16'h4086: mod_frequency[7:0] <= data_in;

			16'h4087: begin
				mod_frequency[11:8] <= data_in[3:0];
				mod_disable <= data_in[7];
				mod_step <= data_in[6];

				if (data_in[7]) begin
					mod_accum[12:0] <= 0;
					old_m_accum <= 0;
				end
			end

			16'h4088: begin
				if (mod_disable) begin
					mod_table[mod_accum[17:13]] <= data_in[2:0];
					mod_accum[17:13] <= mod_accum[17:13] + 1'b1;
				end
			end

			16'h4089: begin
				wave_wren <= data_in[7];
				master_vol <= data_in[1:0];
			end

			16'h408A: begin
				env_speed <= data_in;
				vol_env_ticks <= 0; // Undocumented, but I believe this is right.
				sweep_env_ticks <= 0;
			end
		endcase
	end
end // if m2
end

endmodule
