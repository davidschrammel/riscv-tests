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


RVTEST_RV64M
RVTEST_CODE_BEGIN

  .align 2
  .option norvc

nop
nop
csrr t3, CSR_MTVEC
li t1, 0xAAAAAAAA
li a3, 0xAAAAAAAA
la a3, mtvec_handler
csrw CSR_MTVEC, a3
la a3, my_stvec_handler
csrw CSR_STVEC, a3
la a3, utvec_handler
csrw CSR_UTVEC, a3

li t1,  (1 << CAUSE_MISALIGNED_FETCH)    | \
        (1 << CAUSE_ILLEGAL_INSTRUCTION) | \
        (1 << CAUSE_USER_ECALL);

csrrs t4, medeleg, t1;

li t1,  (1 << CAUSE_MISALIGNED_FETCH)    | \
        (1 << CAUSE_ILLEGAL_INSTRUCTION) | \
        (1 << CAUSE_USER_ECALL);

csrrs t5, sedeleg, t1;

li a0, MSTATUS_MPP;
csrc mstatus, a0;
li a0, MSTATUS_SPP;
csrs mstatus, a0;

la a0, superstart
csrw mepc, a0
mret

superstart:
  li t1, 0xA5A5A5A5
  li a1, 0x4
  li a2, 0x1
  nop
1:  nop
  nop
  ecall
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  sub a1, a1, a2
  bnez a1, 1b
  j end;
# csrw CSR_MTVEC, t3

utvec_handler:
  j my_synchronous_uexception
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j my_synchronous_uexception
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail



my_stvec_handler:
  j my_synchronous_exception
  j msip
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail

mtvec_handler:
  j my_synchronous_exception
  j msip
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail
  j fail

my_synchronous_uexception:
  csrr t1, ucause
  li a0, 0x12345678
  csrr t2, uepc
  ADDI t2,t2,4
  csrw uepc, t2
  li t0, 0xAAAAAAAA
  uret

my_synchronous_exception:
  csrr t1, mcause
  li a0, 0x12345678
  csrr t2, mepc
  ADDI t2,t2,8
  csrw mepc, t2
  li t0, 0xAAAAAAAA
  li t0, 0x00000000
  csrw CSR_STVEC, t0
  csrw CSR_UTVEC, t0

  csrw medeleg, t4;
  csrw sedeleg, t5;

  csrw CSR_MTVEC, t3
  mret

msip:
  li a0, 0xA5A55A5A
  csrr t2, mepc
  ADDI t2,t2,8
  csrw mepc, t2
  li t0, 0xAAAAAAAA
  mret

fail:
  li a0, 0xDEADBEEF
  csrr t2, mepc
  ADDI t2,t2,8
  csrw mepc, t2
  li t0, 0xAAAAAAAA
  mret
  nop
  nop
  nop
  nop
  nop
  nop
  nop

end:
  li a0, 0xCAFEBABE
  .byte 0x00
  .4byte 0x00033537
  .2byte 0x0000
  .byte 0x00
  li t0, 0xAAAAAAAA
  nop
  nop
  nop
  nop
  nop
  nop

RVTEST_PASS

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
