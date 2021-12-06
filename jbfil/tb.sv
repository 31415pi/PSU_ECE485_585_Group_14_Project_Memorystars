// ECE585 Dram Scheduler - Julia Filipchuk
/*
	Done with Checkpoint 2.
*/

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
  u64 queued;
  u64 done;
} mem_request;

typedef enum {
  PAGE_EMPTY,
  PRE,
  ACT,
  READ,
  DATA,
  PAGE_OPEN
} e_bank_state;

typedef struct {
  e_bank_state state;
  u64 cycles;
} bank;



// Global Parameters
int fd = 0;
string inp_filename = "input.txt";
bit inp_valid = 0;
bit inp_finished = 0;
req_input inp;
bit inp_echo = 0;

u64 cycles = 0; // Simulation cycles.


mem_request queue[$:16];
bank banks[16];
u64  next[$]; // Holds possible next events.

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

task automatic display_req(input mem_request req, input string state);
  begin
    $display("%8d  %8d  0x%8h %s", cycles, req.inp.access, req.inp.addr, state);
  end
endtask

task automatic update_queue();
  begin
    for (int i = 0; i < queue.size(); ++i) begin
      mem_request req = queue[i];
      if (req.done == cycles) begin
        display_req(req, "DONE");
        queue.delete(i); --i;
      end
    end
  end
endtask : update_queue

task automatic determine_next();
  u64 next_cycles, other_cycles;
  begin
    // Determine Next Event
    if (inp_valid && queue.size() < 16) begin
      assert (cycles < inp.cycles) else $error("Cycles Out of Order");
      if (cycles < inp.cycles) begin
        next.push_back(inp.cycles);
      end else begin
        next.push_back(cycles);
      end
    end
    for (int i = 0; i < queue.size(); ++i) begin
      next.push_back(queue[i].done);
    end
    
    // Check queue is non-empty
    if (next.size() == 0) begin
      $display("Next Event Queue is empty");
      $finish();
    end
    
    // Find minimum next cycles to advance to.
    next_cycles = next.pop_front(); // Start with first event.
    while (next.size() > 0) begin // Look through the queue for smaller events.
      other_cycles = next.pop_front();
      if (other_cycles < next_cycles) begin
        next_cycles = other_cycles;
      end
    end

    cycles = next_cycles;
    //$display("%8d  UPDATE inp_valid: %d, queue: %0d", cycles, inp_valid, queue.size());
  end
endtask : determine_next

module tb();
  //mem_request req;
  int loops_limit = 100;
  int loops = 0;
  initial begin
    initialize();
    
    cycles = 0;
    do begin
      read_input();
      
      if (inp_valid && inp.cycles <= cycles && queue.size() < 16) begin
        mem_request req;
        req.inp = inp;
        req.queued = cycles;
        req.done = cycles + 100;
        
        queue.push_back(req);
        display_req(req, "START");
        inp_valid = 0;
        continue;
      end
      
      determine_next(); // Updates Cycles.
      
      update_queue();
      
      if (++loops > loops_limit) begin
        $display("Hit Loop Limit");
        $finish();
      end
    end while (!inp_finished || queue.size() > 0);
  end
endmodule : tb

