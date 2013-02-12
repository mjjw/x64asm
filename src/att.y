 /*
Copyright 2103 eric schkufza

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */

%{

#include <map>
#include <string>
#include <vector>

#include "src/code.h"
#include "src/env_reg.h"
#include "src/instruction.h"
#include "src/label.h"
#include "src/m.h"
#include "src/moffs.h"
#include "src/opcode.h"
#include "src/rel.h"
#include "src/type.h"

using namespace std;
using namespace x64asm;

extern int yylex();
extern int yy_line_number;

void yyerror(std::istream& is, x64asm::Code& code, const char* s) { 
	is.setstate(std::ios::failbit); 
	cerr << "Error on line " << yy_line_number << ": "  << s << endl;
}

typedef std::pair<x64asm::Opcode, std::vector<x64asm::Type>> Entry;
typedef std::vector<Entry> Row;
typedef std::map<const char*, Row> Table;

Table att_table = {
	#include "src/att.table"
};

bool is_a(const Operand* o, Type parse, Type target) {


}

// Returns a poorly formed instruction on error
const Instruction* to_instr(const std::string& opc, 
    const std::vector<std::pair<const Operand*, x64asm::Type>*>& ops) {
	const auto itr = att_table.find(opc.c_str());
	if ( itr == att_table.end() )
		return new Instruction{x64asm::NOP, {xmm0}};

	for ( const auto& entry : itr->second ) {
		const auto arity = entry.second.size();
		if ( ops.size() != arity )
			continue;

		auto match = true;
		for ( size_t i = 0; i < arity; ++i ) 
			match &= is_a(ops[i]->first, ops[i]->second, entry.second[i]);

		if ( match ) {
			Instruction* instr = new Instruction{entry.first};
			for ( size_t i = 0, ie = ops.size(); i < ie; ++i )
				instr->set_operand(i, *(ops[i]->first));

			return instr;
		}
	}

	return new Instruction{x64asm::NOP, {xmm0}};
}

R32 base32(const Operand* o) { 
	const auto ret = *((R32*)o);
	delete o;
	return ret;
}

R64 base64(const Operand* o) { 
	const auto ret = *((R64*)o);
	delete o;
	return ret;
}

R32 index32(const Operand* o) { 
	const auto ret = *((R32*)o);
	delete o;
	return ret;
}

R64 index64(const Operand* o) { 
	const auto ret = *((R64*)o);
	delete o;
	return ret;
}

Imm32 disp(const Operand* o) { 
	const auto ret = *((Imm32*)o);
	delete o;
	return ret;
}

Sreg seg(const Operand* o) { 
	const auto ret = *((Sreg*)o);
	delete o;
	return ret;
}

Imm64 offset(const Operand* o) { 
	const auto ret = *((Imm64*)o);
	delete o;
	return ret;
}

%}

%code requires {
  #include "src/instruction.h"
	#include "src/code.h"
	#include "src/env_reg.h"
	#include "src/operand.h"
	#include "src/m.h"
	#include "src/moffs.h"
	#include "src/rel.h"
}

%union {
	x64asm::Scale scale;
	const x64asm::Rip* rip;
	const x64asm::Operand* operand;
	std::pair<const x64asm::Operand*, x64asm::Type>* typed_operand;
	std::vector<std::pair<const Operand*, x64asm::Type>*>* typed_operands;
	const std::string* opcode;
	const x64asm::Instruction* instr;
  std::vector<x64asm::Instruction>* instrs;
}

%token <int> COMMA
%token <int> COLON
%token <int> OPEN
%token <int> CLOSE
%token <int> ENDL

%token <scale>  SCALE
%token <rip>    RIP

%token <operand> HINT
%token <operand> IMM
%token <operand> OFFSET
%token <operand> LABEL
%token <operand> PREF_66
%token <operand> PREF_REX_W
%token <operand> FAR
%token <operand> MM
%token <operand> AL
%token <operand> CL
%token <operand> RL
%token <operand> RH
%token <operand> RB
%token <operand> AX
%token <operand> DX
%token <operand> R_16
%token <operand> EAX
%token <operand> R_32
%token <operand> RAX
%token <operand> R_64
%token <operand> SREG
%token <operand> FS
%token <operand> GS
%token <operand> ST_0
%token <operand> ST
%token <operand> XMM_0
%token <operand> XMM
%token <operand> YMM

%token <opcode> OPCODE

%type <operand> moffs
%type <operand> m

%type <typed_operand>  typed_operand
%type <typed_operands> typed_operands
%type <instr>          instr
%type <instrs>         instrs

%locations
%error-verbose

%parse-param { std::istream& is }
%parse-param { x64asm::Code& code }

%start code

%%

blank : /* empty */ | blank ENDL { }

code : blank instrs { 
	code.assign($2->begin(), $2->end()); delete $2; 
}

instrs : instr { 
  $$ = new vector<Instruction>(); 
	$$->push_back(*$1); 
	delete $1; 
} 
| instrs instr { 
	$1->push_back(*$2); 
	delete($2); 
}

instr : LABEL COLON ENDL blank {
  $$ = new Instruction{Opcode::LABEL_DEFN, {*$1}};
	delete $1;
}
| OPCODE typed_operands ENDL blank {
	$$ = to_instr(*$1, *$2);

	delete $1;
	for ( const auto op : *$2 ) {
		delete op->first;
		delete op;
	}
	delete $2;

	if ( !$$->check() )
		yyerror(is, code, "Unable to parse instruction!");
}

typed_operands : /* empty */ { 
	$$ = new vector<pair<const Operand*, Type>*>(); 
}
| typed_operand { 
	$$ = new vector<pair<const Operand*, Type>*>(); 
	$$->push_back($1); 
}
| typed_operand COMMA typed_operand {
	$$ = new vector<pair<const Operand*, Type>*>(); 
	$$->push_back($3);
	$$->push_back($1);
}
| typed_operand COMMA typed_operand COMMA typed_operand { 
	$$ = new vector<pair<const Operand*, Type>*>(); 
	$$->push_back($5); 
	$$->push_back($3); 
	$$->push_back($1); 
} 
| typed_operand COMMA typed_operand COMMA typed_operand COMMA typed_operand { 
	$$ = new vector<pair<const Operand*, Type>*>(); 
	$$->push_back($7); 
	$$->push_back($5); 
	$$->push_back($3); 
	$$->push_back($1); 
} 

typed_operand : HINT { $$ = new pair<const Operand*, Type>{$1, Type::HINT}; }
	| IMM { $$ = new pair<const Operand*, Type>{$1, Type::IMM_8}; }
	| LABEL { $$ = new pair<const Operand*, Type>{$1, Type::LABEL}; }
	| PREF_66 { $$ = new pair<const Operand*, Type>{$1, Type::PREF_66}; }
	| PREF_REX_W { $$ = new pair<const Operand*, Type>{$1, Type::PREF_REX_W}; }
	| FAR { $$ = new pair<const Operand*, Type>{$1, Type::FAR}; }
	| MM { $$ = new pair<const Operand*, Type>{$1, Type::MM}; }
	| AL { $$ = new pair<const Operand*, Type>{$1, Type::AL}; }
	| CL { $$ = new pair<const Operand*, Type>{$1, Type::CL}; }
	| RL { $$ = new pair<const Operand*, Type>{$1, Type::RL}; }
	| RB { $$ = new pair<const Operand*, Type>{$1, Type::RB}; }
	| AX { $$ = new pair<const Operand*, Type>{$1, Type::AX}; }
	| DX { $$ = new pair<const Operand*, Type>{$1, Type::DX}; }
	| R_16 { $$ = new pair<const Operand*, Type>{$1, Type::R_16}; }
	| EAX { $$ = new pair<const Operand*, Type>{$1, Type::EAX}; }
	| R_32 { $$ = new pair<const Operand*, Type>{$1, Type::R_32}; }
	| RAX { $$ = new pair<const Operand*, Type>{$1, Type::RAX}; }
	| R_64 { $$ = new pair<const Operand*, Type>{$1, Type::R_64}; }
	| SREG { $$ = new pair<const Operand*, Type>{$1, Type::SREG}; }
	| FS { $$ = new pair<const Operand*, Type>{$1, Type::FS}; }
	| GS { $$ = new pair<const Operand*, Type>{$1, Type::GS}; }
	| ST_0 { $$ = new pair<const Operand*, Type>{$1, Type::ST_0}; }
	| ST { $$ = new pair<const Operand*, Type>{$1, Type::ST}; }
	| XMM_0 { $$ = new pair<const Operand*, Type>{$1, Type::XMM_0}; }
	| XMM { $$ = new pair<const Operand*, Type>{$1, Type::XMM}; }
	| YMM { $$ = new pair<const Operand*, Type>{$1, Type::YMM}; }
	| moffs { $$ = new pair<const Operand*, Type>{$1, Type::MOFFS_8}; }
	| m { $$ = new pair<const Operand*, Type>{$1, Type::M_8}; }

moffs :
  OFFSET { $$ = new Moffs8{offset($1)}; }
| SREG COLON OFFSET { $$ = new Moffs8{seg($1), offset($3)}; }

m : 
  OPEN R_32 CLOSE { $$ = new M8{base32($2)}; }
| OPEN R_64 CLOSE { $$ = new M8{base64($2)}; }
| OPEN RIP CLOSE { $$ = new M8{rip}; }
| SREG COLON OPEN R_32 CLOSE { $$ = new M8{seg($1), base32($4)}; }
| SREG COLON OPEN R_64 CLOSE { $$ = new M8{seg($1), base64($4)}; }
| SREG COLON OPEN RIP CLOSE { $$ = new M8{seg($1), rip}; }
| OFFSET OPEN R_32 CLOSE { $$ = new M8{base32($3), disp($1)}; }
| OFFSET OPEN R_64 CLOSE { $$ = new M8{base64($3), disp($1)}; }
| OFFSET OPEN RIP CLOSE { $$ = new M8{rip, disp($1)}; }
| SREG COLON OFFSET OPEN R_32 CLOSE { $$ = new M8{seg($1), base32($5), disp($3)}; }
| SREG COLON OFFSET OPEN R_64 CLOSE { $$ = new M8{seg($1), base64($5), disp($3)}; }
| SREG COLON OFFSET OPEN RIP CLOSE { $$ = new M8{seg($1), rip, disp($3)}; }
| OPEN R_32 COMMA SCALE CLOSE { $$ = new M8{index32($2), $4}; }
| OPEN R_64 COMMA SCALE CLOSE { $$ = new M8{index64($2), $4}; }
| SREG COLON OPEN R_32 COMMA SCALE CLOSE { $$ = new M8{seg($1), index32($4), $6}; }
| SREG COLON OPEN R_64 COMMA SCALE CLOSE { $$ = new M8{seg($1), index64($4), $6}; }
| OFFSET OPEN R_32 COMMA SCALE CLOSE { $$ = new M8{index32($3), $5, disp($1)}; }
| OFFSET OPEN R_64 COMMA SCALE CLOSE { $$ = new M8{index64($3), $5, disp($1)}; }
| SREG COLON OFFSET OPEN R_32 COMMA SCALE CLOSE { $$ = new M8{seg($1), index32($5), $7, disp($3)}; }
| SREG COLON OFFSET OPEN R_64 COMMA SCALE CLOSE { $$ = new M8{seg($1), index64($5), $7, disp($3)}; }
| OPEN R_32 COMMA R_32 COMMA SCALE CLOSE { $$ = new M8{base32($2), index32($4), $6}; }
| OPEN R_64 COMMA R_64 COMMA SCALE CLOSE { $$ = new M8{base64($2), index64($4), $6}; }
| SREG COLON OPEN R_32 COMMA R_32 COMMA SCALE CLOSE { $$ = new M8{seg($1), base32($4), index32($6), $8}; }
| SREG COLON OPEN R_64 COMMA R_64 COMMA SCALE CLOSE { $$ = new M8{seg($1), base64($4), index64($6), $8}; }
| OFFSET OPEN R_32 COMMA R_32 COMMA SCALE CLOSE { $$ = new M8{base32($3), index32($5), $7, disp($1)}; }
| OFFSET OPEN R_64 COMMA R_64 COMMA SCALE CLOSE { $$ = new M8{base64($3), index64($5), $7, disp($1)}; }
| SREG COLON OFFSET OPEN R_32 COMMA R_32 COMMA SCALE CLOSE { $$ = new M8{seg($1), base32($5), index32($7), $9, disp($3)}; }
| SREG COLON OFFSET OPEN R_64 COMMA R_64 COMMA SCALE CLOSE { $$ = new M8{seg($1), base64($5), index64($7), $9, disp($3)}; }

%% 
