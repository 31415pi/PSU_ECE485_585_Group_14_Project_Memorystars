
`timescale 1ns/1ns

module tb();
	initial begin
		string filename;

		$display("\n\n");
		$display("ece585 - Julia Filipchuk");

		if ($test$plusargs ("infile"))
			$display("arg infile present");
		else
			$display("arg infile missing");

		if ($value$plusargs ("infile=%s", filename))
			$display("arg infile = %s", filename);
		
		$display("\n\n");
	end
endmodule : tb

