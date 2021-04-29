`ifndef I2C_MASTER_H
`define I2C_MASTER_H
`include "bit_tick.sv"

//`define I2C_MASTER_DISABLE_ACK_CHECKS

//Jonti
//2021
//code modified from https://github.com/mcgodfrey/i2c-eeprom

/*
References:
https://eewiki.net/pages/viewpage.action?pageId=10125324
http://faculty.lasierra.edu/~ehwang/digitaldesign/public/projects/DE2/I2C/I2C.pdf

Jonti's reference
https://www.nxp.com/docs/en/user-guide/UM10204.pdf
*/

typedef enum logic {
	I2C_MODE_WRITE=1'b0,
	I2C_MODE_READ=1'b1
} i2c_rw_mode_t;

module i2c_master
#(
parameter CLK_SYSTEM_FREQUENCY = 50000000,//FPGA system clock speed
parameter I2C_BAUD_RATE = 100000,//desired I2C baud rate
parameter I2C_BAUD_RATE_MAX_ERROR = 0.25//maximum I2C baud rate error
)
(
	input wire clk,//FPGA system clock
	
	input logic start_trigger,//starts transfer
	input wire [7:0] nbytes_in,//number of bytes to send or receive
	input wire [6:0] addr_in,//address of I2C slave device
	input i2c_rw_mode_t rw_mode,//read from or write to I2C slave device
	
	input wire [7:0] write_data,//byte to write to I2C slave device.
	output reg tx_data_req,//when high update write_data  to the next desired by to send

	output reg [7:0] read_data,//byte read from I2C slave device
	output reg rx_data_ready,//when high read_data will be valid
	
	output logic idle,//when high a new transfer can be triggered
	output logic tranfer_failed,//if a transfer fails this will go high
		
	inout wire sda_w,//I2C data line
	inout wire scl_w//I2C clock line
);

//i2c clock state generation
typedef enum logic[1:0] {
	CLK_STATE_MIDDLE_OF_HIGH,
	CLK_STATE_HIGH_TO_LOW_TRANSITION,
	CLK_STATE_MIDDLE_OF_LOW,
	CLK_STATE_LOW_HIGH_TRANSITION
	} clk_state_t;
clk_state_t i2c_clock_state=CLK_STATE_MIDDLE_OF_HIGH;
logic i2c_clock_hold=0;
logic strobe;
bit_tick
#(
	.ClkFrequency(CLK_SYSTEM_FREQUENCY),
	.Baud(I2C_BAUD_RATE*4),
	.Max_error(I2C_BAUD_RATE_MAX_ERROR)
)
strobe_bit_tick
(
	.clk_in(clk),
	.tick_out(strobe)
);
always@(posedge clk)
begin
	if(strobe)
	begin
		i2c_clock_state<=clk_state_t'(i2c_clock_state+2'd1);
	end
end

//state machine 
typedef enum logic[3:0] {
	STATE_IDLE,
	STATE_START,
	STATE_ADDR,
	STATE_RW,
	STATE_ADDR_ACK_DELAY,
	STATE_ADDR_ACK,
	STATE_ACK,
	STATE_READ_ACK,
	STATE_TX_DATA,
	STATE_RX_DATA,
	STATE_STOP,
	STATE_REPEATED_START
	} state_t;
state_t state;

localparam ACK = 0;

logic start=0;

//bit counter
reg [7:0] bit_count;	

//local logic
reg [6:0] addr;
reg [7:0] data;
reg [7:0] nbytes;
i2c_rw_mode_t rw;
reg scl_en;
reg sda;
logic scl;

initial
begin
	tranfer_failed=0;
	scl_en=0;
	state=STATE_IDLE;
	sda=1;
	bit_count=8'd0;
	addr=0;
	data=0;
	nbytes=0;
	rw=I2C_MODE_WRITE;
	tx_data_req=0;
	rx_data_ready=0;
end
	
//sda_w and scl_w are never pulled high as i2c bus is shared
assign sda_w=(sda)?1'bz:1'b0;
assign scl_w=(scl)?1'bz:1'b0;

wand sda_w_wand;
assign sda_w_wand=sda_w;
assign sda_w_wand=1'b1;

wand scl_w_wand;
assign scl_w_wand=scl_w;
assign scl_w_wand=1'b1;

//syncronizer for bus input as the slave may not transition the clk or the data lines when we would like them to do so.
logic scl_w_wand_in;
logic sda_w_wand_in;
always@(posedge clk)
begin
	scl_w_wand_in<=scl_w_wand;
	sda_w_wand_in<=sda_w_wand;
end

wand i2c_bus_lines_are_high;
assign i2c_bus_lines_are_high=scl_w_wand_in;
assign i2c_bus_lines_are_high=sda_w_wand_in;

//used for user to see when ok to start a transaction
wand i2c_bus_available;
assign i2c_bus_available=(state==STATE_IDLE);
assign i2c_bus_available=~start;
assign i2c_bus_available=~start_trigger;
assign i2c_bus_available=i2c_bus_lines_are_high;
assign idle=i2c_bus_available;

//clock
//scl is enabled whenever we are sending or receiving data.
assign scl=(scl_en)?(i2c_clock_hold||i2c_clock_state==CLK_STATE_MIDDLE_OF_HIGH||i2c_clock_state==CLK_STATE_HIGH_TO_LOW_TRANSITION):1'b1;

always@(posedge clk)
begin
	tranfer_failed<=0;
	rx_data_ready<=0;
	tx_data_req<=0;
	if(start_trigger)start<=1;
	if(strobe)
	begin

		if(state==STATE_IDLE)scl_en<=0;
		else scl_en<=1;

		if(i2c_clock_state==CLK_STATE_MIDDLE_OF_HIGH)//start/stop send time. scl will be high here
		begin
			if(scl_w_wand_in==0)
			begin
				if(!i2c_clock_hold)
				begin
					$display("clock streaching: clock pulled low by slave. %s",state);
				end
				i2c_clock_hold<=1;
			end
			else
			begin
				if(i2c_clock_hold)
				begin
					$display("clock streaching eneded: slave let go of clk.");
				end
				i2c_clock_hold<=0;
				case(state)
				STATE_IDLE,STATE_START:
				begin
					sda<=1;
					if((i2c_bus_lines_are_high&&start&&state==STATE_IDLE)||(state==STATE_START))
					begin
						state<=STATE_ADDR;
						sda<=0;	//send start condition
						//latch in all the values
						addr<=addr_in;
						nbytes<=nbytes_in;
						rw<=rw_mode;
						bit_count<=6;	//addr is only 7 bits long, not 8
					end
				end
				STATE_REPEATED_START:
				begin
					state<=STATE_START;
					sda<=1;
				end
				STATE_STOP:
				begin
					//i think for the last byte when sending the slave will also ack this
					//but i'm not too sure. maybe the slave might nak it to say thats the
					//last byte. on the sht30 it acks the last byte so I'm go for that.
					//if you have issues with the last byte being naked and that's what
					//you expect then comment out this
					if(rw==I2C_MODE_WRITE&&sda_w_wand_in)
					begin
						`ifndef I2C_MASTER_DISABLE_ACK_CHECKS 
						$display("no responce from slave for the last byte");
						tranfer_failed<=1;
						`endif
					end
				end
				STATE_TX_DATA,STATE_RX_DATA:
				begin
					if((bit_count==7&&state==STATE_TX_DATA)||(bit_count==8&&state==STATE_RX_DATA))
					begin
						if(sda_w_wand_in)
						begin
							`ifndef I2C_MASTER_DISABLE_ACK_CHECKS
							$display("no responce from slave");
							tranfer_failed<=1;
							state <= STATE_STOP;
							`endif
						end				
					end
					if(state==STATE_RX_DATA)
					begin
						data[bit_count]<=sda_w_wand_in;
						if(bit_count==0)
						begin
							//byte transfer complete
							state<=STATE_ACK;
							read_data[7:1]<=data[7:1];
							read_data[0]<=sda_w_wand_in;
							rx_data_ready<=1;
							nbytes<=nbytes-1'b1;
						end
						else
						begin
							bit_count<=bit_count-1'b1;
							rx_data_ready<=0;
						end
					end
				end
				endcase
				if(!start_trigger)start<=0;
			end
		end
		else
		if((i2c_clock_state==CLK_STATE_MIDDLE_OF_LOW)&&(!i2c_clock_hold))//data change time. scl will be low here
		begin
			case(state)
			STATE_ADDR:
			begin //send slave address
				sda<=addr[bit_count];
				if(bit_count==0)state<=STATE_RW;
				else bit_count<=bit_count-1'b1;
			end
			STATE_RW:
			begin //send R/W bit
				sda<=rw;
				state<=STATE_ADDR_ACK;
			end
			STATE_ADDR_ACK, STATE_ACK:
			begin
				if((rw==I2C_MODE_WRITE)||(state==STATE_ADDR_ACK))sda<=1;
				else sda<=0;
				//now we have to decide what to do next.
				if(nbytes==0)
				begin
					//there is no data left to read/write
					if(start==1)
					begin
						//repeat start condition
						sda<=1;
						state<=STATE_REPEATED_START;
					end
					else
					begin
						//we are done
						sda<=1;
						state<=STATE_STOP;
					end
				end
				else
				begin
					//we have more data to read/write
					if(rw==I2C_MODE_WRITE)
					begin
						data<=write_data;  //latch in the new data byte
						bit_count<=7;  //8 data bits not +1 due to reading is done on low clk
						state<=STATE_TX_DATA;
					end
					else
					begin
						// Read data
						bit_count<=8;	//8 data bits +1 due to reading is done on high clk
						state<=STATE_RX_DATA;
					end
				end 
			end
			STATE_TX_DATA:
			begin
				sda<=data[bit_count];
				//if there are more bytes to write, then request the next one
				if(bit_count==0)
				begin
					if(nbytes>0)tx_data_req<=1;//ask for next byte
					//byte transfer complete
					state<=STATE_ACK;
					nbytes<=nbytes-1'b1;
				end
				else bit_count<=bit_count-1'b1;
			end
			STATE_RX_DATA:
			begin
				sda<=1;
			end	
			STATE_STOP:
			begin
				sda<=0;
				state<=STATE_IDLE;
			end
			endcase
		end
	end
end


endmodule

`endif
