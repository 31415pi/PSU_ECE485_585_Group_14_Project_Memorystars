package dram_defs;

// This indicates what step the DRAM command is in.
typedef enum logic [2:0] {
	IDLE  = 3'b000, // DOING NOTHING
	PRE   = 3'b001, // PRECHARGE ROW
	ACT   = 3'b010, // ACTIVATE
	RDWR  = 3'b011, // READ or WRITE TO COLUMN
	DATA  = 3'b100, // DATA OUT IS OUT
	BANK  = 3'b101,
	BGRP  = 3'b110,
	DONE  = 3'b111
}dram_command_steps_t;

// This determines what steps to take
typedef enum logic [3:0] {
	NULL	   = 4'b0000,
	HIT        = 4'b0001,
	EMPTY      = 4'b0010,
	MISS       = 4'b0011,
	HIT_LONG   = 4'b0100,
	HIT_SHORT  = 4'b0101,
	MISS_LONG  = 4'b0110,
	MISS_SHORT = 4'b0111
}dram_policy_t;


endpackage: dram_defs
