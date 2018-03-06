#ifndef MACHINE_H
#define MACHINE_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define NO_ARG -1

#define COMMANDS_NUMBER 20000

typedef struct command {
    char *name;
    long arg;
} command;


command *commandOutput = NULL;

int outputline = 0;

int accumulator;

int GET() {
    commandOutput[outputline].name = strdup("GET");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int PUT() {
    commandOutput[outputline].name = strdup("PUT");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int LOAD(long memory) {
    commandOutput[outputline].name = strdup("LOAD");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int LOADI(long memory) {
    commandOutput[outputline].name = strdup("LOADI");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int STORE(long memory) {
    commandOutput[outputline].name = strdup("STORE");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int STOREI(long memory) {
    commandOutput[outputline].name = strdup("STOREI");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int ADD(long memory) {
    commandOutput[outputline].name = strdup("ADD");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int ADDI(long memory) {
    commandOutput[outputline].name = strdup("ADDI");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int SUB(long memory) {
    commandOutput[outputline].name = strdup("SUB");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int SUBI(long memory) {
    commandOutput[outputline].name = strdup("SUBI");
    commandOutput[outputline].arg = memory;
    int ret = outputline;
    outputline++;
    return ret;
}

int SHR() {
    commandOutput[outputline].name = strdup("SHR");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int SHL() {
    commandOutput[outputline].name = strdup("SHL");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int INC() {
    commandOutput[outputline].name = strdup("INC");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int DEC() {
    commandOutput[outputline].name = strdup("DEC");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int ZERO() {
    commandOutput[outputline].name = strdup("ZERO");
    commandOutput[outputline].arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}

int JUMP(int label) {
    commandOutput[outputline].name = strdup("JUMP");
    commandOutput[outputline].arg = label;
    int ret = outputline;
    outputline++;
    return ret;
}

int JZERO(int label) {
    commandOutput[outputline].name = strdup("JZERO");
    commandOutput[outputline].arg = label;
    int ret = outputline;
    outputline++;
    return ret;
}

int JODD(int label) {
    commandOutput[outputline].name = strdup("JODD");
    commandOutput[outputline].arg = label;
    int ret = outputline;
    outputline++;
    return ret;
}

int HALT() {
    (commandOutput[outputline]).name = strdup("HALT");
    (commandOutput[outputline]).arg = NO_ARG;
    int ret = outputline;
    outputline++;
    return ret;
}


void initMachineCodeGeneration() {
    commandOutput = malloc(COMMANDS_NUMBER * sizeof(command));
    outputline = 0;
}

void finishMachineCodeGeneration() {
    for(int i = 0; i < COMMANDS_NUMBER; i++) {
        free(commandOutput[i].name);
    }
    free(commandOutput);
}

void editCommandByLine(int index, int arg) {
	commandOutput[index].arg = arg;
}

void printToFile(char *filename) {
	FILE *f;
	f = fopen(filename, "w+");
	if(f == NULL) {
		fprintf(stderr, "Nie można otworzyć pliku %s\n", filename);
	}
	for(int i = 0; i < outputline; i++) {
		if(commandOutput[i].arg == NO_ARG) {
			fprintf(f, "%s\n", commandOutput[i].name);
		}
		else {
			fprintf(f, "%s %ld\n", commandOutput[i].name, commandOutput[i].arg);
		}
		
	}
	fclose(f);
}


#endif