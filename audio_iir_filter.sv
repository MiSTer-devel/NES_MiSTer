/*MIT License

Copyright (c) 2019 Gregory Hogan (Soltan_G42)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/

module iir_1st_order
#(
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 15,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	input reset,
	input [COUNT_BITS - 1 : 0] div,
	input signed [COEFF_WIDTH - 1 : 0] A2, B1, B2,
	input signed [DATA_WIDTH - 1 :0] in,
	output [DATA_WIDTH - 1:0] out
);

	reg signed [DATA_WIDTH-1:0] x0,x1,y0;
	reg signed [DATA_WIDTH + COEFF_WIDTH - 1 : 0] out32;
	reg [COUNT_BITS - 1:0] count;
 
 // Usage:
 // Design your 1st order iir low/high-pass with a tool that will give you the
 // filter coefficients for the difference equation.  Filter coefficients can
 // be generated in Octave/matlab/scipy using a command similar to
 // [B, A] = butter( 1, 3500/(106528/2), 'low') for a 3500 hz 1st order low-pass
 // assuming 106528Hz sample rate.
 // 
 // The Matlab output is:
 // B = [0.093863   0.093863]
 // A = [1.00000  -0.81227]
 //
 // Then scale coefficients by multiplying by 2^COEFF_SCALE and round to nearest integer
 //
 // B = [3076   3076]
 // A = [32768 -26616]
 //
 // Discard A(1) because it is assumed 1.0 before scaling
 //
 // This leaves you with A2 = -26616 , B1 = 3076 , B2 = 3076
 // B1 + B2 - A2  should sum to 2^COEFF_SCALE = 32768
 //
 // Sample frequency is "clk rate/div": for Genesis this is 53.69mhz/504 = 106528hz
 //
 // COEFF_WIDTH must be at least COEFF_SCALE+1 and must be large enough to
 // handle temporary overflow during this computation: out32 <= (B1*x0 + B2*x1) - A2*y0
 
	assign out = y0;
 
	always @ (*) begin
		out32 <= (B1*x0 + B2*x1) - A2*y0; //Previous output is y0 not y1
	end
	
	always @ (posedge clk) begin
		if(reset) begin
			count <= 0;
			x0 <= 0;
			x1 <= 0;
			y0 <= 0;
		end
		else begin
			count <= count + 1;
			if (count == div - 1) begin
					count <= 0;
					y0 <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[COEFF_SCALE + DATA_WIDTH - 2 : COEFF_SCALE]};
					x1 <= x0;
					x0 <= in;
			end
		end
	end
	
endmodule //iir_1st_order

module iir_2nd_order
#(
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 14,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	input reset,
	input [COUNT_BITS - 1 : 0] div,
	input signed [COEFF_WIDTH - 1 : 0] A2, A3, B1, B2, B3,
	input signed [DATA_WIDTH - 1 : 0] in,
	output [DATA_WIDTH - 1 : 0] out
);

	reg signed [DATA_WIDTH-1 : 0] x0,x1,x2;
	reg signed [DATA_WIDTH-1 : 0] y0,y1;
	reg signed [(DATA_WIDTH + COEFF_WIDTH - 1) : 0] out32;
	reg [COUNT_BITS : 0] count;
 
 
 // Usage:
 // Design your 1st order iir low/high-pass with a tool that will give you the
 // filter coefficients for the difference equation.  Filter coefficients can
 // be generated in Octave/matlab/scipy using a command similar to
 // [B, A] = butter( 2, 5000/(48000/2), 'low') for a 5000 hz 2nd order low-pass
 // assuming 48000Hz sample rate.
 // 
 // Output is:
 // B = [ 0.072231   0.144462   0.072231]
 // A = [1.00000  -1.10923   0.39815]
 //
 // Then scale coefficients by multiplying by 2^COEFF_SCALE and round to nearest integer
 // Make sure your coefficients can be stored as a signed number with COEFF_WIDTH bits.
 //
 // B = [1183   2367   1183]
 // A = [16384  -18174    6523]
 //
 // Discard A(1) because it is assumed 1.0 before scaling
 //
 // This leaves you with A2 = -18174 , A3 = 6523, B1 = 1183 , B2 = 2367 , B3 = 1183
 // B1 + B2 + B3 - A2 - A3 should sum to 2^COEFF_SCALE = 16384
 //
 // Sample frequency is "clk rate/div" 
 //
 // COEFF_WIDTH must be at least COEFF_SCALE+1 and must be large enough to
 // handle temporary overflow during this computation: 
 // out32 <= (B1*x0 + B2*x1 + B3*x2) - (A2*y0 + A3*y1);
 
	assign out = y0;
 
	always @ (*) begin
		out32 <= (B1*x0 + B2*x1 + B3*x2) - (A2*y0 + A3*y1); //Previous output is y0 not y1
	end
	
	always @ (posedge clk) begin
		if(reset) begin
			count <=  0;
			x0 <= 0;
			x1 <= 0;
			x2 <= 0;
			y0 <= 0;
			y1 <= 0; 
		end
		else begin
			count <= count + 1;
			if (count == div - 1) begin
					count <= 0;
					y1 <= y0;
					y0 <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
					x2 <= x1;
					x1 <= x0;
					x0 <= in;
			end
		end
	end
	
endmodule //iir_2nd_order


module iir_2nd_order_div
#(
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 14,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	//input cen,
	input reset,
	input [COUNT_BITS - 1 : 0] div,
	input signed [COEFF_WIDTH - 1 : 0] A2, A3, B1, B2, B3,
	input signed [DATA_WIDTH - 1 : 0] in,
	output [DATA_WIDTH - 1 : 0] out
);

	//reg signed [DATA_WIDTH-1 : 0] x0,x1,x2;
	reg signed [DATA_WIDTH-1 : 0] data_x [2:0];
	//reg signed [DATA_WIDTH-1 : 0] y0,y1;
	reg signed [DATA_WIDTH-1 : 0] data_y [2:0];
	reg signed [(DATA_WIDTH + COEFF_WIDTH - 1) : 0] out32;
	reg [COUNT_BITS : 0] count;
	reg signed [COEFF_WIDTH - 1 : 0] coeff_B[2:0];
	reg signed [COEFF_WIDTH - 1 : 0] coeff_A[2:0];
 
	assign out = data_y[0];
 
	//always @ (*) begin
	//	out32 <= (B1*x0 + B2*x1 + B3*x2) - (A2*y0 + A3*y1); //Previous output is y0 not y1
	//end
	
	always @(*) begin
		coeff_B [0] <= B1;
		coeff_B [1] <= B2;
		coeff_B [2] <= B3;
		coeff_A [0] <= A2;
		coeff_A [1] <= A3;
		coeff_A [2] <=  0;

	end
	
	always @ (posedge clk) begin
	
		if(reset) begin
			count <=  0;
			data_x[0] <= 0;
			data_x[1] <= 0;
			data_x[2] <= 0;
			data_y[0] <= 0;
			data_y[1] <= 0; 
			data_y[2] <= 0; 

		end
		else begin
			count <= count + 1;
			if (count == div - 1) begin
					out32 <= 0;
					count <= 0;
					data_y[1] <= data_y[0];
					data_y[0] <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
					data_x[2] <= data_x[1];
					data_x[1] <= data_x[0];
					data_x[0] <= in;
			end
			if ( count < 3 ) begin
				out32 <= out32 + data_x[count]*coeff_B[count] - data_y[count]*coeff_A[count];
				//out_ready <= 1;
			end
		end
	end
	
endmodule //iir_2nd_order_div


module iir_filter_div_2_mul
#(
	parameter NUM_COEFFS  =  3,
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 14,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	input reset,
	input [COUNT_BITS - 1 : 0] div,
	input signed [COEFF_WIDTH - 1 : 0] coeff_b[NUM_COEFFS - 1 : 0],
	input signed [COEFF_WIDTH - 1 : 0] coeff_a[NUM_COEFFS - 1 : 0],
	input signed [DATA_WIDTH - 1 : 0] in,
	output [DATA_WIDTH - 1 : 0] out
);

	reg signed [DATA_WIDTH-1 : 0] data_x [NUM_COEFFS - 1 : 0];
	reg signed [DATA_WIDTH-1 : 0] data_y [NUM_COEFFS - 1 : 0];
	reg signed [(DATA_WIDTH + COEFF_WIDTH - 1) : 0] out32;
	reg [COUNT_BITS : 0] count;
 
	assign out = data_y[0];
	
	always @ (posedge clk) begin
		if(reset) begin
			count <=  0;
			data_x[0] <= 0;
			data_x[1] <= 0;
			data_x[2] <= 0;
			data_y[0] <= 0;
			data_y[1] <= 0; 
			data_y[2] <= 0; 

		end
		else begin
			count <= count + 1;
			if (count == div - 1) begin
				out32 <= 0;
				count <= 0;
			end
			if ( count < NUM_COEFFS ) begin
				out32 <= out32 + data_x[count]*coeff_b[count] - data_y[count]*coeff_a[count];
			end
			if (count == NUM_COEFFS ) begin
				data_y[0] <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
				data_y[1] <= data_y[0];
				data_x[2] <= data_x[1];
				data_x[1] <= data_x[0];
				data_x[0] <= in;
			end
		end
	end
	
endmodule //iir_filter_div_2_mul

module iir_filter_div_1_mul
#(
	parameter NUM_COEFFS  =  6,
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 14,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	input reset,
	input [COUNT_BITS - 1 : 0] div,
	input signed [COEFF_WIDTH - 1 : 0] coeff[NUM_COEFFS - 1 : 0],
	input signed [DATA_WIDTH - 1 : 0] in,
	output signed [DATA_WIDTH - 1 : 0] out
);

	reg signed [DATA_WIDTH-1 : 0] data [NUM_COEFFS - 1 : 0];
	reg signed [(DATA_WIDTH + COEFF_WIDTH - 1) : 0] out32;
	reg [COUNT_BITS : 0] count;
 
	assign out = data[NUM_COEFFS/2];
	
	
	always @ (posedge clk) begin
		if(reset) begin
			count <=  0;
			for (integer i = 0; i < NUM_COEFFS; i = i + 1) begin: reset_coeffs
				data[i] <= 0;
			end
		end
		else begin
			count <= count + 1'b1;
			if (count == div - 1) begin
				out32 <= 0;
				count <= 0;
			end
			if ( count < NUM_COEFFS ) begin
				out32 <= out32 + data[count]*coeff[count];
			end
			if (count == NUM_COEFFS ) begin
				//data_y[0] <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
				//data_y[1] <= data_y[0];
				//data[2] <= data[1];
				//data[1] <= data[0];
				data[0] <= in;
				for (integer i = 1; i < NUM_COEFFS/2; i = i + 1) begin: update_inputs
					data[i] <= data[i-1];
				end
				data[NUM_COEFFS/2] <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
				for (integer i = NUM_COEFFS/2 + 1; i < NUM_COEFFS; i = i + 1) begin: update_outputs
					data[i] <= data[i-1];
				end
			end
		end
	end
	
endmodule //iir_filter_div_1_mul



module iir_filter_cen //Uses one multiplier
#(
	parameter NUM_COEFFS  =  6,
	parameter COEFF_WIDTH = 18,
	parameter COEFF_SCALE = 14,
	parameter DATA_WIDTH  = 16,
	parameter COUNT_BITS  = 10
)
(
	input clk,
	input reset,
	input cen,
	input signed [COEFF_WIDTH - 1 : 0] coeff[NUM_COEFFS - 1 : 0],
	input signed [DATA_WIDTH - 1 : 0] in,
	output [DATA_WIDTH - 1 : 0] out
);

	reg signed [DATA_WIDTH-1 : 0] data [NUM_COEFFS - 1 : 0];
	reg signed [(DATA_WIDTH + COEFF_WIDTH - 1) : 0] out32;
	reg [COUNT_BITS : 0] count;
 
	assign out = data[NUM_COEFFS/2];
	
	always @ (posedge clk) begin
		if(reset) begin
			count <=  0;
			for (integer i = 0; i < NUM_COEFFS; i = i + 1) begin: reset_coeffs
				data[i] <= 0;
			end
		end
		else begin
			if (cen) begin
				out32 <= 0;
				count <= 0;
			end
			else begin
				count <= count + 1;
				if ( count < NUM_COEFFS ) begin
					out32 <= out32 + data[count]*coeff[count];
				end	
				if (count == NUM_COEFFS ) begin
					data[0] <= in;
					for (integer i = 1; i < NUM_COEFFS/2; i = i + 1) begin: update_inputs
						data[i] <= data[i-1];
					end
					data[NUM_COEFFS/2] <= {out32[DATA_WIDTH + COEFF_WIDTH - 1] , out32[(DATA_WIDTH + COEFF_SCALE - 2) : COEFF_SCALE]};
					for (integer i = NUM_COEFFS/2 + 1; i < NUM_COEFFS; i = i + 1) begin: update_outputs
						data[i] <= data[i-1];
					end
				end
			end
		end
	end
endmodule //iir_filter_cen