// NES Game Genie handling by Kitrinx
// Apr 21, 2019

// Code layout:
// {clock bit, 4'b index, enable, compare enable, 15'b address, 8'b compare, 8'b replace}
//  37         36:33      32      31              30:16         15:8         7:0

localparam MAX_CODES = 32;

module geniecodes(
	input         clk,
	input         reset,
	input         enable,
	input  [15:0] addr_in,
	input   [7:0] data_in,
	input  [37:0] code,
	output        genie_ovr,
	output  [7:0] genie_data
);

reg [32:0] codes[MAX_CODES];

// If MAX_INDEX is changes, these need to be made larger
wire [4:0] index, dup_index;
reg [4:0] next_index;
wire found_dup;

assign index = found_dup ? dup_index : next_index;

// See if the code exists already, so it can be disabled if loaded again
always_comb begin
	int x;
	dup_index = 0;
	found_dup = 0;

	for (x = 0; x < MAX_CODES; x = x + 1'b1) begin
		if (codes[x][30:16] == code[30:16]) begin
			dup_index = x[4:0];
			found_dup = 1'b1;
		end
	end
end

always_ff @(posedge clk) begin
	int x;
	if (reset) begin
		next_index <= 0;
		for (x = 0; x < MAX_CODES; x = x + 1) codes[x] <= 33'd0;
	end else if (code[37]) begin
		// Disable the code if it's the exact same code loaded again, otherwise, 
		// replace it enabled if it has the same address, otherwise, add a new code
		codes[index] <= found_dup ? ((codes[index][15:0] == code[15:0]) ? {codes[index][32] ? 1'b0 : 1'b1, code[31:0]} : {1'b1, code[31:0]}) : {1'b1, code[31:0]};
		if (~found_dup) next_index <= next_index + 1'b1;
	end
end

always_comb begin
	int x;
	genie_ovr = 1'b0;
	genie_data = 8'd0;
	x = 0;

	if (enable) begin
		for (x = 0; x < MAX_CODES; x = x + 1'b1) begin
			if (codes[x][32] && {1'b1, codes[x][30:16]} == addr_in) begin
				if (codes[x][31]) begin        // Check for compare bit if needed
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