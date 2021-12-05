module parser							//Parameters can be changed per module
    `timescale 1fs/1fs
  #(
    parameter TF_READ_BUFFER_WIDTH = 	64,		//#1 Width of input buffer from TF
    parameter P_OUTPUT_WIDTH =		 	64,		//Width of output from parser->MC
    parameter ADDR_WIDTH =				36,		//width of addr portion of TF in
    parameter MEMOP_WIDTH =				12,		//Width of mem op code of TF in
    parameter TF_MEMOP_TIME_WIDTH =	 	12		//Width of timestamp of TF in
    //  parameter longint CYCLE = 			0
  )
  (
    input bit clk,
    input bit MCrequest,
    input bit fullstop,
    output bit clken,
    output bit send_to_mc,
    output bit [(TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0] TEMP
  );

  // longint CYCLE; 
  longint CYCLE;
  bit 	[ADDR_WIDTH-1:0] 			TARGET_ADDY;	//Target addy for memop
  bit 	[MEMOP_WIDTH-1:0] 			MEMOP_CMD;	//Memop command
  bit 	[TF_MEMOP_TIME_WIDTH-1:0] 		MEMOP_TIME;	//Time to perform memop(cycles)  
  //  bit	[(TF_MEMOP_TIME_WIDTH + MEMOP_WIDTH + ADDR_WIDTH)-1:0] TEMP ; // temp


  cpu_clock cpuclk
  (
    .enable(clken),
    .clock(clk)
  );

  memory_controller mc
  (
    .clock(clk),
    .cycle(CYCLE),
    .data_rdy(send_to_mc),
    .data_read(TEMP),
    .data_req(MCrequest),
    .shutdown(fullstop)
  );

  `timescale 1fs/1fs

  //file vars
  string filename;
  int fd_r;

  initial 
    begin
      clken = 1'b0;//grab INFILE & open TRACEFILE	 
      $display($time," parser instantiation");

      if ($test$plusargs ("infile"))
        $display($time," Filename declared");
      else
        $display($time," Filename not declared");
      if ($value$plusargs("infile=%s",filename))
        $display($time," Finding file %s",filename);
      else
        $display($time," %s not found...",filename);
      fd_r = $fopen(filename,"r");	   			//open tracefile in readmode
      if (fd_r)	
        $display($time," Tracefile opened");
      else $display($time," Unable to open tracefile.");
    end								//finish initial block

  always@(posedge clk) 
    begin				
      CYCLE = CYCLE + 1;
      if(MCrequest)// && fullstop)
        begin
          if( $fscanf(fd_r, "%d %d %X", MEMOP_TIME, MEMOP_CMD, TARGET_ADDY ) ==3) 
            begin
              $display($time," [P]CYCLE: %0d memoptime %d memop cmd %d target addy  %x temp %x",CYCLE, MEMOP_TIME, MEMOP_CMD, TARGET_ADDY, TEMP);
              TEMP = {MEMOP_TIME,MEMOP_CMD,TARGET_ADDY};
              $display($time, " [P]CYCLE: %0d FILE-->DATA_LINE: %P", CYCLE, TEMP);
              send_to_mc = 1; // signal to mc data ready          
              #5;
              send_to_mc = 0; // stop signalling data is ready
              #2;
              TEMP = 'b0; // zero out the temp buffer
            end
          else            // fscanf couldnt find anything in the file
            send_to_mc = 0; // signal to mc no data ready
          //      MCrequest = 1'b0;
        end
      //   if (fullstop)
      //   clken = 1'b0;
      // break;
    end
endmodule
