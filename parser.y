%{
	#include <stdio.h>
	#include <stdlib.h>
	#include "errors.h"
	#include "symtable.h"
	#include "machineprinter.h"
	#include "jumpstack.h"
	#include "whilestack.h"

	int yylex(void);
	void yyerror(const char *);
	void finishCompilation();
	long createNumberInRegister(long);
	long createNumberOnStack(long);
	long createArrayMemoryBegin(long, long);

	long errno;
	extern int lineno;
	
	#define DEBUG 0

	#define ACC_USED -10
	#define ACC_UNDEF -11

	#define IS_NUM -12
	#define IS_IDENT -13

	char initStatus;
	int typeStatus;

	//do wrzucania zmiennych na stos tablicy symboli gdy jestesmy w while
	int isInLoop;
	int numbersPushed = 0;

%}

%code requires {
	typedef struct variable {
		char *name;
		long label;
		char initialized;
		int type;
		char referencedAsArrayWithVar;
	} variable;
}

%code provides {
	void errorMessage(long, char *);
}

%union {
	char *string;
	unsigned long long number;
	variable var;
}

%token <string> VAR BGN END
%token <string> IF THEN ELSE ENDIF
%token <string> WHILE DO ENDWHILE
%token <string> FOR FROM TO DOWNTO ENDFOR
%token <string> READ WRITE
%token <string> ASSIGN
%token <string> '+' '-' '*' '/' '%'
%token <string> EQ NEQ LT GT LEQ GEQ
%token <string> '[' ']' ';'
%token <string> ID
%token <number> NUM

%%

program: 
	VAR vdeclarations BGN commands END
					{
						HALT();
						printToFile("wynik.txt");
					}
;

vdeclarations: 
	vdeclarations ID 				
					{
						if(DEBUG) {
							printf("\t\t Deklaracja %s\n", $<string>2);
						}
						if((errno = push($<string>2)) < 0) {
							errorMessage(errno, $<string>2);
						}
						free($<string>1);
						free($<string>2);
					}
|	vdeclarations ID'['NUM']'
					{
						if(DEBUG) {
							printf("\t\t Deklaracja %s[%llu]\n", $<string>2, $<number>4);
						}
						if($<number>4 == 0) {
							errorMessage(ZERO_SIZE_ARRAY, $<string>2);
						}
						if((errno = pushArray($<string>2, $<number>4)) < 0) {
							errorMessage(errno, $<string>2);
						}
						createArrayMemoryBegin(errno, errno - 1);
					}
| 
;

commands:
	commands command
|	command
;

command:
	identifier ASSIGN expression';'
					{
						if(DEBUG) {
							printf("\t\t Przypisanie do %s\n", $<var>1.name);
							printf("\t\t LABEL (memory): %ld, TYPE: %d\n", $<var>1.label, $<var>1.type);
						}
						switch($<var>1.type) {
							case ITERATOR:
								errorMessage(ASSIGN_ON_ITERATOR, $<var>1.name);
								break;
							case PRIMITIVE:
								initialize($<var>1.name);
								break;
							case ARRAY:
								//nic
								break;
						}
						if($<var>3.initialized != ACC_USED) {
							if($<var>3.referencedAsArrayWithVar) {
								LOADI($<var>3.label);
							}
							else {
								LOAD($<var>3.label);
							}
						}
						if($<var>1.referencedAsArrayWithVar) {
							STOREI($<var>1.label);
						}
						else {
							STORE($<var>1.label);
						}
					}
|	ifstart ifend1 ifend2
|	ifstart ifend2
|	WHILE
					{
						if(DEBUG) {
							printf("\t\t WHILE\n");
						}
						isInLoop = 1;
						
					}
		 condition DO
		 			{
		 				if(DEBUG) {
							printf("\t\t DO\n");
						}
						
						int startline = outputline;
						//linijka ktora trzeba zaktualizowac
						pushJumpstack(startline);
						JZERO(-1);
						isInLoop = 0;
						pushWhilestack(numbersPushed);
						numbersPushed = 0;
		 			}
		 commands ENDWHILE
		 			{
		 				if(DEBUG) {
							printf("\t\t ENDWHILE\n");
						}
						//linijka ktora trzeba zaktualizowac
						int jumpAddress = popJumpstack();

						int conditionLine = popJumpstack();

						JUMP(conditionLine);

						int currentline = outputline;
						editCommandByLine(jumpAddress, currentline);


						int numbersToPop = popWhilestack();
						for(int i = 0; i < numbersToPop; i++) {
							pop();
						}
						
		 			}
|	FOR ID FROM value TO value DO
					{
						if(DEBUG) {
							printf("\t\t FOR FROM %s TO %s\n", $<var>4.name, $<var>6.name);
						}

						
						if($<var>4.referencedAsArrayWithVar) {
							LOADI($<var>4.label);
						}
						else {
							LOAD($<var>4.label);
						}

						if($<var>6.referencedAsArrayWithVar) {
							SUBI($<var>6.label);
						}
						else {
							SUB($<var>6.label);
						}
						int startline = outputline;
						JZERO(startline + 3); 
						ZERO();
						JUMP(startline + 9);

						if((errno = pushIterator($<string>2)) < 0) {
							errorMessage(errno, $<string>2);
						}

						//STOROWANIE ITERATORA
						if($<var>4.referencedAsArrayWithVar) {
							LOADI($<var>4.label);
						}
						else {
							LOAD($<var>4.label);
						}

						STORE(errno);

						//STOROWANIE ZAKRESU
						if($<var>6.referencedAsArrayWithVar) {
							LOADI($<var>6.label);
						}
						else {
							LOAD($<var>6.label);
						}

						if($<var>4.referencedAsArrayWithVar) {
							SUBI($<var>4.label);
						}
						else {
							SUB($<var>4.label);
						}

						INC();

						long iterrangeMem = pushIteratorRange();
						STORE(iterrangeMem);


						startline = outputline;
						pushJumpstack(startline);
						JZERO(-1);				
					} 
		commands ENDFOR
					{
						if(DEBUG) {
							printf("\t\t ENDFOR\n");
						}

						long memCell = symMemory($<string>2);
						if(memCell < 0) {
							errorMessage(memCell, $<string>2);
						}

						LOAD(memCell);
						INC();
						STORE(memCell);

						long memCellRange = getRangeForIter($<string>2);
						if(memCellRange < 0) {
							errorMessage(-111111, $<string>2);
						}

						LOAD(memCellRange);
						DEC();
						STORE(memCellRange);

						
						int startline = popJumpstack();
						
						JUMP(startline);

						int currentline = outputline;
						editCommandByLine(startline, currentline);

						//ZDJECIE iteratora oraz iter_range ze stosu
						pop();
						pop();

					}
|	FOR ID FROM value DOWNTO value DO
					{
						if(DEBUG) {
							printf("\t\t FOR FROM %s DOWNTO %s\n", $<var>4.name, $<var>6.name);
						}

						if($<var>6.referencedAsArrayWithVar) {
							LOADI($<var>6.label);
						}
						else {
							LOAD($<var>6.label);
						}

						if($<var>4.referencedAsArrayWithVar) {
							SUBI($<var>4.label);
						}
						else {
							SUB($<var>4.label);
						}

						int startline = outputline;
						JZERO(startline + 3);
						ZERO();
						JUMP(startline + 9);

						if((errno = pushIterator($<string>2)) < 0) {
							errorMessage(errno, $<string>2);
						}

						//STOROWANIE ITERATORA
						if($<var>4.referencedAsArrayWithVar) {
							LOADI($<var>4.label);
						}
						else {
							LOAD($<var>4.label);
						}

						STORE(errno);

						//STOROWANIE ZAKRESU
						if($<var>4.referencedAsArrayWithVar) {
							LOADI($<var>4.label);
						}
						else {
							LOAD($<var>4.label);
						}

						if($<var>6.referencedAsArrayWithVar) {
							SUBI($<var>6.label);
						}
						else {
							SUB($<var>6.label);
						}

						INC();

						long iterrangeMem = pushIteratorRange();
						STORE(iterrangeMem);


						startline = outputline;
						pushJumpstack(startline);
						JZERO(-1);
					}
		 commands ENDFOR
		 			{
		 				if(DEBUG) {
							printf("\t\t ENDFOR\n");
						}

						long memCell = symMemory($<string>2);
						if(memCell < 0) {
							errorMessage(memCell, $<string>2);
						}

						LOAD(memCell);
						DEC();
						STORE(memCell);

						long memCellRange = getRangeForIter($<string>2);
						if(memCellRange < 0) {
							errorMessage(-111111, $<string>2);
						}

						LOAD(memCellRange);
						DEC();
						STORE(memCellRange);

						
						int startline = popJumpstack();
						
						JUMP(startline);

						int currentline = outputline;
						editCommandByLine(startline, currentline);

						//ZDJECIE iteratora oraz iter_range ze stosu
						pop();
						pop();

		 			}
|	READ identifier';'
					{
						if(DEBUG) {
							printf("\t\t READ %s\n", $<var>2.name);
						}
						if($<var>2.type == PRIMITIVE) {
							initialize($<var>2.name);
						}
						
						GET();
						if($<var>2.referencedAsArrayWithVar) {
							STOREI($<var>2.label);
						}
						else {
							STORE($<var>2.label);
						}
						
					}
|	WRITE value';'
					{
						if(DEBUG) {
							printf("\t\t WRITE %s, mem: %ld\n", $<var>2.name, $<var>2.label);
						}
						if($<var>2.referencedAsArrayWithVar) {
							LOADI($<var>2.label);
						}
						else {
							LOAD($<var>2.label);
						}
						
						PUT();
					}
;

ifstart:
	IF condition THEN
					{
						if(DEBUG) {
							printf("IF conditions THEN\n");
						}
						int startline = outputline;
						pushJumpstack(startline);
						JZERO(-1);
					}
;

ifend1:
	commands ELSE
					{
						if(DEBUG) {
							printf("commands ELSE\n");
						}
						
						int jumpAddress = popJumpstack();
						int currentline = outputline;
						pushJumpstack(currentline);
						JUMP(-1);
						currentline = outputline;
						editCommandByLine(jumpAddress, currentline);
					}
;

ifend2:
	commands ENDIF
					{
						if(DEBUG) {
							printf("commands ENDIF\n");
						}

						int jumpAddress = popJumpstack();
						int currentline = outputline;
						editCommandByLine(jumpAddress, currentline);
					}
;




expression:
	value
					{
						if($<var>1.initialized == IS_NUM) {
							$<var>$.name = $<var>1.name;
							$<var>$.referencedAsArrayWithVar = $<var>1.referencedAsArrayWithVar;
							$<var>$.label = $<var>1.label;
							$<var>$.initialized = ACC_USED;
						}
						else {
							$<var>$.name = $<var>1.name;
							$<var>$.referencedAsArrayWithVar = $<var>1.referencedAsArrayWithVar;
							$<var>$.label = $<var>1.label;
							$<var>$.initialized = ACC_UNDEF;
						}
					}
|	value '+' value
					{
						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							ADDI($<var>3.label);
						}
						else {
							ADD($<var>3.label);
						}
						

						//Optymalizacja pod akumulator (odznacz jesli nie ma byc)
						/*
						long reg = setRegister();
						if($<var>3.referencedAsArrayWithVar) {
							STOREI(reg);
						}
						else {
							STORE(reg);
						}
						$<var>$.label = reg;
						*/
						
						$<var>$.initialized = ACC_USED;

					}
|	value '-' value
					{
						if(DEBUG) {
							printf("\t Odejmowanie %s - %s\n", $<var>1.name, $<var>3.name);
						}
						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							SUBI($<var>3.label);
						}
						else {
							SUB($<var>3.label);
						}
						

						//Optymalizacja pod akumulator (odznacz jesli nie ma byc)
						/*
						long reg = setRegister();
						if($<var>3.referencedAsArrayWithVar) {
							STOREI(reg);
						}
						else {
							STORE(reg);
						}
						$<var>$.label = reg;
						*/
						
						$<var>$.initialized = ACC_USED;
					}
|	value '*' value
					{
						long regLeft;
						long regRight;
						if($<var>1.initialized == IS_IDENT && $<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
							regLeft = setRegister();
							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_IDENT && !$<var>1.referencedAsArrayWithVar) {
							LOAD($<var>1.label);
							regLeft = setRegister();
							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_NUM) {
							regLeft = $<var>1.label;
						}
						

						if($<var>3.initialized == IS_IDENT && $<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_IDENT && !$<var>3.referencedAsArrayWithVar) {
							LOAD($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_NUM) {
							regRight = $<var>3.label;
						}
						
						LOAD(regRight);
						SUB(regLeft);
						JZERO(outputline + 2); //przypadek left >= right
						JUMP(outputline + 18); // przypadek left < right

						long regOut = setRegister();
						

						//przypadek left >= right
						ZERO();
						STORE(regOut);
						LOAD(regRight);
						JZERO(outputline + 31);
						JODD(outputline + 4);
						SHR();
						STORE(regRight);
						JUMP(outputline + 6);
						SHR();
						STORE(regRight);
						LOAD(regOut);
						ADD(regLeft);
						STORE(regOut);
						LOAD(regLeft);
						SHL();
						STORE(regLeft);
						JUMP(outputline - 14);

						//przypadek left < right
						ZERO();
						STORE(regOut);
						LOAD(regLeft);
						JZERO(outputline + 14);
						JODD(outputline + 4);
						SHR();
						STORE(regLeft);
						JUMP(outputline + 6);
						SHR();
						STORE(regLeft);
						LOAD(regOut);
						ADD(regRight);
						STORE(regOut);
						LOAD(regRight);
						SHL();
						STORE(regRight);
						JUMP(outputline - 14);


						LOAD(regOut);
						$<var>$.initialized = ACC_USED;
					}
|	value '/' value
					{
						long regLeft;
						long regRight;
						if($<var>1.initialized == IS_IDENT && $<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
							regLeft = setRegister();

							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_IDENT && !$<var>1.referencedAsArrayWithVar) {
							LOAD($<var>1.label);
							regLeft = setRegister();
							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_NUM) {
							regLeft = $<var>1.label;
						}

						if($<var>3.initialized == IS_IDENT && $<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_IDENT && !$<var>3.referencedAsArrayWithVar) {
							LOAD($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_NUM) {
							regRight = $<var>3.label;
						}


						long bitCounter = setRegister();
						long temp = setRegister();

						LOAD(regRight);
						STORE(bitCounter);
						JZERO(outputline + 63);


						LOAD(regRight);
						SUB(regLeft);
						JZERO(outputline + 4);
						ZERO();
						STORE(bitCounter);
						JUMP(outputline + 57);
						
						ZERO();
						STORE(bitCounter);
						LOAD(regLeft);
						STORE(temp);
						LOAD(temp);
						SHR();
						STORE(temp);
						JZERO(outputline + 5);
						LOAD(bitCounter);
						INC();
						STORE(bitCounter);
						JUMP(outputline - 7);

						LOAD(regRight);
						STORE(temp);
						LOAD(temp);
						SHR();
						STORE(temp);
						JZERO(outputline + 5);
						LOAD(bitCounter);
						DEC();
						STORE(bitCounter);
						JUMP(outputline - 7);

						LOAD(regRight);
						STORE(temp);
						LOAD(bitCounter);
						JZERO(outputline + 7);
						DEC();
						STORE(bitCounter);
						LOAD(temp);
						SHL();
						STORE(temp);
						JUMP(outputline - 7);
		

						//teraz bitCounter to jest nasz Quotient (wykorzystujemy ponownie rejestr)
						ZERO();
						STORE(bitCounter); //Q = 0


						LOAD(regRight);
						SUB(temp);
						JZERO(outputline + 2); 
						JUMP(outputline + 19);
						LOAD(temp); 
						SUB(regLeft);
						JZERO(outputline + 5); 
						LOAD(bitCounter);
						SHL();
						STORE(bitCounter);
						JUMP(outputline + 8);
						LOAD(regLeft);
						SUB(temp);
						STORE(regLeft);
						LOAD(bitCounter);
						SHL();
						INC();
						STORE(bitCounter);

						LOAD(temp);
						SHR();
						STORE(temp);
						JUMP(outputline - 21);
					

						LOAD(bitCounter);
						$<var>$.initialized = ACC_USED;
					}
|	value '%' value
					{
						long regLeft;
						long regRight;
						if($<var>1.initialized == IS_IDENT && $<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
							regLeft = setRegister();

							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_IDENT && !$<var>1.referencedAsArrayWithVar) {
							LOAD($<var>1.label);
							regLeft = setRegister();
							STORE(regLeft);
						}
						else if($<var>1.initialized == IS_NUM) {
							regLeft = $<var>1.label;
						}

						if($<var>3.initialized == IS_IDENT && $<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_IDENT && !$<var>3.referencedAsArrayWithVar) {
							LOAD($<var>3.label);
							regRight = setRegister();
							STORE(regRight);
						}
						else if($<var>3.initialized == IS_NUM) {
							regRight = $<var>3.label;
						}


						long bitCounter = setRegister();
						long temp = setRegister();

						LOAD(regRight);
						STORE(temp);
						JZERO(outputline + 56);

						LOAD(regRight);
						SUB(regLeft);
						JZERO(outputline + 4);
						LOAD(regLeft);
						STORE(temp);
						JUMP(outputline + 50);
						
						ZERO();
						STORE(bitCounter);
						LOAD(regLeft);
						STORE(temp);
						LOAD(temp);
						SHR();
						STORE(temp);
						JZERO(outputline + 5);
						LOAD(bitCounter);
						INC();
						STORE(bitCounter);
						JUMP(outputline - 7);

						LOAD(regRight);
						STORE(temp);
						LOAD(temp);
						SHR();
						STORE(temp);
						JZERO(outputline + 5);
						LOAD(bitCounter);
						DEC();
						STORE(bitCounter);
						JUMP(outputline - 7);
						
						LOAD(regRight);
						STORE(temp);
						LOAD(bitCounter);
						JZERO(outputline + 7);
						DEC();
						STORE(bitCounter);
						LOAD(temp);
						SHL();
						STORE(temp);
						JUMP(outputline - 7);

						LOAD(regRight);
						SUB(temp);
						JZERO(outputline + 2); 
						JUMP(outputline + 12);
						LOAD(temp); 
						SUB(regLeft);
						JZERO(outputline + 2); 

						JUMP(outputline + 4);
						LOAD(regLeft);
						SUB(temp);
						STORE(regLeft);


						LOAD(temp);
						SHR();
						STORE(temp);
						JUMP(outputline - 14);
					

						LOAD(regLeft);
						STORE(temp);
						LOAD(temp);
						$<var>$.initialized = ACC_USED;
					}
;

condition:
	value EQ value
					{
						if(DEBUG) {
							printf("\t %s == %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;
						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							SUBI($<var>3.label);
						}
						else {
							SUB($<var>3.label);
						}

						JZERO(startline + 4);
						JUMP(startline + 7);

						if($<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
						}
						else {
							LOAD($<var>3.label);
						}

						if($<var>1.referencedAsArrayWithVar) {
							SUBI($<var>1.label);
						}
						else {
							SUB($<var>1.label);
						}

						JZERO(startline + 9);
						ZERO();
						JUMP(startline + 10);
						INC();

					}
|	value NEQ value
					{
						if(DEBUG) {
							printf("\t %s != %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;

						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							SUBI($<var>3.label);
						}
						else {
							SUB($<var>3.label);
						}

						JZERO(startline + 4);
						JUMP(startline + 7);

						if($<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
						}
						else {
							LOAD($<var>3.label);
						}

						if($<var>1.referencedAsArrayWithVar) {
							SUBI($<var>1.label);
						}
						else {
							SUB($<var>1.label);
						}

						JZERO(startline + 9);
						ZERO();
						INC();
					}
|	value LT value
					{
						if(DEBUG) {
							printf("\t %s < %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;
						if($<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
						}
						else {
							LOAD($<var>3.label);
						}

						if($<var>1.referencedAsArrayWithVar) {
							SUBI($<var>1.label);
						}
						else {
							SUB($<var>1.label);
						}

						JZERO(startline + 5);
						ZERO();
						INC();
					}
|	value GT value
					{
						if(DEBUG) {
							printf("\t %s > %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;
						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							SUBI($<var>3.label);
						}
						else {
							SUB($<var>3.label);
						}

						JZERO(startline + 5);
						ZERO();
						INC();
					}
|	value LEQ value
					{
						if(DEBUG) {
							printf("\t %s <= %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;
						if($<var>1.referencedAsArrayWithVar) {
							LOADI($<var>1.label);
						}
						else {
							LOAD($<var>1.label);
						}

						if($<var>3.referencedAsArrayWithVar) {
							SUBI($<var>3.label);
						}
						else {
							SUB($<var>3.label);
						}

						JZERO(startline + 5);
						ZERO();
						JUMP(startline + 6);
						INC();
					}
|	value GEQ value
					{
						if(DEBUG) {
							printf("\t %s >= %s\n", $<var>1.name, $<var>3.name);
						}

						if(isInLoop) {
							//linijka przed sprawdzeniem condition
							int beforeConditionLine = outputline;
							pushJumpstack(beforeConditionLine);
						}

						int startline = outputline;
						if($<var>3.referencedAsArrayWithVar) {
							LOADI($<var>3.label);
						}
						else {
							LOAD($<var>3.label);
						}

						if($<var>1.referencedAsArrayWithVar) {
							SUBI($<var>1.label);
						}
						else {
							SUB($<var>1.label);
						}

						JZERO(startline + 5);
						ZERO();
						JUMP(startline + 6);
						INC();
					}
;

value:
	NUM
					{
						if(isInLoop) {
							long memory = createNumberOnStack($<number>1);
							$<var>$.label = memory;
						}
						else {
							long reg = createNumberInRegister($<number>1);
							$<var>$.label = reg;
						}

						int size;
						char *buffer;
						size = snprintf(NULL, 0, "%llu", $<number>1);
						buffer = malloc((size + 1) * sizeof(char));
						sprintf(buffer, "%llu", $<number>1);
						$<var>$.name = buffer;
						$<var>$.referencedAsArrayWithVar = 0;
						$<var>$.initialized = IS_NUM;
					}
|	identifier
					{
						if($<var>1.initialized == VARIABLE_UNINITIALIZED && $<var>1.type != ARRAY) {
							errorMessage($<var>1.initialized, $<var>1.name);
						}
						$<var>$.name = $<var>1.name;
						$<var>$.label = $<var>1.label;
						$<var>$.referencedAsArrayWithVar = $<var>1.referencedAsArrayWithVar;
						$<var>$.initialized = IS_IDENT;
					}
;

identifier:
	ID
					{
						if(DEBUG) {
							printf("\t\t\t Identyfikator %s\n", $<string>1);
						}
						long memCell = symMemory($<string>1);
						if(memCell < 0) {
							errorMessage(memCell, $<string>1);
						}
						$<var>$.name = strdup($<string>1);
						$<var>$.label = memCell;
						$<var>$.initialized = initStatus;
						$<var>$.type = typeStatus;
						$<var>$.referencedAsArrayWithVar = 0;
					}
|	ID'['ID']'
					{
						if(DEBUG) {
							printf("\t\t\t Identyfikator %s[%s]\n", $<string>1, $<string>3);
						}
						long memCellInner = symMemory($<string>3);
						if(memCellInner < 0) {
							errorMessage(memCellInner, $<string>3);
						}

						if(isInitialized($<string>3) == VARIABLE_UNINITIALIZED) {
							errorMessage(VARIABLE_UNINITIALIZED, $<string>3);
						}

						long memCellOuter = symMemoryIndex($<string>1, 0);
						if(memCellOuter < 0) {
							errorMessage(memCellOuter, $<string>1);
						}
						$<var>$.name = strdup($<string>1);
						LOAD(memCellInner);
						ADD(memCellOuter - 1);

						if(isInLoop) {
							long memory = pushNumber();
							numbersPushed++;
							STORE(memory);
							$<var>$.label = memory;
						}
						else {
							long reg = setRegister();
							STORE(reg);
							$<var>$.label = reg;
						}
						

						
						$<var>$.type = typeStatus;
						$<var>$.referencedAsArrayWithVar = 1;
					}
|	ID'['NUM']'
					{
						if(DEBUG) {
							printf("\t\t\t Identyfikator %s[%llu]\n", $<string>1, $<number>3);
						}
						long memCell = symMemoryIndex($<string>1, $<number>3);
						if(memCell < 0) {
							errorMessage(memCell, $<string>1);
						}
						$<var>$.name = strdup($<string>1);
						$<var>$.label = memCell;
						$<var>$.type = typeStatus;
						$<var>$.referencedAsArrayWithVar = 0;
					}
;


%%

long createNumberInRegister(long number) {
	ZERO();
	unsigned long long check = 0;
	if(number != 0) {
		int remainder;
		int binary[sizeof(unsigned long long) * 8];
		int index = 0;
		while(number > 0) {
			remainder = number % 2;
			binary[index++] = remainder;
			number /= 2;
		}
		for(int i = index - 1; i > 0; i--) {
			if(binary[i]) {
				INC();
				check += 1;
				SHL();
				check *= 2;
			}
			else {
				SHL();
				check *= 2;
			}
		}
		if(binary[0]) {
			INC();
			check += 1;
		}
	}
	
	if(DEBUG) {
		printf("CHECK %llu\n", check);
	}
	
	long reg = setRegister();
	STORE(reg);
	return reg;
}

long createNumberOnStack(long number) {
	ZERO();
	unsigned long long check = 0;
	if(number != 0) {
		int remainder;
		int binary[sizeof(unsigned long long) * 8];
		int index = 0;
		while(number > 0) {
			remainder = number % 2;
			binary[index++] = remainder;
			number /= 2;
		}
		for(int i = index - 1; i > 0; i--) {
			if(binary[i]) {
				INC();
				check += 1;
				SHL();
				check *= 2;
			}
			else {
				SHL();
				check *= 2;
			}
		}
		if(binary[0]) {
			INC();
			check += 1;
		}
	}
	
	if(DEBUG) {
		printf("CHECK %llu\n", check);
	}
	
	long memory = pushNumber();
	numbersPushed++;
	STORE(memory);
	return memory;
}

long createArrayMemoryBegin(long memBegin, long memoryCell) {
	ZERO();
	unsigned long long check = 0;
	if(memBegin != 0) {
		int remainder;
		int binary[sizeof(unsigned long long) * 8];
		int index = 0;
		while(memBegin > 0) {
			remainder = memBegin % 2;
			binary[index++] = remainder;
			memBegin /= 2;
		}
		for(int i = index - 1; i > 0; i--) {
			if(binary[i]) {
				INC();
				check += 1;
				SHL();
				check *= 2;
			}
			else {
				SHL();
				check *= 2;
			}
		}
		if(binary[0]) {
			INC();
			check += 1;
		}
	}
	if(DEBUG) {
		printf("CHECK Array create %llu\n", check);
	}
	
	STORE(memoryCell);
	return memoryCell;
}

void initializeCompilation() {
	initRegisters();
	initMachineCodeGeneration();
}

void finishCompilation() {
	destroy();
	destroyJumpstack();
	destroyWhilestack();
	finishMachineCodeGeneration();
}

int main(int argc, char **argv) {
	initializeCompilation();
    yyparse();
    finishCompilation();
    printf("Kompilacja zakonczona.\n");
}

void yyerror(char const *s){
	finishCompilation();
	fprintf(stderr, RED"Błąd [linia %d]:%s %s.\n", lineno, NORMAL, s);
	exit(1);
}

void errorMessage(long errno, char *additionalInfo) {
	char *buffer;
	int size;
	switch(errno) {
		case IS_NOT_PRIMITIVE:
			size = snprintf(NULL, 0, "niewłaściwe użycie zmiennej tablicowej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "niewłaściwe użycie zmiennej tablicowej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case IS_NOT_ARRAY:
			size = snprintf(NULL, 0, "niewłaściwe użycie zmiennej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "niewłaściwe użycie zmiennej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case VARIABLE_NOT_DECLARED:
			size = snprintf(NULL, 0, "użycie niezadeklarowanej zmiennej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "użycie niezadeklarowanej zmiennej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case ARRAY_OUT_OF_BOUNDS:
			size = snprintf(NULL, 0, "użycie niedozwolonego indeksu zmiennej tablicowej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "użycie niedozwolonego indeksu zmiennej tablicowej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case VARIABLE_ALREADY_DECLARED:
			size = snprintf(NULL, 0, "ponowna deklaracja zmiennej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "ponowna deklaracja zmiennej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case ZERO_SIZE_ARRAY:
			size = snprintf(NULL, 0, "zmienna tablicowa '%s' nie może mieć rozmiaru 0", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "zmienna tablicowa '%s' nie może mieć rozmiaru 0", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case VARIABLE_UNINITIALIZED:
			size = snprintf(NULL, 0, "niezainicjalizowana zmienna '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "niezainicjalizowana zmienna '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		case ASSIGN_ON_ITERATOR:
			size = snprintf(NULL, 0, "próba zmiany wartości zmiennej iterującej '%s'", additionalInfo);
			buffer = malloc((size + 1) * sizeof(char));
			sprintf(buffer, "próba zmiany wartości zmiennej iterującej '%s'", additionalInfo);
			yyerror(buffer);
			free(buffer);
			break;
		default:
			yyerror("nieznany błąd (możliwe przekroczenie zakresu obsługiwanych typów)");
			break;
	}
}
