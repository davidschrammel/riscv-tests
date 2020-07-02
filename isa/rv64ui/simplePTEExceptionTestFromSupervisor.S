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
#define PAGE_TABLE_LEVEL_0 0x0000000080002000
#define PAGE_TABLE_LEVEL_1 0x0000000080003000
#define PAGE_TABLE_LEVEL_2 0x0000000080004000
#define PAGE_ZERO 0x0000000080005000
#define PAGE_ZERO_OFF 0x80005000
#define PAGE_ONE 0x0000000080006000
#define PAGE_TWO 0x0000000080007000

#define PTE_PKEY_SHIFT 54

# DRAM_BASE          0x80000000
# RISCV_PGSIZE       4096


RVTEST_RV64M
RVTEST_CODE_BEGIN

  # Turn on VM
  li a0, (SATP_MODE & ~(SATP_MODE<<1)) * SATP_MODE_SV39
  la a1, page_table_1
  srl a1, a1, RISCV_PGSHIFT
  or a1, a1, a0
  csrw sptbr, a1
  sfence.vma


  # Set up MPRV with MPP=S, so loads and stores use S-mode
  li a1, ((MSTATUS_MPP & ~(MSTATUS_MPP<<1)) * PRV_S) | MSTATUS_MPRV
  csrs mstatus, a1

  # Try a faulting store to make sure dirty bit is not set
  li TESTNUM, 2
  li t2, 1
  sw t2, dummy - DRAM_BASE, a0

  # Set SUM=1 so user memory access is permitted
  li TESTNUM, 3
  li a1, ((MSTATUS_MPP & ~(MSTATUS_MPP<<1)) * PRV_S) | MSTATUS_SUM
  csrs mstatus, a1

  # Make sure SUM=1 works
  lw t0, dummy - DRAM_BASE
  bnez t0, die

  # Try a non-faulting store to make sure dirty bit is set
  sw t2, dummy - DRAM_BASE, a0

  # Make sure it succeeded
  lw t0, dummy - DRAM_BASE
  bne t0, t2, die

  # test access to page protected with mpkey
  lw a0, dummy_5 - DRAM_BASE
  lw a0, dummy_7  - DRAM_BASE
  # this should lead to an exception
  lw a0, dummy_10 - DRAM_BASE

 # Leave MPRV
 li t0, MSTATUS_MPRV
 csrc mstatus, t0

 # Make sure D bit is set
 lw t0, page_table_leaf_entry_1
 li a0, PTE_A | PTE_D
 and t0, t0, a0
 bne t0, a0, die

 # Enter MPRV again
 li t0, MSTATUS_MPRV
 csrs mstatus, t0

 # Make sure that superpage entries trap when PPN LSBs are set.
 li TESTNUM, 4
 lw a0, page_table_1 - DRAM_BASE
 or a0, a0, 1 << PTE_PPN_SHIFT
 sw a0, page_table_1 - DRAM_BASE, t0
 sfence.vma
 sw a0, page_table_1 - DRAM_BASE, t0
 j die

  RVTEST_PASS

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  csrr t0, mcause

  add t0, t0, -MPKEY_MISMATCH_FAULT
  nop;
  beqz t0, load_key
  nop;
  add t0, t0, MPKEY_MISMATCH_FAULT

  add t0, t0, -CAUSE_STORE_PAGE_FAULT
  bnez t0, die

  li t1, 2
  bne TESTNUM, t1, 1f
  # Make sure D bit is clear
  lw t0, page_table_leaf_entry_1
  and t1, t0, PTE_D
  bnez t1, die
skip:
  csrr t0, mepc
  add t0, t0, 4
  csrw mepc, t0
  mret
load_key:
  csrr t0, CSR_MPK
  ori t0, t0, 0x3
  csrw CSR_MPK, t0
  mret

1:
  li t1, 3
  bne TESTNUM, t1, 1f
  # The implementation doesn't appear to set D bits in HW.
  # Make sure the D bit really is clear.
  lw t0, page_table_leaf_entry_1
  and t1, t0, PTE_D
  bnez t1, die
  # Set the D bit.
  or t0, t0, PTE_D
  sw t0, page_table_leaf_entry_1, t1
  sfence.vma
  mret

1:
  li t1, 4
  bne TESTNUM, t1, 1f
  j pass

1:
die:
  RVTEST_FAIL


RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

# .align 12
# page_table_1: .dword (DRAM_BASE/RISCV_PGSIZE << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
#  dummey: .dword 0


.align 12
page_table_1: .dword (( 0x0000000080003000 / RISCV_PGSIZE) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_A
              .dword 0x0
              .dword (( 0x0000000080003000 / RISCV_PGSIZE) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_A

.align 12
page_table_entry_1: .dword (( 0x0000000080004000 / RISCV_PGSIZE) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_A
                    .dword 0x0
                    .dword 0x0

.align 12
page_table_leaf_entry_0: .dword (( DRAM_BASE / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
                         .dword 0x0
                         .dword (( PAGE_TABLE_LEVEL_0 / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
                         .dword (( PAGE_TABLE_LEVEL_1 / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
                         .dword (( PAGE_TABLE_LEVEL_2 / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
page_table_leaf_entry_1: .dword (( PAGE_ZERO / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
page_table_leaf_entry_2: .dword (( PAGE_ONE / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A
page_table_leaf_entry_3: .dword 0b0000000011 << PTE_PKEY_SHIFT | (( PAGE_TWO / RISCV_PGSIZE ) << PTE_PPN_SHIFT) | PTE_V | PTE_U | PTE_R | PTE_W | PTE_X | PTE_A

# t3 ... old mtvec DON'T overwrite
.align 12
.dword 0x0
dummy: .word 0x0
# dummy: .word 0xFEDCBA98
#dummy_1: .word 0xCAFEBABE
#dummy_2: .word 0xFFFFFFFF
#dummy_3: .word 0xABCDEF12
#dummy_4: .word 0xDEADBEEF

.align 12
dummy_5: .word 0x00000123
dummy_6: .word 0xCEAEBEBA
dummy_7: .word 0x88888888
dummy_8: .word 0x12345ABC
dummy_9: .word 0x11111111
#
.align 12
dummy_10: .word 0xBEEFDEAD
dummy_11: .word 0xBEEFDEAD
dummy_12: .word 0xBEEFDEAD
dummy_13: .word 0xBEEFDEAD
dummy_14: .word 0xBEEFDEAD

RVTEST_DATA_END
