#ifndef JUMPSTACK_H
#define JUMPSTACK_H

#include <stdio.h>
#include <stdlib.h>

typedef struct jump {
    int commandLineNumer;
    struct jump *next;
} jump;

jump *jumpstack = NULL;

void pushJumpstack(int commandLineNumer) {
    jump *singlejump = malloc(sizeof(jump));
    singlejump->commandLineNumer = commandLineNumer;

    if(jumpstack == NULL) {
        singlejump->next = NULL;
        jumpstack = singlejump;
    }
    else {
        singlejump->next = jumpstack;
        jumpstack = singlejump;
    }
}

int popJumpstack() {
    if(jumpstack == NULL) {
        fprintf(stderr, "EMPTY SYMBOL TABLE\n");
        return -1;
    }
    else {
        jump *temp = jumpstack;
        jumpstack = temp->next;
        int ret = temp->commandLineNumer;
        free(temp);
        return ret;
    }
}

void destroyJumpstack() {
    while(jumpstack != NULL) {
        jump *temp = jumpstack;
        jumpstack = temp->next;
        free(temp);
    }
}

#endif