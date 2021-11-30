// need to do:
// add proper time delays for various cycle dependencies
// sort parameter into file, so its not set  in each module
// add interface method
// cycle advance <> bidirectional updates
// age of mem entry is + 100 cycles vs simply every 100 cycles

module memory_controller
  #(
    parameter TF_READ_BUFFER_WIDTH = 	64,		//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH =		 	64,		//Width of output from parser->MC
    parameter ADDR_WIDTH =				36,		//width of addr portion of TF in
    parameter MEMOP_WIDTH =				12,		//Width of mem op code of TF in
    parameter TF_MEMOP_TIME_WIDTH =	 	12		//Width of timestamp of TF in
  )
  (
    input bit clock,
    input longint cycle,
    input bit data_rdy,
    input bit [(TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0]  data_read,
    output bit data_req,
    output bit shutdown
  );

  bit 	[ADDR_WIDTH-1:0] 			TARGET_ADDY;	//Target addy for memop
  bit 	[MEMOP_WIDTH-1:0] 			MEMOP_CMD;	//Memop command
  bit 	[TF_MEMOP_TIME_WIDTH-1:0] 	MEMOP_TIME;	//Time to perform memop(cycles)  

  logic [(TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0] buffer [$:15]; //bounded queue of data_read width and depth of 16
  //https://www.chipverify.com/systemverilog/systemverilog-queues

  always@(posedge clock)
    begin
      shutdown = 1'b1;
      //   $monitor("rq %b, data %x", data_req, data_read); 

      {MEMOP_TIME, MEMOP_CMD, MEMOP_TIME} = buffer[0];							//grab first buffer and split it
      if( (buffer.size() < 16) && (shutdown == 1) )// && (MEMOP_TIME != cycle) )	//when buffer isnt full, and not trying to shutdown
        begin
          data_req = 1'b1; // reqdata and wait 2
          #2;      
          if (data_rdy == 1) // if data is ready
            begin
              buffer = { buffer , data_read }; //grab the data from data_read and put in the end of the buffer
              data_req= 1'b0;			//stop requesting data
              $display($time," [M]CYCLE: %0d RECEIVED DATA!!            BUFFER SIZE: %D",cycle, buffer.size());
              #5;
            end
        end
      else
        data_req = 1'b0;

      if ((cycle % 100 == 0))// && (buffer.size() != 0) )			//if the cycle is at 100 then pop an entry into aether
        if(cycle > MEMOP_TIME)
         begin
           $display($time, " [M]CYCLE: %0d POPPING %p, BUFFER SIZE: %D", cycle, buffer.pop_front(), buffer.size() );
         end
      else begin end
      else //if (cycle > 100)
        begin
          //        shutdown = 1'b0;
        end
    end
endmodule
