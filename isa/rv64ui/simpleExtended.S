# See LICENSE for license details.

#*****************************************************************************
# simple.S
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

RVTEST_RV64U

RVTEST_CODE_BEGIN

li a0, 0x80000000
li a0, 0x12345678
nop
nop
nop
nop
nop
li t0, 0xAAAAAAAA
li TESTNUM, 1
nop
nop
nop
csrrw t1, CSR_USCRATCH, t0
csrrw t1, CSR_USCRATCH, t1
csrr t1, CSR_CYCLE
nop
csrw CSR_MPK, a0
li TESTNUM, 2
csrr t0, CSR_CYCLE
csrr t0, CSR_MPK
li a0, 0x0
bne a0, t0, fail
li TESTNUM, 3
csrr t0, CSR_CYCLE
csrw CSR_MPK, t0
csrr t0, CSR_MPK
bne a0, t0, fail
li TESTNUM, 4
csrw CSR_MPK, t0
csrr t0, CSR_MPK
bne a0, t0, fail
nop
li a2, 0xAAAAAAAA
nop
nop
nop
nop
nop
nop
nop
nop
li TESTNUM, 5
csrr t1,CSR_MPK
bne a0, t1, fail
li a3, 0xA5A55A5A
li a4, 0xCAFEBABE


RVTEST_PASS

fail:
  RVTEST_FAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
