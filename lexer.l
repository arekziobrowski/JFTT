%{
	#include "parser.h"

	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "errors.h"

	extern void yyerror(const char*);
	int lineno = 1;
%}

%x comment
WHITESPACE [ \t]
NUMBER [0-9]

%%

"(" 		{BEGIN(comment);}

<comment>{
	<<EOF>>	{yyerror("koniec pliku a nie zamkniety"); yyterminate();}
	")"		{BEGIN(INITIAL);}
	.		;
	\n 		{lineno++;}
}

"+"			{return '+';}
"-"			{return '-';}
"*"			{return '*';}
"/"			{return '/';}
"%"			{return '%';}
"="			{return EQ;}
"<>"		{return NEQ;}
"<"			{return LT;}
">"			{return GT;}
"<="		{return LEQ;}
">="		{return GEQ;}
":="		{return ASSIGN;}

VAR			{return VAR;}
BEGIN		{return BGN;}
END			{return END;}
READ		{return READ;}
WRITE		{return WRITE;}
IF			{return IF;}
THEN		{return THEN;}
ELSE		{return ELSE;}
ENDIF		{return ENDIF;}
FOR			{return FOR;}
FROM		{return FROM;}
TO			{return TO;}
DOWNTO		{return DOWNTO;}
ENDFOR		{return ENDFOR;}
WHILE		{return WHILE;}
DO 			{return DO;}
ENDWHILE	{return ENDWHILE;}

";"			{return ';';}
"["			{return '[';}
"]"			{return ']';}

[_a-z]+		{yylval.string = strdup(yytext); return ID;}
{NUMBER}+	{yylval.number = strtoull(yytext, NULL, 10); return NUM;}
[_a-zA-Z0-9]+	{yyerror("nierozpoznany napis"); yyterminate();}
{WHITESPACE}	;
\n 				{lineno++;}
.			{yyerror("nieznany znak"); yyterminate();}

%%




