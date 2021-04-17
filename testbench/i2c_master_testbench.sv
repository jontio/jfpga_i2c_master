`timescale 1ps/1ps

/*

I2C Master testbench
Jonti 2021

*/

`include "i2c_master.sv"

`define TEST_FAILS_ON_NO_SLAVE_ATTATCHED_WRITE
`define TEST_FAILS_ON_NO_SLAVE_ATTATCHED_READ
`define TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK
`define TEST_WRITE_BYTES_TO_SLAVE
`define TEST_READ_BYTES_FROM_SLAVE
`define TEST_READ_BYTES_FROM_SLAVE_WITH_CLOCK_STREACHING
`define TEST_CONTINIOUS_START_TRIGGER

//verilog is so stupid!!!!! I can't even seem to get the thing to calculate the size of `I2C_BYTES_TO_USE
`define I2C_BYTES_TO_USE '{8'h26,8'hC7,8'h86}
`define I2C_BYTES_TO_USE_NUMBER_OF_BYTES 3

`define MAX_CLOCK_STREACHING_DELAYS 30

localparam HIGH = 1;
localparam LOW = 0;
localparam ACK = 0;
localparam NAK = 1;

parameter PERIOD=8000;
parameter CLK_SYSTEM_FREQUENCY = 50000000;

parameter I2C_ADDRESS = 7'h45;

parameter I2C_BAUD_RATE = CLK_SYSTEM_FREQUENCY/8;
parameter I2C_BAUD_RATE_MAX_ERROR=0.25;

parameter I2C_CLK_SYSTEM_CYCLES_PER_BIT=CLK_SYSTEM_FREQUENCY/I2C_BAUD_RATE;

module i2c_master_testbench;

logic clk_50M=1;
wand i2c_sda_w;
wand i2c_scl_w;

assign i2c_sda_w=1;
assign i2c_scl_w=1;

logic i2c_sda_private=1;
assign i2c_sda_w=i2c_sda_private?1'bz:0;

logic i2c_scl_private=1;
assign i2c_scl_w=i2c_scl_private?1'bz:0;

//-----

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
//for deployment
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


//-----------

task clk();
	#(PERIOD/2);
	clk_50M=~clk_50M;
	#(PERIOD/2);
	clk_50M=~clk_50M; 
endtask

integer i;
integer test_clock_streaching_delay_clks=0;

logic i2c_start_detected;
logic i2c_stop_detected;
logic i2c_last_i2c_sda_w;
logic i2c_last_i2c_scl_w;
logic i2c_last_bus_idle;
logic i2c_bus_idle_change_detected;
logic i2c_sda_w_change_detected;
logic i2c_scl_w_change_detected;
logic i2c_tranfer_failed_detected=0;
assign i2c_bus_idle_change_detected=(i2c_last_bus_idle!=i2c_bus_idle);
assign i2c_sda_w_change_detected=(i2c_last_i2c_sda_w!=i2c_sda_w);
assign i2c_scl_w_change_detected=(i2c_last_i2c_scl_w!=i2c_scl_w);
assign i2c_start_detected=(i2c_scl_w&&i2c_last_i2c_scl_w&&i2c_last_i2c_sda_w&&!i2c_sda_w);
assign i2c_stop_detected=(i2c_scl_w&&i2c_last_i2c_scl_w&&!i2c_last_i2c_sda_w&&i2c_sda_w);
always@(posedge clk_50M)
begin
    i2c_last_bus_idle<=i2c_bus_idle;
    i2c_last_i2c_sda_w<=i2c_sda_w;
    i2c_last_i2c_scl_w<=i2c_scl_w;
    if(i2c_tranfer_failed)i2c_tranfer_failed_detected<=1;
    if(i2c_start)i2c_tranfer_failed_detected<=0;
end

task i2c_clk_cycles_wait(int number_of_i2c_clk_cycles_to_wait_for);
    for(i=0;i<I2C_CLK_SYSTEM_CYCLES_PER_BIT*number_of_i2c_clk_cycles_to_wait_for;i=i+1)
    begin
        clk();
    end
endtask

task i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(int number_of_i2c_clk_cycles_to_wait_for);
    for(i=0;i<I2C_CLK_SYSTEM_CYCLES_PER_BIT*number_of_i2c_clk_cycles_to_wait_for;i=i+1)
    begin
        clk();
        if(i2c_bus_idle_change_detected)
        begin
            $display("i2c_bus_idle_change_detected unexpected");
            $stop();
        end
        if(i2c_start_detected)
        begin
            $display("i2c_start_detected unexpected");
            $stop();
        end
        if(i2c_stop_detected)
        begin
            $display("i2c_stop_detected unexpected");
            $stop();
        end
        if(i2c_sda_w_change_detected)
        begin
            $display("i2c_sda_w_change_detected unexpected");
            $stop();
        end
        if(i2c_scl_w_change_detected)
        begin
            $display("i2c_scl_w_change_detected unexpected");
            $stop();
        end
    end
endtask

task i2c_transfer_task();
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait till finished or timeout
    for(i=0;i<I2C_CLK_SYSTEM_CYCLES_PER_BIT*11&&(!i2c_bus_idle);i=i+1)clk();//(11=1start+8bits+1ack+1stop)
endtask

task wait_for_start(int number_of_bits_to_wait_for);
    for(i=0;i<I2C_CLK_SYSTEM_CYCLES_PER_BIT*number_of_bits_to_wait_for;i=i+1)
    begin
        clk();
        if(i2c_bus_idle)
        begin
            $display("bus unexpectedly idle");
            $stop();
        end
        if(i2c_start_detected||i2c_stop_detected)break;
    end
    if(i2c_stop_detected)
    begin
        $display("i2c_stop_detected before start");
        $stop();
    end
    if(i2c_start_detected)$display("i2c_start_detected");
    else
    begin
        $display("i2c_start_detected wasn't detected");
        $stop();
    end
endtask

task wait_for_stop(int number_of_bits_to_wait_for);
    if(i2c_bus_idle)
    begin
        $display("bus unexpectedly idle");
        $stop();
    end
    for(i=0;i<I2C_CLK_SYSTEM_CYCLES_PER_BIT*number_of_bits_to_wait_for;i=i+1)
    begin
        clk();
        if(i2c_start_detected||i2c_stop_detected)break;
        if(i2c_bus_idle)
        begin
            $display("bus unexpectedly idle");
            $stop();
        end
    end
    if(i2c_start_detected)
    begin
        $display("i2c_start_detected before stop");
        $stop();
    end
    if(i2c_stop_detected)$display("i2c_stop_detected");
    else
    begin
        $display("i2c_stop_detected wasn't detected");
        $stop();
    end
endtask

task wait_for_scl_to_be(logic desired_i2c_scl_w,int number_of_bits_to_wait_for);
    for(i=0;i<(I2C_CLK_SYSTEM_CYCLES_PER_BIT*number_of_bits_to_wait_for)&&(i2c_scl_w!=desired_i2c_scl_w);i=i+1)
    begin
        clk();
        if(i2c_bus_idle)
        begin
            $display("i2c_bus_idle unexpected");
            $stop();
        end
        if(i2c_start_detected)
        begin
            $display("i2c_start_detected unexpected");
            $stop();
        end
        if(i2c_stop_detected)
        begin
            $display("i2c_stop_detected unexpected");
            $stop();
        end        
    end
    if(i2c_scl_w!=desired_i2c_scl_w)
    begin
        if(desired_i2c_scl_w)$display("timeout waiting for i2c_scl_w to become high");
        else $display("timeout waiting for i2c_scl_w to become low");
        $stop();
    end
endtask

logic [8:0] i2c_rx_byte;
int k;
task read_bits_from_i2c_sda_w(int number_of_bits_to_read);
    i2c_rx_byte=9'bx;
    for(k=0;k<number_of_bits_to_read;k=k+1)
    begin
        wait_for_scl_to_be(LOW,2);
        wait_for_scl_to_be(HIGH,2);
        //$display("reading bit=%d of value=%b",k,i2c_sda_w);
        i2c_rx_byte=i2c_rx_byte<<1;
        i2c_rx_byte[0]=i2c_sda_w;
    end
endtask

logic [8:0] i2c_tx_byte;
task write_bits_to_i2c_sda_w(int number_of_bits_to_write);
    for(k=0;k<number_of_bits_to_write;k=k+1)
    begin
        wait_for_scl_to_be(LOW,2);
        //$display("writing bit=%d of value=%b",k,i2c_tx_byte[number_of_bits_to_write-1-k]);
        i2c_sda_private=i2c_tx_byte[number_of_bits_to_write-1-k];
        wait_for_scl_to_be(HIGH,2);
        wait_for_scl_to_be(LOW,2);
    end
    i2c_sda_private=NAK;
endtask

task send_ack_nak(logic ack_nak);
    wait_for_scl_to_be(LOW,2);
    i2c_sda_private=ack_nak;
    wait_for_scl_to_be(HIGH,2);
    wait_for_scl_to_be(LOW,2);
    i2c_sda_private=NAK;
endtask

logic [7:0] i2c_bytes_to_send [`I2C_BYTES_TO_USE_NUMBER_OF_BYTES]=`I2C_BYTES_TO_USE;
parameter i2c_bytes_to_send_size=$bits(i2c_bytes_to_send)/8;
int i2c_bytes_to_send_counter;
logic [7:0] i2c_expected_byte;

task TEST_FAILS_ON_NO_SLAVE_ATTATCHED_WRITE();
    $display("test for nak if no slave attatched in write mode");
    i2c_addr_in=I2C_ADDRESS;
    i2c_nbytes_in=1;
    i2c_rw_mode=I2C_MODE_WRITE;
    i2c_transfer_task();
    if(!i2c_bus_idle)
    begin
        $display("test for nak if no slave attatched in write mode failed");
        $stop();
    end
    if(!i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected was expected but didn't happen");
        $stop();
    end
endtask

task TEST_FAILS_ON_NO_SLAVE_ATTATCHED_READ();
    $display("test for nak if no slave attatched in read mode");
    i2c_addr_in=I2C_ADDRESS;
    i2c_nbytes_in=1;
    i2c_rw_mode=I2C_MODE_READ;
    i2c_transfer_task();
    if(!i2c_bus_idle)
    begin
        $display("test for nak if no slave attatched in read mode failed");
        $stop();
    end
    if(!i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected was expected but didn't happen");
        $stop();
    end
endtask

task TEST_WRITE_BYTES_TO_SLAVE();
    $display("test write bytes to slave...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_WRITE;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=i2c_bytes_to_send[0];
    i2c_expected_byte=i2c_write_data;
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    //read the bytes the i2c device sends and send back acks 
    for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_write_data=i2c_bytes_to_send[i2c_bytes_to_send_counter+1];
        read_bits_from_i2c_sda_w(8);
        send_ack_nak(ACK);
        if(i2c_rx_byte[7:0]!=i2c_expected_byte)
        begin
            $display("received data=%B (%h)",i2c_rx_byte[7:0],i2c_rx_byte[7:0]);
            $display("did not receive expected i2c data");
            $stop();
        end
        i2c_expected_byte=i2c_write_data;
    end
    //wait for stop
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
    if(i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected");
        $stop();
    end
endtask

task TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK();
    $display("test write bytes to slave fails if sends no data ack...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_WRITE;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=i2c_bytes_to_send[0];
    i2c_expected_byte=i2c_write_data;
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    //read the byte the i2c device sends and send back nak to stop master
    read_bits_from_i2c_sda_w(8);
    send_ack_nak(NAK);
    //master should stop as we sent a nak
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
    if(!i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected was expected but didn't happen");
        $stop();
    end
endtask

task TEST_READ_BYTES_FROM_SLAVE();
    $display("test read bytes from slave...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_READ;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=8'bx;
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    //send bytes for i2c to read
    for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_tx_byte[7:0]=i2c_bytes_to_send[i2c_bytes_to_send_counter];
        write_bits_to_i2c_sda_w(8);//write the byte
        read_bits_from_i2c_sda_w(1);//read the ack/nak
        if(i2c_bytes_to_send_counter!=(i2c_bytes_to_send_size-1))
        begin
            if(i2c_rx_byte[0]==NAK)
            begin
                $display("got nak from i2c master but master still has bytes to read");
                $stop();
            end
        end
        // $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
        // $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
        if(i2c_read_data!=i2c_tx_byte[7:0])
        begin
            $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
            $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
            $display("did not receive expected i2c data");
            $stop();
        end
    end
    if(i2c_rx_byte[0]==ACK)
    begin
        $display("got ack from i2c master but master doesn't have any more bytes to read");
        $stop();
     end
    //wait for stop
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
    if(i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected");
        $stop();
    end
endtask

task TEST_READ_BYTES_FROM_SLAVE_WITH_CLOCK_STREACHING();
    $display("test read bytes from slave with clock streaching...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_READ;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=8'bx;
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);

    i2c_scl_private=0;//start clock streach
    i2c_clk_cycles_wait(1);//i2c may release sda
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);//wait a bit
    i2c_scl_private=1;//stop clock streach

    //send bytes for i2c to read
    for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_tx_byte[7:0]=i2c_bytes_to_send[i2c_bytes_to_send_counter];
        //write the byte with some various place to streach the clock
        for(k=0;k<8;k=k+1)
        begin
            wait_for_scl_to_be(LOW,2);
            if(i2c_bytes_to_send_counter==0&&k!=2)
            begin
                i2c_scl_private=0;//start clock streach
                i2c_clk_cycles_wait(1);//i2c may release sda
                i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);//wait a bit
                i2c_scl_private=1;//stop clock streach
            end
            //$display("writing bit=%d of value=%b",k,i2c_tx_byte[number_of_bits_to_write-1-k]);
            i2c_sda_private=i2c_tx_byte[8-1-k];
            wait_for_scl_to_be(HIGH,2);
            wait_for_scl_to_be(LOW,2);
            if(i2c_bytes_to_send_counter==1&&k==2)
            begin
                i2c_scl_private=0;//start clock streach
                i2c_clk_cycles_wait(1);//i2c may release sda
                i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);//wait a bit
                i2c_scl_private=1;//stop clock streach
            end
            if(i2c_bytes_to_send_counter==2&&k==7)
            begin
                i2c_scl_private=0;//start clock streach
                i2c_clk_cycles_wait(1);//i2c may release sda
                i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);//wait a bit
                i2c_scl_private=1;//stop clock streach
            end

        end
        i2c_sda_private=NAK;

        i2c_scl_private=0;//start clock streach
        i2c_clk_cycles_wait(1);//i2c may release sda
        i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);//wait a bit
        i2c_scl_private=1;//stop clock streach

        read_bits_from_i2c_sda_w(1);//read the ack/nak
        if(i2c_bytes_to_send_counter!=(i2c_bytes_to_send_size-1))
        begin
            if(i2c_rx_byte[0]==NAK)
            begin
                $display("got nak from i2c master but master still has bytes to read");
                $stop();
            end
        end
        if(i2c_read_data!=i2c_tx_byte[7:0])
        begin
            $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
            $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
            $display("did not receive expected i2c data");
            $stop();
        end
    end
    if(i2c_rx_byte[0]==ACK)
    begin
        $display("got ack from i2c master but master doesn't have any more bytes to read");
        $stop();
    end
    //wait for stop
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
    if(i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detectedn");
        $stop();
    end

    $display("trying slightly different streaching delays after address ack to see if we can make it glitch...");
    for(test_clock_streaching_delay_clks=1;test_clock_streaching_delay_clks<=`MAX_CLOCK_STREACHING_DELAYS;test_clock_streaching_delay_clks++)
    begin
        i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
        $display("test_clock_streaching_delay_clks=%d",test_clock_streaching_delay_clks);
        i2c_nbytes_in=i2c_bytes_to_send_size;
        i2c_rw_mode=I2C_MODE_READ;
        i2c_addr_in=I2C_ADDRESS;
        i2c_write_data=8'bx;
        i2c_start=1;
        clk();
        i2c_start=0;
        //wait for start
        wait_for_start(2);
        //read the next 8 bits
        read_bits_from_i2c_sda_w(8);
        if(i2c_rx_byte[7:1]!=i2c_addr_in)
        begin
            $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
            $display("did not receive expected i2c address");
            $stop();
        end
        if(i2c_rx_byte[0]!=i2c_rw_mode)
        begin
            $display("did not receive expected i2c rw mode");
            $stop();
        end
        send_ack_nak(ACK);

        i2c_scl_private=0;//start clock streach
        for(i=0;i<test_clock_streaching_delay_clks;i++)clk();
        i2c_scl_private=1;//stop clock streach

        //send bytes for i2c to read
        for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
        begin
        i2c_tx_byte[7:0]=i2c_bytes_to_send[i2c_bytes_to_send_counter];
        //write the byte with some various place to streach the clock
        for(k=0;k<8;k=k+1)
        begin
            wait_for_scl_to_be(LOW,2);
            //$display("writing bit=%d of value=%b",k,i2c_tx_byte[number_of_bits_to_write-1-k]);
            i2c_sda_private=i2c_tx_byte[8-1-k];
            wait_for_scl_to_be(HIGH,2);
            wait_for_scl_to_be(LOW,2);
        end
        i2c_sda_private=NAK;
        read_bits_from_i2c_sda_w(1);//read the ack/nak
        if(i2c_bytes_to_send_counter!=(i2c_bytes_to_send_size-1))
        begin
            if(i2c_rx_byte[0]==NAK)
            begin
                $display("got nak from i2c master but master still has bytes to read");
                $stop();
            end
        end
        if(i2c_read_data!=i2c_tx_byte[7:0])
        begin
            $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
            $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
            $display("did not receive expected i2c data");
            $stop();
        end
        end
        if(i2c_rx_byte[0]==ACK)
        begin
            $display("got ack from i2c master but master doesn't have any more bytes to read");
            $stop();
        end
        //wait for stop
        wait_for_stop(2);
        if(!i2c_bus_idle)
        begin
            $display("bus not idle");
            $stop();
        end
        if(i2c_tranfer_failed_detected)
        begin
            $display("i2c_tranfer_failed_detectedn");
            $stop();
        end
    end



endtask

task TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK_FOR_LAST_BYTE();
    $display("test write bytes to slave fails if sends no data ack for last byte...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_WRITE;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=i2c_bytes_to_send[0];
    i2c_expected_byte=i2c_write_data;
    i2c_start=1;
    clk();
    i2c_start=0;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    //read the bytes the i2c device sends and send back acks on all but the last one
    //this should cause the i2c master to signal transfer failed
    for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_write_data=i2c_bytes_to_send[i2c_bytes_to_send_counter+1];
        read_bits_from_i2c_sda_w(8);
        if(i2c_bytes_to_send_counter<(i2c_bytes_to_send_size-1))send_ack_nak(ACK);
        else send_ack_nak(NAK);
        if(i2c_rx_byte[7:0]!=i2c_expected_byte)
        begin
            $display("received data=%B (%h)",i2c_rx_byte[7:0],i2c_rx_byte[7:0]);
            $display("did not receive expected i2c data");
            $stop();
        end
        if(i2c_bytes_to_send_counter>=(i2c_bytes_to_send_size-1))break;
        i2c_expected_byte=i2c_write_data;
    end
    if(!i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected was expected but didn't happen");
        $stop();
    end
    //master should stop as we sent a nak
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
endtask

task TEST_CONTINIOUS_START_TRIGGER();
    $display("test continious start trigger for write then read some stuff back...");
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_WRITE;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=i2c_bytes_to_send[0];
    i2c_expected_byte=i2c_write_data;
    i2c_start=1;
    clk();
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    //read the bytes the i2c device sends and send back acks 
    for(i2c_bytes_to_send_counter=1;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_write_data=i2c_bytes_to_send[i2c_bytes_to_send_counter];
        read_bits_from_i2c_sda_w(8);
        send_ack_nak(ACK);
        if(i2c_rx_byte[7:0]!=i2c_expected_byte)
        begin
            $display("received data=%B (%h)",i2c_rx_byte[7:0],i2c_rx_byte[7:0]);
            $display("did not receive expected i2c data");
            $stop();
        end
        i2c_expected_byte=i2c_write_data;
    end
    read_bits_from_i2c_sda_w(8);
    send_ack_nak(ACK);
    if(i2c_rx_byte[7:0]!=i2c_expected_byte)
    begin
        $display("received data=%B (%h)",i2c_rx_byte[7:0],i2c_rx_byte[7:0]);
        $display("did not receive expected i2c data");
        $stop();
    end
    //change mode to read while still transmitting to produce a repeated start
    i2c_nbytes_in=i2c_bytes_to_send_size;
    i2c_rw_mode=I2C_MODE_READ;
    i2c_addr_in=I2C_ADDRESS;
    i2c_write_data=8'bx;
    //wait for start
    wait_for_start(2);
    //read the next 8 bits
    read_bits_from_i2c_sda_w(8);
    if(i2c_rx_byte[7:1]!=i2c_addr_in)
    begin
        $display("received address=%B (%h)",i2c_rx_byte[7:1],i2c_rx_byte[7:1]);
        $display("did not receive expected i2c address");
        $stop();
    end
    if(i2c_rx_byte[0]!=i2c_rw_mode)
    begin
        $display("did not receive expected i2c rw mode");
        $stop();
    end
    send_ack_nak(ACK);
    i2c_start=0;
    //send bytes for i2c to read
    for(i2c_bytes_to_send_counter=0;i2c_bytes_to_send_counter<i2c_bytes_to_send_size;i2c_bytes_to_send_counter++)
    begin
        i2c_tx_byte[7:0]=i2c_bytes_to_send[i2c_bytes_to_send_counter];
        write_bits_to_i2c_sda_w(8);//write the byte
        read_bits_from_i2c_sda_w(1);//read the ack/nak
        if(i2c_bytes_to_send_counter!=(i2c_bytes_to_send_size-1))
        begin
            if(i2c_rx_byte[0]==NAK)
            begin
                $display("got nak from i2c master but master still has bytes to read");
                $stop();
            end
        end
        // $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
        // $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
        if(i2c_read_data!=i2c_tx_byte[7:0])
        begin
            $display("sent data=%B (%h)",i2c_tx_byte[7:0],i2c_tx_byte[7:0]);
            $display("received data=%B (%h)",i2c_read_data,i2c_read_data);
            $display("did not receive expected i2c data");
            $stop();
        end
    end
    if(i2c_rx_byte[0]==ACK)
    begin
        $display("got ack from i2c master but master doesn't have any more bytes to read");
        $stop();
     end
    //wait for stop
    wait_for_stop(2);
    if(!i2c_bus_idle)
    begin
        $display("bus not idle");
        $stop();
    end
    if(i2c_tranfer_failed_detected)
    begin
        $display("i2c_tranfer_failed_detected");
        $stop();
    end
endtask

initial begin

`ifdef TEST_FAILS_ON_NO_SLAVE_ATTATCHED_WRITE
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_FAILS_ON_NO_SLAVE_ATTATCHED_WRITE();
`endif
`ifdef TEST_FAILS_ON_NO_SLAVE_ATTATCHED_READ
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_FAILS_ON_NO_SLAVE_ATTATCHED_READ();
`endif

`ifdef TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK();
`endif

`ifdef TEST_WRITE_BYTES_TO_SLAVE
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_WRITE_BYTES_TO_SLAVE();
`endif

`ifdef TEST_READ_BYTES_FROM_SLAVE
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_READ_BYTES_FROM_SLAVE();
`endif

`ifdef TEST_READ_BYTES_FROM_SLAVE_WITH_CLOCK_STREACHING
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_READ_BYTES_FROM_SLAVE_WITH_CLOCK_STREACHING();
`endif

`ifdef TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK_FOR_LAST_BYTE
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_WRITE_BYTES_TO_SLAVE_FAILS_IF_SENDS_NO_DATA_ACK_FOR_LAST_BYTE();
`endif

`ifdef TEST_CONTINIOUS_START_TRIGGER
    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    TEST_CONTINIOUS_START_TRIGGER();
`endif

    i2c_clk_cycles_wait_and_assert_no_change_of_i2c_bus_state(5);
    $display("tests passed");

end



endmodule
