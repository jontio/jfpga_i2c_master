`ifndef SEGDISPLAY_H
`define SEGDISPLAY_H

//Note this won't display negative values

`include "bin2bcd.sv"

module segDisplay 
#(
parameter SEGS = 4, //# of segs to use
parameter DROP_LEADING_ZEROS = 1, // if set to 1 then leading zeros wont be displayed
parameter DIPLAY_AS_DEC = 1 // if 1 then datain will be displayed as dec else will be displayed as hex
)
(
	input wire clk,
	input wire seg_update_strobe,
	input wire [(4*SEGS)-1:0] datain,
	input wire reset,
	input logic [$clog2(SEGS):0] decimal_place_location,//0 is RHS and so on.//
	input logic show_decimal_place,
	output reg[7:0] dataout=0,
	output reg[SEGS-1:0] seg=~0
);

reg [(4*SEGS)-1:0] dataintmp;

always @(posedge clk)
begin
	dataintmp<=datain;
end

reg [SEGS-1:0] seg_inv=(1<<(SEGS-1));

//convert from bin to bcd if needed
wire [(4*SEGS)+((4*SEGS)-4)/3:0] bcd;
wire [(4*SEGS)-1:0] datain_local;
assign datain_local=DIPLAY_AS_DEC?bcd:dataintmp;
bin2bcd
#(.W(4*SEGS))  // input width
bin2bcd0
(
	.bin(dataintmp),  // binary in
	.bcd(bcd) //bcd out
);

//for dataout and seg given datain_local and nibbleSelect
integer maxNonZeroNibble;
integer i;
reg [($clog2(4*SEGS))-1:0] nibbleSelect=((4*SEGS)-1);
wire [3:0] CurrentSegDigit;
assign CurrentSegDigit=(datain_local[nibbleSelect -: 4]);
always @ ( posedge clk )
begin

	if(seg_update_strobe)
	begin

		seg<=~seg_inv;
	
		//find max nibble that is non zero else say the last nibble is non zero even if it's not so as to display a zero.
		maxNonZeroNibble<=4;
		for(i=1;i<SEGS;i=i+1)
		begin
			if(|datain_local[4*i+3 -: 4])maxNonZeroNibble<=(4*i+3);
		end

		if((!DROP_LEADING_ZEROS)||(nibbleSelect<=maxNonZeroNibble)||((seg_inv<=decimal_place_location+1)&&show_decimal_place))
		begin
			case ( CurrentSegDigit )
			0: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b1000000};
			1: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b1111001};
			2: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0100100};
			3: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0110000};
			4: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0011001};
			5: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0010010};  
			6: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0000010}; 
			7: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b1111000};
			8: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0000000};
			9: dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0010000};
			10:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0001000};
			11:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0000011};
			12:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b1000110};
			13:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0100001};
			14:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0000110};
			15:dataout<={~seg_inv[decimal_place_location]|~show_decimal_place,7'b0001110};
			default: dataout<={~seg_inv[decimal_place_location|~show_decimal_place],7'b1101111};
			endcase
		end
		else dataout<=8'b11111111;
		
	end
	
end

//tring out tasks.

task reset_task();
begin
	seg_inv<=(1<<(SEGS-1));
	nibbleSelect<=((4*SEGS)-1);
end
endtask

task next_nibble_task();
begin
	seg_inv<=(seg_inv>>1);
	nibbleSelect<=(nibbleSelect-4);
end
endtask

//seq for updating nibbleSelect and seg_inv
always @ (  posedge clk )
begin
	if(seg_update_strobe)
	begin
		if((reset)||(seg_inv==1))reset_task();//first seg is MSN
		else next_nibble_task();//shift to the next nibble
	end
end

endmodule

`endif