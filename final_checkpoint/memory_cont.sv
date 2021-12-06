//////////////////////////////////////////////////////////////////////////////
// memory_cont.sv - A memory controller for our DRAM simulation
//
// Authors:	Chase Bradley-West, Madison Uxia Klementyn
// Date:	06-01-2021
//
// Description:
// ------------
//
/////////////////////////////////////////////////////////////////////////////


module memory_controller
`timescale 1fs/1fs
import dram_defs::*;
  #(
    parameter TF_READ_BUFFER_WIDTH = 	64,		//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH =		 	64,		//Width of output from parser->MC
    parameter ADDR_WIDTH =				36,		//width of addr portion of TF in
    parameter MEMOP_WIDTH =				2,		//Width of mem op code of TF in
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

	logic[3:0] test1;
	logic[3:0] test2;

	logic[1:0] bank_group;
	logic[1:0] bank;
	logic[14:0] row;
	logic[10:0] column;
	
	logic [1:0] precharged_bank;
	logic [1:0] selected_group;
	logic[14:0] activated_row;
	logic rd_wr;
	dram_command_t cmd;

	dram_command_steps_t DRAM_STATUS;
	dram_policy_t POLICY;	
	logic different_bg;
	logic different_b;
	logic en;

	dram_cmd DUT( .*, .counter(cycle), .clk(clock) );



  always@(posedge clock)
    begin
      shutdown = 1'b1;

      //{MEMOP_TIME, MEMOP_CMD, TARGET_ADDY} = buffer[0];							//grab first buffer and split it
      if( (buffer.size() < 16) && (shutdown == 1) )// && (MEMOP_TIME != cycle) )	//when buffer isnt full, and not trying to shutdown
        begin
          data_req = 1'b1; // reqdata and wait 2
          #2;      
          if (data_rdy == 1) // if data is ready
            begin
              buffer = { buffer , data_read }; //grab the data from data_read and put in the end of the buffer
              data_req= 1'b0;			//stop requesting data
      	      {MEMOP_TIME, MEMOP_CMD, TARGET_ADDY} = buffer[buffer.size() - 1];	
	      $display("%d ENQUEUE: %d %d %X", cycle, MEMOP_TIME, MEMOP_CMD, TARGET_ADDY);
              #5;
            end
        end
      else
	test1 <= DUT.s;
	test2 <= DUT.S;
      if(test1 == test2)begin		//if the cycle is at 100 then pop an entry into aether
        if(cycle > MEMOP_TIME) begin // check to see if something is trying to send us back in time (error)
         begin
 	   //if(buffer.size() == 0) begin $display("END OF PROGRAM!"); $stop; end
	   begin
		// Ensures that the DRAM is not currently running a command
		if( (DUT.s == DUT.S) || ((DUT.s == IDLE) && (DUT.S == IDLE)) ) begin
			// Pop the queue, decode the instruction
			{MEMOP_TIME, MEMOP_CMD, TARGET_ADDY} = buffer.pop_front();	
			// Are we at the time that we wanted to execute the command?
			if(MEMOP_TIME <= cycle) begin

				$cast(cmd, MEMOP_CMD);
				bank_group = TARGET_ADDY[35:34];
				bank = TARGET_ADDY[33:32];
				row = TARGET_ADDY[31:17];
				column = TARGET_ADDY[16:6];
				
				// Handle the page polic
				if( (DUT.s == IDLE) && (DUT.S == IDLE) ) begin // Edge case: we just started the program
					activated_row = row;
					selected_group = bank_group;
					precharged_bank = bank;			
					if(cmd == WRITE) rd_wr <= 1; else rd_wr <= 0;
					POLICY <= MISS;
					$display("%d %s Bank Group %X Bank %X Row %X Column %X", cycle, cmd.name, bank_group, bank, row, column);	
				end else begin 
					if(row == activated_row) begin 
						different_b <= 0;
						different_bg <= 0;
						if(cmd == WRITE) rd_wr <= 1; else rd_wr <= 0;
						if(bank != precharged_bank) different_b <= 1;
						if(bank_group != selected_group) different_bg <= 1;
						POLICY <= HIT; 
					end
					else if(bank == precharged_bank) begin 
						different_b <= 0;
						different_bg <= 0;
						if(cmd == WRITE) rd_wr <= 1; else rd_wr <= 0;
						if(bank_group != selected_group) different_bg <= 1;
						if(bank != precharged_bank) different_b <= 1;
						POLICY <= EMPTY; 
					end
					else begin 
						different_b <= 0;
						different_bg <= 0;
						if(cmd == WRITE) rd_wr <= 1; else rd_wr <= 0;
						if(bank_group != selected_group) different_bg <= 1;
						if(bank != precharged_bank) different_b <= 1;
						POLICY <= MISS; 
					end
					activated_row = row;
					selected_group = bank_group;
					precharged_bank = bank;		

				end
				en <= 1;
				@(negedge clock);
				en <= 0; // Keeps the DRAM from running endlessly
			end else buffer = { buffer, { MEMOP_TIME, MEMOP_CMD, TARGET_ADDY } };
		end else begin
			// ... know when to stop the program.
 	   		if(buffer.size() == 0) begin #(600*2*1562.5) while(DUT.s != DUT.S) begin /*$display("%s %s", DUT.s.name, DUT.S.name)*/; end $stop; end
		end
   	   end
         end
	end
	end
	end
endmodule
