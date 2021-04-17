`ifndef SEGDISPLAYWITHSTROBE_H
`define SEGDISPLAYWITHSTROBE_H

//Note this won't display negative values

`include "segDisplay.sv"
`include "bit_tick.sv"

module segDisplayWithStrobe
#(
parameter SEGS = 3, //# of segs to use for each display
parameter DROP_LEADING_ZEROS = 1, // if set to 1 then leading zeros wont be displayed
parameter DIPLAY_AS_DEC = 1, // if 1 then datain will be displayed as dec else will be displayed as hex
parameter CLK_SYSTEM_FREQUENCY = 50000000,
parameter LED_UPDATE_RATE = 90,
parameter LED_UPDATE_RATE_MAX_ERROR = 0.25 //for 90Hz --> 67.5Hz to 112.5Hz
)
(
	input wire clk,
	input wire [(4*SEGS)-1:0] datain,
	input logic [$clog2(SEGS):0] decimal_place_location,//0 is RHS and so on.//
	input logic show_decimal_place,
	output reg[7:0] dataout,
	output reg[(SEGS-1):0] seg
);

//bit strobe for led seg advance
wire ledstrobe;
bit_tick
#(
	.ClkFrequency(CLK_SYSTEM_FREQUENCY),
	.Baud(LED_UPDATE_RATE*SEGS),
	.Max_error(LED_UPDATE_RATE_MAX_ERROR)
)
ledstrobe_bit_tick
(
	.clk_in(clk),
	.tick_out(ledstrobe)
);

segDisplay
#(
.SEGS(SEGS),
.DROP_LEADING_ZEROS(DROP_LEADING_ZEROS),
.DIPLAY_AS_DEC(DIPLAY_AS_DEC)
)
segDisplay0
(
	.clk(clk),
	.seg_update_strobe(ledstrobe),
	.datain(datain),
	.dataout(dataout),
	.seg(seg),
	.decimal_place_location(decimal_place_location),
	.show_decimal_place(show_decimal_place)
);


endmodule

`endif