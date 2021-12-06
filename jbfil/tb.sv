// ECE585 Dram Scheduler - Julia Filipchuk

typedef longint unsigned u64;
typedef int unsigned u32;
//typedef bit bool;

typedef struct {
  u64 cycles;
  u32 access;
  u64 addr;
} req_input;

typedef struct {
  req_input inp;
} mem_request;

// Global Parameters
mem_request queue[$:16];

int fd = 0;
string inp_filename = "input.txt";
bit inp_valid = 0;
bit inp_finished = 0;
req_input inp;
bit inp_echo = 1;

task initialize();
  begin
    if ($test$plusargs("show_read"))
      inp_echo = 1;
    else
      inp_echo = 0;
    
    if ($value$plusargs("inpfile=%s", inp_filename))
      $display("arg inpfile: %s", inp_filename);
    
    fd = $fopen(inp_filename, "r");
    if (!fd) begin
      $display("Unable to open file: %s", inp_filename);
      $finish();
    end
  end
endtask : initialize

task automatic read_input();
  begin
    if (!inp_valid) begin
      int res = $fscanf(fd, "%d %d %h", inp.cycles, inp.access, inp.addr);
      if (res < 0) begin
        inp_finished = 1;
      end
      else if (res != 3) begin
        $display("Read invalid number of parameters (%d). Expected 3.", res);
        $finish();
      end
      else begin
        inp_valid = 1;
        if (inp_echo) begin
          $display("%8d  %8d  0x%8h", inp.cycles, inp.access, inp.addr);
        end
      end
    end
  end
endtask

module tb();
  initial begin
    initialize();
    
    while (!inp_finished) begin
      read_input();
      inp_valid = 0;
    end
  end
endmodule : tb


