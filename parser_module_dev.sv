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
//					  	48b... lets use 64 as the input stream buffer/line:
//						64b-(2b+36b) = 30b for time. 
//		-Solution:		<8b>	<16b>	<4b>	<36b>
//						timing data - mem op begin at - op type - hex addy
//		-Width in hex:	2		4		1	9 = 16 hex width
//		-width in bin:	8b		16b		4b	36b = 64
//	Comment references:	
//		#1	parameters https://verificationguide.com/systemverilog/systemverilog-parameters-and-define/
//		#2	read input file	https://www.chipverify.com/systemverilog/systemverilog-file-io
module parser								//Parameters can be changed per module
  #(
    parameter TF_READ_BUFFER_WIDTH=64; 	//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH=64;		//Width of output from parser->MC
    parameter ADDR_WIDTH=36;			//width of addr portion of TF in
    parameter MEMOP_WIDTH=2;			//Width of mem op code of TF in
    parameter TF_MEMOP_TIME_WIDTH=8;	//Width of timestamp of TF in
    parameter PARSER_TIME_CODE=8;		//Width of parser timecode/info
    parameter IN_BUFF_SIZE=64;			//Width of MC buffer entry
    parameter IN_BUFF_CT=16;			//Depth of MC buffer (how many positions in buffer)
   )
  // ADD BEGIN 
  // ADD TIMING
  input  clk;			//"system clock"

  input  in_buff[TF_READ_BUFFER_WIDTH-1:0]; //1 line from file goes here

  output out_buff[P_OUTPUT_WIDTH-1:0]; //parser->MemController Unit

  logic CUR_CNT[TF_MEMOP_TIME_WIDTH-1:0];	//Count from inputting first line
  logic TARGET_ADDY[ADDR_WIDTH-1:0];		//Target addy for memop
  logic MEMOP_CMD[MEMOP_WIDTH-1:0];		//Memop command
  logic MEMOP_TIME[TF_MEMOP_TIME_WIDTH-1:0];//Time to perform memop(cycles)  

  //OPEN TRACEFILE	

  int fd_r;
  fd_r = $fopen("./tracefile.txt", "r");	//open tracefile in readmode
  if (fd_r)		$display("Tracefile opened");
  else		{	$display("Unable to open tracefile.");
             //error logic code;
            }
  //READ TRACEFILE
    //add timing conditionals -- switch case?
    while ($fscanf (fd_r, "%//scanf logic") == 2) 
      begin // parse input line into in_buff 
        $display ("display input");
    end
  
  //use IN_BUFF to read a line and hold it while the MEMOP_TIME and friends hold the previous lines info
  //error check see LINE 9 & 10
  //parse in_buff into various (logic) placeholders...    
  //check MC if ready
  //add MC ready input port
  //compare logic
  //compare memop time to system time
  //if MC ready and memop time & system time match, parse one line group to MC
  
endmodule parser
      
module mem_controller()

  logic BUFFER[IN_BUFF_CT-1:0][IN_BUFF_SIZE-1:0];//MC BUFFER - PACKED ARRAY - SPACIALLY CONTIGUOUS

endmodule mem_controller
      
module bus_intrfc_unit()
endmodule bus_interfc_unit
   
module policy()
endmodule policy
