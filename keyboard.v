

module keyboard
(
	input  clk,
	input  reset,

	input [10:0] ps2_key,

	output [7:0] joystick_0,
	output [7:0] joystick_1,
	
	output reg [11:0] powerpad	
);

reg joy_num;
reg [7:0] buttons;
assign joystick_0 = joy_num ? 7'b0 : buttons;
assign joystick_1 = joy_num ? buttons : 7'b0;

wire [7:0] code     = {ps2_key[7:0]};
wire       pressed  = ps2_key[9];
 
always @(posedge clk) begin
	reg old_stb;

	if(reset)begin
		joy_num  <= 0;
		buttons  <= 0;
		powerpad <= 0;
	end

	old_stb <= ps2_key[10];
	if(old_stb != ps2_key[10]) begin
		case(code)
			'h16: if(pressed) joy_num <= 0; // 1
			'h1E: if(pressed) joy_num <= 1; // 2

			'h75: buttons[4]   <= pressed;  // arrow up
			'h72: buttons[5]   <= pressed;  // arrow down
			'h6B: buttons[6]   <= pressed;  // arrow left
			'h74: buttons[7]   <= pressed;  // arrow right
			
			'h29: buttons[0]   <= pressed;  // Space
			'h11: buttons[1]   <= pressed;  // Alt
			'h0d: buttons[2]   <= pressed;  // Tab
			'h76: buttons[3]   <= pressed;  // Escape
			'h5A: buttons[3]   <= pressed;  // Enter
			
			'h24: powerpad[0]  <= pressed;  // E
			'h2D: powerpad[1]  <= pressed;  // R
			'h2C: powerpad[2]  <= pressed;  // T
			'h35: powerpad[3]  <= pressed;  // Y
			'h23: powerpad[4]  <= pressed;  // D
			'h2B: powerpad[5]  <= pressed;  // F
			'h34: powerpad[6]  <= pressed;  // G
			'h33: powerpad[7]  <= pressed;  // H
			'h21: powerpad[8]  <= pressed;  // C
			'h2A: powerpad[9]  <= pressed;  // V
			'h32: powerpad[10] <= pressed;  // B
			'h31: powerpad[11] <= pressed;  // N
		endcase
	end
end

endmodule
