// NES Mouse-To-Zapper emulation, by Kitrinx
// Apr, 20 2019

module zapper (
	input        clk,
	input        reset,
	input [24:0] ps2_mouse,
	input [15:0] analog,
	input        analog_trigger,
	input        mode,
	input        trigger_mode,
	input  [8:0] cycle,
	input  [8:0] scanline,
	input  [5:0] color,
	output reg  [1:0] reticle,
	output       light,
	output       trigger
);

assign light = ~light_state;
assign trigger = trigger_state;

// Mouse control byte
// {Y overflow, X overflow Y sign bit, X sign bit, 1'b1, Middle Btn, Right Btn, Left Btn}
// 15-8 is x coordinate, 23:16 is y coordinate, in 2's complement.
// Bit 24 is high on a new packet.

wire signed [8:0] mouse_x = {ps2_mouse[4], ps2_mouse[15:8]};
wire signed [8:0] mouse_y = {ps2_mouse[5], ps2_mouse[23:16]};
wire mouse_msg = ps2_mouse[24];
wire mouse_button = ps2_mouse[0];
wire light_state = light_cnt > 0;

wire signed [9:0] x_diff = pos_x + mouse_x;
wire signed [9:0] y_diff = pos_y - mouse_y;

reg [8:0] light_cnt; // timer for 10-25 scanlines worth of "light" activity.
reg signed [9:0] pos_x, pos_y;
wire trigger_state = (trigger_cnt > 'd2_100_000);
reg old_msg;
reg [8:0] old_scanline;
reg pressed;

int trigger_cnt;

wire hit_x = ((pos_x >= cycle - 1'b1 && pos_x <= cycle + 1'b1) && scanline == pos_y);
wire hit_y = ((pos_y >= scanline - 1'b1 && pos_y <= scanline + 1'b1) && cycle == pos_x);

wire is_offscreen = ((pos_x >= 254 || pos_x <= 1) || (pos_y >= 224 || pos_y <= 8));
wire light_square = ((pos_x >= cycle - 3'd4 && pos_x <= cycle + 3'd4) && (pos_y >= scanline - 3'd4 && pos_y <= scanline + 3'd4));

// Jump through a few hoops to deal with signed math
wire signed [7:0] joy_x = analog[7:0];
wire signed [7:0] joy_y = analog[15:8];
wire [7:0] joy_x_a = joy_x + 8'd128;
wire [7:0] joy_y_a = joy_y + 8'd128;

always @(posedge clk) begin
if (reset) begin
	{trigger_cnt, pos_x, pos_y, light_cnt} <= 0;
	reticle <= 0;
end else begin
	old_scanline <= scanline;
	old_msg <= mouse_msg;

	if (trigger_cnt > 0)
		trigger_cnt <= trigger_cnt - 1'b1;

	// "Drain" the light from the zapper over time
	if (old_scanline != scanline && light_cnt > 0)
		light_cnt <= light_cnt - 1'b1;

	// Register the mouse click regardless of mode to make it easier to map
	// special lightgun hardware
	if (~old_msg & mouse_msg & ~trigger_mode) begin
		if (trigger_cnt == 0 && mouse_button && ~pressed) begin
			trigger_cnt <= 'd830000 + 'd2_100_000;
			pressed <= 1'b1;
		end

		if (~mouse_button)
			pressed <= 0;
	end

	// Update mouse coordinates if needed
	if (~old_msg & mouse_msg & ~mode) begin
		if (x_diff <= 0)
			pos_x <= 0;
		else if (x_diff >= 255)
			pos_x <= 10'd255;
		else
			pos_x <= x_diff;

		if (y_diff <= 0)
			pos_y <= 0;
		else if (y_diff >= 255)
			pos_y <= 10'd255;
		else
			pos_y <= y_diff;
	end

	// Check for the mapped trigger button regardless of mode
	if (trigger_mode) begin
		if (trigger_cnt == 0 && analog_trigger && ~pressed) begin
			trigger_cnt <= 'd830000 + 'd2_100_000;
			pressed <= 1'b1;
		end

		if (~analog_trigger)
			pressed <= 0;
	end

	// Update X/Y based on analog stick if in joystick mode
	if (mode) begin
		pos_x <= joy_x_a;
		pos_y <= y_axis_lut[joy_y_a];
	end

	if (hit_x || hit_y)
		reticle[0] <= 1'b1;
	else
		reticle[0] <= 1'b0;
	
	reticle[1] <= is_offscreen;
	
	// See if we're "pointed" at light
	if (light_square && ~is_offscreen) begin
		if (color == 'h20 || color == 'h30)
			light_cnt <= 'd26;
		else if ((color[5:4] == 3 && color < 'h3E) || color == 'h10)
			if (light_cnt < 'd20) light_cnt <= 'd20;
		else if ((color[5:4] == 2 && color < 'h2E) || color == 'h00)
			if (light_cnt < 'd17) light_cnt <= 'd17;
	end
end
end

wire [7:0] y_axis_lut[256] = '{
	8'd0,   8'd0,   8'd1,   8'd2,   8'd3,   8'd4,   8'd5,   8'd6,
	8'd7,   8'd8,   8'd9,   8'd10,  8'd11,  8'd12,  8'd13,  8'd14,
	8'd15,  8'd16,  8'd16,  8'd17,  8'd18,  8'd19,  8'd20,  8'd21,
	8'd22,  8'd23,  8'd24,  8'd25,  8'd26,  8'd27,  8'd28,  8'd29,
	8'd30,  8'd31,  8'd32,  8'd32,  8'd33,  8'd34,  8'd35,  8'd36,
	8'd37,  8'd38,  8'd39,  8'd40,  8'd41,  8'd42,  8'd43,  8'd44,
	8'd45,  8'd46,  8'd47,  8'd48,  8'd48,  8'd49,  8'd50,  8'd51,
	8'd52,  8'd53,  8'd54,  8'd55,  8'd56,  8'd57,  8'd58,  8'd59,
	8'd60,  8'd61,  8'd62,  8'd63,  8'd64,  8'd64,  8'd65,  8'd66,
	8'd67,  8'd68,  8'd69,  8'd70,  8'd71,  8'd72,  8'd73,  8'd74,
	8'd75,  8'd76,  8'd77,  8'd78,  8'd79,  8'd80,  8'd80,  8'd81,
	8'd82,  8'd83,  8'd84,  8'd85,  8'd86,  8'd87,  8'd88,  8'd89,
	8'd90,  8'd91,  8'd92,  8'd93,  8'd94,  8'd95,  8'd96,  8'd96,
	8'd97,  8'd98,  8'd99,  8'd100, 8'd101, 8'd102, 8'd103, 8'd104,
	8'd105, 8'd106, 8'd107, 8'd108, 8'd109, 8'd110, 8'd111, 8'd112,
	8'd112, 8'd113, 8'd114, 8'd115, 8'd116, 8'd117, 8'd118, 8'd119,
	8'd120, 8'd121, 8'd122, 8'd123, 8'd124, 8'd125, 8'd126, 8'd127,
	8'd128, 8'd128, 8'd129, 8'd130, 8'd131, 8'd132, 8'd133, 8'd134,
	8'd135, 8'd136, 8'd137, 8'd138, 8'd139, 8'd140, 8'd141, 8'd142,
	8'd143, 8'd144, 8'd144, 8'd145, 8'd146, 8'd147, 8'd148, 8'd149,
	8'd150, 8'd151, 8'd152, 8'd153, 8'd154, 8'd155, 8'd156, 8'd157,
	8'd158, 8'd159, 8'd160, 8'd160, 8'd161, 8'd162, 8'd163, 8'd164,
	8'd165, 8'd166, 8'd167, 8'd168, 8'd169, 8'd170, 8'd171, 8'd172,
	8'd173, 8'd174, 8'd175, 8'd176, 8'd176, 8'd177, 8'd178, 8'd179,
	8'd180, 8'd181, 8'd182, 8'd183, 8'd184, 8'd185, 8'd186, 8'd187,
	8'd188, 8'd189, 8'd190, 8'd191, 8'd192, 8'd192, 8'd193, 8'd194,
	8'd195, 8'd196, 8'd197, 8'd198, 8'd199, 8'd200, 8'd201, 8'd202,
	8'd203, 8'd204, 8'd205, 8'd206, 8'd207, 8'd208, 8'd208, 8'd209,
	8'd210, 8'd211, 8'd212, 8'd213, 8'd214, 8'd215, 8'd216, 8'd217,
	8'd218, 8'd219, 8'd220, 8'd221, 8'd222, 8'd223, 8'd224, 8'd224,
	8'd225, 8'd226, 8'd227, 8'd228, 8'd229, 8'd230, 8'd231, 8'd232,
	8'd233, 8'd234, 8'd235, 8'd236, 8'd237, 8'd238, 8'd239, 8'd240
};

endmodule

