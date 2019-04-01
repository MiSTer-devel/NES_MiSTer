// 69 - Sunsoft FME-7
module Mapper69(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, 0, prg_conflict, prg_open_bus, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
reg vram_a10;
wire vram_ce;
reg irq;
reg [15:0] flags_out = 0;
wire [15:0] audio;

reg [7:0] chr_bank[0:7];
reg [4:0] prg_bank[0:3];
reg [1:0] mirroring;
reg irq_countdown, irq_trigger;
reg [15:0] irq_counter;
reg [3:0] addr;
reg ram_enable, ram_select;
wire [16:0] new_irq_counter = irq_counter - {15'b0, irq_countdown};

always @(posedge clk)
if (~enable) begin
	chr_bank[0] <= 0;
	chr_bank[1] <= 0;
	chr_bank[2] <= 0;
	chr_bank[3] <= 0;
	chr_bank[4] <= 0;
	chr_bank[5] <= 0;
	chr_bank[6] <= 0;
	chr_bank[7] <= 0;
	prg_bank[0] <= 0;
	prg_bank[1] <= 0;
	prg_bank[2] <= 0;
	prg_bank[3] <= 0;
	mirroring <= 0;
	irq_countdown <= 0;
	irq_trigger <= 0;
	irq_counter <= 0;
	addr <= 0;
	ram_enable <= 0;
	ram_select <= 0;
	irq <= 0;
end else if (ce) begin
	irq_counter <= new_irq_counter[15:0];
	if (irq_trigger && new_irq_counter[16]) irq <= 1;
	if (!irq_trigger) irq <= 0;

	if (prg_ain[15] & prg_write) begin
		case (prg_ain[14:13])
			0: addr <= prg_din[3:0];
			1: begin
				case(addr)
					0,1,2,3,4,5,6,7: chr_bank[addr[2:0]] <= prg_din;
					8,9,10,11:       prg_bank[addr[1:0]] <= prg_din[4:0];
					12:              mirroring <= prg_din[1:0];
					13:              {irq_countdown, irq_trigger} <= {prg_din[7], prg_din[0]};
					14:              irq_counter[7:0] <= prg_din;
					15:              irq_counter[15:8] <= prg_din;
				endcase

				if (addr == 8) {ram_enable, ram_select} <= prg_din[7:6];
			end
		endcase
	end
end

always begin
	casez(mirroring[1:0])
		2'b00: vram_a10 = {chr_ain[10]};    // vertical
		2'b01: vram_a10 = {chr_ain[11]};    // horizontal
		2'b1?: vram_a10 = {mirroring[0]};   // 1 screen lower
	endcase
end

reg [4:0] prgout;
reg [7:0] chrout;

always begin
	casez(prg_ain[15:13])
		3'b011: prgout = prg_bank[0];
		3'b100: prgout = prg_bank[1];
		3'b101: prgout = prg_bank[2];
		3'b110: prgout = prg_bank[3];
		3'b111: prgout = 5'b11111;
		default: prgout = 5'bxxxxx;
	endcase

	chrout = chr_bank[chr_ain[12:10]];
end

wire ram_cs = (prg_ain[15] == 0 && ram_select);
assign prg_aout = {1'b0, ram_cs, 2'b00, prgout[4:0], prg_ain[12:0]};
assign prg_allow = ram_cs ? ram_enable : !prg_write;
assign chr_allow = flags[15];
assign chr_aout = {4'b10_00, chrout, chr_ain[9:0]};
assign vram_ce = chr_ain[13];

//Taken from Loopy's Power Pak mapper source
//audio
	wire [6:0] fme7_out;
	wire [15:0] fme7_sample;
	FME7_sound snd0(clk, ce, ~enable, prg_write, prg_ain, prg_din, fme7_out);
	//FME7_sound snd0(m2, reset, nesprg_we, prgain, nesprgdin, fme7_out);
	//pdm #(7) pdm_mod(clk20, fme7_out, exp6);

//Need a better lookup table for this
//This is just the NES APU lookup table, which is designed for 2 4-bit square waves, not 3
ApuLookupTable lookup(clk,
	{4'b0, fme7_out[5:1]}, //fme7_out range: 0-2D
	{8'b0},                //No triange, noise or DMC
	fme7_sample);
assign audio = {fme7_sample[14:0], 1'b0};    // Double.  Volume will be slightly higher, rather than slightly lower than expected

endmodule

//Taken from Loopy's Power Pak mapper source map45.v
module FME7_sound(
	input clk,
	input ce,
	input reset,
	input wr,
	input [15:0] ain,
	input [7:0] din,
	output [6:0] out
);
	reg [3:0] regC;
	reg [11:0] freq0,freq1,freq2;
	reg [2:0] en;
	reg [3:0] vol0,vol1,vol2;
	reg [11:0] count0,count1,count2;
	reg [4:0] duty0,duty1,duty2;

	always@(posedge clk) begin
		if(reset) begin
			en <= 0;
		end else if (ce) begin
			if(wr) begin
				if(ain[15:13]==3'b110)  //C000
					regC<=din[3:0];
				if(ain[15:13]==3'b111)  //E000
				case(regC)
					0:freq0[7:0]<=din;
					1:freq0[11:8]<=din[3:0];
					2:freq1[7:0]<=din;
					3:freq1[11:8]<=din[3:0];
					4:freq2[7:0]<=din;
					5:freq2[11:8]<=din[3:0];
					7:en<=din[2:0];
					8:vol0<=din[3:0];
					9:vol1<=din[3:0];
					10:vol2<=din[3:0];
				endcase
			end
			if(count0==freq0) begin
				count0<=0;
				duty0<=duty0+1'd1;
			end else
				count0<=count0+1'd1;

			if(count1==freq1) begin
				count1<=0;
				duty1<=duty1+1'd1;
			end else
				count1<=count1+1'd1;
			if(count2==freq2) begin
				count2<=0;
				duty2<=duty2+1'd1;
			end else
				count2<=count2+1'd1;
		end
	end

	wire [3:0] ch0={4{~en[0] & duty0[4]}} & vol0;
	wire [3:0] ch1={4{~en[1] & duty1[4]}} & vol1;
	wire [3:0] ch2={4{~en[2] & duty2[4]}} & vol2;
	assign out=ch0+ch1+ch2;

endmodule


// Mapper 190, Magic Kid GooGoo
// Mapper 67, Sunsoft-3
module Mapper67 (
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, 0, prg_conflict, prg_open_bus, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? irq : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio_in : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
wire irq;
reg [15:0] flags_out = 0;

reg [7:0] prg_bank_0;
reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3;
reg [1:0] mirroring;
reg irq_ack;
reg irq_enable;
reg irq_low;
reg [15:0] irq_counter;
wire mapper190 = (flags[7:0] == 190);

always @(posedge clk)
if (~enable) begin
	prg_bank_0 <= 0;
	chr_bank_0 <= 0;
	chr_bank_1 <= 0;
	chr_bank_2 <= 0;
	chr_bank_3 <= 0;
	mirroring <= 2'b00; //vertical for mapper190
	irq_counter <= 0;
	irq_enable <= 0;
	irq_low <= 0;
end else if (ce) begin
	irq_ack <= 1'b0;
	if ((prg_write) && (prg_ain[15])) begin// Cover all from $8000 to $FFFF to maximize compatibility
		if (!mapper190)
			casez({prg_ain[14:11],irq_low})
				5'b000_1_?: chr_bank_0 <= prg_din;
				5'b001_1_?: chr_bank_1 <= prg_din;
				5'b010_1_?: chr_bank_2 <= prg_din;
				5'b011_1_?: chr_bank_3 <= prg_din;
				5'b110_1_?: mirroring <= prg_din[1:0];
				5'b111_1_?: prg_bank_0 <= prg_din;
				5'b100_1_0: {irq_low, irq_counter[15:8]} <= {1'b1,prg_din};
				5'b100_1_1: {irq_low, irq_counter[7:0]} <= {1'b0,prg_din};
				5'b101_1_?: {irq_low, irq_ack, irq_enable} <= {2'b01, prg_din[4]};
			endcase
		else
			casez({prg_ain[13],prg_ain[1:0]})
				3'b0_??: prg_bank_0[3:0] <= {prg_ain[14],prg_din[2:0]};
				3'b1_00: chr_bank_0 <= prg_din;
				3'b1_01: chr_bank_1 <= prg_din;
				3'b1_10: chr_bank_2 <= prg_din;
				3'b1_11: chr_bank_3 <= prg_din;
			endcase

		if (irq_enable) begin
			irq_counter <= irq_counter - 16'd1;
			if (irq_counter == 16'h0) begin
				irq <= 1'b1; // IRQ
				irq_enable <= 0;
			end
		end
		if (irq_ack)
			irq <= 1'b0; // IRQ ACK
	end
end

always begin
	casez({mirroring})
		2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
		2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
		2'b1?   :   vram_a10 = {mirroring[0]};   // 1 screen lower:upper
	endcase
end

reg [7:0] prgsel;
always begin
	case(prg_ain[14])
	1'b0: prgsel = prg_bank_0;                // $8000 is swapable
	1'b1: prgsel = mapper190 ? 8'h00 : 8'hFF; // $C000 is hardwired to first/last bank
	endcase
end

reg [7:0] chrsel;
always begin
	casez(chr_ain[12:11])
		0: chrsel = chr_bank_0;
		1: chrsel = chr_bank_1;
		2: chrsel = chr_bank_2;
		3: chrsel = chr_bank_3;
	endcase
end

assign chr_aout = {3'b10_0, chrsel, chr_ain[10:0]};             //  2kB banks

wire [21:0] prg_aout_tmp = {2'b00, prgsel[5:0], prg_ain[13:0]}; // 16kB banks
wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};

assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;

assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;
assign chr_allow = flags[15];
assign vram_ce = chr_ain[13];

endmodule


// #68 - Sunsoft-4 - Game After Burner, and some japanese games. MAX: 128kB PRG, 256kB CHR
module Mapper68(
	input        clk,         // System clock
	input        ce,          // M2 ~cpu_clk
	input        enable,      // Mapper enabled
	input [31:0] flags,       // Cart flags
	input [15:0] prg_ain,     // prg address
	inout [21:0] prg_aout_b,  // prg address out
	input        prg_read,    // prg read
	input        prg_write,   // prg write
	input  [7:0] prg_din,     // prg data in
	inout  [7:0] prg_dout_b,  // prg data out
	inout        prg_allow_b, // Enable access to memory for the specified operation.
	input [13:0] chr_ain,     // chr address in
	inout [21:0] chr_aout_b,  // chr address out
	input        chr_read,    // chr ram read
	inout        chr_allow_b, // chr allow write
	inout        vram_a10_b,  // Value for A10 address line
	inout        vram_ce_b,   // True if the address should be routed to the internal 2kB VRAM.
	inout        irq_b,       // IRQ
	input [15:0] audio_in,    // Inverted audio from APU
	inout [15:0] audio_b,     // Mixed audio output
	inout [15:0] flags_out_b  // flags {0, 0, 0, 0, 0, prg_conflict, prg_open_bus, has_chr_dout}
);

assign prg_aout_b   = enable ? prg_aout : 22'hZ;
assign prg_dout_b   = enable ? 8'hFF : 8'hZ;
assign prg_allow_b  = enable ? prg_allow : 1'hZ;
assign chr_aout_b   = enable ? chr_aout : 22'hZ;
assign chr_allow_b  = enable ? chr_allow : 1'hZ;
assign vram_a10_b   = enable ? vram_a10 : 1'hZ;
assign vram_ce_b    = enable ? vram_ce : 1'hZ;
assign irq_b        = enable ? 1'b0 : 1'hZ;
assign flags_out_b  = enable ? flags_out : 16'hZ;
assign audio_b      = enable ? audio_in : 16'hZ;

wire [21:0] prg_aout, chr_aout;
wire prg_allow;
wire chr_allow;
wire vram_a10;
wire vram_ce;
reg [15:0] flags_out = 0;

reg [6:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3;
reg [6:0] nametable_0, nametable_1;
reg [2:0] prg_bank;
reg use_chr_rom;
reg mirroring;

always @(posedge clk)
if (~enable) begin
	chr_bank_0 <= 0;
	chr_bank_1 <= 0;
	chr_bank_2 <= 0;
	chr_bank_3 <= 0;
	nametable_0 <= 0;
	nametable_1 <= 0;
	prg_bank <= 0;
	use_chr_rom <= 0;
	mirroring <= 0;
end else if (ce) begin
	if (prg_ain[15] && prg_write) begin
		case(prg_ain[14:12])
			0: chr_bank_0  <= prg_din[6:0]; // $8000-$8FFF: 2kB CHR bank at $0000
			1: chr_bank_1  <= prg_din[6:0]; // $9000-$9FFF: 2kB CHR bank at $0800
			2: chr_bank_2  <= prg_din[6:0]; // $A000-$AFFF: 2kB CHR bank at $1000
			3: chr_bank_3  <= prg_din[6:0]; // $B000-$BFFF: 2kB CHR bank at $1800
			4: nametable_0 <= prg_din[6:0]; // $C000-$CFFF: 1kB Nametable register 0 at $2000
			5: nametable_1 <= prg_din[6:0]; // $D000-$DFFF: 1kB Nametable register 1 at $2400
			6: {use_chr_rom, mirroring} <= {prg_din[4], prg_din[0]}; // $E000-$EFFF: Nametable control
			7: prg_bank <= prg_din[2:0];
		endcase
	end
end

wire [2:0] prgout = (prg_ain[14] ? 3'b111 : prg_bank);
assign prg_aout = {5'b00_000, prgout, prg_ain[13:0]};
assign prg_allow = prg_ain[15] && !prg_write;

reg [6:0] chrout;
always begin
	casez(chr_ain[12:11])
		0: chrout = chr_bank_0;
		1: chrout = chr_bank_1;
		2: chrout = chr_bank_2;
		3: chrout = chr_bank_3;
	endcase
end

assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
wire [6:0] nameout = (vram_a10 == 0) ? nametable_0 : nametable_1;

assign chr_allow = flags[15];
assign chr_aout = (chr_ain[13] == 0) ? {4'b10_00, chrout, chr_ain[10:0]} : {5'b10_001, nameout, chr_ain[9:0]};
assign vram_ce = chr_ain[13] && !use_chr_rom;

endmodule