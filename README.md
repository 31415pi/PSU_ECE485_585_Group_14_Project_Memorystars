# PARSER MODULE



# ECE485 DRAM Scheduling Algorithm
Team members: Madison Klementyn, Jana Alhuneidi, Julia Bogdan Filipchuk, Bradley Chase

## Checkpoints
### Tuesday, November 2nd at noon
- [ ] Read and parse input trace file. (user specified name)
- [ ] Toggleable debug at runtime or compiletime
- [ ] Github repository setup
- [ ] Diagram showing mapping of address bits

### TBD
- [ ] Working code
  - [ ] Add items to queues
  - [ ] Remove items form queues
  - [ ] Maintain correct (sumulated) time
  - [ ] State what info neds to be in the queue
- [ ] Demo of correct output for DRAM commands

## Final Project Description

Your team is responsible for the simulation of a memory controller capable serving the
shared last level cache of a four core 3.2 GHz processor employing a single memory
channel. The system uses a relaxed consistency (XC) model. The memory channel is
populated by a single-ranked 8GB PC4-25600 DIMM (constructed with memory chips
organized as x8 devices with a 2KB page size and 24-24-24 timing). There is no ECC.
The memory controller must exploit bank parallelism and an open page policy. Assume
the DIMM is already initialized and all banks are in the pre-charged state. Do not model
additive latency or CRC. The controller should maintain a queue of 16 outstanding
memory requests.

You can use any programming language (e.g. C, C++, Java) or hardware description
language (e.g. SystemVerilog) you like to implement the simulation. Note that you are
not doing a synthesizable design, though you must keep track of DRAM cycle counts. 
