#include <stdio.h>

int main()
{
    const char *pointer = "hello world";
    printf("%%p => %p\n", pointer);
    printf("%%s => %s\n", pointer);
    printf("%%d => %d\n", pointer);
    return 0;
}