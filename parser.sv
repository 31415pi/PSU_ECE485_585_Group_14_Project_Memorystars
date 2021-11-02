// Code your design here
//	parser_module
//	ECE485/585 - Fall 2021
//	Group 14
// 	Author: Madison Uxia Klementyn
//	Description:
//		Parsing module responsible for reading Trace File (TF) 
//		-Must:	Read file
//				Check: temporal linearity - increasing time
//				Check: max 4 memory operations per clock cycle
//	Notable info:
//		-TF format: 	<time><operation><hex addy>
//		-Example:		<30>> <0,1,2>	 <0x01FF97000>
//		-Value Width:  	  8b	2b			 36b
//						64b-(2b+36b) = 30b for time. 
//		-Solution:		<8b>	<16b>	<4b>	<36b>
//						timing data - mem op begin at - op type - hex addy
//		-Width in hex:	2		4		1	9 = 16 hex width
//		-width in bin:	8b		16b		4b	36b = 64
//	Comment references:	
//		#1	parameters https://verificationguide.com/systemverilog/systemverilog-parameters-and-define/
//		#2	read input file	https://www.chipverify.com/systemverilog/systemverilog-file-io

// USEAGE:
// +define+SHOW_ALL compiler instruction shows all dev output
`ifdef SHOW_ALL
`define SHOW_INFILE
`define SHOW_FILENAME
`define SHOW_READ
`define SHOW_OPEN
`endif
module parser						//Parameters can be changed per module
  #(
    parameter TF_READ_BUFFER_WIDTH = 64,//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH =		 64,//Width of output from parser->MC
    parameter ADDR_WIDTH =			 36,//width of addr portion of TF in
    parameter MEMOP_WIDTH =			 4,	//Width of mem op code of TF in
    parameter TF_MEMOP_TIME_WIDTH =	 8,	//Width of timestamp of TF in
    parameter TAG_WIDTH =			 8	//Width of tag/parser timecode/info
//    parameter IN_BUFF_SIZE =		 64,//Width of MC buffer entry
//    parameter IN_BUFF_CT =			 16//Depth of MC buffer (how many positions in buffer)
    //   parameter PARSER_DEPTH =		 8//DEPTH OF PARSERS BUFFER
  );
  //  (
  //    input clk
  //  );
  `timescale 1fs/1fs
  //tracefile stored into parser buffer
//  bit  	[TF_MEMOP_TIME_WIDTH-1:0]	CUR_CNT ;	//Count from INPT first line
  bit 	[ADDR_WIDTH-1:0] 			TARGET_ADDY;
 //Target addy for memop
  bit 	[MEMOP_WIDTH-1:0] 			MEMOP_CMD;			//Memop command
  bit 	[TF_MEMOP_TIME_WIDTH-1:0] 	MEMOP_TIME;	//Time to perform memop(cycles)  
  bit 	[TAG_WIDTH-1:0]				TAG;						//parser tag, stripped in mc	

  bit	[(TAG_WIDTH + TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0] INSTR [$]; // CUSTOM INSTRUCTION queue FOR BUS PROTOCOL...
  bit	[(TAG_WIDTH + TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0] TEMP ; // temp

  //file vars
  string filename;
  int fd_r;

  //clock vars
  bit clk_en = 0;						 // ENABLE CLOCK
  bit clk;

  //COUNTER
  reg [31:0]CYCLE = 1;
 
  enum									//state machine positionals
  {
    donothing = 	0,
    pushtostack =	1,
    popfromstack = 	2,
    endoffile = 	3
  } progress_t;

  typedef enum bit [7:0]
  {
    s0 = 8'b00000001 ,//<< donothing,	 	//do nothing
    s1 = 8'b00000001 << pushtostack,		//read line and push to stack
    s2 = 8'b00000001 << popfromstack,	//pop from stack onto bus
    s3 = 8'b00000001 << endoffile 		//end of file
  }state_t;

  state_t cs, ns;						//create state trackers
  
  //FSM vars
  bit A = 1;	//timing
  bit B = 0;	//action
  bit C = 1;	//unique
  int D = 0; 	//count
  //KICK IT OFF
  bit start = 1'b0;

  cpu_clock CPU_CLOCK					//instantiate the cpu clock module 
  (
    .enable (clk_en),
    .clock ( clk )
  );

	//optional dev output turn on by defining SHOW_READ or SHOW_ALL
	`ifdef SHOW_READ
		$monitor($time, " CYCLE: %h CS: %d NS: %d A: %b B: %b C: %b", CYCLE, cs, ns, A, B, C);
		$monitor($time, " TAG: %d: READ INPUT: %d %d 0x%X",TAG, MEMOP_TIME, MEMOP_CMD, TARGET_ADDY);
		$monitor($time, " INSTRUCTION[0]: %X", INSTR[0]);
		$monitor($time, " TARGET ADDY[0]: %x", INSTR[0][(ADDR_WIDTH)-1:0]);	
		$monitor($time, " MEM OP     [0]: %d", INSTR[0][(ADDR_WIDTH + MEMOP_WIDTH)-1:(ADDR_WIDTH)]);	
		$monitor($time, " CYCLE TIME [0]: %d", INSTR[0][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH)]);
		$monitor($time, " TAG        [0]: %d", INSTR[0][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH + TAG_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH  + TF_MEMOP_TIME_WIDTH)]);
	`endif

  initial 
    begin				     			//grab INFILE & open TRACEFILE	  	
      $monitor($time, " CYCLE: %d", CYCLE);
      if ($test$plusargs ("infile"))
        `ifdef SHOW_INFILE
        $display("Filename declared");
      else
        $display("Filename not declared");
      `endif
      if ($value$plusargs("infile=%s",filename))
        `ifdef SHOW_FILENAME
        $display("Finding file %s",filename);
      else
        $display("%s not found...",filename);
      `endif
      fd_r = $fopen(filename,"r");	   //open tracefile in readmode
      if (fd_r)	
        `ifdef SHOW_OPEN
        $display("Tracefile opened");
      else			$display("Unable to open tracefile.");
      `endif
    end									//finish initial block


  always@(posedge clk) begin : nxt_st	//next state block evaluated at every clock HIGH -- might need to change to any edge**
    cs = (start == 0) ? s1 : ns;		//getting the state machine to first state or loading the current state update
    TAG = 0;
    start = 1;							// we began so no more start requirement. //replace this bit with TOP LEVEL TB!**
    CYCLE = CYCLE + 1;					//increment cycle counter
    unique case(1'b1)
      cs[0]:	begin 								//
					ns = ({ABC} == 110) ? s1 : 
						 ({ABC} == 00X) ? s3 : s0;
				end					
      cs[1]:	begin
					ns = ({ABC} == 110) ? s2 : s1;   //read a line
				end
	  cs[2]:	begin
					ns = ({ABC} == 1X1) ? s0 :
					ns = ({ABC} == AX0) ? s1 :
					ns = ({ABC} == 0XX) ? s3 : s2;
				end
	  cs[3]:	begin
					ns = ({ABC} == 01X) ? s4 :
					ns = ({ABC} == 110) ? s3;
				end
	  cs[4]:	begin
					ns = ({ABC} == 110) ? s1 :
					ns = ({ABC} == 101) ? s0 : s4;
				end
    endcase // end case block 
  end	: nxt_st//end posed clk blk

  always_comb : fileop//current state block for file data ops
	unique case(1'b1)
	  cs[0]:	begin 
					B = (C == 0) ? 1 : 0;
					B = (A == 0) ? 0 : 1;
				end	//nop
  	  cs[1]:	begin		//read a line
				   if( $fscanf (fd_r, "%d %d %X", MEMOP_TIME, MEMOP_CMD, TARGET_ADDY ) ==3) // CREATE A COUNTER FOR LINES READ**
					  begin
					  end						//finish readline from tracefile
				   else // error or empty line
					  begin
					    B = 1;
						C = 0;
					  end // end error on read line 
				end // end cur state 1
	  cs[2]:	begin		//push to stack
					TEMP = {MEMOP_TIME-CYCLE,MEMOP_TIME,MEMOP_CMD,TARGET_ADDY};	//GENERATE INSTRUCTION AND STORE
					INSTR.push_front(TEMP);	 
				end		// finish push to stack
	  cs[3]:	begin //pop from stack to temp var
					temp = INSTR.pop_front();
					B = 1;
				end
	  cs[4]:	begin
					//placeholder for send to mc**
					B = (C == 0) ? 1 : 0;

				end
				endcase 
	 endcase //end always block
  end : fileop // end current state block for file data ops
//  always_comb begin : 

 always_comb : 

 always_comb : unique_count// FSM block for queue unique timestamp counting [C]
	case(INSTR.size())
		0:		begin
					C = 0;	
				end //queue unique time for memop = 0, 1
		1:		begin
					C = 0;
				end //queue unique time for memop = 2
		default:begin
					repeat(INSTR.size()-1)
						begin
							A = (INSTR[D][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH)] <  CYCLE) ? 1 : 0;
							C = (INSTR[D][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH)] == INSTR[D+1][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH)]) ? 0 : 1; 
							D = D + 1;
						end // end repeat block
					D = 0; // reset counter to zero
	endcase
 end unique_count// end FSM blk for queue count

endmodule :parser

INSTR[0][(ADDR_WIDTH + MEMOP_WIDTH + TF_MEMOP_TIME_WIDTH)-1:(ADDR_WIDTH + MEMOP_WIDTH)]