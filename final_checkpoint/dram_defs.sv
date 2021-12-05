package dram_defs;

// This indicates what step the DRAM command is in.
typedef enum logic [3:0] {
	IDLE  = 4'b0000, // DOING NOTHING
	PRE   = 4'b0001, // PRECHARGE ROW
	ACT   = 4'b0010, // ACTIVATE
	RDWR  = 4'b0011, // READ or WRITE TO COLUMN
	DATA  = 4'b0100, // DATA OUT IS OUT
	RRDS  = 4'b0101,
	RRDL  = 4'b0110,
	CCDS  = 4'b0111,
	CCDL  = 4'b1000,
	DONE  = 4'b1001
}dram_command_steps_t;

// This determines what steps to take
typedef enum logic [3:0] {
	NULL	   = 4'b0000,
	HIT        = 4'b0001,
	EMPTY      = 4'b0010,
	MISS       = 4'b0011
}dram_policy_t;


endpackage: dram_defs
