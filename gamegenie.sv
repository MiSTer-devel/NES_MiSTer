// NES Game Genie handling by Kitrinx
// Apr 21, 2019

// http://nesdev.com/archive.html
// According to nesdev, galoob has given permission to distribute the game genie rom.
// If this is in error, please contact us immediately and we will rectify the situation.

// Code layout:
// {clock bit, 4'b index, enable, compare enable, 15'b address, 8'b compare, 8'b replace}
//  37         36:33      32      31              30:16         15:8         7:0

// Note: this module was made to be replaced by a proper MiSTer menu someday, so it's broken
// into a module for handling the GG ROM (disposable) and one for evaluating codes that should
// be compatible with any future, better code entry system.

module gamegenie (
	input             clk,
	input             ce,
	input      [15:0] addr_in,
	input      [7:0]  data_in,
	input             write,
	input             enable,
	input             reset,
	output            reset_gg,
	input             extra_codes,
	output reg [37:0] code,
	input      [31:0] mapper_data_in,
	output     [31:0] mapper_data_out,
	output            hijack
);

assign hijack = |hijack_cnt;

wire [31:0] genie_mapper_data = 32'h0000_4000;

reg activate;
reg old_activate;
reg [3:0] code_count;
reg [1:0] sendcodes;
reg [32:0] code1, code2, code3;
reg [15:0] reset_cnt;
reg [1:0] hijack_cnt;

assign mapper_data_out = hijack ? genie_mapper_data : mapper_data_in;
assign reset_gg = (reset_cnt > 0);

always_ff @(posedge clk) begin
	old_activate <= activate;
	if (old_activate & ~activate) begin
		if (|hijack_cnt) hijack_cnt <= hijack_cnt - 1'b1;
		reset_cnt <= 16'd60000;
	end

	// Reset the system after gamegenie is done for maximum compatibility
	if (reset_cnt)
		reset_cnt <= reset_cnt - 1'b1;
	
	// Send the codes one at a time after the genie indicates it's getting ready to release the bus
	// The "active" signal will go from low to high to low when start is pressed, but the codes
	// are only valid while the flag is high, and the bus should be released when it goes low again.
	if (sendcodes > 0) begin
		sendcodes <= sendcodes - 1'b1;
		code_count <= code_count + 1'b1;
		case (sendcodes)
			3: code <= {1'b1, code_count, code1};
			2: code <= {1'b1, code_count, code2};
			1: code <= {1'b1, code_count, code3};
		endcase
	end else
		code <= 37'd0;

	if (reset) begin // Note: this should only happen on COLD boot
		hijack_cnt <= enable ? (extra_codes ? 2'd3 : 2'd1) : 2'd0;
		activate <= 1'b0;
		code_count <= 0;
		{code1, code2, code3} <= 0;
	end else if (ce) begin

		if (write & hijack) begin
			case (addr_in)
				// Master reg
				'h8000: begin
					{code3[32],code2[32],code1[32],code1[31],code2[31],code3[31],activate} <= {~data_in[6:4], data_in[3:0]};
					if (data_in[0]) // The codes are only in a valid state while this bit is high
						sendcodes <= 2'd3;
				end
				
				// Address High
				'h8001: code1[30:24] <= data_in[6:0]; 
				'h8005: code2[30:24] <= data_in[6:0];
				'h8009: code3[30:24] <= data_in[6:0];
				
				// Address Low
				'h8002: code1[23:16] <= data_in[7:0];
				'h8006: code2[23:16] <= data_in[7:0];
				'h800A: code3[23:16] <= data_in[7:0];
				
				// Compare
				'h8003: code1[15:8] <= data_in[7:0];
				'h8007: code2[15:8] <= data_in[7:0];
				'h800B: code3[15:8] <= data_in[7:0];
				
				// Replace
				'h8004: code1[7:0] <= data_in[7:0];
				'h8008: code2[7:0] <= data_in[7:0];
				'h800C: code3[7:0] <= data_in[7:0];
			endcase
		end
	end
end

endmodule

module geniecodes(
	input         clk,
	input         reset,
	input         enable,
	input         extra_codes,
	input  [15:0] addr_in,
	input   [7:0] data_in,
	input  [37:0] code,
	output        genie_ovr,
	output  [7:0] genie_data
);

// The size of this may need adjustment if the code input method changes
reg [32:0] codes[9];

always_ff @(posedge clk) begin
	if (reset) begin
		codes <= '{33'd0, 33'd0, 33'd0, 33'd0, 33'd0, 33'd0, 33'd0, 33'd0, 33'd0};
	end else if (code[37])
		codes[code[36:33]] <= code[32:0];
end

wire [3:0] x;

wire [3:0] max_code = (extra_codes ? 4'd9 : 4'd3);

always_comb begin
	genie_ovr = 1'b0;
	genie_data = 8'd0;
	x = 0;

	if (enable) begin
		for (x = 0; x < 9; x = x + 1'b1) begin
			if (codes[x][32] && {1'b1, codes[x][30:16]} == addr_in && x < max_code) begin
				if (codes[x][31] || |codes[x][15:8]) begin        // Check for compare bit if needed
					if (codes[x][15:8] == data_in) begin
						genie_ovr = 1'b1;
						genie_data = codes[x][7:0];
					end
				end else begin                 // Otherwise just match
					genie_ovr = 1'b1;
					genie_data = codes[x][7:0];
				end
			end
		end
	end
end


endmodule