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
module parser								//Parameters can be changed per module
  #(
    parameter TF_READ_BUFFER_WIDTH=64, 	//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH=64,		//Width of output from parser->MC
    parameter ADDR_WIDTH=36,			//width of addr portion of TF in
    parameter MEMOP_WIDTH=2,			//Width of mem op code of TF in
    parameter TF_MEMOP_TIME_WIDTH=8,	//Width of timestamp of TF in
    parameter TAG_WIDTH=8,				//Width of tag/parser timecode/info
    parameter IN_BUFF_SIZE=64,			//Width of MC buffer entry
    parameter IN_BUFF_CT=16			//Depth of MC buffer (how many positions in buffer)
  );
  
  int unsigned CUR_CNT;		//Count from inputting first line
  int unsigned TARGET_ADDY;	//Target addy for memop
  int unsigned MEMOP_CMD;	//Memop command
  int unsigned MEMOP_TIME;	//Time to perform memop(cycles)  
  int unsigned TAG;			//parser tag, stripped in mc	
  string filename;
  
  //OPEN INFILE & TRACEFILE	
  initial 
    begin
      if ($test$plusargs ("infile"))
        $display("arg infile present");
      else
        $display("arg infile missing");

      int fd_r;
      fd_r = $fopen("tracefile.txt", "r");	//open tracefile in readmode
      if (fd_r)		$display("Tracefile opened");
      else			$display("Unable to open tracefile.");

      //READ TRACEFILE
      while ($fscanf (fd_r, "%d %d %X", MEMOP_TIME, MEMOP_CMD, TARGET_ADDY) == 3) 
        begin
          $display ("displaying input: %d %d %x", MEMOP_TIME, MEMOP_CMD, TARGET_ADDY);
        end
    end
endmodule :parser
