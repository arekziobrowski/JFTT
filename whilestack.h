#ifndef WHILESTACK_H
#define WHILESTACK_H

#include <stdio.h>
#include <stdlib.h>

typedef struct whilerec {
    int whileCount;
    struct whilerec *next;
} whilerec;

whilerec *whilestack = NULL;

void pushWhilestack(int whileCount) {
    whilerec *singlewhile = malloc(sizeof(whilerec));
    singlewhile->whileCount = whileCount;

    if(whilestack == NULL) {
        singlewhile->next = NULL;
        whilestack = singlewhile;
    }
    else {
        singlewhile->next = whilestack;
        whilestack = singlewhile;
    }
}

int popWhilestack() {
    if(whilestack == NULL) {
        fprintf(stderr, "EMPTY SYMBOL TABLE\n");
        return -1;
    }
    else {
        whilerec *temp = whilestack;
        whilestack = temp->next;
        int ret = temp->whileCount;
        free(temp);
        return ret;
    }
}

void destroyWhilestack() {
    while(whilestack != NULL) {
        whilerec *temp = whilestack;
        whilestack = temp->next;
        free(temp);
    }
}

#endif