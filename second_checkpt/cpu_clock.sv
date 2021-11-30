//	cpu_clock_sim
//	ECE485/585 - Fall 2021
//	Group 14
// 	Author: Madison Uxia Klementyn
//	Description:
//		Parsing module responsible for delivering CPU system clock
//		-Must:	Be a clock for a 3.2GHz quad core
//				3 200 000 000 clock cycles/second
//				312.5ps/clock cycle
// notes: datatypes in sv https://www.doulos.com/knowhow/systemverilog/systemverilog-tutorials/systemverilog-data-types/
// USEAGE:
module cpu_clock
    `timescale 1fs/1fs
  (
    input logic enable,// = 1,		//enable low active
    output logic clock// = 0
  );

  initial
    begin
      #0		clock = 0;
      while(!enable)
        begin
          #1562.5	assign clock = !clock;
        end
    end

endmodule : cpu_clock
