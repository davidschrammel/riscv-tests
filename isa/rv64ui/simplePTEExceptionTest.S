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

# set, and read the mpk register
li t3, 0x80123456789ABCDE
csrw CSR_MPK, t3

csrr a3, CSR_MPK
sub t3, a3, t3

bnez t3, die
csrw CSR_MPK, x0

# read and save the current mtvec
csrr t3, CSR_MTVEC

# set own mtvec to leave userspace after we're done
la a3, my_mtvec_handler
ori a3, a3, 1
csrw CSR_MTVEC, a3

# register stvec handler
la a3, my_stvec_handler
ori a3, a3, 1
csrw CSR_STVEC, a3

# register utvec handler virtual address
la a3, utvec_handler
li t0, PAGE_ZERO
sub a3, a3, t0
ori a3, a3, 1
csrw CSR_UTVEC, a3

li TESTNUM, 2
csrr t1, medeleg
csrr t1, sedeleg

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
  j fail_skip_i
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
  j my_synchronous_exception # fail_skip_i
  j fail_skip_i

my_synchronous_exception:
  li a0, 0x12345678
  # // To successfully complete the test the content of the register MUST be 0x2800
  csrr t1, CSR_MPK
  li t2, 0x2800
  beq t1,t2, no_ecall
  li a7, 0x2
  j no_ecall
m_ecall_end:
  li a0, 0xDEADDEAD
no_ecall:
  li t0, 0xAAAAAAAA
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
page_table_leaf_entry_4: .dword 0b0000000101 << PTE_PKEY_SHIFT | (( PAGE_THREE / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D

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
1:
  # // if key has to be incremented too often there's an error
  li t5, 0x2801
  csrr t4, CSR_MPK
  bgeu t4, t5, die_u
  # 3 and 7
  addi TESTNUM, TESTNUM, 1
  # load dummy address on same page
  la t1, dummy
  lwu t0, 0(t1)
  li t1, 0x000123456
  bne t0, t1, die_u
  # 4 and 8
  addi TESTNUM, TESTNUM, 1
  # load dummy address on other page (should work)
  la t1, dummy_6
  lwu t0, 0(t1)
  li t1, 0xCEAEBEBA
  bne t0, t1, die_u
  # 5 and 9
  addi TESTNUM, TESTNUM, 1
  # load dummy address on other page (should fail)
  la t1, dummy_10
  lwu t0, 0(t1)
  li t1, 0xBEEFDEAD
  bne t0, t1, die_u
  # 6 and 10
  addi TESTNUM, TESTNUM, 1
  # load dummy address on other page (should fail)
  la t1, dummy_15
  li t0, 0xCAFECAFE
  sw t0, 0(t1)
  li t0, 0x0
  lwu t0, 0(t1)
  li t1, 0xCAFECAFE
  bne t0, t1, die_u
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  # load 1 to subtracttion and indication for the utvec handler on the tested round
  li a2, 0x1
  sub a1, a1, a2
  bnez a1, 1b
  ecall

die_u:
  li a7, 0x1
  ecall


# vectored utvec handler
.align 8
utvec_handler:
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
  j fail_u
  j my_synchronous_uexception
  j fail_u

my_synchronous_uexception:
  csrr t4, ucause
  li t5, 0x12345678
  csrw CSR_USCRATCH, t5
  # load the missing key and do a key increment for the first pass
  csrr t4, CSR_MPK
  bnez a2, keyloading_testrun_2
  # mask and keyslot 0
  andi t5, t4, 0x3FF
  add t5, t5, -0x2
  # set to writeable if key is 2
  bnez t5, no_writeenable
  li t5, 0x800
  or t4, t4, t5
no_writeenable:
  addi t4, t4, 0x1
  j write_mpk
keyloading_testrun_2:
  csrr t4, CSR_MPK
  li t5, 0x3FF800
  and t5, t4, t5
  srli t5, t5, 11
  add t5, t5, 0x1
  slli t4, t5, 11
write_mpk:
  csrw CSR_MPK, t4
  li t5, 0xAAAAAAAA

  uret

fail_u:
  li a0, 0xDEADBEEF
  csrr t2, uepc
  ADDI t2,t2,8
  csrw uepc, t2
  li t0, 0xAAAAAAAA
  uret

# dummy data on separate page to test everything
.align 12
dummy_5: .word 0x00000123
dummy_6: .word 0xCEAEBEBA
dummy_7: .word 0x88888888
dummy_8: .word 0x12345ABC
dummy_9: .word 0x11111111

# dummy data on separate page to test everything
.align 12
dummy_10: .word 0xBEEFDEAD
dummy_11: .word 0xBEEFDEAD
dummy_12: .word 0xBEEFDEAD
dummy_13: .word 0xBEEFDEAD
dummy_14: .word 0xBEEFDEAD

# dummy data on separate page to test everything
.align 12
dummy_15: .word 0xBEEFBEEF
dummy_16: .word 0xBEEFDEAD
dummy_17: .word 0xBEEFDEAD
dummy_18: .word 0xBEEFDEAD
dummy_19: .word 0xBEEFDEAD

RVTEST_DATA_END
