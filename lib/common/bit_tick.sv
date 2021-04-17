`ifndef BIT_TICK_H
`define BIT_TICK_H
//this module creates a strobe (high for just one clock cycle) at a rate of "Baud" times a second given a clock speed of "ClkFrequency"
module bit_tick
#(
parameter ClkFrequency = 50000000, // 50MHz
parameter Baud = 115200,
parameter Max_error=0.01 //1%
)
(
input clk_in, //clock in
output tick_out //a high for one clock cycle when time. The period may vary to keep the average period equal to Baud 
);
//I dont trust any number of size 31:0 here (some intermediates can be bigger and then do fail) so make them bigger, I'm not sure how to cast like in C. Not sure if [127:0]*[2:0] or [127:0]+[2:0] produces what is expected or not. 
localparam [127:0] Baud_BIG=Baud;
localparam [127:0] ClkFrequency_BIG=ClkFrequency;

//calc acc width for error
//this sucks. i can't make a function that takes real values and works out the min val by stepping through BaudGeneratorAccWidth
//to find the min value. all I can do is do the upperbound.
//if i create a function it says real unsupported. I dont want to Synthesize it I just want to use it to preprocess.
//come on this is sooooooo stupid!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//i cant even use $display with some calc in it. come on who is writing the specs???
localparam real ClkFrequency_real=ClkFrequency;
localparam real Baud_real=Baud;
localparam real tmp_val_real=ClkFrequency_real/(2.0*Baud_real*Max_error);
localparam integer tmp_val_int=tmp_val_real;
localparam BaudGeneratorAccWidth=$clog2(tmp_val_int);

initial
begin
//	$display("bit_tick Baud=%d BaudGeneratorAccWidth=%d BaudGeneratorInc=%d {this stupid thing cant even calulate exact step (%f*2^%f)/%f} or exact hz %f*%f/(2^%f)",Baud,BaudGeneratorAccWidth,BaudGeneratorInc,Baud,BaudGeneratorAccWidth,ClkFrequency,BaudGeneratorInc,ClkFrequency,BaudGeneratorAccWidth);
end

localparam BaudGeneratorInc = (((Baud_BIG)<<BaudGeneratorAccWidth)+(ClkFrequency_BIG>>1))/(ClkFrequency_BIG);
reg [BaudGeneratorAccWidth:0] BaudGeneratorAcc=0;
always @(posedge clk_in)
begin
	BaudGeneratorAcc <= BaudGeneratorAcc[BaudGeneratorAccWidth-1:0] + BaudGeneratorInc[BaudGeneratorAccWidth:0];
end
assign tick_out = BaudGeneratorAcc[BaudGeneratorAccWidth];
endmodule

`endif