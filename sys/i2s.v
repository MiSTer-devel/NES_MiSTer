
module i2s
(
	input      reset,
	input      clk_sys,

	output reg sclk,
	output reg lrclk,
	output reg sdata,

	input                signed_sample,
	input [AUDIO_DW-1:0]	left_chan,
	input [AUDIO_DW-1:0]	right_chan
);

localparam AUDIO_DW = 16;

reg bit_en;
always @(negedge clk_sys) begin
	reg [5:0] div;
	
	div <= div + 1'd1;
	if(div == 23) div <= 0;
	
	bit_en <= !div;
end

always @(posedge clk_sys) begin
	reg [AUDIO_DW-1:0] bit_cnt;
	reg [AUDIO_DW-1:0] left;
	reg [AUDIO_DW-1:0] right;
	reg                msclk;

	sclk <= msclk;

	if(reset) begin
		bit_cnt <= 1;
		lrclk   <= 1;
		sclk    <= 1;
		msclk   <= 1;
	end
	else begin
		if(bit_en) begin
			msclk <= ~msclk;
			if(msclk) begin
				if(bit_cnt >= AUDIO_DW) begin
					bit_cnt <= 1;
					lrclk <= ~lrclk;
					if(lrclk) begin
						left  <= left_chan;
						right <= right_chan;
					end
				end
				else begin
					bit_cnt <= bit_cnt + 1'd1;
				end
				sdata <= lrclk ? right[AUDIO_DW - bit_cnt] : left[AUDIO_DW - bit_cnt];
			end
		end
	end
end

endmodule
