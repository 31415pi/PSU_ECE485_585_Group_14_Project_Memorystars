//////////////////////////////////////////////////////////////////////////////
// dram_cmd.sv - Emulates the lifespan of a DRAM command
//
// Author:	Chase Bradley-West (chase.bradley.west@gmail.com)
// Date:	11-30-2021
//
// Description:
// ------------
//
/////////////////////////////////////////////////////////////////////////////

module dram_cmd
import dram_defs::*;
(
	input logic		clk,
	input logic[63:0]	counter,
	output dram_command_steps_t DRAM_STATUS,
	input dram_policy_t POLICY
);
	dram_command_steps_t s, S;
	dram_command_steps_t previous_step;
	dram_policy_t previous_policy = NULL;

	int Tras = 52;
	int Tcl = 24;
	int Trp = 24;
	int Tburst = 4;	
	int Trcd = 24;
	int Trrd_l = 6;
	int Trrd_s = 4;
	int Tccd_l = 8;
	int Tccd_s = 4;
	int clk_cycle_counter = 0;

	logic step_complete_flag = 1'b0;
	logic step_complete = 1'b0;
	logic print_once = 1'b1;
	logic[63:0] internal_counter;

	task act_event_different_bank(output step_complete);
		#(Trrd_l*2*5);
		step_complete = 1'b1;
	endtask
	
	task act_event_different_bank_group(output step_complete);
		#(Trrd_s*2*5);
		step_complete = 1'b1;
	endtask
	
	task act_event(output step_complete);
		#(Trcd*2*5)
		step_complete = 1'b1;
	endtask
	
	task pre_event(output step_complete);
		#(Trp*2*5);
		step_complete = 1'b1;
	endtask	

	task rdwr_event_different_bank(output step_complete);
		#(Tccd_l*2*5);
		step_complete = 1'b1;
	endtask
	
	task rdwr_event_different_bank_group(output step_complete);
		#(Tccd_s*2*5);
		step_complete = 1'b1;	
	endtask

	task rdwr_event(output step_complete);
		#(Tcl*2*5);
		step_complete = 1'b1;
	endtask	

	task data_event(output step_complete);
		#(Tburst*2*5);
		step_complete = 1'b1;
	endtask	

	task stop_events(output step_complete);
		step_complete = 1'b0;
	endtask

	
	always_comb begin
		if(step_complete_flag) step_complete = '1;
		if(previous_policy != NULL) begin if(previous_policy != POLICY) S = IDLE; end
		case(s)
			IDLE:    S = IDLE; 
			PRE:     if(step_complete) begin $display("%d IDLE", internal_counter); S = ACT;  step_complete = '0; end
			ACT:     if(step_complete) begin if(previous_step != IDLE) $display("%d PRE", internal_counter); S = RDWR; step_complete = '0; end
			RDWR:    if(step_complete) begin if(previous_step != IDLE) $display("%d ACT", internal_counter); S = DATA; step_complete = '0; end
			DATA:    if(step_complete) begin $display("%d RDWR", internal_counter); S = DONE; step_complete = '0; print_once = 1'b1; end
			DONE: if(S == DONE) begin if(print_once) begin $display("%d DATA", internal_counter); print_once = 1'b0; end end
			default: S = IDLE;
		endcase	

		case(POLICY)
			HIT: begin
				if(s == IDLE)  S <= RDWR;
			end
			MISS: begin		
				if(s == IDLE) S <= PRE;
			end
			EMPTY: begin		
				if(s == IDLE) S <= ACT;
			end
			default: ;
		endcase

	end

	// Updates the internal clock cycle counter, and issues the next steps for the DRAM command.
	// This also follows the 3-always FSM rule by updating the current state with the next state.
	always_ff@(posedge clk) begin
		case(POLICY)
			HIT: begin
				if(S == RDWR) rdwr_event(step_complete_flag); 
				else if(S == DATA) data_event(step_complete_flag);
				else if(S == DONE) begin stop_events(step_complete_flag); previous_policy = POLICY; end
			end
			MISS: begin		
				if(S == PRE) pre_event(step_complete_flag);
				else if(S == ACT) act_event(step_complete_flag);
				else if(S == RDWR) rdwr_event(step_complete_flag); 
				else if(S == DATA) data_event(step_complete_flag);
				else if(S == DONE) begin stop_events(step_complete_flag); previous_policy = POLICY; end
			end
			EMPTY: begin		
				if(S == ACT) act_event(step_complete_flag);
				else if(S == RDWR) rdwr_event(step_complete_flag); 
				else if(S == DATA) data_event(step_complete_flag);
				else if(S == DONE) begin stop_events(step_complete_flag); previous_policy = POLICY; end
			end	
			default: ;
		endcase
	
		if(s != S) previous_step <= s;	
		s <= S;
		internal_counter <= counter;
	end
	
endmodule: dram_cmd