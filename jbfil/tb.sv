// ECE585 Dram Scheduler - Julia Filipchuk

typedef longint unsigned u64;
typedef int unsigned u32;
//typedef bit bool;

parameter max_u64 = 64'hFFFF_FFFF_FFFF_FFFF;

// Dram Timing Parameters.
parameter dram_cycle = 2; // Clock cycles per dram cycle.
parameter tRC    = dram_cycle * 76;
parameter tRAS   = dram_cycle * 52;
parameter tRRD_L = dram_cycle *  6;
parameter tRRD_S = dram_cycle *  4;
parameter tRP    = dram_cycle * 24; // Time to Precharge
parameter tRFC   = 350; // ns
parameter tCWD   = dram_cycle * 20;  // (CWL) 
parameter tCAS   = dram_cycle * 24;  // (CL)
parameter tRCD   = dram_cycle * 24; // Time to Activate Row
parameter tWR    = dram_cycle * 20;
parameter tRTP   = dram_cycle * 12;
parameter tCCD_L = dram_cycle *  8;
parameter tCCD_S = dram_cycle *  4;
parameter tBURST = dram_cycle *  4;
parameter tWTR_L = dram_cycle * 12;
parameter tWTR_S = dram_cycle *  4;
parameter REFI   = 7.8;  // us


typedef enum {
  READ, WRITE, FETCH
} e_reqest_access;

typedef struct {
  u64 cycles;
  u32 access;
  u64 addr;
} req_input;

typedef struct {
  req_input inp;
  int grp, bank, col, row, sel; // Components of address
  int bank_idx;
  
  u64 queued;
  u64 done; // Only for checkpoint 2
  u64 started;
  u64 finished;
  bit pending;
} mem_request;

typedef enum {
  EMPTY,
  CHARGED,
  OPEN
} e_bank_state;

typedef struct {
  u64 cycles;
  int bank_idx;
  req_input ident; // input identifier.
} bank_rw;

typedef struct {
  e_bank_state state;
  u64 cycles;
  bit pending; // Has pending operation.
  u64 done; // When current command is done.
  u64 next_act; // When next activate can happen.
  
  int row;              // row if in OPEN state.
  bank_rw scheduled[$]; // Queued Reads and Writes
} bank;



// Global Parameters
int fd = 0;
string inp_filename = "input.txt";
bit inp_valid = 0;
bit inp_finished = 0;
req_input inp;
bit inp_echo = 0;

u64 cycles = 0; // Simulation cycles.
bit dram_this_cycle = 0; // Set to mark a dram command has been sent this cycle.
u64 loops_limit = 0; // Set to limit max simulations cycles.

mem_request queue[$:16]; // Holds queue of memory requests
u64  next[$]; // Holds possible next events.
bank banks[16];
bank_rw scheduled[$]; // Holds pending reads/writes.
int last_grp = 100;


task initialize();
  begin
    if ($test$plusargs("show_read"))
      inp_echo = 1;
    else
      inp_echo = 0;
    
    $value$plusargs("loop_limit=%d", loops_limit);
    $value$plusargs("inpfile=%s", inp_filename);
    
    
    fd = $fopen(inp_filename, "r");
    if (!fd) begin
      $display("Unable to open file: %s", inp_filename);
      $finish();
    end
    
    for (int i = 0; i < $size(banks); ++i) begin
      banks[i].state = EMPTY;
      banks[i].pending = 0;
      banks[i].next_act = max_u64;
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

task automatic new_request(inout mem_request req, input req_input inp);
  begin
    req.inp = inp;
    req.grp  = inp.addr[30 +:  2];
    req.bank = inp.addr[29 +:  2];
    req.row  = inp.addr[17 +: 15];
    req.col  = inp.addr[ 6 +: 11];
    req.sel  = inp.addr[ 0 +:  6];
    req.pending = 0;
    req.bank_idx = req.grp * 4 + req.bank; // Build index into bank array.
  end
endtask : new_request;

// DRAM BANK MODEL
task automatic command_bank(inout bank bank, inout mem_request req);
  bank_rw rw;
  u64 extra_grp_delay;
  begin
    
    //assert (dram_this_cycle == 0) else $error("Already sent command this cycle");
    //assert (cycles & 1 == 0) else $error("Not in memory clock");
    dram_this_cycle = 0;
    
    case (bank.state)
      EMPTY: begin
        // PRE <bank group> <bank>
        $display("%d PRE %0d %0d", cycles, req.grp, req.bank);
        
        bank.pending = 1;
        bank.state = CHARGED;
        bank.done = cycles + tRP;
      end
      
      CHARGED: begin // BANK Charged
        $display("%d ACT %0d %0d", cycles, req.grp, req.bank);
        
        bank.pending = 1;
        bank.state = OPEN;
        bank.row = req.row;
        bank.done = cycles + tRCD;
        bank.next_act = cycles + tRAS;
      end
      
      OPEN: begin
        // TODO: transition to EMPTY? What is the timeout for this?
        if (req.row != bank.row) begin // PAGE MISS
          assert (bank.scheduled.size() == 0) else $error("Pending Data. Can't Precharge.");
          
          bank.pending = 1;
          bank.state = CHARGED;
          bank.done = cycles + tRP;
          if (bank.done < bank.next_act) begin
            bank.done = bank.next_act; // Need to wait for tRAS.
          end
        end
        
        else begin // PAGE HIT
          if (req.inp.access == READ || req.inp.access == FETCH) begin
            // RD  <bank group> <bank> <column> 
            $display("%d RD %0d %0d %0d", cycles, req.grp, req.bank, req.col);
          end else begin
            $display("%d WR %0d %0d %0d", cycles, req.grp, req.bank, req.col);
          end
          
          
          // Schedule a Read/Write event.
          rw.cycles = cycles + tCAS + tBURST;
          rw.bank_idx = req.bank_idx;
          rw.ident = req.inp;

          bank.scheduled.push_back(rw);
          scheduled.push_back(rw);
          
          //bank.pending = 1;
          //bank.state = OPEN;
          //req.done = cycles + dram_cycle; // Next possible time for command. 
          
          if (last_grp != req.grp) last_grp = req.grp;
          //else rw.cycles += = tCCD_L;
          
          // Set request as pending.
          req.started = cycles;
          req.pending = 1;
        end
      end
    endcase
  end
endtask : command_bank


task automatic offer_next_schedule();
  begin
    
  end
endtask

// Try to schedule the request.
task automatic schedule_request_try(input mem_request req);
  begin
    // If we have sent a request this memory cycle. Try next cycle.
    if (dram_this_cycle == 1) begin
      next.push_back((cycles + 2) & ~(64'd1)); // Schedule to send memory next cycle.
      return;
    end
    
    // Check if we can schedule this cycle. If not prep for next cycle.
    if (cycles & 1 != 0) begin
      next.push_back(cycles + 1); // Schedule to send memory next cycle.
      return;
    end
    
    // Send command to bank.
    command_bank(banks[req.bank_idx], req);
  end
endtask

// Schedule the next dram request.
task automatic schedule_dram_fifo(); // Schedule First
  mem_request req;
  begin
    // Pick first request.
    if (queue.size() > 0) begin
      req = queue[0];
      
      // If bank is not busy then schedule.
      if (req.pending == 0 && banks[req.bank].pending == 0) begin
        command_bank(banks[req.bank_idx], queue[0]); // May add to next
      end
    end
  end
endtask

// Schedule the next ready dram request.
task automatic schedule_dram_ready();
  mem_request req;
  bit req_scheduled;
  begin
    // Pick first request.
    for (int i = 0; i < queue.size(); ++i) begin
      req = queue[i];
      
      // If req not pending and bank is not busy then schedule.
      if (req.pending == 0 && banks[req.bank].pending == 0) begin
        command_bank(banks[req.bank_idx], queue[i]); // May add to next
        break;
      end
    end
  end
endtask


// Enumerate all dram events. Add to next queue.
task automatic offer_next_dram();
  begin
    for (int i = 0; i < $size(banks); ++i) begin
      if (banks[i].pending) begin
        next.push_back(banks[i].done);
      end
    end
    if (scheduled.size() > 0) begin // Add next read/write completion.
      next.push_back(scheduled[0].cycles);
    end
  end
endtask

// Serivice all banks at the current cycle count. Service any scheduled events.
task automatic advance_dram();
  bank_rw rw;
  mem_request req;
  bit req_matched = 0;
  begin
    for (int i = 0; i < $size(banks); ++i) begin
      if (banks[i].pending == 1 && banks[i].done == cycles) begin
        banks[i].pending = 0;
      end
      
      // Check if data burst is over.
      if (banks[i].scheduled.size() > 0 && banks[i].scheduled[0].cycles == cycles) begin
        rw = banks[i].scheduled.pop_front();
        
        // Update bank status.
      end
    end
    
    // Check if data burst is over.
    if (scheduled.size() > 0 && scheduled[0].cycles == cycles) begin
      rw = scheduled.pop_front();
      
      // Finish matching Request.
      for (int i = 0; i < queue.size(); ++i) begin
        if (queue[i].inp.cycles == rw.ident.cycles
            && queue[i].inp.access == rw.ident.access
            && queue[i].inp.addr == rw.ident.addr) begin
          req = queue[i];
          assert (req.pending == 1) else $error("Finished request that is not pending");
          
          queue.delete(i);
          
          req.finished = cycles;
          //display_req(req, "FINISHED");
          req_matched = 1;
          break;
        end
      end
      
      assert (req_matched) else $error("Request not found.");
    end
  end
endtask

task automatic display_req(input mem_request req, input string state);
  begin
    $display("%d  %8d  0x%8h %s", cycles, req.inp.access, req.inp.addr, state);
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


task automatic offer_next_input();
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
  end
endtask

task automatic offer_next_queue();
  begin
    for (int i = 0; i < queue.size(); ++i) begin
      next.push_back(queue[i].done);
    end
    
    // Check queue is non-empty
    if (next.size() == 0) begin
      $display("Next Event Queue is empty");
      $finish();
    end
  end
endtask

task automatic advance_cycles();
  u64 next_cycles, other_cycles;
  begin
    // Find minimum next cycles to advance to.
    next_cycles = max_u64; // Start with first event.
    while (next.size() > 0) begin // Look through the queue for smaller events.
      other_cycles = next.pop_front();
      if (other_cycles < next_cycles) begin
        next_cycles = other_cycles;
      end
    end

    // Can send memory request if new_cycles is even or change is more than 1 cycle.
    // TODO: Only works for dram_cycle <= 2. Otherwise won't clear flag properly.
    if (next_cycles % dram_cycle == 0 || next_cycles - cycles >= dram_cycle)
      dram_this_cycle = 0; // Reset dram sent this cycle.
    
    // Update Cycles. This is the only place this change can happen.
    assert (cycles != next_cycles) else begin
      $error("Cycles not advancing");
      $finish();
    end
    cycles = next_cycles;
    
    
    //$display("%8d  UPDATE inp_valid: %d, queue: %0d", cycles, inp_valid, queue.size());
  end
endtask : advance_cycles

module tb();
  //mem_request req;
  u64 loops = 0;
  initial begin
    initialize();
    
    cycles = 0;
    do begin
      read_input();
      
      if (inp_valid && inp.cycles <= cycles && queue.size() < 16) begin
        mem_request req;
        new_request(req, inp);
        req.queued = cycles;
        // req.done = cycles + 100; // Only for Checkpoint2.
        // display_req(req, "START"); // Only for Checkpoint2.
        
        queue.push_back(req);
        inp_valid = 0;
        continue;
      end
      
      // Try to schedule request. If a device wants to schedule but is off-cycle then
      // it will add the next memory_cycle to the next options.
      schedule_dram_fifo();
      //schedule_dram_ready();
      
      offer_next_input();
      //offer_next_queue(); // Only for Checkpoint2.
      offer_next_schedule();
      offer_next_dram();
      advance_cycles(); // Cycles are advanced.
      
      //update_queue(); // Only for Checkpoint2.
      advance_dram();
      
      if (loops_limit > 0 && ++loops > loops_limit) begin
        $error("Hit Loop Limit");
        $finish();
      end
    end while (!inp_finished || queue.size() > 0);
  end
endmodule : tb

