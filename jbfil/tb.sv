// ECE585 Dram Scheduler - Julia Filipchuk
//
// Features
//  - fifo or ready based scheduling.
//  - satisfy requests even if not pending.

typedef longint unsigned u64;
typedef int unsigned u32;
//typedef bit bool;

parameter max_u64 = 64'hFFFF_FFFF_FFFF_FFFF;

// Address to Memory Organization
parameter u64 bits_adr = 33;
parameter u64 bits_row = 15;
parameter u64 bits_col = 11;
parameter u64 bits_grp =  2;
parameter u64 bits_bnk =  2;
parameter u64 bits_sel =  3; // Bytes Select.

typedef enum {
//MSB <-------------> LSB
  ROW, BNK, COL, GRP, SEL // Likely best address mapping.
  // We utilize all of the bank groups. Consecutive reads access different
  // groups. Since no time penalty for consecutive bank access we are not hurt
  // there.

  //ROW, BNK, GRP, COL, SEL // Issue long reads since group is constant almost
  //every time.

  //GRP, BNK, ROW, COL, SEL // Original Mapping. Utilizes only first bank for
  //all spatial accesses.
} e_addr_mapping;

parameter u64 shift_sel =  (SEL < SEL) * bits_sel + (SEL < GRP) * bits_grp + (SEL < BNK) * bits_bnk + (SEL < ROW) * bits_row + (SEL < COL) * bits_col;
parameter u64 shift_grp =  (GRP < SEL) * bits_sel + (GRP < GRP) * bits_grp + (GRP < BNK) * bits_bnk + (GRP < ROW) * bits_row + (GRP < COL) * bits_col;
parameter u64 shift_bnk =  (BNK < SEL) * bits_sel + (BNK < GRP) * bits_grp + (BNK < BNK) * bits_bnk + (BNK < ROW) * bits_row + (BNK < COL) * bits_col;
parameter u64 shift_row =  (ROW < SEL) * bits_sel + (ROW < GRP) * bits_grp + (ROW < BNK) * bits_bnk + (ROW < ROW) * bits_row + (ROW < COL) * bits_col;
parameter u64 shift_col =  (COL < SEL) * bits_sel + (COL < GRP) * bits_grp + (COL < BNK) * bits_bnk + (COL < ROW) * bits_row + (COL < COL) * bits_col;

parameter u64 mask_adr = ((1 << bits_adr) - 1);
parameter u64 mask_row = ((1 << bits_row) - 1) << shift_row;
parameter u64 mask_col = ((1 << bits_col) - 1) << shift_col;
parameter u64 mask_grp = ((1 << bits_grp) - 1) << shift_grp;
parameter u64 mask_bnk = ((1 << bits_bnk) - 1) << shift_bnk;
parameter u64 mask_sel = ((1 << bits_sel) - 1) << shift_sel;
parameter u64 mask_match = mask_row | mask_col | mask_grp | mask_bnk;


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

typedef enum {
  PAGE_TBD, PAGE_HIT, PAGE_MISS, PAGE_EMPTY
} e_page_result;

typedef enum {
  LOG_NONE,   // No extra info.
  LOG_PAGE,   // Show page HIT, MISS, EMPTY
  LOG_BANK,   // Show Bank command states.
  LOG_QUEUED, // Show queued requests.
  LOG_EXTRA,  // Show explicitly request information row, col, grp, bnk.
  LOG_CHECKS = 9  // Show checks, address map.
} e_log_level;

typedef struct {
  u64 cycles;
  u32 access;
  u64 addr;
} req_input;

typedef struct {
  req_input inp;
  u64 id;
  int grp, bnk, col, row, sel; // Components of address
  int bank_idx;
  u64 addr_match; // Portion of address that will match consecutive accesses.
  
  u64 queued;
  u64 done; // Only for checkpoint 2
  u64 started;
  u64 finished;
  bit pending;
  e_page_result page_res;
} mem_request;

typedef enum {
  EMPTY,
  CHARGED,
  OPEN
} e_bank_state;

typedef struct {
  u64 cycles;
  int bank_idx;
  u64 req_id; // input identifier.
  u64 addr_match;
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
// =============================================================================
int fd = 0;
string inp_filename = "input.txt";
bit inp_valid = 0;
bit inp_finished = 0;
u64 req_next_id = 0;
req_input inp;
bit inp_echo = 0;
int verbose = 0;

u64 cycles = 0; // Simulation cycles.
bit dram_this_cycle = 0; // Set to mark a dram command has been sent this cycle.
u64 loops_limit = 0; // Set to limit max simulations cycles.

mem_request queue[$:16]; // Holds queue of memory requests
u64  next[$]; // Holds possible next events.
bank banks[16];
bank_rw scheduled[$]; // Holds pending reads/writes.
int last_grp = 100;
// =============================================================================


task display_checks();
  begin
    if (verbose < LOG_CHECKS) return;
    
    $display("Address Organization");
    $display("        %64s %5s %5s", "mask", "bits", "shift");
    $display(" addr   %b %5d %5d", mask_adr, bits_adr, 0);
    $display(" row    %b %5d %5d", mask_row, bits_row, shift_row);
    $display(" col    %b %5d %5d", mask_col, bits_col, shift_col);
    $display(" grp    %b %5d %5d", mask_grp, bits_grp, shift_grp);
    $display(" bank   %b %5d %5d", mask_bnk, bits_bnk, shift_bnk);
    $display(" sel    %b %5d %5d", mask_sel, bits_sel, shift_sel);

    $finish();
  end
endtask

task initialize();
  begin

    // Read Command line args.
    if ($test$plusargs("show_read"))
      inp_echo = 1;
    else
      inp_echo = 0;
    
    if (!$value$plusargs("loop_limit=%d", loops_limit))
      loops_limit = 0;
    if (!$value$plusargs("inpfile=%s", inp_filename))
      inp_filename = "input.txt";
    if (!$value$plusargs("verbose=%d", verbose))
      verbose = 0;
    
    display_checks();

    // Assign initial values.

    // Open the input file. Close previous file if needed.
    if (fd) $fclose(fd);
    fd = $fopen(inp_filename, "r");
    if (!fd) begin
      $display("Unable to open file: %s", inp_filename);
      $finish();
    end
    
    for (int i = 0; i < $size(banks); ++i) begin
      banks[i].state = CHARGED; // Starts out charged.
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
    req.id = ++req_next_id;
    req.grp  = inp.addr[shift_grp +: bits_grp]; // TODO: Encode all of these as parameters.
    req.bnk  = inp.addr[shift_bnk +: bits_bnk];
    req.row  = inp.addr[shift_row +: bits_row];
    req.col  = inp.addr[shift_col +: bits_col];
    req.sel  = inp.addr[shift_sel +: bits_sel];
    req.pending = 0;
    req.addr_match = inp.addr & mask_match;
    req.bank_idx = req.grp * 4 + req.bnk; // Build index into bank array.
    req.page_res = PAGE_TBD;
  end
endtask : new_request;

// Output a memory request to the given bank.
task automatic command_bank(inout bank bank, inout mem_request req);
  bank_rw rw;
  u64 extra_grp_delay;
  begin
    
    assert (dram_this_cycle == 0) else $error("Already sent command this cycle");
    assert ((cycles & 1) == 0) else $error("Not in memory clock cycles=%0d", cycles);
    dram_this_cycle = 1; // Mark that command sent this cycle.
    
    case (bank.state)

      // This state marks non-charged with no row loaded. Currently not used!
      EMPTY: begin
        // PRE <bank group> <bank>
        $display("%d PRE %0d %0d", cycles, req.grp, req.bnk);
        assert(req.page_res != PAGE_TBD) else $error("Possible Invalid state.");
        
        bank.pending = 1;
        bank.state = CHARGED;
        bank.done = cycles + tRP;
      end
      
      CHARGED: begin // BANK Charged
        // ACT <bank group> <bank> <row>
        $display("%d ACT %0d %0d %0d", cycles, req.grp, req.bnk, req.row);
        if (req.page_res == PAGE_TBD) begin
          req.page_res = PAGE_EMPTY;
          log_req(LOG_PAGE, req, "ACTIVATE ROW {PAGE_EMPTY}");
        end else begin
          log_req(LOG_BANK, req, "ACTIVATE ROW");
        end
        
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

          // PRE <bank group> <bank>
          $display("%d PRE %0d %0d", cycles, req.grp, req.bnk);
          
          bank.pending = 1;
          bank.state = CHARGED;
          bank.done = cycles + tRP;
          if (bank.done < bank.next_act) begin
            bank.done = bank.next_act; // Need to wait for tRAS.
          end

          assert(req.page_res == PAGE_TBD); // Does this hold?
          if (req.page_res == PAGE_TBD) begin
            req.page_res = PAGE_MISS;
            log_req(LOG_PAGE, req, "PRECHARGE {PAGE_MISS}");
          end else begin
            log_req(LOG_BANK, req, "PRECHARGE");
          end
        end
        
        else begin // PAGE HIT
          if (req.inp.access == READ || req.inp.access == FETCH) begin
            // RD  <bank group> <bank> <column> 
            $display("%d RD %0d %0d %0d", cycles, req.grp, req.bnk, req.col);
          end else begin
            // WR  <bank group> <bank> <column>
            $display("%d WR %0d %0d %0d", cycles, req.grp, req.bnk, req.col);
          end

          if (req.page_res == PAGE_TBD) begin
            req.page_res = PAGE_HIT;
            log_req(LOG_PAGE, req, "SCHEDULED RW {PAGE_HIT}");
          end else begin
            log_req(LOG_BANK, req, "SCHEDULED RW");
          end
          
          
          // Schedule a Read/Write event.
          rw.cycles = cycles + tCAS + tBURST;
          rw.bank_idx = req.bank_idx;
          rw.req_id = req.id;
          rw.addr_match = req.addr_match;

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
// Either sends the memory request or adds to the next queue to singal we need
// to try again next cycle.
task automatic try_request(inout mem_request req);
  begin
    // If we have sent a request this memory cycle. Try next cycle.
    if (dram_this_cycle == 1) begin
      next.push_back((cycles + 2) & ~(64'd1)); // Schedule to send memory next cycle.
      return;
    end
    
    // Check if we can schedule this cycle. If not prep for next cycle.
    if ((cycles & 1) > 0) begin
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

      // Since only a the top request is scheduled... No need to check
      // addr_match.

      // If bank is not busy then schedule.
      if (req.pending == 0 && banks[req.bank_idx].pending == 0) begin
        try_request(queue[0]); // May add to next
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

      // Check if this request will be completed by scheduled transactions.
      // Since any matching will be to the same bank, no need to worry about
      // conflicts of order. First transaction will always schedule first.
      req_scheduled = 0;
      for (int j = 0; j < scheduled.size(); ++j) begin
        if (req.addr_match == scheduled[j].addr_match) begin
          req_scheduled = 1;
          break;
        end
      end
      if (req_scheduled == 1) continue;
      
      // If req not pending and bank is not busy then schedule.
      if (req.pending == 0 && banks[req.bank_idx].pending == 0) begin
        try_request(queue[i]); // May add to next
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
  u64 addr_match;
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
        //if (queue[i].inp.cycles == rw.ident.cycles
            //&& queue[i].inp.access == rw.ident.access
            //&& queue[i].inp.addr == rw.ident.addr) begin
        if (queue[i].id == rw.req_id) begin
          req = queue[i];
          assert (req.pending == 1) else $error("Scheduled request that is not pending");
          
          queue.delete(i);
          
          req.finished = cycles;
          req.pending = 0;
          log_req(LOG_BANK, req, "COMPLETED (scheduled)");
          req_matched = 1;
          addr_match = req.addr_match; // Get pattern for matching addresses.

          // Check for any queued requests completed by proximity.
          for (int j = 0; j < queue.size(); ++j) begin
            req = queue[j];
            // Matching addresses will have same row, bank, group, and column
            // but different select bits.
            if (req.addr_match == addr_match) begin
              assert(req.pending == 0) else $error("Request should not have been started.");
              req.finished = cycles;
              log_req(LOG_BANK, req, "COMPLETED (satisfied)");

              
              // Remove from queue. Maintain index.
              queue.delete(j); --j;
            end
          end

          return;
        end
        $error("Request not found in queue.");
        $finish();
      end
      
    end
  end
endtask

task automatic display_req(input mem_request req, input string state);
  begin
    if (verbose < LOG_EXTRA)
      $display("%d  %8d  0x%8h %s", cycles, req.inp.access, req.inp.addr, state);
    else
      $display("%d  %8d  0x%8h (grp: %1d, bnk: %1d, row: %5d, col: %4d) %s", cycles, req.inp.access, req.inp.addr, req.grp, req.bnk, req.row, req.col, state);
  end
endtask

task automatic log_req(input e_log_level level, input mem_request req, input string state);
  begin
    if (verbose >= level) display_req(req, state);
  end
endtask

// Update Queue. Depreciated after checkpoint 2.
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
        log_req(LOG_QUEUED, req, "QUEUED");
        
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

