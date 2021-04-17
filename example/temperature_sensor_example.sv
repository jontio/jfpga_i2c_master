`include "i2c_master.sv"
module temperature_sensor_example
#(

parameter CLK_SYSTEM_FREQUENCY = 50000000,//system clock input
parameter SEGS=3,//3 segments
parameter LED_UPDATE_RATE=90, //90Hz
parameter LED_UPDATE_RATE_MAX_ERROR=0.25,//for 90Hz --> 67.5Hz to 112.5Hz (actually produces 95Hz with current code)

parameter I2C_BAUD_RATE = 100000,
parameter I2C_BAUD_RATE_MAX_ERROR=0.25,

parameter TEMPERATURE_SENSOR_READ_DELAY=CLK_SYSTEM_FREQUENCY/2//update rate between temperature sensor reads in system clock cycles

)
(
	//the system clock
    input logic clk_50M,
	
	//LED segments
    output logic[7:0] segData,
	output logic[(SEGS-1):0] segSelect,
	
	//general-purpose LED
	output logic led=1'b0,

	//the I2C bus wires
    inout wire i2c_sda_w,
    inout wire i2c_scl_w
);

//segment display driver
logic [11:0] dataDisplayValue;
logic[(SEGS-1):0] segSelect_inveted;
assign segSelect=~segSelect_inveted;
segDisplayWithStrobe
#(
.SEGS(SEGS), //# of segs to use for each display
.DROP_LEADING_ZEROS(1), // if set to 1 then leading zeros wont be displayed
.DIPLAY_AS_DEC(1),// if 1 then datain will be displayed as dec else will be displayed as hex
.CLK_SYSTEM_FREQUENCY(CLK_SYSTEM_FREQUENCY),
.LED_UPDATE_RATE(LED_UPDATE_RATE),
.LED_UPDATE_RATE_MAX_ERROR(LED_UPDATE_RATE_MAX_ERROR)
)
segDisplay
(
	.clk(clk_50M),
	.datain(dataDisplayValue),
	.dataout(segData),
	.seg(segSelect_inveted),
    .decimal_place_location(1),
	.show_decimal_place(1)
);

//i2c driver
logic i2c_start=0;
logic [7:0] i2c_nbytes_in;
logic [6:0] i2c_addr_in;
i2c_rw_mode_t i2c_rw_mode;
logic [7:0] i2c_write_data;
logic [7:0] i2c_read_data;
logic i2c_tx_data_req;
logic i2c_rx_data_ready; 
logic i2c_bus_idle;
logic i2c_tranfer_failed;
// wire i2c_sda_w;
// wire i2c_scl_w;
i2c_master
#(
    .CLK_SYSTEM_FREQUENCY(CLK_SYSTEM_FREQUENCY),
    .I2C_BAUD_RATE(I2C_BAUD_RATE),
    .I2C_BAUD_RATE_MAX_ERROR(I2C_BAUD_RATE_MAX_ERROR)
)
i2c_master0
(
	.clk(clk_50M),
	.start_trigger(i2c_start),
	.nbytes_in(i2c_nbytes_in),
	.addr_in(i2c_addr_in),
	.rw_mode(i2c_rw_mode),
	.write_data(i2c_write_data),
	.read_data(i2c_read_data),
	.tx_data_req(i2c_tx_data_req), 
	.rx_data_ready(i2c_rx_data_ready), 
	.sda_w(i2c_sda_w),
	.scl_w(i2c_scl_w),
    .idle(i2c_bus_idle),
    .tranfer_failed(i2c_tranfer_failed)
);

//something to periodically strobe i2c_run_job to signify that the FPGA should begin another read of the temperature sensor
logic i2c_run_job=0;
logic [31:0] i2c_trigger_counter=0;
always@(posedge clk_50M)
begin
    i2c_run_job<=0;
    i2c_trigger_counter<=i2c_trigger_counter+1;
    if(i2c_trigger_counter==TEMPERATURE_SENSOR_READ_DELAY-1)
    begin
		led<=~led;
        i2c_run_job<=1;
        i2c_trigger_counter<=0;
    end
end

//registers to send to the temperature sensor and also registers for the response
logic  [7:0] tempSensorData[8]='{8'h2c,8'h06,0,0,0,0,0,0};
//a read/write index as well as something that describes the state of the system
logic [3:0] tempSensorData_index=9;

//the main part of the code that initiates read and write transfers to the I2C bus as well as deciding what should be sent and also saving the received data to registers and processing them
always@(posedge clk_50M)
begin
    i2c_start<=0;
	
	//if okay to initiate a transfer
	if(i2c_bus_idle)
	begin
		//when a job comes in start a transfer writing to the temperature sensor
		if(i2c_run_job)
		begin
			i2c_rw_mode<=I2C_MODE_WRITE;
			i2c_nbytes_in<=2;
			i2c_addr_in<=7'h45;
			i2c_write_data<=tempSensorData[0];
			tempSensorData_index<=1;
			i2c_start<=1;
		end
		//if we have already written to the temperature sensor then it's time to read from it so start a read transfer
		if(tempSensorData_index==2)
		begin
			i2c_rw_mode<=I2C_MODE_READ;
			i2c_nbytes_in<=6;
			i2c_addr_in<=7'h45;
			i2c_start<=1;
		end
	end

	//if more data is requested from us then give it to the I2C master module
	if(i2c_tx_data_req&&tempSensorData_index<=1)
	begin
		i2c_write_data<=tempSensorData[tempSensorData_index];
		tempSensorData_index<=tempSensorData_index+2'd1;
	end
	//if data is available to us from the I2C master module than write it to the registers
	if(i2c_rx_data_ready&&tempSensorData_index>=2)
	begin
		tempSensorData[tempSensorData_index]<=i2c_read_data;
		tempSensorData_index<=tempSensorData_index+2'd1;
	end
	//if all bytes are received from the temperature sensor then process them
	if(tempSensorData_index==8)
	begin
		//approximate temperature in centigrade * 10
        //This won't work for negative temperatures
        dataDisplayValue<={{16'd0,tempSensorData[2],tempSensorData[3]}*31'd1750-31'd29491200+31'd32768}>>16;
        tempSensorData_index<=tempSensorData_index+2'd1;
	end

	//if a failure happened go into an idle state and wait for the next job
	if(i2c_tranfer_failed)
    begin
        tempSensorData_index<=9;
    end

end

endmodule

