all: interpreter compiler
interpreter:
	g++ -Wall -std=c++11 interpreter.cc -o interpreter
	g++ -Wall -std=c++11 interpreter-cln.cc -l cln -o interpreter-cln
compiler:
	bison -d parser.y -o parser.c
	flex -o lexer.c lexer.l
	gcc lexer.c parser.c -lm -lfl -o out -std=c99 -D_BSD_SOURCE
clean:
	rm interpreter interpreter-cln out parser.c lexer.c parser.h
