#ifndef SYMTABLE_H
#define SYMTABLE_H

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "errors.h"

#define PRIMITIVE 0
#define ARRAY 1
#define ITERATOR 2
#define ITERATOR_RANGE 3

#define UNINITIALIZED 0
#define INITIALIZED 1

typedef struct symrec{
    char *name;
    int type;
    long memBegin;
    long memEnd;
    char initialized;
    struct symrec *next;
} symrec;

symrec *symtable = NULL;
long memHead = 10;

char *registers = NULL;
int registersCount = 0;
int registerPointer = 0;


extern char initStatus;
extern int typeStatus;

void initRegisters() {
	registers = malloc(memHead * sizeof(char));
	registersCount = memHead;
	registerPointer = 0;
}

int setRegister() {
	if(registerPointer == registersCount) {
		registerPointer = 0;
	}
	int ret = registerPointer;
	registerPointer++;
	return ret;
}

int contains(char *name) {
    for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
            return 1;
        }
    }
    return 0;
}

long push(char *name) {
    if(contains(name)) {
        return VARIABLE_ALREADY_DECLARED;
    }

    symrec *variable = malloc(sizeof(symrec));
    variable->name = strdup(name);
    variable->type = PRIMITIVE;
    variable->memBegin = memHead;
    variable->memEnd = memHead;

    variable->initialized = UNINITIALIZED;

    memHead++;

    if(symtable == NULL) {
        variable->next = NULL;
        symtable = variable;
    }
    else {
        variable->next = symtable;
        symtable = variable;
    }

    return variable->memBegin;
}

long pushArray(char *name, long size) {
    if(contains(name)) {
        return VARIABLE_ALREADY_DECLARED;
    }

    symrec *variable = malloc(sizeof(symrec));
    variable->name = strdup(name);
    variable->type = ARRAY;
    variable->memBegin = memHead + 1;
    variable->memEnd = variable->memBegin + size - 1;

    memHead += (size + 1);

    if(symtable == NULL) {
        variable->next = NULL;
        symtable = variable;
    }
    else {
        variable->next = symtable;
        symtable = variable;
    }

    return variable->memBegin;
}

long pushIterator(char *name) {
	if(contains(name)) {
        return VARIABLE_ALREADY_DECLARED;
    }

    symrec *variable = malloc(sizeof(symrec));
    variable->name = strdup(name);
    variable->type = ITERATOR;
    variable->memBegin = memHead;
    variable->memEnd = memHead;

    variable->initialized = INITIALIZED;

    memHead++;

    if(symtable == NULL) {
        variable->next = NULL;
        symtable = variable;
    }
    else {
        variable->next = symtable;
        symtable = variable;
    }

    return variable->memBegin;
}

long pushIteratorRange() {
	symrec *variable = malloc(sizeof(symrec));
    variable->name = strdup("ITERATOR_RANGE");
    variable->type = ITERATOR_RANGE;
    variable->memBegin = memHead;
    variable->memEnd = memHead;

    variable->initialized = INITIALIZED;

    memHead++;

    if(symtable == NULL) {
        variable->next = NULL;
        symtable = variable;
    }
    else {
        variable->next = symtable;
        symtable = variable;
    }

    return variable->memBegin;
}

long pushNumber() {
	symrec *variable = malloc(sizeof(symrec));
    variable->name = strdup("NUMBER_STACK");
    variable->type = ITERATOR_RANGE;
    variable->memBegin = memHead;
    variable->memEnd = memHead;

    variable->initialized = INITIALIZED;

    memHead++;

    if(symtable == NULL) {
        variable->next = NULL;
        symtable = variable;
    }
    else {
        variable->next = symtable;
        symtable = variable;
    }

    return variable->memBegin;
}

long getRangeForIter(char *name) {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
        	return iter->memBegin + 1;
        }
    }
    return -1;
}

void initialize(char *name) {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
        	iter->initialized = INITIALIZED;
        }
    }
}


int isInitialized(char *name) {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
        	if(iter->initialized == UNINITIALIZED) {
        		return VARIABLE_UNINITIALIZED;
        	}
        	return VARIABLE_INITIALIZED;
        }
    }
    return VARIABLE_NOT_DECLARED;
}


long symMemory(char *name) {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
        	if(iter->type == ARRAY) {
        		return IS_NOT_PRIMITIVE;
        	}
        	else {
        		if(iter->initialized == UNINITIALIZED) {
        			initStatus = VARIABLE_UNINITIALIZED;
        		}
        		else {
        			initStatus = VARIABLE_INITIALIZED;
        		}
        		typeStatus = iter->type;
            	return iter->memBegin;
            }
        }
    }
    return VARIABLE_NOT_DECLARED;
}

void traverse() {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        printf("zmienna: %s, memBegin: %ld, initialized: %d\n", iter->name, iter->memBegin, iter->initialized);
    }
}

long symMemoryIndex(char *name, long index) {
	for(symrec *iter = symtable; iter != NULL; iter = iter->next) {
        if(strcmp(iter->name, name) == 0) {
        	if(iter->type != ARRAY) {
        		return IS_NOT_ARRAY;
        	}
        	else {
        		if(index > iter->memEnd - iter->memBegin) {
        			return ARRAY_OUT_OF_BOUNDS;
        		}
        		
        		typeStatus = iter->type;
            	return iter->memBegin + index;
            }
        }
    }
    return VARIABLE_NOT_DECLARED;
}

int pop() {
    if(symtable == NULL) {
        fprintf(stderr, "EMPTY SYMBOL TABLE\n");
        return -1;
    }
    else {
        symrec *temp = symtable;
        symtable = temp->next;
        memHead = temp->memBegin;
        free(temp->name);
        free(temp);
        return 1;
    }
}

void destroy() {
    while(symtable != NULL) {
        symrec *temp = symtable;
        symtable = temp->next;
        free(temp->name);
        free(temp);
    }
    free(registers);
}



#endif