// NES LPF Modual by Soltan_G42
module fds_lpf(
	input clk,
	input reset,
	input [15:0] in,
	output [15:0] out);


	wire [15:0] signedIn, middle, signedOut; 
	
	assign signedIn = {~in[15], in[14:0]}; //convert to signed
	
	dumb_resample resample96(clk,reset,signedIn, middle); //This is not the way to do this 
	
	lpf_2k lpf2k(clk,reset,middle,signedOut);  //This is our 2k lowpass filter
	
	assign out = {~signedOut[15], signedOut[14:0]}; //convert to unsigned
	
endmodule


module lpf_2k(
	input clk,
	input reset,
	input [15:0] in,
	output [15:0] out);

	wire signed [17:0] coeff[3:0];

	
	assign coeff[0]  =  18'sd1008;
	assign coeff[1]  =  18'sd1008;
	assign coeff[2]  =  18'sd14368;
	assign coeff[3]  =  18'sd0;

	iir_filter_div_1_mul #(.NUM_COEFFS(4),.COEFF_SCALE(14)) lpf2k(
		.clk(clk),
		.reset(reset),
		.div(224), //224 is the divider for ~96000khz on NES core. 
		.coeff(coeff),
		.in(in),
		.out(out));
	
endmodule //lpf_2k

module dumb_resample(
	input clk,
	input reset,
	input signed [15:0] in,
	output signed [15:0] out);
	
	reg signed [22:0] sample_sum;
	reg [9:0] count;
	
	
	always @ (posedge clk) begin
		if(reset) begin
			count <= 0;
			sample_sum <= 0;
		end
		else begin
			count <= count + 1'b1;
			if (count < 128) begin
				sample_sum <= sample_sum + in;
			end
			if (count == 224) begin
				sample_sum <= 0;
				count <= 0;
				out <= sample_sum[22:7];
			end
		end
	end
endmodule