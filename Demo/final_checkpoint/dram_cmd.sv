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
`timescale 1fs/1fs
import dram_defs::*;
(
	input logic		clk,
	input logic[63:0]	counter,
	input logic		different_bg,
	input logic		different_b,
	input logic		en,
	input logic		rd_wr, // 0 for read, 1 for write
	input dram_command_t	cmd,
	input logic[1:0]	bank,
	input logic[1:0]	bank_group,
	input logic[14:0]	row,
	input logic[10:0]	column,
	input dram_policy_t POLICY,
	output dram_command_steps_t DRAM_STATUS

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
	int Tcwd = 20;
	int Twr = 20;
	int Telapsed = 0;
	
	int speed = 1562.5;

	logic step_complete_flag = 1'b0;
	logic step_complete = 1'b0;
	logic print_once = 1'b1;
	logic reset_counter = 1'b0;
	logic counter_reset = 1'b0;
	logic ras_display = 1'b0;
	logic first_instruction = 1'b1;
	logic hail_mary = 1'b1;
	logic[63:0] internal_counter;

	task act_event_different_bank(output step_complete);
		#(Trrd_l*2*speed);
		step_complete = 1'b1;
	endtask
	
	task act_event_different_bank_group(output step_complete);
		#(Trrd_s*2*speed);
		step_complete = 1'b1;
	endtask
	
	task act_event(output step_complete);
		if(first_instruction) begin
			#(Trcd*2*speed)
			;
		end
		step_complete = 1'b1;
	endtask
	
	task pre_event(output step_complete);
		if(first_instruction) begin
			#(Trp*2*speed);
			;
		end
		step_complete = 1'b1;
	endtask	

	task rdwr_event_different_bank(output step_complete);
		#(Tccd_l*2*speed);
		step_complete = 1'b1;
	endtask
	
	task rdwr_event_different_bank_group(output step_complete);
		#(Tccd_s*2*speed);
		step_complete = 1'b1;	
	endtask

	task rdwr_event(output step_complete);
		if(first_instruction) begin
			#(Tcl*2*speed);
			;
		end else if(POLICY == HIT) begin
			#(Tcl*2*speed);
			;
		end
		step_complete = 1'b1;
	endtask	

	task data_event(output step_complete);
		if(POLICY == HIT) begin ; end //$display("%s %s", s.name, S.name); #(Tcl*2*speed) ; end
		else if(first_instruction) begin
			if(rd_wr) begin
				#(Tburst*2*speed);
				#(Twr*2*speed);
				#(Tcwd*2*speed);
			end else #(Tburst*2*speed); // A data write is just Tburst
		end
		step_complete = 1'b1;
	endtask	

	task stop_events(output step_complete);
		step_complete = 1'b0;
	endtask

	
	always_comb begin
		if(counter_reset) reset_counter = 0;
		if(step_complete_flag) step_complete = '1;
		if(previous_policy != NULL) begin 
			if(en) 	begin 
				S = IDLE; 
				//$display("%d", Telapsed - 24);
				$display("%d %s Bank Group %X Bank %X Row %X Column %X", internal_counter, cmd.name, bank_group, bank, row, column);	
				Telapsed = 0;
				first_instruction = '0;
			end
		end
		case(s)
			IDLE:    S = IDLE; 
			PRE:     if(step_complete) begin 
					Telapsed = Telapsed + Trp;
					S = ACT;  
					step_complete = '0;
			end
			RRDS: 	 if(step_complete) begin 
					$display("%d RRDS", internal_counter - 0); 
					first_instruction = '1;
					Telapsed = Telapsed + Trrd_s + 24;
					if(different_b) S = RRDL;
					else S = RDWR;
					step_complete = '0;
			end
			RRDL:	if(step_complete) begin 
					$display("%d RRDL", internal_counter - 0); 
					S = RDWR; 
					step_complete = '0; 
					first_instruction = '1;
					Telapsed = Telapsed + Trrd_l; 
			end
			CCDS:	if(step_complete) begin
					$display("%d CCDS", internal_counter - 0);
					
					Telapsed = Telapsed + Tccd_s;	
					if(different_b) S = CCDL;
					else S = RDWR;
					first_instruction = '1;
					step_complete = '0;
			end
			CCDL:	if(step_complete) begin 
					$display("%d CCDL", internal_counter - 0); 
					S = DATA; 	
					step_complete = '0; 
					first_instruction = '1;
					Telapsed = Telapsed + Tccd_l + 24; 
			end
			ACT:    if(step_complete) begin 
				if(previous_step != IDLE) begin
					first_instruction = '1;
					$display("%d PRE", internal_counter - 0); 
				end
				first_instruction = '1;
				Telapsed = Telapsed + Trcd;
				S = RDWR; 
				step_complete = '0; 
			end
			RDWR:   if(step_complete) begin 
				if(previous_step != IDLE) $display("%d ACT", internal_counter - 0); 
				Telapsed = Telapsed + Tcl;
				S = DATA; 
				first_instruction = '1;
				step_complete = '0; 
			end
			DATA:   if(step_complete) begin 
				Telapsed = Telapsed + Tburst;
				if(rd_wr) begin
					Telapsed = Telapsed + Twr;
					Telapsed = Telapsed + Tcwd;
					$display("%d WR", internal_counter - 0); 
				end else begin
					// Let the row access strobe finish.
					if(POLICY == MISS) begin 
						if( (Telapsed-Trp) < Tras) begin 
							//$display("PAGE MISS! ADDING %d CYCLES!", (Tras- (Telapsed-Trp))); 
							Telapsed = Telapsed + (Tras - (Telapsed-Trp)); 
							ras_display = '1;
						end
						//else $display("%d %d", Telapsed, Tras);
					end
					$display("%d RD", internal_counter - 0); 
				end
				
				S = DONE; 
				step_complete = '0; 
				first_instruction = '1;
				print_once = 1'b1; 
			end
			DONE: if(S == DONE) begin 
				if(print_once) begin 
					if(ras_display) begin
						$display("%d DATA", internal_counter - 0); print_once = 1'b0;
						$display("%d RAS", internal_counter - 2);
						ras_display = '0;
					end else $display("%d DATA", internal_counter - 0); print_once = 1'b0; 
				end 
				first_instruction = '1;
			end
			default: S = IDLE;
		endcase	
		
		// This case switch statement
		// determines how the DRAM command should start
		case(POLICY)
			HIT: begin
				if(s == IDLE) begin
					//$display("%d %s Bank Group %X Bank %X Row %X Column %X", internal_counter, cmd.name, bank_group, bank, row, column);	
					if(different_bg) S <= CCDS;
					else if(different_b) S <= CCDL;
					else S <= RDWR;
				end
			end
			MISS: begin		
				if(s == IDLE) begin
					S <= PRE;
				end
			end
			EMPTY: begin		
				if(s == IDLE) begin
					if(different_bg) S <= RRDS;
					else if(different_b) S <= RRDL;
					else S <= ACT;
				end
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
				else if(S == CCDS) rdwr_event_different_bank_group(step_complete_flag);
				else if(S == CCDL) rdwr_event_different_bank(step_complete_flag);
				else if(S == DATA) begin data_event(step_complete_flag); end
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
				else if(S == RRDS) act_event_different_bank_group(step_complete_flag);
				else if(S == RRDL) act_event_different_bank(step_complete_flag);
				else if(S == RDWR) rdwr_event(step_complete_flag); 
				else if(S == DATA) data_event(step_complete_flag);
				else if(S == DONE) begin stop_events(step_complete_flag); previous_policy = POLICY; end
			end	
			default: ;
		endcase
	
		if(s != S) previous_step <= s;	
		s <= S;
		internal_counter <= counter;
		counter_reset <= 0;
	end
	
endmodule: dram_cmd
