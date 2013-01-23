#ifndef X64_INCLUDE_X64_H
#define X64_INCLUDE_X64_H

#include "src/assembler/assembler.h"
#include "src/assembler/function.h"

#include "src/cfg/cfg.h"
#include "src/cfg/defined_register.h"
#include "src/cfg/dominators.h"
#include "src/cfg/live_register.h"
#include "src/cfg/loops.h"
#include "src/cfg/reachable.h"
#include "src/cfg/remove_nop.h"
#include "src/cfg/remove_unreachable.h"

#include "src/code/code.h"
#include "src/code/constants.h"
#include "src/code/cr.h"
#include "src/code/dr.h"
#include "src/code/eflag.h"
#include "src/code/hint.h"
#include "src/code/imm.h"
#include "src/code/instruction.h"
#include "src/code/label.h"
#include "src/code/m.h"
#include "src/code/mm.h"
#include "src/code/modifier.h"
#include "src/code/moffs.h"
#include "src/code/op_set.h"
#include "src/code/op_type.h"
#include "src/code/opcode.h"
#include "src/code/operand.h"
#include "src/code/properties.h"
#include "src/code/r.h"
#include "src/code/rel.h"
#include "src/code/sreg.h"
#include "src/code/stream.h"
#include "src/code/st.h"
#include "src/code/xmm.h"
#include "src/code/ymm.h"

#endif
