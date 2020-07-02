# See LICENSE for license details.

#*****************************************************************************
# simpleUserlevelException.S
#-----------------------------------------------------------------------------
#
# This is the most basic self checking test. If your simulator does not
# pass thiss then there is little chance that it will pass any of the
# more complicated self checking tests.
#

#include "riscv_test.h"
#include "test_macros.h"

#define CSR_MPK 0x046

//defines for user mode interrupts
#define CSR_USTATUS 0x000
#define CSR_UIE 0x004
#define CSR_UTVEC 0x005
#define CSR_USCRATCH 0x040
#define CSR_UEPC 0x041
#define CSR_UCAUSE 0x042
#define CSR_UTVAL 0x043
#define CSR_UIP 0x044

#define MPKEY_MISMATCH_FAULT 14
#define PAGE_ZERO 0x0000000080005000
#define PAGE_ONE 0x0000000080006000
#define PAGE_TWO 0x0000000080007000
#define PAGE_THREE 0x0000000080008000

#define PTE_PKEY_SHIFT 54

#define TESTVALUE_1 0x12345ABC
#define TESTVALUE_2 0xCEAEBEBA

#define ERROR_1 0b1
#define ERROR_2 0b10
#define ERROR_3 0b100
#define ERROR_4 0b1000
#define ERROR_5 0b10000
#define ERROR_6 0b100000


RVTEST_RV64M
RVTEST_CODE_BEGIN


# activate VM
li a0, (SATP_MODE & ~(SATP_MODE<<1)) * SATP_MODE_SV39
la a1, page_table_root_node
srl a1, a1, RISCV_PGSHIFT
or a1, a1, a0
csrw sptbr, a1
sfence.vma

# Set up MPRV with MPP=S, so loads and stores use S-mode
li a1, MSTATUS_MPRV
csrs mstatus, a1
# clear the MPP for usermode
li a1, MSTATUS_MPP
csrc mstatus, a1

# read and save the current mtvec
csrr t3, CSR_MTVEC

# set own mtvec to leave userspace after we're done
la a3, my_mtvec_handler
addi a3, a3, 0x1
csrw CSR_MTVEC, a3

# register stvec handler
la a3, my_stvec_handler
csrw CSR_STVEC, a3

# register utvec handler virtual address
la a3, utvec_handler
li t0, PAGE_ZERO
sub a3, a3, t0
csrw CSR_UTVEC, a3

li TESTNUM, 2
# delegate exceptions from machine mode to supervisor mode
li t1,  (1 << CAUSE_MISALIGNED_FETCH)    | \
        (1 << CAUSE_ILLEGAL_INSTRUCTION) | \
        (1 << MPKEY_MISMATCH_FAULT);
csrrs t4, medeleg, t1;

# delegate exceptions from supervisor mode to usermode
li t1,  (1 << CAUSE_MISALIGNED_FETCH)    | \
        (1 << CAUSE_ILLEGAL_INSTRUCTION) | \
        (1 << MPKEY_MISMATCH_FAULT);
csrrs t5, sedeleg, t1;

# prepare return to userspace by loading the virtual address into the mepc
la a0, superstart
sub a0, a0, t0
csrw mepc, a0
mret


.align 8
my_mtvec_handler:
  j my_synchronous_exception
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j m_ecall_end
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i

.align 8
my_stvec_handler:
  j my_synchronous_exception
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i
  j fail_skip_i

my_synchronous_exception:
  li a0, 0x12345678
m_ecall_end:
  bnez a7, end_procedure
  # // To successfully complete the test the content of the register MUST be 0x2800
  # // t2 holds the value of dummy_8 from the second time utvec was executed
  la t2, dummy_13
  lw t2, 0(t2)
  li t1, TESTVALUE_2

  # TESTVALUE_2 MUST NOT BE IN T2
  beq t1, t2, store_worked_error
  # TESTVALUE_1 should pass
  li t1, TESTVALUE_1
  beq t1, t2, end_procedure
store_worked_error:
  li a7, ERROR_6
end_procedure:
  # // Restore environment for pass
  li t0, 0x0
  csrw CSR_STVEC, t0
  csrw CSR_UTVEC, t0

  csrw medeleg, t0;
  csrw sedeleg, t0;

  csrw CSR_MTVEC, t3
  bnez a7, die
  j end

fail_skip_i:
  li a0, 0xDEADBEEF
  csrr t2, mepc
  ADDI t2,t2,8
  csrw mepc, t2
  li t0, 0xAAAAAAAA
  mret

end:
  li a0, 0xCAFEBABE
  li t0, 0xAAAAAAAA
  nop
  nop


RVTEST_PASS

die:
    RVTEST_FAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

TEST_DATA

# Set the dirty page bit because: privileged 1.10 p. 61
# The A and D bits are never cleared by the implementation. If the supervisor software does
# not rely on accessed and/or dirty bits, e.g. if it does not swap memory pages to secondary storage
# or if the pages are being used to map I/O space, it should always set them to 1 in the PTE to
# improve performance.

# root page table
.align 12
page_table_root_node: .dword (( 0x0000000080003000 / RISCV_PGSIZE) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_A

# intermediate paget table
.align 12
page_table_entry_1: .dword (( 0x0000000080004000 / RISCV_PGSIZE) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_A

# leaf page table with and without mpkeys
.align 12
page_table_leaf_entry_1: .dword (( PAGE_ZERO / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D
page_table_leaf_entry_2: .dword (( PAGE_ONE / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D
page_table_leaf_entry_3: .dword 0b0000000011 << PTE_PKEY_SHIFT | (( PAGE_TWO / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D


# t3 ... old mtvec DON'T overwrite!!
# a7 != ... befor an ecall means DIE
.align 12
dummy: .word 0x000123456
dummy_1: .word 0xCAFEBABE
dummy_2: .word 0xFFFFFFFF
dummy_3: .word 0xABCDEF12
dummy_4: .word 0xDEADBEEF
superstart:
  li t1, 0xA5A5A5A5
  li a1, 0x2
  li a2, 0x0

  # // load a value from a protected page wit wd = 1 (should work)
  # // test 3
  addi TESTNUM, TESTNUM, 1
  la t1, dummy_13
  li t2, TESTVALUE_1
  lwu t1, 0(t1)
  bne t1, t2, die_u

  # // This store should cause an exception necessary to pass the testcase
  # // test 4
  addi TESTNUM, TESTNUM, 1
  la t1, dummy_13
  li t2, TESTVALUE_2
  sw t2, 0(t1)
  nop
  nop
  nop
  nop
  ecall
  nop
  nop
  nop
  nop


die_u:
  li a7, ERROR_1
  ecall


# vectored utvec handler
.align 8
utvec_handler:
  j my_synchronous_uexception
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j fail_u
  j my_synchronous_uexception
  j fail_u

my_synchronous_uexception:
  # MUST be a MPKEY cause
  addi TESTNUM, TESTNUM, 1
  csrr t4, ucause
  li t5, 0xE
  bne t5, t4, wrong_cause

  # IF first exception load the key and return
  la t4, dummy_5
  lw t5, 0(t4)
  bnez t5, second_mpkey_ex
  addi t5, t5, 0x1
  sw t5, 0(t4)

  # load the key
  csrr t5, CSR_MPK
  ori t5, t5, 0x403
  csrw CSR_MPK, t5

  uret

second_mpkey_ex:
  # load the missing key and do a key increment for the first pass
  addi TESTNUM, TESTNUM, 1
  csrr t4, CSR_MPK
  # load mask for key 3
  andi t4, t4, 0x7FF
  li t5, 0x403
  bne t5, t4, wrong_key_loaded



  # jump over the next instruction to pass the testcase
  csrr t5, uepc
  ADDI t5,t5,16
  csrw uepc, t5
  uret
wrong_cause:
  li a7, ERROR_4
  ecall
wrong_key_loaded:
  li a7, ERROR_5
  ecall


fail_u:
  li a7, ERROR_3
  ecall

# dummy data on separate page to test everything
.align 12
dummy_5: .word 0x0
dummy_6: .word 0x11111111
dummy_7: .word 0x11111111
dummy_8: .word 0x11111111
dummy_9: .word 0x11111111

# dummy data on separate page to test everything
.align 12
dummy_10: .word 0xBEEFDEAD
dummy_11: .word 0xBEEFDEAD
dummy_12: .word 0xBEEFDEAD
dummy_13: .word TESTVALUE_1
dummy_14: .word 0xBEEFDEAD

RVTEST_DATA_END
