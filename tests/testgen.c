
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>


#define ARRAY_SIZE(arr) (sizeof(arr)/sizeof(*arr))

// const uint64_t addr_mask = 0xFFFFFFFFFll;
// const uint64_t row_mask  = 0xFFFE00000ll;
// const uint64_t col_mask  = 0x0001FFC00ll;
// const uint64_t bnk_mask  = 0x000000300ll;
// const uint64_t grp_mask  = 0x0000000C0ll;
// const uint64_t sel_mask  = 0x00000003Fll;
// 
// const int row_shift = 21;
// const int col_shift = 10;
// const int bnk_shift =  8;
// const int grp_shift =  6;
// const int sel_shift =  0;

const int row_bits = 15;
const int col_bits = 11;
const int grp_bits =  2;
const int bnk_bits =  2;
const int sel_bits =  6;
const int sel_offs =  3; // offset by 3 bits.

// bank group : bank : row : column : fifo
// 2^2          :2^2   :2^15 : 2^11 :2^3
const int sel_shift =  0;
const int col_shift =  sel_bits;
const int row_shift =  sel_bits + col_bits;
const int bnk_shift =  sel_bits + col_bits + row_bits;
const int grp_shift =  sel_bits + col_bits + row_bits + bnk_bits;

const uint64_t addr_mask = ((1ull << (row_bits + col_bits + grp_bits + bnk_bits + sel_bits)) - 1);
const uint64_t row_mask  = ((1ull << row_bits) - 1) << row_shift;
const uint64_t col_mask  = ((1ull << col_bits) - 1) << col_shift;
const uint64_t grp_mask  = ((1ull << grp_bits) - 1) << grp_shift;
const uint64_t bnk_mask  = ((1ull << bnk_bits) - 1) << bnk_shift;
const uint64_t sel_mask  = ((1ull << sel_bits) - 1) << sel_shift;
const uint64_t off_mask  = ((1ull << sel_offs) - 1) << sel_shift;





enum cmd { READ, WRITE, FETCH };

FILE *tests_file = NULL;
FILE *test_file = NULL;
const char *test_prefix = NULL;
int test_num = 0;
int save_tests = 0;

void addr_write(int cycles, enum cmd cmd, uint64_t addr) {
	uint64_t addr_masked = addr & addr_mask & ~off_mask;
    if (save_tests) {
		fprintf(test_file,  "%d %1d 0x%09llX\n", cycles, cmd, addr_masked);
	} else {
		fprintf(tests_file, "%8d  %1d  0x%09llX\n", cycles, cmd, addr_masked);
	}
}

int64_t addr_create(int cycles, enum cmd cmd, int row, int col, int bnk, int grp, int sel) {
    int64_t addr = 0;
    
    assert(cmd <= FETCH);
    assert(row < (1 << row_bits));
    assert(col < (1 << col_bits));
    assert(bnk < (1 << bnk_bits));
    assert(grp < (1 << grp_bits));
    assert(sel < (1 << sel_bits >> sel_offs));
    
    addr |= (((uint64_t)row) << row_shift) & row_mask;
    addr |= (((uint64_t)col) << col_shift) & col_mask;
    addr |= (((uint64_t)bnk) << bnk_shift) & bnk_mask;
    addr |= (((uint64_t)grp) << grp_shift) & grp_mask;
    addr |= (((uint64_t)sel) << sel_shift << sel_offs) & sel_mask;
    
    
	uint64_t addr_masked = addr & addr_mask & ~off_mask;
	if (save_tests) {
		fprintf(test_file,  "%d %d 0x%09lX\n", cycles, cmd, addr_masked);
	}
	fprintf(tests_file, "%8d  %1d  0x%09lX", cycles, cmd, addr_masked);
    fprintf(tests_file, "  # row: %5d col: %4d bnk: %1d grp: %1d fifo: %1d", row, col, grp, bnk, sel);
    fprintf(tests_file, "\n");
}



void next_test(const char *msg) {
    char fn[256];
    ++test_num;
	
	if (save_tests) {
		snprintf(fn, 256, "%s_%02d.txt", test_prefix, test_num);
		if (test_file) fclose(test_file);
		fprintf(stderr, "Opening file: %s\n", fn);
		test_file = fopen(fn, "w");
	}
    
    fprintf(tests_file, "\n# Test %3d : %s\n", test_num, msg);
}

void comment(const char *msg) {
	
    fprintf(tests_file, "# %s\n", msg);
}



int gen_normal() {
	int cycles = 0;
	
	next_test("Check Each Position");
    addr_create(0, READ, 1, 0, 0, 0, 0);
    addr_create(0, READ, 0, 1, 0, 0, 0);
    addr_create(0, READ, 0, 0, 0, 1, 0);
    addr_create(0, READ, 0, 0, 1, 0, 0);
    addr_create(0, READ, 0, 0, 0, 0, 1);
    
    
    next_test("EMPTY single"); // Row not open 
    addr_create(0, READ, 1, 0, 0, 0, 0);
    addr_create(9, READ, 1, 0, 0, 1, 0); // Diff bank
    
    next_test("HIT single"); // Same column in open row.
    addr_create(0, READ, 1, 1, 1, 1, 0);
    addr_create(9, READ, 1, 2, 1, 1, 0);
    
    next_test("MISS single");  // Incorrect Row with Open row
    addr_create(0, READ, 1, 1, 1, 1, 0);
    addr_create(9, READ, 2, 1, 1, 1, 0);
    
    next_test("Bank group switch on a page hit");
    addr_create(cycles++, READ, 1, 0, 0, 0, 0);
    addr_create(cycles++, READ, 1, 0, 0, 0, 0);
    
    next_test("Consecutive banks READ"); cycles = 0;
    addr_create(cycles++, READ, 0, 0, 0, 0, 0);
    addr_create(cycles++, READ, 0, 0, 0, 1, 0);
    addr_create(cycles++, READ, 0, 0, 0, 2, 0);
    addr_create(cycles++, READ, 0, 0, 0, 3, 0);
    addr_create(cycles++, READ, 0, 0, 1, 0, 0);
    addr_create(cycles++, READ, 0, 0, 1, 1, 0);
    addr_create(cycles++, READ, 0, 0, 1, 2, 0);
    addr_create(cycles++, READ, 0, 0, 1, 3, 0);
    addr_create(cycles++, READ, 0, 0, 2, 0, 0);
    addr_create(cycles++, READ, 0, 0, 2, 1, 0);
    addr_create(cycles++, READ, 0, 0, 2, 2, 0);
    addr_create(cycles++, READ, 0, 0, 2, 3, 0);
    addr_create(cycles++, READ, 0, 0, 3, 0, 0);
    addr_create(cycles++, READ, 0, 0, 3, 1, 0);
    addr_create(cycles++, READ, 0, 0, 3, 2, 0);
    addr_create(cycles++, READ, 0, 0, 3, 3, 0);
    
    next_test("Consecutive columns READ. Same bank/grp."); cycles = 0;
    addr_create(cycles++, READ, 0,  0, 0, 0, 0);
    addr_create(cycles++, READ, 0,  1, 0, 0, 0);
    addr_create(cycles++, READ, 0,  2, 0, 0, 0);
    addr_create(cycles++, READ, 0,  3, 0, 0, 0);
    addr_create(cycles++, READ, 0,  4, 0, 0, 0);
    addr_create(cycles++, READ, 0,  5, 0, 0, 0);
    addr_create(cycles++, READ, 0,  6, 0, 0, 0);
    addr_create(cycles++, READ, 0,  7, 0, 0, 0);
    addr_create(cycles++, READ, 0,  8, 0, 0, 0);
    addr_create(cycles++, READ, 0,  9, 0, 0, 0);
    addr_create(cycles++, READ, 0, 10, 0, 0, 0);
    addr_create(cycles++, READ, 0, 11, 0, 0, 0);
    addr_create(cycles++, READ, 0, 12, 0, 0, 0);
    addr_create(cycles++, READ, 0, 13, 0, 0, 0);
    addr_create(cycles++, READ, 0, 14, 0, 0, 0);
    addr_create(cycles++, READ, 0, 15, 0, 0, 0);
    
    
    next_test("Bank switch on a page hit"); cycles = 0;
    addr_create(cycles++, READ, 0,  0, 0, 0, 0);
    addr_create(cycles++, READ, 0,  0, 1, 0, 0);
	
	
    next_test("Bank group switch followed by a bank switch on a page hit"); cycles = 0;
    addr_create(cycles++, READ, 0,  0, 0, 0, 0);
    addr_create(cycles++, READ, 0,  0, 0, 1, 0);
    addr_create(cycles++, READ, 0,  0, 1, 1, 0);
	
	
    next_test("Bank group switch on a page empty"); cycles = 0;
    addr_create(0, READ, 0,  0, 0, 0, 0);
    addr_create(1, READ, 0,  0, 0, 1, 0);
	
	
    next_test("Bank switch on a page empty"); cycles = 0;
    addr_create(0, READ, 0,  0, 0, 0, 0);
    addr_create(1, READ, 0,  0, 1, 0, 0);
	
	
    next_test("Bank group switch followed by a bank switch on a page empty"); cycles = 0;
    addr_create(0, READ, 0,  0, 0, 0, 0);
    addr_create(1, READ, 0,  0, 0, 1, 0);
    addr_create(2, READ, 0,  0, 1, 1, 0);
}

void gen_stress() {
	char buf[256] = "";
	//int counts[] = { 100 };
	int counts[] = { 100, 1000, 10000, 100000, 1000000 };
	int count = 0;
	
	for (int t = 0; t < ARRAY_SIZE(counts); ++t) {
		count = counts[t];
		sprintf(buf, "stress consecutive %d", count);
		test_num = count -1;
		next_test(buf);
		for (int i = 0; i < count; ++i) {
			addr_write(i, READ, (off_mask + 1) * i);
		}
	}
}

static uint64_t big_rand() {
	uint64_t val = rand();
	val = (val << 16ull) + rand();
	val = (val << 16ull) + rand();
	val = (val << 16ull) + rand();
	val = (val << 16ull) + rand();
	val = (val << 16ull) + rand();
	return val;
}
void gen_random() {
	char buf[256] = "";
	//int counts[] = { 100 };
	int counts[] = { 100, 1000, 10000, 100000, 1000000 };
	int count = 0;
	
	for (int t = 0; t < ARRAY_SIZE(counts); ++t) {
		count = counts[t];
		sprintf(buf, "stress random %d", count);
		test_num = count -1;
		next_test(buf);
		for (int i = 0; i < count; ++i) {
			addr_write(i, READ, big_rand() & addr_mask & ~off_mask);
		}
	}
}

int main(int argc, char *argv[])
{
    
	enum test_kind {
		test_specific,
		test_stress,
		test_random,
	} kind = test_specific;
	
	test_prefix = "test";
	
	
	tests_file = stdout;
	for (int i = 1; i < argc; ++i) {
		#define argchk(_arg) (_stricmp(argv[i], _arg) == 0)
		if (argchk("-save")) {
			save_tests = 1;
		}
		if (argchk("-stress")) {
			kind = test_stress;
			test_prefix = "stress_test";
		}
		if (argchk("-random")) {
			kind = test_random;
			test_prefix = "stress_random_test";
		}
	}
	
	switch (kind) {
	case test_specific:
		if (save_tests) {
			tests_file = fopen("tests.txt", "w");
		}
		gen_normal();
		break;
	case test_stress:
		gen_stress();
		break;
	case test_random:
		gen_random();
		break;
    }
	
    return 0;
}