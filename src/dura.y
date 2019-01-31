/* asMSX - an MSX / Z80 assembler
   (C) Eduardo A. Robsy Petrus, 2000-2010
   Bison grammar file
         v.0.01a: [10/09/2000] First public version

         v.0.01b: [03/05/2001] Bugfixes. Added PRINTFIX,FIXMUL, FIXDIV

         v.0.10 : [19/08/2004] Overall enhance. Opcodes 100% checked

         v.0.11 : [31/12/2004] IX, IY do accept negative or null offsets

         v.0.12 : [11/09/2005] Recovery version
         Added REPT/ENDR, variables/constants, RANDOM, DEBUG blueMSX,
                     BREAKPOINT blueMSX, PHASE/DEPHASE, $ symbol

         v.0.12e: [07/10/2006]
                     Additional parameters for INCBIN "file" [SKIP num] [SIZE num]
                     Second page locating macro (32KB ROMs / megaROMs)
                     Added experimental support for MegaROMs:
                        * MEGAROM [mapper] - define mapper type
                        * SUBPAGE [n] AT [address] - define page
                        * SELECT [n] AT [address] - set page

         v.0.12f: [16/11/2006]
                     Several binary operators fixed
                     Conditional assembly

         v.0.12f1:[17/11/2006]
                     Nested conditional assembly and other conditions

         v.0.12g:[18/03/2007]
                     PHASE/DEPHASE bug fixed
                     Initial CAS format support
                     WAV output added
                     Enhanced conditional assembly: IFDEF

         v.0.14: [UNRELEASED]
		     First working Linux version
		     Somewhat improved stability

         v.0.15: [UNRELEASED]
                     ADD IX,HL and ADD IY,HL operations removed
                     Label vs Macro collisions solved
                     Overall improvement in pointer stability
		     INCBIN now can SKIP and SIZE upto 32-bit 

         v.0.16: [CANDIDATE]
		     First version fully developed in Linux
		     Fixed bug affecting filename extensions
		     Removed the weird IM 0/1 - apparently it is just a plain undocumented IM 0 opcode
		     FILENAME directive to set assembler output filenames
		     ZILOG directive for using Zilog style indirections and official syntax
		     ROM/MEGAROM now have a standard 16 byte header
		     Fixed a really annoying bug regarding $DB data read as pseudo DB
		     SINCLAIR directive included to support TAP file generation (ouch!) --> STILL TO BE TESTED 

		Pending:
			- Adjust BIOS for SINCLAIR model?
			- DISK support
			- R800/Z80/8080/Gameboy support
			- Sinclair ZX Spectrum TAP/TZX file format supported
			
	 [Post-Rosby versions]
	 v.0.17: [19/12/2013]
		[FIX] Issue 1: Crash on Linux when including additional .asm files (by theNestruo)
		[FIX] Issue 5: Non-zero exit code on errors (by theNestruo)

	 v.0.18: [01/02/2017]
	 	Fixed issue with .megaflashrom and the defines.
	 
	 v.0.18.1: [11/02/2017]
	 	Fixed multiple compilation warnings by specifying function parameters and return type explicitly
                Fixed a problem with cassette file name generation due to uninitialized variable 'binario'
	 v.0.18.2: [25/05/2017]
	 	Added -z flag. This flag allows using standard Zilog syntax without setting .ZILOG on the code.
	 	Now local labels can be also set using .Local_Label along the previous @@Local_Label.
		Now .instruction are correctly parsed. For instance, before it was allowed to set "azilog", "bzilog"
		instead of only allowing ".zilog" or "zilog". 
	 v.0.18.3: [10/06/2017]
		Fixed induced bug of February 5th when using INCLUDE. Parser 1 p1_tmpstr wasn't using malloc memory. Instead it uses
		strtok allocated memory. This is never deleted, we must check this in the future to prevent memory leaks.
	 v.0.18.4: [18/06/2017]
		Unterminated string hotfix. Find a better way to solve it. Probably a more flex-like fix.
*/

/* C headers and definitions */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

#define VERSION "0.18.4"
#define DATE "18/06/2017"

#define Z80 0
#define ROM 1
#define BASIC 2
#define MSXDOS 3
#define MEGAROM 4
#define SINCLAIR 5

#define KONAMI 0
#define KONAMISCC 1
#define ASCII8 2
#define ASCII16 3

#define MAX_ID 32000

#define FREQ_HI 0x7FFF
#define FREQ_LO 0x8000
#define SILENCE 0x0000

extern FILE *yyin;		/* yyin is defined in Flex-generated lexer */
extern int yylex(void);
int preprocessor1(char *);	/* defined in parser1.l */
int preprocessor2();		/* defined in parser2.l */
int preprocessor3(int);		/* defined in parser3.l */

/* forward function declarations to address GCC -Wimplicit-function-declaration warnings */
void yyerror(char *);
void register_label(char *);
void register_local(char *);
void type_rom();
void type_megarom(int);
void type_basic();
void type_msxdos();
void type_sinclair();
void msx_bios();
void error_message(int);
void locate_32k();
void create_subpage(int, int);
void select_page_direct(int, int);
void select_page_register(int, int);
void write_byte(int);
void write_word(int);
void register_symbol(char *, int, int);
void register_variable(char *, int);
void include_binary(char *, int, int);
void finalize();
void write_string(char *);
void create_txt();
int is_defined_symbol(char *);
void warning_message(int);
void relative_jump(int);
int read_label(char *);
int read_local(char *);
void write_bin();
void write_cas();
void write_wav();
int d_rand();

int wav_header[44] = {
  0x52, 0x49, 0x46, 0x46,
  0x44, 0x00, 0x00, 0x00,
  0x57, 0x41, 0x56, 0x45,
  0x66, 0x6D, 0x74, 0x20,
  0x10, 0x00, 0x00, 0x00,
  0x01, 0x00, 0x02, 0x00,
  0x44, 0xAC, 0x00, 0x00,
  0x10, 0xB1, 0x02, 0x00,
  0x04, 0x00, 0x10, 0x00,
  0x64, 0x61, 0x74, 0x61,
  0x20, 0x00, 0x00, 0x00
};

FILE *archivo, *fmsg, *output, *wav;
char *memory, *fuente, *interno, *binario, *filename;
char *salida, *simbolos, *ensamblador, *original;
int cassette = 0, size = 0, ePC = 0, PC = 0;
int subpage, pagesize, lastpage, mapper, pageinit;
int usedpage[256];
int dir_inicio = 0xffff, dir_final = 0x0000;
int inicio = 0, advertencias = 0, lineas, parity;
int zilog = 0, pass = 1, bios = 0, type = 0;
int conditional[16];
int conditional_level = 0, maxima = 0, ultima_global = 0;
int maxpage[4] = {32, 64, 256, 256};

struct
{
  char *nombre;
  int valor;
  int type;
  int pagina;
} lista_identificadores[MAX_ID];
%}

%union
{
  int val;
  double real;
  char *tex;
}

/* Main elements */

%left '+' '-' OP_OR OP_XOR
%left SHIFT_L SHIFT_R
%left '*' '/' '%' '&'
%left OP_OR_LOG OP_AND_LOG
%left NEGATIVO
%left NEGACION OP_NEG_LOG
%left OP_EQUAL OP_MINOR_EQUAL OP_MINOR OP_MAJOR OP_MAJOR_EQUAL OP_NON_EQUAL

%token <tex> COMILLA
%token <tex> TEXTO
%token <tex> IDENTIFICADOR
%token <tex> LOCAL_IDENTIFICADOR

%token <val> PREPRO_LINE
%token <val> PREPRO_FILE

%token <val> PSEUDO_CALLDOS
%token <val> PSEUDO_CALLBIOS
%token <val> PSEUDO_MSXDOS
%token <val> PSEUDO_PAGE
%token <val> PSEUDO_BASIC
%token <val> PSEUDO_ROM
%token <val> PSEUDO_MEGAROM
%token <val> PSEUDO_SINCLAIR
%token <val> PSEUDO_BIOS
%token <val> PSEUDO_ORG
%token <val> PSEUDO_START
%token <val> PSEUDO_END
%token <val> PSEUDO_DB
%token <val> PSEUDO_DW
%token <val> PSEUDO_DS
%token <val> PSEUDO_EQU
%token <val> PSEUDO_ASSIGN
%token <val> PSEUDO_INCBIN
%token <val> PSEUDO_SKIP
%token <val> PSEUDO_DEBUG
%token <val> PSEUDO_BREAK
%token <val> PSEUDO_PRINT
%token <val> PSEUDO_PRINTTEXT
%token <val> PSEUDO_PRINTHEX
%token <val> PSEUDO_PRINTFIX
%token <val> PSEUDO_SIZE
%token <val> PSEUDO_BYTE
%token <val> PSEUDO_WORD
%token <val> PSEUDO_RANDOM
%token <val> PSEUDO_PHASE
%token <val> PSEUDO_DEPHASE
%token <val> PSEUDO_SUBPAGE
%token <val> PSEUDO_SELECT
%token <val> PSEUDO_SEARCH
%token <val> PSEUDO_AT
%token <val> PSEUDO_ZILOG
%token <val> PSEUDO_FILENAME

%token <val> PSEUDO_FIXMUL
%token <val> PSEUDO_FIXDIV
%token <val> PSEUDO_INT
%token <val> PSEUDO_FIX
%token <val> PSEUDO_SIN
%token <val> PSEUDO_COS
%token <val> PSEUDO_TAN
%token <val> PSEUDO_SQRT
%token <val> PSEUDO_SQR
%token <real> PSEUDO_PI
%token <val> PSEUDO_ABS
%token <val> PSEUDO_ACOS
%token <val> PSEUDO_ASIN
%token <val> PSEUDO_ATAN
%token <val> PSEUDO_EXP
%token <val> PSEUDO_LOG
%token <val> PSEUDO_LN
%token <val> PSEUDO_POW

%token <val> PSEUDO_IF
%token <val> PSEUDO_IFDEF
%token <val> PSEUDO_ELSE
%token <val> PSEUDO_ENDIF

%token <val> PSEUDO_CASSETTE

%token <val> MNEMO_LD
%token <val> MNEMO_LD_SP
%token <val> MNEMO_PUSH
%token <val> MNEMO_POP
%token <val> MNEMO_EX
%token <val> MNEMO_EXX
%token <val> MNEMO_LDI 
%token <val> MNEMO_LDIR
%token <val> MNEMO_LDD 
%token <val> MNEMO_LDDR
%token <val> MNEMO_CPI 
%token <val> MNEMO_CPIR
%token <val> MNEMO_CPD 
%token <val> MNEMO_CPDR
%token <val> MNEMO_ADD
%token <val> MNEMO_ADC
%token <val> MNEMO_SUB
%token <val> MNEMO_SBC
%token <val> MNEMO_AND
%token <val> MNEMO_OR
%token <val> MNEMO_XOR
%token <val> MNEMO_CP
%token <val> MNEMO_INC
%token <val> MNEMO_DEC
%token <val> MNEMO_DAA
%token <val> MNEMO_CPL
%token <val> MNEMO_NEG
%token <val> MNEMO_CCF
%token <val> MNEMO_SCF
%token <val> MNEMO_NOP
%token <val> MNEMO_HALT
%token <val> MNEMO_DI
%token <val> MNEMO_EI
%token <val> MNEMO_IM
%token <val> MNEMO_RLCA
%token <val> MNEMO_RLA
%token <val> MNEMO_RRCA
%token <val> MNEMO_RRA
%token <val> MNEMO_RLC
%token <val> MNEMO_RL
%token <val> MNEMO_RRC
%token <val> MNEMO_RR
%token <val> MNEMO_SLA
%token <val> MNEMO_SLL
%token <val> MNEMO_SRA
%token <val> MNEMO_SRL
%token <val> MNEMO_RLD
%token <val> MNEMO_RRD
%token <val> MNEMO_BIT
%token <val> MNEMO_SET
%token <val> MNEMO_RES
%token <val> MNEMO_IN
%token <val> MNEMO_INI
%token <val> MNEMO_INIR
%token <val> MNEMO_IND
%token <val> MNEMO_INDR
%token <val> MNEMO_OUT
%token <val> MNEMO_OUTI
%token <val> MNEMO_OTIR
%token <val> MNEMO_OUTD
%token <val> MNEMO_OTDR
%token <val> MNEMO_JP
%token <val> MNEMO_JR
%token <val> MNEMO_DJNZ
%token <val> MNEMO_CALL
%token <val> MNEMO_RET
%token <val> MNEMO_RETI
%token <val> MNEMO_RETN
%token <val> MNEMO_RST
       
%token <val> REGISTRO
%token <val> REGISTRO_IX
%token <val> REGISTRO_IY
%token <val> REGISTRO_R
%token <val> REGISTRO_I
%token <val> REGISTRO_F
%token <val> REGISTRO_AF
%token <val> REGISTRO_IND_BC
%token <val> REGISTRO_IND_DE
%token <val> REGISTRO_IND_HL
%token <val> REGISTRO_IND_SP
%token <val> REGISTRO_16_IX
%token <val> REGISTRO_16_IY
%token <val> REGISTRO_PAR
%token <val> MODO_MULTIPLE       
%token <val> CONDICION

%token <val> NUMERO
%token <val> EOL

%token <real> REAL

%type <real> valor_real
%type <val> valor
%type <val> valor_3bits
%type <val> valor_8bits
%type <val> valor_16bits
%type <val> indireccion_IX
%type <val> indireccion_IY

%%

/* Gramar rules */

entrada: /* empty */
        | entrada linea
;

linea:    pseudo_instruccion EOL
        | mnemo_load8bit EOL
        | mnemo_load16bit EOL
        | mnemo_exchange EOL
        | mnemo_arit16bit EOL
        | mnemo_arit8bit EOL
        | mnemo_general EOL
        | mnemo_rotate EOL
        | mnemo_bits EOL
        | mnemo_io EOL
        | mnemo_jump EOL
        | mnemo_call EOL
        | PREPRO_FILE TEXTO EOL {
            strcpy(fuente, $2);
          }
        | PREPRO_LINE valor EOL {
            lineas = $2;
          }
        | etiqueta linea
        | etiqueta EOL
;

etiqueta: IDENTIFICADOR ':' {
            register_label(strtok($1, ":"));
          }
        | LOCAL_IDENTIFICADOR ':' {
            register_local(strtok($1, ":"));
          }
;

pseudo_instruccion: PSEUDO_ORG valor {
            if (conditional[conditional_level])
            {
              PC = $2;
              ePC = PC;
            }
          }
        | PSEUDO_PHASE valor {
            if (conditional[conditional_level])
              ePC = $2;
          }
        | PSEUDO_DEPHASE {
            if (conditional[conditional_level])
              ePC=PC;
          }
        | PSEUDO_ROM {
            if (conditional[conditional_level])
              type_rom();
          }
        | PSEUDO_MEGAROM {
            if (conditional[conditional_level])
              type_megarom(0);
          }
        | PSEUDO_MEGAROM valor {
            if (conditional[conditional_level])
              type_megarom($2);
          }
        | PSEUDO_BASIC {
            if (conditional[conditional_level])
              type_basic();
          }
        | PSEUDO_MSXDOS {
            if (conditional[conditional_level])
              type_msxdos();
          }
        | PSEUDO_SINCLAIR {
            if (conditional[conditional_level])
              type_sinclair();
          }
        | PSEUDO_BIOS {
            if (conditional[conditional_level])
            {
              if (!bios)
                msx_bios();
            }
          }
        | PSEUDO_PAGE valor {
            if (conditional[conditional_level])
            {
              subpage = 0x100;
              if ($2 > 3)
                error_message(22);
              else
              {
                PC = 0x4000 * $2;
                ePC = PC;
              }
            }
          }
        | PSEUDO_SEARCH {
            if (conditional[conditional_level])
            {
              if ((type != MEGAROM) && (type != ROM))
                error_message(41);
              locate_32k();
            }
          }
        | PSEUDO_SUBPAGE valor PSEUDO_AT valor {
            if (conditional[conditional_level])
            {
              if (type != MEGAROM)
                error_message(40);
              create_subpage($2, $4);
            }
          }
        | PSEUDO_SELECT valor PSEUDO_AT valor {
            if (conditional[conditional_level])
            {
              if (type != MEGAROM)
                error_message(40);
              select_page_direct($2, $4);
            }
          }
        | PSEUDO_SELECT REGISTRO PSEUDO_AT valor {
            if (conditional[conditional_level])
            {
              if (type != MEGAROM)
                error_message(40);
              select_page_register($2, $4);
            }
          }
        | PSEUDO_START valor {
            if (conditional[conditional_level])
              inicio=$2;
          }
        | PSEUDO_CALLBIOS valor {
            if (conditional[conditional_level])
            {
              write_byte(0xfd);
              write_byte(0x2a);
              write_word(0xfcc0);
              write_byte(0xdd);
              write_byte(0x21);
              write_word($2);
              write_byte(0xcd);
              write_word(0x001c);
            }
          }
        | PSEUDO_CALLDOS valor {
            if (conditional[conditional_level])
            {
              if (type != MSXDOS)
                error_message(25);
              write_byte(0x0e);
              write_byte($2);
              write_byte(0xcd);
              write_word(0x0005);
            }
          }
        | PSEUDO_DB listado_8bits {
            ;
          }
        | PSEUDO_DW listado_16bits {
            ;
          }
        | PSEUDO_DS valor_16bits {
            if (conditional[conditional_level])
            {
              if (dir_inicio > PC)
                dir_inicio=PC;
              PC += $2;
              ePC += $2;
              if (PC > 0xffff)
                error_message(1);
            }
          }
        | PSEUDO_BYTE {
            if (conditional[conditional_level])
            {
              PC++;
              ePC++;
            }
          }
        | PSEUDO_WORD {
            if (conditional[conditional_level])
            {
              PC += 2;
              ePC += 2;
            }
          }
        | IDENTIFICADOR PSEUDO_EQU valor {
            if (conditional[conditional_level])
              register_symbol(strtok($1, "="), $3, 2);
          }
        | IDENTIFICADOR PSEUDO_ASSIGN valor {
            if (conditional[conditional_level])
              register_variable(strtok($1, "="), $3);
          }
        | PSEUDO_INCBIN TEXTO {
            if (conditional[conditional_level])
              include_binary($2, 0, 0);
          }
        | PSEUDO_INCBIN TEXTO PSEUDO_SKIP valor {
            if (conditional[conditional_level])
            {
              if ($4 <= 0)
                error_message(30);
              include_binary($2, $4, 0);
            }
          }
        | PSEUDO_INCBIN TEXTO PSEUDO_SIZE valor {
            if (conditional[conditional_level])
            {
              if ($4 <= 0)
                error_message(30);
              include_binary($2, 0, $4);
            }
          }
        | PSEUDO_INCBIN TEXTO PSEUDO_SKIP valor PSEUDO_SIZE valor {
            if (conditional[conditional_level])
            {
              if (($4 <= 0) || ($6 <= 0))
                error_message(30);
              include_binary($2,$4,$6);
            }
          }
        | PSEUDO_INCBIN TEXTO PSEUDO_SIZE valor PSEUDO_SKIP valor {
            if (conditional[conditional_level])
            {
              if (($4 <= 0) || ($6 <= 0))
                error_message(30);
              include_binary($2, $6, $4);
            }
          }
        | PSEUDO_END {
            if (pass==3)
              finalize();
            PC = 0;
            ePC = 0;
            ultima_global = 0;
            type = 0;
            zilog = 0;
            if (conditional_level)
              error_message(45);
          }
        | PSEUDO_DEBUG TEXTO {
            if (conditional[conditional_level])
            {
              write_byte(0x52);
              write_byte(0x18);
              write_byte((int)(strlen($2) + 4));
              write_string($2);
            }
          }
        | PSEUDO_BREAK {
            if (conditional[conditional_level])
            {
              write_byte(0x40);
              write_byte(0x18);
              write_byte(0x00);
            }
          }
        | PSEUDO_BREAK valor {
            if (conditional[conditional_level])
            {
              write_byte(0x40);
              write_byte(0x18);
              write_byte(0x02);
              write_word($2);
            }
          }
        | PSEUDO_PRINTTEXT TEXTO {
            if (conditional[conditional_level])
            {
              if (pass == 2)
              {
                if (fmsg == NULL)
                  create_txt();
				if (fmsg)
                  fprintf(fmsg, "%s\n", $2);
              }
            }
          }
        | PSEUDO_PRINT valor {
            if (conditional[conditional_level])
            {
              if (pass == 2)
              {
                if (fmsg == NULL)
                  create_txt();
				if (fmsg)
                  fprintf(fmsg, "%d\n", (short int)$2 & 0xffff);
              }
            }
          }
        | PSEUDO_PRINT valor_real {
            if (conditional[conditional_level])
            {
              if (pass == 2)
              {
                if (fmsg == NULL)
                  create_txt();
				if (fmsg)
                  fprintf(fmsg, "%.4f\n", $2);
              }
            }
          }
        | PSEUDO_PRINTHEX valor {
            if (conditional[conditional_level])
            {
              if (pass == 2)
              {
                if (fmsg == NULL)
                  create_txt();
				if (fmsg)
                  fprintf(fmsg, "$%4.4x\n", (short int)$2 & 0xffff);
              }
            }
          }
        | PSEUDO_PRINTFIX valor {
            if (conditional[conditional_level])
            {
              if (pass == 2)
              {
                if (fmsg == NULL)
                  create_txt();
				if (fmsg)
                  fprintf(fmsg, "%.4f\n", ((float)($2 & 0xffff)) / 256);
              }
            }
          }
        | PSEUDO_SIZE valor {
            if (conditional[conditional_level] && (pass == 2))
            {
              if (size > 0)
                error_message(15);
              else
                size = $2;
            }
          }
        | PSEUDO_IF valor {
            if (conditional_level == 15)
			{
              error_message(44);
			  exit(1);	/* this is to stop code analyzer warning about conditional[] buffer overrun */
			}
            conditional_level++;
            if ($2)
              conditional[conditional_level] = 1 & conditional[conditional_level - 1];
            else
              conditional[conditional_level] = 0;
          }
        | PSEUDO_IFDEF IDENTIFICADOR {
            if (conditional_level == 15)
			{
              error_message(44);
			  exit(1);	/* this is to stop code analyzer warning about conditional[] buffer overrun */
			}
            conditional_level++;
            if (is_defined_symbol($2))
              conditional[conditional_level] = 1 & conditional[conditional_level - 1];
            else
              conditional[conditional_level] = 0;
          }
        | PSEUDO_ELSE {
            if (!conditional_level)
              error_message(42);
            conditional[conditional_level] = (conditional[conditional_level] ^ 1) & conditional[conditional_level - 1];
          }
        | PSEUDO_ENDIF {
            if (!conditional_level)
              error_message(43);
            conditional_level--;
          }
        | PSEUDO_CASSETTE TEXTO {
            if (conditional[conditional_level])
            {
              if (!interno[0])
                strcpy(interno, $2);
              cassette |= $1;
            }
          }
        | PSEUDO_CASSETTE {
            if (conditional[conditional_level])
            {
              if (!interno[0])
              {
                strcpy(interno, binario);
                interno[strlen(interno) - 1] = 0;
              }
              cassette |= $1;
            }
          }
        | PSEUDO_ZILOG {
            zilog = 1;
          }
        | PSEUDO_FILENAME TEXTO {
            strcpy(filename, $2);
          }
;

indireccion_IX: '[' REGISTRO_16_IX ']' {
            $$ = 0;
          }
	| '[' REGISTRO_16_IX '+' valor_8bits ']' {
            $$ = $4;
          }
	| '[' REGISTRO_16_IX '-' valor_8bits ']' {
            $$ = -$4;
          }
;
	
indireccion_IY: '[' REGISTRO_16_IY ']' {
            $$ = 0;
          }
	| '[' REGISTRO_16_IY '+' valor_8bits ']' {
            $$ = $4;
          }
	| '[' REGISTRO_16_IY '-' valor_8bits ']' {
            $$ = -$4;
          }
;
	
mnemo_load8bit: MNEMO_LD REGISTRO ',' REGISTRO {
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_IX {
            if (($2 > 3) && ($2 != 7))
              error_message(2);
            write_byte(0xdd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO_IX ',' REGISTRO {
            if (($4 > 3) && ($4 != 7))
              error_message(2);
            write_byte(0xdd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO_IX ',' REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_IY {
            if (($2 > 3) && ($2 != 7))
              error_message(2);
            write_byte(0xfd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO_IY ',' REGISTRO {
            if (($4 > 3) && ($4 != 7))
              error_message(2);
            write_byte(0xfd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO_IY ',' REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0x40 | ($2 << 3) | $4);
          }
        | MNEMO_LD REGISTRO ',' valor_8bits {
            write_byte(0x06 | ($2 << 3));
            write_byte($4);
          }
        | MNEMO_LD REGISTRO_IX ',' valor_8bits {
            write_byte(0xdd);
            write_byte(0x06 | ($2 << 3));
            write_byte($4);
          }
        | MNEMO_LD REGISTRO_IY ',' valor_8bits {
            write_byte(0xfd);
            write_byte(0x06 | ($2 << 3));
            write_byte($4);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_IND_HL {
            write_byte(0x46 | ($2 << 3));
          }
        | MNEMO_LD REGISTRO ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0x46 | ($2 << 3));
            write_byte($4);
          }
        | MNEMO_LD REGISTRO ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0x46 | ($2 << 3));
            write_byte($4);
          }
        | MNEMO_LD REGISTRO_IND_HL ',' REGISTRO {
            write_byte(0x70 | $4);
          }
        | MNEMO_LD indireccion_IX ',' REGISTRO {
            write_byte(0xdd);
            write_byte(0x70 | $4);
            write_byte($2);
          }
        | MNEMO_LD indireccion_IY ',' REGISTRO {
            write_byte(0xfd);
            write_byte(0x70 | $4);
            write_byte($2);
          }
        | MNEMO_LD REGISTRO_IND_HL ',' valor_8bits {
            write_byte(0x36);
            write_byte($4);
          }
        | MNEMO_LD indireccion_IX ',' valor_8bits {
            write_byte(0xdd);
            write_byte(0x36);
            write_byte($2);
            write_byte($4);
          }
        | MNEMO_LD indireccion_IY ',' valor_8bits {
            write_byte(0xfd);
            write_byte(0x36);
            write_byte($2);
            write_byte($4);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_IND_BC {
            if ($2 != 7)
              error_message(4);
            write_byte(0x0a);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_IND_DE {
            if ($2 != 7)
              error_message(4);
            write_byte(0x1a);
          }
        | MNEMO_LD REGISTRO ',' '[' valor_16bits ']' {
            if ($2 != 7)
              error_message(4);
            write_byte(0x3a);
            write_word($5);
          }
        | MNEMO_LD REGISTRO_IND_BC ',' REGISTRO {
            if ($4 != 7)
              error_message(5);
            write_byte(0x02);
          }
        | MNEMO_LD REGISTRO_IND_DE ',' REGISTRO {
            if ($4 != 7)
              error_message(5);
            write_byte(0x12);
          }
        | MNEMO_LD '[' valor_16bits ']' ',' REGISTRO {
            if ($6 != 7)
              error_message(5);
            write_byte(0x32);
            write_word($3);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_I {
            if ($2 != 7)
              error_message(4);
            write_byte(0xed);
            write_byte(0x57);
          }
        | MNEMO_LD REGISTRO ',' REGISTRO_R {
            if ($2 != 7)
              error_message(4);
            write_byte(0xed);
            write_byte(0x5f);
          }
        | MNEMO_LD REGISTRO_I ',' REGISTRO {
            if ($4 != 7)
              error_message(5);
            write_byte(0xed);
            write_byte(0x47);
          }
        | MNEMO_LD REGISTRO_R ',' REGISTRO {
            if ($4 != 7)
              error_message(5);
            write_byte(0xed);
            write_byte(0x4f);
          }
;

mnemo_load16bit: MNEMO_LD REGISTRO_PAR ',' valor_16bits {
            write_byte(0x01 | ($2 << 4));
            write_word($4);
          }
        | MNEMO_LD REGISTRO_16_IX ',' valor_16bits {
            write_byte(0xdd);
            write_byte(0x21);
            write_word($4);
          }
        | MNEMO_LD REGISTRO_16_IY ',' valor_16bits {
            write_byte(0xfd);
            write_byte(0x21);
            write_word($4);
          }
        | MNEMO_LD REGISTRO_PAR ',' '[' valor_16bits ']' {
            if ($2 != 2)
            {
              write_byte(0xed);
              write_byte(0x4b | ($2 << 4));
            }
            else 
              write_byte(0x2a);
            write_word($5);
          }
        | MNEMO_LD REGISTRO_16_IX ',' '[' valor_16bits ']' {
            write_byte(0xdd);
            write_byte(0x2a);
            write_word($5);
          }
        | MNEMO_LD REGISTRO_16_IY ',' '[' valor_16bits ']' {
            write_byte(0xfd);
            write_byte(0x2a);
            write_word($5);
          }
        | MNEMO_LD '[' valor_16bits ']' ',' REGISTRO_PAR {
            if ($6 != 2)
            {
              write_byte(0xed);
              write_byte(0x43 | ($6 << 4));
            }
            else
              write_byte(0x22);
            write_word($3);
          }
        | MNEMO_LD '[' valor_16bits ']' ',' REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0x22);
            write_word($3);
          }
        | MNEMO_LD '[' valor_16bits ']' ',' REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0x22);
            write_word($3);
          }
        | MNEMO_LD_SP ',' '[' valor_16bits ']' {
            write_byte(0xed);
            write_byte(0x7b);
            write_word($4);
          }
        | MNEMO_LD_SP ',' valor_16bits {
            write_byte(0x31);
            write_word($3);
          }
        | MNEMO_LD_SP ',' REGISTRO_PAR {
            if ($3 != 2)
              error_message(2);
            write_byte(0xf9);
          }
        | MNEMO_LD_SP ',' REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0xf9);
          }
        | MNEMO_LD_SP ',' REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0xf9);
          }
        | MNEMO_PUSH REGISTRO_PAR {
            if ($2 == 3)
              error_message(2);
            write_byte(0xc5 | ($2 << 4));
          }
        | MNEMO_PUSH REGISTRO_AF {
            write_byte(0xf5);
          }
        | MNEMO_PUSH REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0xe5);
          }
        | MNEMO_PUSH REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0xe5);
          }
        | MNEMO_POP REGISTRO_PAR {
            if ($2 == 3)
              error_message(2);
            write_byte(0xc1 | ($2 << 4));
          }
        | MNEMO_POP REGISTRO_AF {
            write_byte(0xf1);
          }
        | MNEMO_POP REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0xe1);
          }
        | MNEMO_POP REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0xe1);
          }
;

mnemo_exchange: MNEMO_EX REGISTRO_PAR ',' REGISTRO_PAR {
            if ((($2 != 1) || ($4 != 2)) && (($2 != 2) || ($4 != 1)))
              error_message(2);
            if (zilog && ($2 != 1))
              warning_message(5);
            write_byte(0xeb);
          }
        | MNEMO_EX REGISTRO_AF ',' REGISTRO_AF COMILLA {
            write_byte(0x08);
          }
        | MNEMO_EXX {
            write_byte(0xd9);
          }
        | MNEMO_EX REGISTRO_IND_SP ',' REGISTRO_PAR {
            if ($4 != 2)
              error_message(2);
            write_byte(0xe3);
          }
        | MNEMO_EX REGISTRO_IND_SP ',' REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0xe3);
          }
        | MNEMO_EX REGISTRO_IND_SP ',' REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0xe3);
          }
        | MNEMO_LDI {
            write_byte(0xed);
            write_byte(0xa0);
          }
        | MNEMO_LDIR {
            write_byte(0xed);
            write_byte(0xb0);
          }
        | MNEMO_LDD {
            write_byte(0xed);
            write_byte(0xa8);
          }
        | MNEMO_LDDR {
            write_byte(0xed);
            write_byte(0xb8);
          }
        | MNEMO_CPI {
            write_byte(0xed);
            write_byte(0xa1);
          }
        | MNEMO_CPIR {
            write_byte(0xed);
            write_byte(0xb1);
          }
        | MNEMO_CPD {
            write_byte(0xed);
            write_byte(0xa9);
          }
        | MNEMO_CPDR {
            write_byte(0xed);
            write_byte(0xb9);
          }
;

mnemo_arit8bit: MNEMO_ADD REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            write_byte(0x80|$4);
          }
        | MNEMO_ADD REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x80 | $4);
          }
        | MNEMO_ADD REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x80 | $4);
          }
        | MNEMO_ADD REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            write_byte(0xc6);
            write_byte($4);
          }
        | MNEMO_ADD REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            write_byte(0x86);
          }
        | MNEMO_ADD REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x86);
            write_byte($4);
          }
        | MNEMO_ADD REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x86);
            write_byte($4);
          }
        | MNEMO_ADC REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            write_byte(0x88 | $4);
          }
        | MNEMO_ADC REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x88 | $4);
          }
        | MNEMO_ADC REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x88 | $4);
          }
        | MNEMO_ADC REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            write_byte(0xce);
            write_byte($4);
          }
        | MNEMO_ADC REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            write_byte(0x8e);
          }
        | MNEMO_ADC REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x8e);
            write_byte($4);
          }
        | MNEMO_ADC REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x8e);
            write_byte($4);
          }
        | MNEMO_SUB REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0x90 | $4);
          }
        | MNEMO_SUB REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x90 | $4);
          }
        | MNEMO_SUB REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x90 | $4);
          }
        | MNEMO_SUB REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xd6);
            write_byte($4);
          }
        | MNEMO_SUB REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0x96);
          }
        | MNEMO_SUB REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x96);
            write_byte($4);
          }
        | MNEMO_SUB REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x96);
            write_byte($4);
          }
        | MNEMO_SBC REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            write_byte(0x98 | $4);
          }
        | MNEMO_SBC REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x98 | $4);
          }
        | MNEMO_SBC REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x98 | $4);
          }
        | MNEMO_SBC REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            write_byte(0xde);
            write_byte($4);
          }
        | MNEMO_SBC REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            write_byte(0x9e);
          }
        | MNEMO_SBC REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdd);
            write_byte(0x9e);
            write_byte($4);
          }
        | MNEMO_SBC REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            write_byte(0xfd);
            write_byte(0x9e);
            write_byte($4);
          }
        | MNEMO_AND REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xa0 | $4);
          }
        | MNEMO_AND REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xa0 | $4);
          }
        | MNEMO_AND REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xa0 | $4);
          }
        | MNEMO_AND REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xe6);
            write_byte($4);
          }
        | MNEMO_AND REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xa6);
          }
        | MNEMO_AND REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xa6);
            write_byte($4);
          }
        | MNEMO_AND REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xa6);
            write_byte($4);
          }
        | MNEMO_OR REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xb0 | $4);
          }
        | MNEMO_OR REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog) 
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xb0 | $4);
          }
        | MNEMO_OR REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xb0 | $4);
          }
        | MNEMO_OR REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xf6);
            write_byte($4);
          }
        | MNEMO_OR REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xb6);
          }
        | MNEMO_OR REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xb6);
            write_byte($4);
          }
        | MNEMO_OR REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xb6);
            write_byte($4);
          }
        | MNEMO_XOR REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xa8 | $4);
          }
        | MNEMO_XOR REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xa8 | $4);
          }
        | MNEMO_XOR REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xa8 | $4);
          }
        | MNEMO_XOR REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xee);
            write_byte($4);
          }
        | MNEMO_XOR REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xae);
          }
        | MNEMO_XOR REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xae);
            write_byte($4);
          }
        | MNEMO_XOR REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xae);
            write_byte($4);
          }
        | MNEMO_CP REGISTRO ',' REGISTRO {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xb8 | $4);
          }
        | MNEMO_CP REGISTRO ',' REGISTRO_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
              write_byte(0xdd);
              write_byte(0xb8 | $4);
          }
        | MNEMO_CP REGISTRO ',' REGISTRO_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xb8 | $4);
          }
        | MNEMO_CP REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfe);
            write_byte($4);
          }
        | MNEMO_CP REGISTRO ',' REGISTRO_IND_HL {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xbe);
          }
        | MNEMO_CP REGISTRO ',' indireccion_IX {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0xbe);
            write_byte($4);
          }
        | MNEMO_CP REGISTRO ',' indireccion_IY {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0xbe);
            write_byte($4);
          }
        | MNEMO_ADD REGISTRO {
            if (zilog)
              warning_message(5);
            write_byte(0x80 | $2);
          }
        | MNEMO_ADD REGISTRO_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x80 | $2);
          }
        | MNEMO_ADD REGISTRO_IY {
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x80 | $2);
          }
        | MNEMO_ADD valor_8bits {
            if (zilog)
              warning_message(5);
            write_byte(0xc6);
            write_byte($2);
          }
        | MNEMO_ADD REGISTRO_IND_HL {
            if (zilog)
              warning_message(5);
            write_byte(0x86);
          }
        | MNEMO_ADD indireccion_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x86);
            write_byte($2);
          }
        | MNEMO_ADD indireccion_IY {
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x86);
            write_byte($2);
          }
        | MNEMO_ADC REGISTRO {
            if (zilog)
              warning_message(5);
            write_byte(0x88 | $2);
          }
        | MNEMO_ADC REGISTRO_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x88 | $2);
          }
        | MNEMO_ADC REGISTRO_IY {
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x88|$2);
          }
        | MNEMO_ADC valor_8bits {
            if (zilog)
              warning_message(5);
            write_byte(0xce);
            write_byte($2);
          }
        | MNEMO_ADC REGISTRO_IND_HL {
            if (zilog)
              warning_message(5);
            write_byte(0x8e);
          }
        | MNEMO_ADC indireccion_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x8e);
            write_byte($2);
          }
        | MNEMO_ADC indireccion_IY {
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x8e);
            write_byte($2);
          }
        | MNEMO_SUB REGISTRO {
            write_byte(0x90 | $2);
          }
        | MNEMO_SUB REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0x90 | $2);
          }
        | MNEMO_SUB REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0x90 | $2);
          }
        | MNEMO_SUB valor_8bits {
            write_byte(0xd6);
            write_byte($2);
          }
        | MNEMO_SUB REGISTRO_IND_HL {
            write_byte(0x96);
          }
        | MNEMO_SUB indireccion_IX {
            write_byte(0xdd);
            write_byte(0x96);
            write_byte($2);
          }
        | MNEMO_SUB indireccion_IY {
            write_byte(0xfd);
            write_byte(0x96);
            write_byte($2);
          }
        | MNEMO_SBC REGISTRO {
            if (zilog)
              warning_message(5);
            write_byte(0x98|$2);
          }
        | MNEMO_SBC REGISTRO_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x98 | $2);
          }
        | MNEMO_SBC REGISTRO_IY {
            if (zilog)
              warning_message(5);
            write_byte(0xfd);
            write_byte(0x98 | $2);
          }
        | MNEMO_SBC valor_8bits {
            if (zilog)
              warning_message(5);
            write_byte(0xde);
            write_byte($2);
          }
        | MNEMO_SBC REGISTRO_IND_HL {
            if (zilog)
              warning_message(5);
            write_byte(0x9e);
          }
        | MNEMO_SBC indireccion_IX {
            if (zilog)
              warning_message(5);
            write_byte(0xdd);
            write_byte(0x9e);
            write_byte($2);
          }
        | MNEMO_SBC indireccion_IY {
            if (zilog)
              warning_message(5);
              write_byte(0xfd);
              write_byte(0x9e);
              write_byte($2);
          }
        | MNEMO_AND REGISTRO {
            write_byte(0xa0 | $2);
          }
        | MNEMO_AND REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0xa0 | $2);
          }
        | MNEMO_AND REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0xa0 | $2);
          }
        | MNEMO_AND valor_8bits {
            write_byte(0xe6);
            write_byte($2);
          }
        | MNEMO_AND REGISTRO_IND_HL {
            write_byte(0xa6);
          }
        | MNEMO_AND indireccion_IX {
            write_byte(0xdd);
            write_byte(0xa6);
            write_byte($2);
          }
        | MNEMO_AND indireccion_IY {
            write_byte(0xfd);
            write_byte(0xa6);
            write_byte($2);
          }
        | MNEMO_OR REGISTRO {
            write_byte(0xb0 | $2);
          }
        | MNEMO_OR REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0xb0 | $2);
          }
        | MNEMO_OR REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0xb0 | $2);
          }
        | MNEMO_OR valor_8bits {
            write_byte(0xf6);
            write_byte($2);
          }
        | MNEMO_OR REGISTRO_IND_HL {
            write_byte(0xb6);
          }
        | MNEMO_OR indireccion_IX {
            write_byte(0xdd);
            write_byte(0xb6);
            write_byte($2);
          }
        | MNEMO_OR indireccion_IY {
            write_byte(0xfd);
            write_byte(0xb6);
            write_byte($2);
          }
        | MNEMO_XOR REGISTRO {
            write_byte(0xa8 | $2);
          }
        | MNEMO_XOR REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0xa8 | $2);
          }
        | MNEMO_XOR REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0xa8 | $2);
          }
        | MNEMO_XOR valor_8bits {
            write_byte(0xee);
            write_byte($2);
          }
        | MNEMO_XOR REGISTRO_IND_HL {
            write_byte(0xae);
          }
        | MNEMO_XOR indireccion_IX {
            write_byte(0xdd);
            write_byte(0xae);
            write_byte($2);
          }
        | MNEMO_XOR indireccion_IY {
            write_byte(0xfd);
            write_byte(0xae);
            write_byte($2);
          }
        | MNEMO_CP REGISTRO {
            write_byte(0xb8 | $2);
          }
        | MNEMO_CP REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0xb8 | $2);
          }
        | MNEMO_CP REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0xb8 | $2);
          }
        | MNEMO_CP valor_8bits {
            write_byte(0xfe);
            write_byte($2);
          }
        | MNEMO_CP REGISTRO_IND_HL {
            write_byte(0xbe);
          }
        | MNEMO_CP indireccion_IX {
            write_byte(0xdd);
            write_byte(0xbe);
            write_byte($2);
          }
        | MNEMO_CP indireccion_IY {
            write_byte(0xfd);
            write_byte(0xbe);
            write_byte($2);
          }
        | MNEMO_INC REGISTRO {
            write_byte(0x04 | ($2 << 3));
          }
        | MNEMO_INC REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0x04 | ($2 << 3));
          }
        | MNEMO_INC REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0x04 | ($2 << 3));
          }
        | MNEMO_INC REGISTRO_IND_HL {
            write_byte(0x34);
          }
        | MNEMO_INC indireccion_IX {
            write_byte(0xdd);
            write_byte(0x34);
            write_byte($2);
          }
        | MNEMO_INC indireccion_IY {
            write_byte(0xfd);
            write_byte(0x34);
            write_byte($2);
          }
        | MNEMO_DEC REGISTRO {
            write_byte(0x05 | ($2 << 3));
          }
        | MNEMO_DEC REGISTRO_IX {
            write_byte(0xdd);
            write_byte(0x05 | ($2 << 3));
          }
        | MNEMO_DEC REGISTRO_IY {
            write_byte(0xfd);
            write_byte(0x05 | ($2 << 3));
          }
        | MNEMO_DEC REGISTRO_IND_HL {
            write_byte(0x35);
          }
        | MNEMO_DEC indireccion_IX {
            write_byte(0xdd);
            write_byte(0x35);
            write_byte($2);
          }
        | MNEMO_DEC indireccion_IY {
            write_byte(0xfd);
            write_byte(0x35);
            write_byte($2);
          }
;

mnemo_arit16bit: MNEMO_ADD REGISTRO_PAR ',' REGISTRO_PAR {
            if ($2 != 2)
              error_message(2);
            write_byte(0x09 | ($4 << 4));
          }
        | MNEMO_ADC REGISTRO_PAR ',' REGISTRO_PAR {
            if ($2 != 2)
              error_message(2);
            write_byte(0xed);
            write_byte(0x4a | ($4 << 4));
          }
        | MNEMO_SBC REGISTRO_PAR ',' REGISTRO_PAR {
            if ($2 != 2)
              error_message(2);
            write_byte(0xed);
            write_byte(0x42 | ($4 << 4));
          }
        | MNEMO_ADD REGISTRO_16_IX ',' REGISTRO_PAR {
            if ($4 == 2)
              error_message(2);
            write_byte(0xdd);
            write_byte(0x09 | ($4 << 4));
          }
        | MNEMO_ADD REGISTRO_16_IX ',' REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0x29);
          }
        | MNEMO_ADD REGISTRO_16_IY ',' REGISTRO_PAR {
            if ($4 == 2)
              error_message(2);
            write_byte(0xfd);
            write_byte(0x09 | ($4 << 4));
          }
        | MNEMO_ADD REGISTRO_16_IY ',' REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0x29);
          }
        | MNEMO_INC REGISTRO_PAR {
            write_byte(0x03 | ($2 << 4));
          }
        | MNEMO_INC REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0x23);
          }
        | MNEMO_INC REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0x23);
          }
        | MNEMO_DEC REGISTRO_PAR {
            write_byte(0x0b | ($2 << 4));
          }
        | MNEMO_DEC REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0x2b);
          }
        | MNEMO_DEC REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0x2b);
          }
;

mnemo_general: MNEMO_DAA {
            write_byte(0x27);
          }
        | MNEMO_CPL {
            write_byte(0x2f);
          }
        | MNEMO_NEG {
            write_byte(0xed);
            write_byte(0x44);
          }
        | MNEMO_CCF {
            write_byte(0x3f);
          }
        | MNEMO_SCF {
            write_byte(0x37);
          }
        | MNEMO_NOP {
            write_byte(0x00);
          }
        | MNEMO_HALT {
            write_byte(0x76);
          }
        | MNEMO_DI {
            write_byte(0xf3);
          }
        | MNEMO_EI {
            write_byte(0xfb);
          }
        | MNEMO_IM valor_8bits {
            if (($2 < 0) || ($2 > 2))
              error_message(3);
            write_byte(0xed);
            if ($2 == 0)
              write_byte(0x46);
            else if ($2==1)
              write_byte(0x56);
            else
              write_byte(0x5e);
          }
;

mnemo_rotate: MNEMO_RLCA {
            write_byte(0x07);
          }
        | MNEMO_RLA {
            write_byte(0x17);
          }
        | MNEMO_RRCA {
            write_byte(0x0f);
          }
        | MNEMO_RRA {
            write_byte(0x1f);
          }
        | MNEMO_RLC REGISTRO {
            write_byte(0xcb);
            write_byte($2);
          }
        | MNEMO_RLC REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x06);
          }
        | MNEMO_RLC indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4);
          }
        | MNEMO_RLC indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4);
          }
        | MNEMO_RLC indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x06);
          }
        | MNEMO_RLC indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x06);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RLC indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte($2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RLC indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte($2);
          }
        | MNEMO_RL REGISTRO {
            write_byte(0xcb);
            write_byte(0x10 | $2);
          }
        | MNEMO_RL REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x16);
          }
        | MNEMO_RL indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x10);
          }
        | MNEMO_RL indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x10);
          }
        | MNEMO_RL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x16);
          }
        | MNEMO_RL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x16);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x10 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x10 | $2);
          }
        | MNEMO_RRC REGISTRO {
            write_byte(0xcb);
            write_byte(0x08 | $2);
          }
        | MNEMO_RRC REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x0e);
          }
        | MNEMO_RRC indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x08);
          }
        | MNEMO_RRC indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x08);
          }
        | MNEMO_RRC indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x0e);
          }
        | MNEMO_RRC indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x0e);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RRC indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x08 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RRC indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x08 | $2);
          }
        | MNEMO_RR REGISTRO {
            write_byte(0xcb);
            write_byte(0x18 | $2);
          }
        | MNEMO_RR REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x1e);
          }
        | MNEMO_RR indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x18);
          }
        | MNEMO_RR indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x18);
          }
        | MNEMO_RR indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x1e);
          }
        | MNEMO_RR indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x1e);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RR indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x18 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RR indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x18 | $2);
          }
        | MNEMO_SLA REGISTRO {
            write_byte(0xcb);
            write_byte(0x20 | $2);
          }
        | MNEMO_SLA REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x26);
          } 
        | MNEMO_SLA indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x20);
          }
        | MNEMO_SLA indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x20);
          }
        | MNEMO_SLA indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x26);
          }
        | MNEMO_SLA indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x26);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SLA indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x20 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SLA indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x20 | $2);
          }
        | MNEMO_SLL REGISTRO {
            write_byte(0xcb);
            write_byte(0x30 | $2);
          }
        | MNEMO_SLL REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x36);
          }
        | MNEMO_SLL indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x30);
          }
        | MNEMO_SLL indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x30);
          }
        | MNEMO_SLL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x36);
          }
        | MNEMO_SLL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x36);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SLL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x30|$2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SLL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x30 | $2);
          }
        | MNEMO_SRA REGISTRO {
            write_byte(0xcb);
            write_byte(0x28 | $2);
          }
        | MNEMO_SRA REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x2e);
          }
        | MNEMO_SRA indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x28);
          }
        | MNEMO_SRA indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x28);
          }
        | MNEMO_SRA indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x2e);
          }
        | MNEMO_SRA indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x2e);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SRA indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x28 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SRA indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x28 | $2);
          }
        | MNEMO_SRL REGISTRO {
            write_byte(0xcb);
            write_byte(0x38 | $2);
          }
        | MNEMO_SRL REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x3e);
          }
        | MNEMO_SRL indireccion_IX ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x38);
          }
        | MNEMO_SRL indireccion_IY ',' REGISTRO {
            if ($4 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte($4 | 0x38);
          }
        | MNEMO_SRL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x3e);
          }
        | MNEMO_SRL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($2);
            write_byte(0x3e);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SRL indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x38 | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SRL indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($5);
            write_byte(0x38|$2);
          }
        | MNEMO_RLD {
            write_byte(0xed);
            write_byte(0x6f);
          }
        | MNEMO_RRD {
            write_byte(0xed);
            write_byte(0x67);
          }
;

mnemo_bits: MNEMO_BIT valor_3bits ',' REGISTRO {
            write_byte(0xcb);
            write_byte(0x40 | ($2 << 3) | ($4));
          }
        | MNEMO_BIT valor_3bits ',' REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x46 | ($2 << 3));
          }
        | MNEMO_BIT valor_3bits ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x46 | ($2 << 3));
          }
        | MNEMO_BIT valor_3bits ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x46 | ($2 << 3));
          }
        | MNEMO_SET valor_3bits ',' REGISTRO {
            write_byte(0xcb);
            write_byte(0xc0 | ($2 << 3) | ($4));
          }
        | MNEMO_SET valor_3bits ',' REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0xc6 | ($2 << 3));
          }
        | MNEMO_SET valor_3bits ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0xc6 | ($2 << 3));
          }
        | MNEMO_SET valor_3bits ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0xc6 | ($2 << 3));
          }
        | MNEMO_SET valor_3bits ',' indireccion_IX ',' REGISTRO {
            if ($6 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0xc0 | ($2 << 3) | $6);
          }
        | MNEMO_SET valor_3bits ',' indireccion_IY ',' REGISTRO {
            if ($6 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0xc0 | ($2 << 3) | $6);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SET valor_3bits ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($7);
            write_byte(0xc0 | ($5 << 3) | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_SET valor_3bits ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($7);
            write_byte(0xc0 | ($5 << 3) | $2);
          }
        | MNEMO_RES valor_3bits ',' REGISTRO {
            write_byte(0xcb);
            write_byte(0x80 | ($2 << 3) | ($4));
          }
        | MNEMO_RES valor_3bits ',' REGISTRO_IND_HL {
            write_byte(0xcb);
            write_byte(0x86 | ($2 << 3));
          }
        | MNEMO_RES valor_3bits ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x86 | ($2 << 3));
          }
        | MNEMO_RES valor_3bits ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x86 | ($2 << 3));
          }
        | MNEMO_RES valor_3bits ',' indireccion_IX ',' REGISTRO {
            if ($6 == 6)
              error_message(2);
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x80 | ($2 << 3) | $6);
          }
        | MNEMO_RES valor_3bits ',' indireccion_IY ',' REGISTRO {
            if ($6 == 6)
              error_message(2);
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($4);
            write_byte(0x80 | ($2 << 3) | $6);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RES valor_3bits ',' indireccion_IX {
            write_byte(0xdd);
            write_byte(0xcb);
            write_byte($7);
            write_byte(0x80 | ($5 << 3) | $2);
          }
        | MNEMO_LD REGISTRO ',' MNEMO_RES valor_3bits ',' indireccion_IY {
            write_byte(0xfd);
            write_byte(0xcb);
            write_byte($7);
            write_byte(0x80 | ($5 << 3) | $2);
          }
;

mnemo_io: MNEMO_IN REGISTRO ',' '[' valor_8bits ']' {
            if ($2 != 7)
              error_message(4);
            write_byte(0xdb);
            write_byte($5);
          }
        | MNEMO_IN REGISTRO ',' valor_8bits {
            if ($2 != 7)
              error_message(4);
            if (zilog)
              warning_message(5);
            write_byte(0xdb);
            write_byte($4);
          }
        | MNEMO_IN REGISTRO ',' '[' REGISTRO ']' {
            if ($5 != 1)
              error_message(2);
            write_byte(0xed);
            write_byte(0x40 | ($2 << 3));
          }
        | MNEMO_IN '[' REGISTRO ']'{
            if ($3 != 1)
              error_message(2);
            if (zilog)
              warning_message(5);
            write_byte(0xed);
            write_byte(0x70);
          }
        | MNEMO_IN REGISTRO_F ',' '[' REGISTRO ']' {
            if ($5 != 1)
              error_message(2);
            write_byte(0xed);
            write_byte(0x70);
          }
        | MNEMO_INI {
            write_byte(0xed);
            write_byte(0xa2);
          }
        | MNEMO_INIR {
            write_byte(0xed);
            write_byte(0xb2);
          }
        | MNEMO_IND {
            write_byte(0xed);
            write_byte(0xaa);
          }
        | MNEMO_INDR {
            write_byte(0xed);
            write_byte(0xba);
          }
        | MNEMO_OUT '[' valor_8bits ']' ',' REGISTRO {
            if ($6 != 7)
              error_message(5);
            write_byte(0xd3);
            write_byte($3);
          }
        | MNEMO_OUT valor_8bits ',' REGISTRO {
            if ($4 != 7)
              error_message(5);
            if (zilog)
              warning_message(5);
            write_byte(0xd3);
            write_byte($2);
          }
        | MNEMO_OUT '[' REGISTRO ']' ',' REGISTRO {
            if ($3 != 1)
              error_message(2);
            write_byte(0xed);
            write_byte(0x41 | ($6 << 3));
          }
        | MNEMO_OUT '[' REGISTRO ']' ',' valor_8bits {
            if ($3 != 1)
              error_message(2);
            if ($6 != 0)
              error_message(6);
            write_byte(0xed);
            write_byte(0x71);
          }
        | MNEMO_OUTI {
            write_byte(0xed);
            write_byte(0xa3);
          }
        | MNEMO_OTIR {
            write_byte(0xed);
            write_byte(0xb3);
          }
        | MNEMO_OUTD {
            write_byte(0xed);
            write_byte(0xab);
          }
        | MNEMO_OTDR {
            write_byte(0xed);
            write_byte(0xbb);
          }
        | MNEMO_IN '[' valor_8bits ']' {
            if (zilog)
              warning_message(5);
            write_byte(0xdb);
            write_byte($3);
          }
        | MNEMO_IN valor_8bits {
            if (zilog)
              warning_message(5);
            write_byte(0xdb);
            write_byte($2);
          }
        | MNEMO_OUT '[' valor_8bits ']' {
            if (zilog)
              warning_message(5);
            write_byte(0xd3);
            write_byte($3);
          }
        | MNEMO_OUT valor_8bits {
            if (zilog)
              warning_message(5);
            write_byte(0xd3);
            write_byte($2);
          }
;

mnemo_jump: MNEMO_JP valor_16bits {
            write_byte(0xc3);
            write_word($2);
          }
        | MNEMO_JP CONDICION ',' valor_16bits {
            write_byte(0xc2 | ($2 << 3));
            write_word($4);
          }
        | MNEMO_JP REGISTRO ',' valor_16bits {
            if ($2 != 1)
              error_message(7);
            write_byte(0xda);
            write_word($4);
          }
        | MNEMO_JR valor_16bits {
            write_byte(0x18);
            relative_jump($2);
          }
        | MNEMO_JR REGISTRO ',' valor_16bits {
            if ($2 != 1)
              error_message(7);
            write_byte(0x38);
            relative_jump($4);
          }
        | MNEMO_JR CONDICION ',' valor_16bits {
            if ($2 == 2)
              write_byte(0x30);
            else if ($2 == 1)
              write_byte(0x28);
            else if ($2 == 0)
              write_byte(0x20);
            else
              error_message(9);
            relative_jump($4);
          }
        | MNEMO_JP REGISTRO_PAR {
            if ($2 != 2)
              error_message(2);
            write_byte(0xe9);
          }
        | MNEMO_JP REGISTRO_IND_HL {
            write_byte(0xe9);
          }
        | MNEMO_JP REGISTRO_16_IX {
            write_byte(0xdd);
            write_byte(0xe9);
          }
        | MNEMO_JP REGISTRO_16_IY {
            write_byte(0xfd);
            write_byte(0xe9);
          }
        | MNEMO_JP '[' REGISTRO_16_IX ']' {
            write_byte(0xdd);
            write_byte(0xe9);
          }
        | MNEMO_JP '[' REGISTRO_16_IY ']' {
            write_byte(0xfd);
            write_byte(0xe9);
          }
        | MNEMO_DJNZ valor_16bits {
            write_byte(0x10);
            relative_jump($2);
          }
;

mnemo_call: MNEMO_CALL valor_16bits {
            write_byte(0xcd);
            write_word($2);
          }
        | MNEMO_CALL CONDICION ',' valor_16bits {
            write_byte(0xc4 | ($2 << 3));
            write_word($4);
          }
        | MNEMO_CALL REGISTRO ',' valor_16bits {
            if ($2 != 1)
              error_message(7);
            write_byte(0xdc);
            write_word($4);
          }
        | MNEMO_RET {
            write_byte(0xc9);
          }
        | MNEMO_RET CONDICION {
            write_byte(0xc0 | ($2 << 3));
          }
        | MNEMO_RET REGISTRO {
            if ($2 != 1)
              error_message(7);
            write_byte(0xd8);
          }
        | MNEMO_RETI {
            write_byte(0xed);
            write_byte(0x4d);
          }
        | MNEMO_RETN {
            write_byte(0xed);
            write_byte(0x45);
          }
        | MNEMO_RST valor_8bits {
            if (($2 % 8 != 0) || ($2 / 8 > 7) || ($2 / 8 < 0))
              error_message(10);
            write_byte(0xc7 | (($2 / 8) << 3));
          }

valor: NUMERO {
            $$ = $1;
          }
        | IDENTIFICADOR {
            $$ = read_label($1);
          }
        | LOCAL_IDENTIFICADOR {
            $$ = read_local($1);
          }
        | '-' valor %prec NEGATIVO {
            $$ =- $2;
          }
        | valor OP_EQUAL valor {
            $$ = ($1 == $3);
          }
        | valor OP_MINOR_EQUAL valor {
            $$ = ($1 <= $3);
          }
        | valor OP_MINOR valor {
            $$ = ($1 < $3);
          }
        | valor OP_MAJOR_EQUAL valor {
            $$ = ($1 >= $3);
          }
        | valor OP_MAJOR valor {
            $$ = ($1 > $3);
          }
        | valor OP_NON_EQUAL valor {
            $$ = ($1 != $3);
          }
        | valor OP_OR_LOG valor {
            $$ = ($1 || $3);
          }
        | valor OP_AND_LOG valor {$$ = ($1 && $3);
          }
        | valor '+' valor {
            $$ = $1 + $3;
          }
        | valor '-' valor {
            $$ = $1 - $3;
          }
        | valor '*' valor {
            $$ = $1 * $3;
          }
        | valor '/' valor {
            if (!$3)
              error_message(1);
            else
              $$ = $1 / $3;
          }
        | valor '%' valor {
            if (!$3)
              error_message(1);
            else
              $$ = $1 % $3;
          }
        | '(' valor ')' {
            $$ = $2;
          }
        | '~' valor %prec NEGACION {
            $$ =~ $2;
          }
        | '!' valor %prec OP_NEG_LOG {
            $$ =! $2;
          }
        | valor '&' valor {
            $$ = $1 & $3;
          }
        | valor OP_OR valor {
            $$ = $1 | $3;
          }
        | valor OP_XOR valor {
            $$ = $1 ^ $3;
          }
        | valor SHIFT_L valor {
            $$ = $1 << $3;
          }
        | valor SHIFT_R valor {
            $$ = $1 >> $3;
          }
        | PSEUDO_RANDOM '(' valor ')' {
          for (; ($$ = d_rand() & 0xff) >= $3;)
            ;
          }
        | PSEUDO_INT '(' valor_real ')' {
            $$ = (int)$3;
          }
        | PSEUDO_FIX '(' valor_real ')' {
            $$ = (int)($3 * 256);
          }
        | PSEUDO_FIXMUL '(' valor ',' valor ')' {
            $$ = (int)((((float)$3 / 256) * ((float) $5 / 256)) * 256);
          }
        | PSEUDO_FIXDIV '(' valor ',' valor ')' {
            $$ = (int)((((float)$3 / 256) / ((float)$5 / 256)) * 256);
          }
;

valor_real: REAL {
            $$ = $1;
          }
        | '-' valor_real {
            $$ =- $2;
          }
        | valor_real '+' valor_real {
            $$ = $1 + $3;
          }
        | valor_real '-' valor_real {
            $$ = $1 - $3;
          }
        | valor_real '*' valor_real {
            $$ = $1 * $3;
          }
        | valor_real '/' valor_real {
            if (!$3)
              error_message(1);
            else
              $$ = $1 / $3;
          }
        | valor '+' valor_real {
            $$ = (double)$1 + $3;
          }
        | valor '-' valor_real {
            $$ = (double)$1 - $3;
          }
        | valor '*' valor_real {
            $$ = (double)$1 * $3;
          }
        | valor '/' valor_real {
            if ($3 < 1e-6)
              error_message(1);
            else
              $$ = (double)$1 / $3;
          }
        | valor_real '+' valor {
            $$ = $1 + (double)$3;
          }
        | valor_real '-' valor {
            $$ = $1 - (double)$3;
          }
        | valor_real '*' valor {
            $$ = $1 * (double)$3;
          }
        | valor_real '/' valor {
            if (!$3)
              error_message(1);
            else
              $$ = $1 / (double)$3;
          }
        | PSEUDO_SIN '(' valor_real ')' {
            $$ = sin($3);
          }
        | PSEUDO_COS '(' valor_real ')' {
            $$ = cos($3);
          }
        | PSEUDO_TAN '(' valor_real ')' {
            $$ = tan($3);
          }
        | PSEUDO_SQR '(' valor_real ')' {
            $$ = $3 * $3;
          }
        | PSEUDO_SQRT '(' valor_real ')' {
            $$ = sqrt($3);
          }
        | PSEUDO_PI {
            $$ = 3.14159265358979323846;	/* use this instead of M_PI to avoid slightly different ROMs depending on compiler */
          }
        | PSEUDO_ABS '(' valor_real ')' {
            $$ = abs((int)$3);
          }
        | PSEUDO_ACOS '(' valor_real ')' {
            $$ = acos($3);
          }
        | PSEUDO_ASIN '(' valor_real ')' {
            $$ = asin($3);
          }
        | PSEUDO_ATAN '(' valor_real ')' {
            $$ = atan($3);
          }
        | PSEUDO_EXP '(' valor_real ')' {
            $$ = exp($3);
          }
        | PSEUDO_LOG '(' valor_real ')' {
            $$ = log10($3);
          }
        | PSEUDO_LN '(' valor_real ')' {
            $$ = log($3);
          }
        | PSEUDO_POW '(' valor_real ',' valor_real ')' {
            $$ = pow($3, $5);
          }
        | '(' valor_real ')' {
            $$ = $2;
          }
;

valor_3bits: valor {
            if (($1 < 0) || ($1 > 7))
              warning_message(3);
            $$ = $1 & 0x07;
          }
;

valor_8bits: valor {
            if (($1 > 255) || ($1 < -128))
              warning_message(2);
            $$ = $1 & 0xff;
          }
;

valor_16bits: valor {
            if (($1 > 65535) || ($1 < -32768))
              warning_message(1);
            $$ = $1 & 0xffff;
          }
;

listado_8bits : valor_8bits {
            write_byte($1);
          }
        | TEXTO {
            write_string($1);
          }
        | listado_8bits ',' valor_8bits {
            write_byte($3);
          }
        | listado_8bits ',' TEXTO {
            write_string($3);
          }
;

listado_16bits : valor_16bits {
            write_word($1);
          }
        | TEXTO {
            write_string($1);
          }
        | listado_16bits ',' valor_16bits {
            write_word($3);
          }
        | listado_16bits ',' TEXTO {
            write_string($3);
          }
;

%%

/* Additional C functions */
void msx_bios()
{
  bios = 1;
  /* BIOS routines */
  register_symbol("CHKRAM", 0x0000, 0);
  register_symbol("SYNCHR", 0x0008, 0);
  register_symbol("RDSLT" , 0x000c, 0);
  register_symbol("CHRGTR", 0x0010, 0);
  register_symbol("WRSLT" , 0x0014, 0);
  register_symbol("OUTDO" , 0x0018, 0);
  register_symbol("CALSLT", 0x001c, 0);
  register_symbol("DCOMPR", 0x0020, 0);
  register_symbol("ENASLT", 0x0024, 0);
  register_symbol("GETYPR", 0x0028, 0);
  register_symbol("CALLF" , 0x0030, 0);
  register_symbol("KEYINT", 0x0038, 0);
  register_symbol("INITIO", 0x003b, 0);
  register_symbol("INIFNK", 0x003e, 0);
  register_symbol("DISSCR", 0x0041, 0);
  register_symbol("ENASCR", 0x0044, 0);
  register_symbol("WRTVDP", 0x0047, 0);
  register_symbol("RDVRM" , 0x004a, 0);
  register_symbol("WRTVRM", 0x004d, 0);
  register_symbol("SETRD" , 0x0050, 0);
  register_symbol("SETWRT", 0x0053, 0);
  register_symbol("FILVRM", 0x0056, 0);
  register_symbol("LDIRMV", 0x0059, 0);
  register_symbol("LDIRVM", 0x005c, 0);
  register_symbol("CHGMOD", 0x005f, 0);
  register_symbol("CHGCLR", 0x0062, 0);
  register_symbol("NMI"   , 0x0066, 0);
  register_symbol("CLRSPR", 0x0069, 0);
  register_symbol("INITXT", 0x006c, 0);
  register_symbol("INIT32", 0x006f, 0);
  register_symbol("INIGRP", 0x0072, 0);
  register_symbol("INIMLT", 0x0075, 0);
  register_symbol("SETTXT", 0x0078, 0);
  register_symbol("SETT32", 0x007b, 0);
  register_symbol("SETGRP", 0x007e, 0);
  register_symbol("SETMLT", 0x0081, 0);
  register_symbol("CALPAT", 0x0084, 0);
  register_symbol("CALATR", 0x0087, 0);
  register_symbol("GSPSIZ", 0x008a, 0);
  register_symbol("GRPPRT", 0x008d, 0);
  register_symbol("GICINI", 0x0090, 0);
  register_symbol("WRTPSG", 0x0093, 0);
  register_symbol("RDPSG" , 0x0096, 0);
  register_symbol("STRTMS", 0x0099, 0);
  register_symbol("CHSNS" , 0x009c, 0);
  register_symbol("CHGET" , 0x009f, 0);
  register_symbol("CHPUT" , 0x00a2, 0);
  register_symbol("LPTOUT", 0x00a5, 0);
  register_symbol("LPTSTT", 0x00a8, 0);
  register_symbol("CNVCHR", 0x00ab, 0);
  register_symbol("PINLIN", 0x00ae, 0);
  register_symbol("INLIN" , 0x00b1, 0);
  register_symbol("QINLIN", 0x00b4, 0);
  register_symbol("BREAKX", 0x00b7, 0);
  register_symbol("ISCNTC", 0x00ba, 0);
  register_symbol("CKCNTC", 0x00bd, 0);
  register_symbol("BEEP"  , 0x00c0, 0);
  register_symbol("CLS"   , 0x00c3, 0);
  register_symbol("POSIT" , 0x00c6, 0);
  register_symbol("FNKSB" , 0x00c9, 0);
  register_symbol("ERAFNK", 0x00cc, 0);
  register_symbol("DSPFNK", 0x00cf, 0);
  register_symbol("TOTEXT", 0x00d2, 0);
  register_symbol("GTSTCK", 0x00d5, 0);
  register_symbol("GTTRIG", 0x00d8, 0);
  register_symbol("GTPAD" , 0x00db, 0);
  register_symbol("GTPDL" , 0x00de, 0);
  register_symbol("TAPION", 0x00e1, 0);
  register_symbol("TAPIN" , 0x00e4, 0);
  register_symbol("TAPIOF", 0x00e7, 0);
  register_symbol("TAPOON", 0x00ea, 0);
  register_symbol("TAPOUT", 0x00ed, 0);
  register_symbol("TAPOOF", 0x00f0, 0);
  register_symbol("STMOTR", 0x00f3, 0);
  register_symbol("LFTQ"  , 0x00f6, 0);
  register_symbol("PUTQ"  , 0x00f9, 0);
  register_symbol("RIGHTC", 0x00fc, 0);
  register_symbol("LEFTC" , 0x00ff, 0);
  register_symbol("UPC"   , 0x0102, 0);
  register_symbol("TUPC"  , 0x0105, 0);
  register_symbol("DOWNC" , 0x0108, 0);
  register_symbol("TDOWNC", 0x010b, 0);
  register_symbol("SCALXY", 0x010e, 0);
  register_symbol("MAPXYC", 0x0111, 0);
  register_symbol("FETCHC", 0x0114, 0);
  register_symbol("STOREC", 0x0117, 0);
  register_symbol("SETATR", 0x011a, 0);
  register_symbol("READC" , 0x011d, 0);
  register_symbol("SETC"  , 0x0120, 0);
  register_symbol("NSETCX", 0x0123, 0);
  register_symbol("GTASPC", 0x0126, 0);
  register_symbol("PNTINI", 0x0129, 0);
  register_symbol("SCANR" , 0x012c, 0);
  register_symbol("SCANL" , 0x012f, 0);
  register_symbol("CHGCAP", 0x0132, 0);
  register_symbol("CHGSND", 0x0135, 0);
  register_symbol("RSLREG", 0x0138, 0);
  register_symbol("WSLREG", 0x013b, 0);
  register_symbol("RDVDP" , 0x013e, 0);
  register_symbol("SNSMAT", 0x0141, 0);
  register_symbol("PHYDIO", 0x0144, 0);
  register_symbol("FORMAT", 0x0147, 0);
  register_symbol("ISFLIO", 0x014a, 0);
  register_symbol("OUTDLP", 0x014d, 0);
  register_symbol("GETVCP", 0x0150, 0);
  register_symbol("GETVC2", 0x0153, 0);
  register_symbol("KILBUF", 0x0156, 0);
  register_symbol("CALBAS", 0x0159, 0);
  register_symbol("SUBROM", 0x015c, 0);
  register_symbol("EXTROM", 0x015f, 0);
  register_symbol("CHKSLZ", 0x0162, 0);
  register_symbol("CHKNEW", 0x0165, 0);
  register_symbol("EOL"   , 0x0168, 0);
  register_symbol("BIGFIL", 0x016b, 0);
  register_symbol("NSETRD", 0x016e, 0);
  register_symbol("NSTWRT", 0x0171, 0);
  register_symbol("NRDVRM", 0x0174, 0);
  register_symbol("NWRVRM", 0x0177, 0);
  register_symbol("RDBTST", 0x017a, 0);
  register_symbol("WRBTST", 0x017d, 0);
  register_symbol("CHGCPU", 0x0180, 0);
  register_symbol("GETCPU", 0x0183, 0);
  register_symbol("PCMPLY", 0x0186, 0);
  register_symbol("PCMREC", 0x0189, 0);
}

void error_message(int codigo)
{
  printf("%s, line %d: ", strtok(fuente, "\042"), lineas);
  switch (codigo)
  {
    case 0:
      fprintf(stderr, "syntax error\n");
      break;
    case 1:
      fprintf(stderr, "memory overflow\n");
      break;
    case 2:
      fprintf(stderr, "wrong register combination\n");
      break;
    case 3:
      fprintf(stderr, "wrong interruption mode\n");
      break;
    case 4:
      fprintf(stderr, "destiny register should be A\n");
      break;
    case 5:
      fprintf(stderr, "source register should be A\n");break;
    case 6:
      fprintf(stderr, "value should be 0\n");
      break;
    case 7:
      fprintf(stderr, "missing condition\n");
      break;
    case 8:
      fprintf(stderr, "unreachable address\n");
      break;
    case 9:
      fprintf(stderr, "wrong condition\n");
      break;
    case 10:
      fprintf(stderr, "wrong restart address\n");
      break;
    case 11:
      fprintf(stderr, "symbol table overflow\n");
      break;
    case 12:
      fprintf(stderr, "undefined identifier\n");
      break;
    case 13:
      fprintf(stderr, "undefined local label\n");
      break;
    case 14:
      fprintf(stderr, "symbol redefinition\n");
      break;
    case 15:
      fprintf(stderr, "size redefinition\n");
      break;
    case 16:
      fprintf(stderr, "reserved word used as identifier\n");
      break;
    case 17:
      fprintf(stderr, "code size overflow\n");
      break;
    case 18:
      fprintf(stderr, "binary file not found\n");
      break;
    case 19:
      fprintf(stderr, "ROM directive should preceed any code\n");
      break;
    case 20:
      fprintf(stderr, "type previously defined\n");
      break;
    case 21:
      fprintf(stderr, "BASIC directive should preceed any code\n");
      break;
    case 22:
      fprintf(stderr, "page out of range\n");
      break;
    case 23:
      fprintf(stderr, "MSXDOS directive should preceed any code\n");
      break;
    case 24:
      fprintf(stderr, "no code in the whole file\n");
      break;
    case 25:
      fprintf(stderr, "only available for MSXDOS\n");
      break;
    case 26:
      fprintf(stderr, "machine not defined\n");
      break;
    case 27:
      fprintf(stderr, "MegaROM directive should preceed any code\n");
      break;
    case 28:
      fprintf(stderr, "cannot write ROM code/data to page 3\n");
      break;
    case 29:
      fprintf(stderr, "included binary shorter than expected\n");
      break;
    case 30:
      fprintf(stderr, "wrong number of bytes to skip/include\n");
      break;
    case 31:
      fprintf(stderr, "megaROM subpage overflow\n");
      break;
    case 32:
      fprintf(stderr, "subpage 0 can only be defined by megaROM directive\n");
      break;
    case 33:
      fprintf(stderr, "unsupported mapper type\n");
      break;
    case 34:
      fprintf(stderr, "megaROM code should be between 4000h and BFFFh\n");
      break;
    case 35:
      fprintf(stderr, "code/data without subpage\n");
      break;
    case 36:
      fprintf(stderr, "megaROM mapper subpage out of range\n");
      break;
    case 37:
      fprintf(stderr, "megaROM subpage already defined\n");
      break;
    case 38:
      fprintf(stderr, "Konami megaROM forces page 0 at 4000h\n");
      break;
    case 39:
      fprintf(stderr, "megaROM subpage not defined\n");
      break;
    case 40:
      fprintf(stderr, "megaROM-only macro used\n");
      break;
    case 41:
      fprintf(stderr, "only for ROMs and megaROMs\n");
      break;
    case 42:
      fprintf(stderr, "ELSE without IF\n");
      break;
    case 43:
      fprintf(stderr, "ENDIF without IF\n");
      break;
    case 44:
      fprintf(stderr, "Cannot nest more IF's\n");
      break;
    case 45:
      fprintf(stderr, "IF not closed\n");
      break;
    case 46:
      fprintf(stderr, "Sinclair directive should preceed any code\n");
      break;
    default:
      fprintf(stderr, "Unexpected error code %d\n", codigo);
  }
  remove("~tmppre.?");
  exit(codigo + 1);
}

void warning_message(int codigo)
{
  if (pass != 2)
    return;

  printf("%s, line %d: Warning: ", strtok(fuente, "\042"), lineas);
  switch (codigo)
  {
    case 0:
      fprintf(stderr, "undefined error\n");
      break;
    case 1:
      fprintf(stderr, "16-bit overflow\n");
      break;
    case 2:
      fprintf(stderr, "8-bit overflow\n");
      break;
    case 3:
      fprintf(stderr, "3-bit overflow\n");
      break;
    case 4:
      fprintf(stderr, "output cannot be converted to CAS\n");
      break;
    case 5:
      fprintf(stderr, "non official Zilog syntax\n");
      break;
    case 6:
      fprintf(stderr, "undocumented Zilog instruction\n");
      break;
    default:
      fprintf(stderr, "unexpected warning %d\n", codigo);
  }
  advertencias++;
}

/* Generate byte */
void write_byte(int b)
{
  /* If the condition of this block is fulfilled, create the code */
  if ((!conditional_level) || (conditional[conditional_level]))
  {
    if (type != MEGAROM)
    {
      if (PC >= 0x10000)
        error_message(1);

      if ((type == ROM) && (PC >= 0xC000))
        error_message(28);

      if (dir_inicio > PC)
        dir_inicio = PC;

      if (dir_final < PC)
        dir_final = PC;

      if (size && (PC >= dir_inicio + size * 1024) && (pass == 2))
        error_message(17);

      if (size && (dir_inicio + size * 1024 > 65536) && (pass == 2))
        error_message(1);

      memory[PC++] = (char)b;
      ePC++;
    }
    else
    {	/* if (type==MEGAROM) */
      if (subpage == 0x100)
        error_message(35);

      if (PC >= pageinit + 1024 * pagesize)
        error_message(31);

      memory[subpage * pagesize * 1024 + PC - pageinit] = (char)b;
      PC++;
      ePC++;
    }
  }
}

void write_string(char *str)
{
  size_t t;
  for (t = 0; t < strlen(str); t++)
    write_byte((int)str[t]);
}

void write_word(int w)
{
  write_byte(w & 0xff);
  write_byte((w >> 8) & 0xff);
}

void relative_jump(int direccion)
{
  int salto;

  salto = direccion - ePC - 1;

  if ((salto > 127) || (salto < -128))
    error_message(8);

  write_byte(salto);
}

void register_label(char *nombre)
{
  int i;

  if (pass == 2)
    for (i = 0; i < maxima; i++)
      if (!strcmp(nombre, lista_identificadores[i].nombre))
      {
        ultima_global = i;
        return;
      }

  for (i = 0; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
      error_message(14);

  if (++maxima == MAX_ID)
    error_message(11);

  lista_identificadores[maxima - 1].nombre = malloc(strlen(nombre) + 4);
  strcpy(lista_identificadores[maxima - 1].nombre, nombre);
  lista_identificadores[maxima - 1].valor = ePC;
  lista_identificadores[maxima-1].type = 1;
  lista_identificadores[maxima-1].pagina = subpage;
  ultima_global = maxima - 1;
}

void register_local(char *nombre)
{
  int i;

  if (pass == 2)
    return;

  for (i = ultima_global; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
      error_message(14);

  if (++maxima == MAX_ID)
    error_message(11);

  lista_identificadores[maxima - 1].nombre = malloc(strlen(nombre) + 4);
  strcpy(lista_identificadores[maxima - 1].nombre, nombre);
  lista_identificadores[maxima - 1].valor = ePC;
  lista_identificadores[maxima - 1].type = 1;
  lista_identificadores[maxima - 1].pagina = subpage;
}

void register_symbol(char *nombre, int numero, int type)
{
  int i;
  char *_nombre;

  if (pass == 2)
    return;

  for (i = 0; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
    {
      error_message(14);
      return;
    }

  if (++maxima == MAX_ID)
    error_message(11);

  lista_identificadores[maxima - 1].nombre = malloc(strlen(nombre) + 1);

  /* guarantees we won't pass string literal to strtok(), which causes SEGFAULT on GCC 6.2.0 */
  _nombre = strdup(nombre);
  if (!_nombre)
  {
    printf("Error: can't allocate memory with strdup() in %s\n", __func__);
    exit(1);
  }

  strcpy(lista_identificadores[maxima - 1].nombre, strtok(_nombre, " "));
  free(_nombre);

  lista_identificadores[maxima - 1].valor = numero;
  lista_identificadores[maxima - 1].type = type;
}

void register_variable(char *nombre, int numero)
{
  int i;

  for (i = 0; i < maxima; i++)
    if ((!strcmp(nombre, lista_identificadores[i].nombre)) && (lista_identificadores[i].type == 3))
    {
      lista_identificadores[i].valor = numero;
      return;
    }

  if (++maxima == MAX_ID)
    error_message(11);

  lista_identificadores[maxima - 1].nombre = malloc(strlen(nombre) + 1);
  strcpy(lista_identificadores[maxima - 1].nombre, strtok(nombre, " "));
  lista_identificadores[maxima - 1].valor = numero;
  lista_identificadores[maxima - 1].type = 3;
}

int read_label(char *nombre)
{
  int i;

  for (i = 0; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
      return lista_identificadores[i].valor;

  if ((pass == 1) && (i == maxima))
    return ePC;

  error_message(12);
  exit(0);	/* error_message() never returns; add exit() to stop compiler warnings about bad return value */
}

int read_local(char *nombre)
{
  int i;

  if (pass == 1)
    return ePC;

  for (i = ultima_global; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
      return lista_identificadores[i].valor;

  error_message(13);
  exit(0);	/* error_message() never returns; add exit() to stop compiler warnings about bad return value */
}

void create_txt()
{
  /* Generate the name of output text file */
  strcpy(salida, filename);
  salida = strcat(salida, ".txt");
  fmsg = fopen(salida, "wt");
  if (fmsg == NULL)
    return;

  fprintf(fmsg, "; Output text file from %s\n", ensamblador);
  fprintf(fmsg, "; generated by asMSX v.%s\n\n", VERSION);
  printf("Output text file %s saved\n", salida);
}

void salvar_simbolos()
{
  int i, j;
  FILE *fichero;

  j = 0;
  for (i = 0; i < maxima; i++)
    j += lista_identificadores[i].type;

  if (j > 0)
  {
    if ((fichero = fopen(simbolos, "wt")) == NULL)
	{
      error_message(0);
	  exit(1); /* this is unreachable due to error_message() never returning; use it to prevent code analyzer warning */
	}

    fprintf(fichero, "; Symbol table from %s\n", ensamblador);
    fprintf(fichero, "; generated by asMSX v.%s\n\n", VERSION);

    j = 0;
    for (i = 0; i < maxima; i++)
      if (lista_identificadores[i].type == 1)
        j++;
    if (j > 0)
    {
      fprintf(fichero, "; global and local labels\n");
      for (i = 0; i < maxima; i++)
        if (lista_identificadores[i].type == 1)
        {
          if (type != MEGAROM)
            fprintf(fichero, "%4.4Xh %s\n", lista_identificadores[i].valor, lista_identificadores[i].nombre);
          else
            fprintf(fichero, "%2.2Xh:%4.4Xh %s\n", lista_identificadores[i].pagina & 0xff, lista_identificadores[i].valor, lista_identificadores[i].nombre);
        }
    }

    j = 0;
    for (i = 0; i < maxima; i++)
      if (lista_identificadores[i].type == 2)
        j++;
    if (j > 0)
    {
      fprintf(fichero, "; other identifiers\n");
      for (i = 0; i < maxima; i++)
        if (lista_identificadores[i].type == 2)
          fprintf(fichero, "%4.4Xh %s\n", lista_identificadores[i].valor, lista_identificadores[i].nombre);
    }

    j = 0;
    for (i=0; i < maxima; i++)
      if (lista_identificadores[i].type == 3)
        j++;
    if (j > 0)
    {
      fprintf(fichero, "; variables - value on exit\n");
      for (i = 0; i < maxima; i++)
        if (lista_identificadores[i].type == 3)
          fprintf(fichero, "%4.4Xh %s\n", lista_identificadores[i].valor, lista_identificadores[i].nombre);
    }

    fclose(fichero);
    printf("Symbol file %s saved\n", simbolos);
  }
}

void yyerror(char *s)
{
  /* print bison error message */
  fprintf(stderr, "Parsing error: %s\n", s);
  error_message(0);
}

void include_binary(char *nombre, int skip, int n)
{
  FILE *fichero;
  int k;
  int i;

  if ((fichero = fopen(nombre, "rb")) == NULL)
    error_message(18);

  if (pass == 1)
    printf("Including binary file %s", nombre);

  if ((pass == 1) && (skip))
    printf(", skipping %i bytes", skip);

  if ((pass == 1) && n)
    printf(", saving %i bytes", n);

  if (pass == 1)
    printf("\n");
 
  if (skip)
    for (i = 0; (!feof(fichero)) && (i < skip); i++)
      k = fgetc(fichero);
 
  if (skip && feof(fichero))
    error_message(29);
 
  if (n)
  {
    for (i = 0; (i < n) && (!feof(fichero));)
    {
      k = fgetc(fichero);
      if (!feof(fichero))
      {
        write_byte(k);
        i++;
      }
    }
    if (i < n)
      error_message(29);
  }
  else
    for (; !feof(fichero);)		/* TODO: rewrite this as while loop and test it */
    {
      k = fgetc(fichero);
      if (!feof(fichero))		/* TODO: can this loose the last byte from included file? */
        write_byte(k);
    }

  fclose(fichero);
}


void write_zx_byte(int c)
{
  int k;
  k = c & 0xff;
  putc(k, output);
  parity ^= k;
}

void write_zx_word(int c)
{
  write_zx_byte(c & 0xff);
  write_zx_byte((c >> 8) & 0xff);
}

void write_zx_number(int i)
{
  int c;

  c = i / 10000;
  i -= c * 10000;
  write_zx_byte(c + 48);

  c = i / 1000;
  i -= c * 1000;
  write_zx_byte(c + 48);

  c = i / 100;
  i -= c * 100;
  write_zx_byte(c + 48);

  c = i / 10;
  write_zx_byte(c + 48);

  i %= 10;
  write_zx_byte(i + 48);
}

void write_bin()
{
  int i, j;

  if ((dir_inicio > dir_final) && (type != MEGAROM))
    error_message(24);

  if (type == Z80)
    binario = strcat(binario, ".z80");
  else if (type == ROM)
  {
    binario = strcat(binario, ".rom");
    PC = dir_inicio + 2;
    write_word(inicio);
    if (!size)
      size = 8 * ((dir_final - dir_inicio + 8191) / 8192);
  }
  else if (type == BASIC)
    binario = strcat(binario, ".bin");
  else if (type == MSXDOS)
    binario = strcat(binario, ".com");
  else if (type == MEGAROM)
  {
    binario = strcat(binario, ".rom");
    PC = 0x4002;
    subpage = 0x00;
    pageinit = 0x4000;
    write_word(inicio);
  }
  else if (type == SINCLAIR)
    binario = strcat(binario, ".tap");

  if (type == MEGAROM)
  {
    for (i = 1, j = 0; i <= lastpage; i++)
      j += usedpage[i];
    j >>= 1;
    if (j < lastpage)
      fprintf(stderr, "Warning: %i out of %i megaROM pages are not defined\n", lastpage - j, lastpage);
  }

  printf("Binary file %s saved\n", binario);
  output = fopen(binario, "wb");
  if (type == BASIC)
  {
    putc(0xfe, output);
    putc(dir_inicio & 0xff, output);
    putc((dir_inicio >> 8) & 0xff, output);
    putc(dir_final & 0xff, output);
    putc((dir_final >> 8) & 0xff, output);
    if (!inicio)
      inicio = dir_inicio;
    putc(inicio & 0xff, output);
    putc((inicio >> 8) & 0xff, output);
  }
  else if (type == SINCLAIR)
  {
    if (inicio)
    {
      putc(0x13, output);
      putc(0, output);
      putc(0, output);
      parity = 0x20;
      write_zx_byte(0);

      {
        size_t t;
        for (t = 0; t < 10; t++) 
          if (t < strlen(filename))
            write_zx_byte(filename[t]);
          else
            write_zx_byte(0x20);
      }

      write_zx_byte(0x1e);      /* line length */
      write_zx_byte(0);
      write_zx_byte(0x0a);      /* 10 */
      write_zx_byte(0);
      write_zx_byte(0x1e);      /* line length */
      write_zx_byte(0);
      write_zx_byte(0x1b);
      write_zx_byte(0x20);
      write_zx_byte(0);
      write_zx_byte(0xff);
      write_zx_byte(0);
      write_zx_byte(0x0a);
      write_zx_byte(0x1a);
      write_zx_byte(0);
      write_zx_byte(0xfd);      /* CLEAR */
      write_zx_byte(0xb0);      /* VAL */
      write_zx_byte('\"');
      write_zx_number(dir_inicio - 1);
      write_zx_byte('\"');
      write_zx_byte(':');
      write_zx_byte(0xef);      /* LOAD */
      write_zx_byte('\"');
      write_zx_byte('\"');
      write_zx_byte(0xaf);      /* CODE */
      write_zx_byte(':');
      write_zx_byte(0xf9);      /* RANDOMIZE */
      write_zx_byte(0xc0);      /* USR */
      write_zx_byte(0xb0);      /* VAL */
      write_zx_byte('\"');
      write_zx_number(inicio);
      write_zx_byte('\"');
      write_zx_byte(0x0d);
      write_zx_byte(parity);
    }

    putc(19, output);		/* Header len */
    putc(0, output);		/* MSB of len */
    putc(0, output);		/* Header is 0 */
    parity = 0;

    write_zx_byte(3);		/* Filetype (Code) */

    {
      size_t t;
      for (t = 0; t < 10; t++) 
        if (t < strlen(filename))
          write_zx_byte(filename[t]);
        else
          write_zx_byte(0x20);
    }

    write_zx_word(dir_final - dir_inicio + 1);
    write_zx_word(dir_inicio);	/* load address */
    write_zx_word(0);		/* offset */
    write_zx_byte(parity);

    write_zx_word(dir_final - dir_inicio + 3);	/* Length of next block */
    parity = 0;
    write_zx_byte(255);		/* Data... */

    for (i = dir_inicio; i <= dir_final; i++)
      write_zx_byte(memory[i]);
    write_zx_byte(parity);
  }

  if (type != SINCLAIR)
  {
    if (!size)
    {
      if (type != MEGAROM)
        for (i = dir_inicio; i <= dir_final; i++)
          putc(memory[i], output);
      else
        for (i = 0; i < (lastpage + 1) * pagesize * 1024; i++)
          putc(memory[i], output);
    } else if (type != MEGAROM)
      for (i = dir_inicio; i < dir_inicio + size * 1024; i++)
        putc(memory[i], output);
    else
      for (i = 0; i < size * 1024; i++)
        putc(memory[i], output);
  }

  fclose(output);
}

void finalize()
{
  /* Generate the name of file with symbolic information */
  strcpy(simbolos, filename);
  simbolos = strcat(simbolos, ".sym");
 
  write_bin();

  if (cassette & 1)
    write_cas();

  if (cassette & 2)
    write_wav();

  if (maxima > 0)
    salvar_simbolos();

  printf("Completed in %.2f seconds", (float)clock() / (float)CLOCKS_PER_SEC);

  if (advertencias > 1)
    fprintf(stderr, ", %i warnings\n", advertencias);
  else if (advertencias == 1)
    fprintf(stderr, ", 1 warning\n");
  else
    printf("\n");

  remove("~tmppre.*");
  exit(0);
}

void inicializar_memory()
{
  const size_t memory_size = 0x1000000;	/* 16 megabytes */

  memory = malloc(memory_size);
  if (!memory)
  {
    fprintf(stderr, "Failed to allocate %lu bytes for pointer 'memory' in function '%s'\n", (unsigned long)memory_size, __func__);
    exit(1);
  }

  memset(memory, 0, memory_size);
}

void inicializar_sistema()
{
  inicializar_memory();
  interno = malloc(256);
  interno[0] = 0;
  register_symbol("Eduardo_A_Robsy_Petrus_2007", 0, 0);
}

void type_sinclair()
{
  if ((type) && (type != SINCLAIR))
    error_message(46);
  type = SINCLAIR;
  if (!dir_inicio)
  {
    PC = 0x8000;
    ePC = PC;
  }
}

void type_rom()
{
  if ((pass == 1) && (!dir_inicio))
    error_message(19);

  if ((type) && (type != ROM))
    error_message(20);

  type = ROM;
  write_byte(65);
  write_byte(66);
  PC += 14;
  ePC += 14;
  if (!inicio)
    inicio = ePC;
}

void type_megarom(int n)
{
  int i;

  if (pass == 1)
    for (i = 0; i < 256; i++)
      usedpage[i] = 0;

  if ((pass == 1) && (!dir_inicio))
    error_message(19);
/* 
  if ((pass == 1) && ((!PC) || (!ePC)))
    error_message(19); 
*/
  if ((type) && (type != MEGAROM))
    error_message(20);

  if ((n < 0) || (n > 3))
    error_message(33);

  type = MEGAROM;

  usedpage[0] = 1;
  subpage = 0;
  pageinit = 0x4000;
  lastpage = 0;

  if ((n == 0) || (n == 1) || (n == 2))
    pagesize = 8;
  else
    pagesize = 16;

  mapper = n;
  PC = 0x4000;
  ePC = 0x4000;
  write_byte(65);
  write_byte(66);
  PC += 14;
  ePC += 14;
  if (!inicio)
    inicio = ePC;
}


void type_basic()
{
  if ((pass == 1) && (!dir_inicio))
    error_message(21);

  if ((type) && (type != BASIC))
    error_message(20);

  type = BASIC;
}

void type_msxdos()
{
  if ((pass == 1) && (!dir_inicio))
    error_message(23);

  if ((type) && (type != MSXDOS))
    error_message(20);
  type = MSXDOS;
  PC = 0x0100;
  ePC = 0x0100;
}

void create_subpage(int n, int dir)
{
  if (n > lastpage)
    lastpage = n;

  if (!n)
    error_message(32);

  if (usedpage[n] == pass)
    error_message(37);
  else
    usedpage[n] = pass;

  if ((dir < 0x4000) || (dir > 0xbfff))
    error_message(35);

  if (n > maxpage[mapper])
    error_message(36);

  subpage = n;
  pageinit = (dir / pagesize) * pagesize;
  PC = pageinit;
  ePC = PC;
}

void locate_32k()
{
  int i;
  int locate32[31] = {
	  0xCD, 0x38, 0x01, 0x0F,
	  0x0F, 0xE6, 0x03, 0x4F,
	  0x21, 0xC1, 0xFC, 0x85,
	  0x6F, 0x7E, 0xE6, 0x80,
	  0xB1, 0x4F, 0x2C, 0x2C,
	  0x2C, 0x2C, 0x7E, 0xE6,
	  0x0C, 0xB1, 0x26, 0x80,
	  0xCD, 0x24, 0x00
	};
  for (i = 0; i < 31; i++)
    write_byte(locate32[i]);
}

int selector(int dir)
{
  dir = (dir / pagesize) * pagesize;

  if ((mapper == KONAMI) && (dir == 0x4000))
    error_message(38);

  if (mapper == KONAMISCC)
    dir += 0x1000;
  else if (mapper == ASCII8)
    dir = 0x6000 + (dir - 0x4000) / 4;
  else if (mapper == ASCII16)
  {
    if (dir == 0x4000)
      dir = 0x6000;
    else
      dir = 0x7000;
  }

  return dir;
}


void select_page_direct(int n, int dir)
{
  int sel;
 
  sel = selector(dir);
 
  if ((pass == 2) && (!usedpage[n]))
    error_message(39);

  write_byte(0xf5);
  write_byte(0x3e);
  write_byte(n);
  write_byte(0x32);
  write_word(sel);
  write_byte(0xf1);
}

void select_page_register(int r, int dir)
{
  int sel;

  sel = selector(dir);

  if (r != 7)
  {
    write_byte(0xf5);			/* PUSH AF */
    write_byte(0x40 | (7 << 3) | r);	/* LD A,r */
  }

  write_byte(0x32);
  write_word(sel);

  if (r != 7)
    write_byte(0xf1);			/* POP AF */
}

void write_cas()
{
  FILE *salida;
  int i;
  int cas[8] = {
    0x1F, 0xA6, 0xDE, 0xBA, 0xCC, 0x13, 0x7D, 0x74
  };

  if ((type == MEGAROM) || ((type == ROM) && (dir_inicio < 0x8000)))
  {
    warning_message(0);
    return;
  }

  binario[strlen(binario) - 3] = 0;
  binario = strcat(binario, "cas");

  salida = fopen(binario, "wb");

  for (i = 0; i < 8; i++)
    fputc(cas[i], salida);

  if ((type == BASIC) || (type == ROM))
  {
    for (i=0; i < 10; i++)
      fputc(0xd0, salida);

    {
      size_t t;
      if (strlen(interno) < 6)
        for (t = strlen(interno); t < 6; t++)
          interno[t] = 32;	/* pad with space */
    }

    for (i = 0; i < 6; i++)
      fputc(interno[i], salida);

    for (i = 0; i < 8; i++)
      fputc(cas[i], salida);

    putc(dir_inicio & 0xff, salida);
    putc((dir_inicio >> 8) & 0xff, salida);
    putc(dir_final & 0xff, salida);
    putc((dir_final >> 8) & 0xff, salida);
    putc(inicio & 0xff, salida);
    putc((inicio >> 8) & 0xff, salida);
  }

  for (i = dir_inicio; i <= dir_final; i++)
    putc(memory[i], salida);

  fclose(salida);
  printf("Cassette file %s saved\n",binario);
}

void wav_store(int value)
{
  fputc(value & 0xff, wav);
  fputc((value >> 8) & 0xff, wav);
}

void wav_write_one()
{
  int l;
 
  for (l = 0; l < 5 * 2; l++)
    wav_store(FREQ_LO);

  for (l = 0; l < 5 * 2; l++)
    wav_store(FREQ_HI);

  for (l = 0; l < 5 * 2; l++)
    wav_store(FREQ_LO);

  for (l = 0; l < 5 * 2; l++)
    wav_store(FREQ_HI);
}

void wav_write_zero()
{
  int l;

  for (l = 0; l < 10 * 2; l++)
    wav_store(FREQ_LO);

  for (l = 0; l < 10 * 2; l++)
    wav_store(FREQ_HI);
}

void wav_write_nothing()
{
  int l;

  for (l = 0; l < 18 * 2; l++)
    wav_store(SILENCE);
}

void wav_write_byte(int m)	/* only used in write_wav() */
{
  int l;

  wav_write_zero();
  for (l = 0; l < 8; l++) 
  {
    if (m & 1)
      wav_write_one();
    else
      wav_write_zero();
    m = m >> 1;
  }
  wav_write_one();
  wav_write_one();
}

void write_wav()	/* This function is broken since public GPLv3 release */
{			/* TODO: use https://github.com/joyrex2001/castools to fix it */
  int wav_size, i;

  if ((type == MEGAROM) || ((type == ROM) && (dir_inicio < 0x8000)))
  {
    warning_message(0);
    return;
  }

  binario[strlen(binario) - 3] = 0;
  binario = strcat(binario, "wav");

  wav = fopen(binario, "wb");

  if ((type == BASIC) || (type == ROM))
  {
    wav_size = (3968 * 2 + 1500 * 2 + 11 * (10 + 6 + 6 + dir_final - dir_inicio + 1)) * 40;
    wav_size = wav_size << 1;

    wav_header[4] = (wav_size + 36) & 0xff;
    wav_header[5] = ((wav_size + 36) >> 8) & 0xff;
    wav_header[6] = ((wav_size + 36) >> 16) & 0xff;
    wav_header[7] = ((wav_size + 36) >> 24) & 0xff;
    wav_header[40] = wav_size & 0xff;
    wav_header[41] = (wav_size >> 8) & 0xff;
    wav_header[42] = (wav_size >> 16) & 0xff;
    wav_header[43] = (wav_size >> 24) & 0xff;

    /* Write WAV header */
    for (i = 0; i < 44; i++)
      fputc(wav_header[i], wav);

    /* Write long header */
    for (i = 0; i < 3968; i++)
      wav_write_one();

    /* Write file identifier */
    for (i = 0; i < 10; i++)
      wav_write_byte(0xd0);

    /* Write MSX name */
    if (strlen(interno) < 6)
    {
      size_t t;
      for (t = strlen(interno); t < 6; t++)
        interno[t] = 32; /* 32 is space character */
    }

    for (i = 0; i < 6; i++)
      wav_write_byte(interno[i]);

    /* Write blank */
    for (i = 0; i < 1500; i++)
      wav_write_nothing();

    /* Write short header */
    for (i = 0; i < 3968; i++)
      wav_write_one();

    /* Write init, end and start addresses */
    wav_write_byte(dir_inicio & 0xff);
    wav_write_byte((dir_inicio >> 8) & 0xff);
    wav_write_byte(dir_final & 0xff);
    wav_write_byte((dir_final >> 8) & 0xff);
    wav_write_byte(inicio & 0xff);
    wav_write_byte((inicio >> 8) & 0xff);

    /* Write data */
    for (i = dir_inicio; i <= dir_final; i++)
      wav_write_byte(memory[i]);
  }
  else if (type == Z80)
  {
    wav_size = (3968 * 1 + 1500 * 1 + 11 * (dir_final - dir_inicio + 1)) * 36;
    wav_size = wav_size << 1;

    wav_header[4] = (wav_size + 36) & 0xff;
    wav_header[5] = ((wav_size + 36) >> 8) & 0xff;
    wav_header[6] = ((wav_size + 36) >> 16) & 0xff;
    wav_header[7] = ((wav_size + 36) >> 24) & 0xff;
    wav_header[40] = wav_size & 0xff;
    wav_header[41] = (wav_size >> 8) & 0xff;
    wav_header[42] = (wav_size >> 16) & 0xff;
    wav_header[43] = (wav_size >> 24) & 0xff;

    /* Write WAV header */
    for (i = 0; i < 44; i++)
      fputc(wav_header[i], wav);

    /* Write long header */
    for (i = 0; i < 3968; i++)
      wav_write_one();

    /* Write data */
    for (i = dir_inicio; i <= dir_final; i++)
    wav_write_byte(memory[i]);
  }
  else
    wav_size = 0;
    
  /* Write blank */
  for (i=0; i < 1500; i++)
    wav_write_nothing();
    
  /* Close file */
  fclose(wav);
  
  printf("Audio file %s saved [%2.2f sec]\n", binario, (float)wav_size/176400);
}


int is_defined_symbol(char *nombre)
{
  int i;

  for (i = 0; i < maxima; i++)
    if (!strcmp(nombre, lista_identificadores[i].nombre))
      return 1;

  return 0;
}


/*
 Deterministic versions rand() and srand() to keep generated binary files
 consistent across platforms and compilers. Code snippet is from here:
 http://stackoverflow.com/questions/4768180/rand-implementation
*/

#define D_RAND_MAX 32767
static unsigned long int rand_seed = 1;
int d_rand()
{
  rand_seed = (rand_seed * 1103515245 + 12345);
  return (unsigned int)(rand_seed/65536) % (D_RAND_MAX + 1);
}


int main(int argc, char *argv[])
{
  size_t i;
  int fileArg = 1;
  printf("-------------------------------------------------------------------------------\n");
  printf(" asMSX v.%s. MSX cross-assembler. Eduardo A. Robsy Petrus [%s]\n",VERSION,DATE);
  printf("-------------------------------------------------------------------------------\n");  
  if (argc > 3 || argc < 2 )
  {
    printf("Syntax: asMSX [-z] [file.asm]\n");
    exit(0);
  } else if (argc == 3){
   if (strcmp(argv[1], "-z") == 0) {
	 zilog = 1;
	 fileArg = 2;
   } else {
	 printf("Syntax: asMSX [-z] [file.asm]\n");
	 exit(0);
   }
  }   
  
  clock();
  inicializar_sistema();
  ensamblador = malloc(256);
  fuente = malloc(256);
  original = malloc(256);
  binario = malloc(256);
  simbolos = malloc(256);
  salida = malloc(256);
  filename = malloc(256);
  if (!filename)
  {
    fprintf(stderr, "Error: can't open file %s\n", filename);
    exit(1);
  }

  strcpy(filename, argv[fileArg]);
  strcpy(ensamblador, filename);

  for (i = strlen(filename) - 1; (filename[i] != '.') && i; i--);

  if (i)
    filename[i] = 0;
  else
    strcat(ensamblador, ".asm");

  /* Generate the name of binary file */
  strcpy(binario, filename);

  preprocessor1(ensamblador);
  preprocessor3(zilog);
  sprintf(original, "~tmppre.%i", preprocessor2());
 
  printf("Assembling source file %s\n", ensamblador);

  conditional[0] = 1;

  archivo = fopen(original, "r");

  yyin = archivo;

  yyparse();

  remove("~tmppre.?");
  return 0;
}
