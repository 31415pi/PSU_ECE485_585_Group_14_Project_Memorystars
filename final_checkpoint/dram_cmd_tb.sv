//////////////////////////////////////////////////////////////////////////////
// carwash_fsm.sv - Testbench for my carwash finite state machine
//
// Author:	Chase Bradley-West (chase.bradley.west@gmail.com)
// Date:	06-01-2021
//
// Description:
// ------------
// This is the test bench from my previous homework assignment,
// except this time I spiced it up a bit, added a few more bells and whistles,
// and most importantly I traverse ALL possible paths instead of just a few.
//
/////////////////////////////////////////////////////////////////////////////


module dram_cmd_tb
import dram_defs::*;
#(
	parameter DUTY = 5
);

	logic[63:0] counter;	
	// Inputs
	logic	clk;

	// Outputs
	dram_command_steps_t DRAM_STATUS;
	dram_policy_t POLICY;	
	logic different_bg;
	logic different_b;
	logic en;

	dram_cmd DUT( .* );

	// Set up the monitors we want the test bench to display... it's pretty gross
	initial begin
		counter = '0;
		en = '0;
		different_b = '0;
		different_bg = '0;
		POLICY = NULL;
		//$monitor("%d %s", DUT.S.name,  DUT.s.name);
		//$monitor("%d", counter);
	end

	// Clock generator. 
	always begin
		#DUTY clk = 1;
		#DUTY clk = 0;	
	end

	always@(posedge clk) begin
		counter <= counter + 1;
	end
	
	// Implicit FSM
	initial begin: generator
		$display("%d EXECUTING A MISS SIMULATION", counter);
		en <= 1;
		POLICY <= MISS;
		#DUTY
		en <= 0;
		#1200
		$display("%d EXECUTING A HIT SIMULATION", counter);
		POLICY <= HIT;
		en <= 1;
		#DUTY
		en <= 0;
		#1200
		$display("%d EXECUTING AN EMPTY SIMULATION", counter);
		POLICY <= EMPTY;
		en <= 1;
		#DUTY;
		en <= 0;
		#1200
		$display("%d EXECUTING AN EMPTY SIMULATION WITH DIFFERENT BANK GROUP & DIFFERENT BANK", counter);
		different_b <= 1;
		different_bg <= 1;
		#DUTY
		en <= 1;
		POLICY <= EMPTY;
		#DUTY
		en <= 0;
		#1200	
		$display("%d EXECUTING AN EMPTY SIMULATION WITH DIFFERENT BANK GROUP", counter);
		different_bg <= 1;
		different_b <= 0;
		#DUTY
		en <= 1;
		POLICY <= EMPTY;
		#DUTY
		en <= 0;
		#1200	
		$display("%d EXECUTING AN EMPTY SIMULATION WITH DIFFERENT BANK", counter);
		different_b <= 1;
		different_bg <= 0;
		#DUTY
		en <= 1;
		POLICY <= EMPTY;
		#DUTY
		en <= 0;
		#1200	
		$display("%d EXECUTING A HIT SIMULATION WITH DIFFERENT BANK GROUP & DIFFERENT BANK", counter);
		different_b <= 1;
		different_bg <= 1;
		#DUTY
		en <= 1;
		POLICY <= HIT;
		#DUTY
		en <= 0;
		#1200	
		$display("%d EXECUTING A HIT SIMULATION WITH DIFFERENT BANK GROUP", counter);
		different_bg <= 1;	
		different_b <= 0;
		#DUTY
		en <= 1;
		POLICY <= HIT;
		#DUTY
		en <= 0;
		#1200	
		$display("%d EXECUTING A HIT SIMULATION WITH DIFFERENT BANK", counter);
		different_b <= 1;
		different_bg <= 0;
		#DUTY
		en <= 1;
		POLICY <= HIT;
		#DUTY
		en <= 0;
		#1200	

	$stop;
	end: generator

endmodule: dram_cmd_tb
