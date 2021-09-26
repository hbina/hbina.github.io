#include <string.h>
#include <stdio.h>
#include <stdlib.h>

void Decode64(char *z64)
{
    char *zData;
    unsigned int n64;
    int i, j;
    int a, b, c, d;
    static int isInit = 0;
    static int trans[128];
    static unsigned char zBase[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    if (!isInit)
    {
        for (i = 0; i < 128; i++)
        {
            trans[i] = 0;
        }
        for (i = 0; zBase[i]; i++)
        {
            trans[zBase[i] & 0x7f] = i;
        }
        isInit = 1;
    }
    n64 = strlen(z64);
    while (n64 > 0 && z64[n64 - 1] == '=')
        n64--;
    zData = z64;
    for (i = j = 0; i + 3 < n64; i += 4)
    {
        a = trans[z64[i] & 0x7f];
        b = trans[z64[i + 1] & 0x7f];
        c = trans[z64[i + 2] & 0x7f];
        d = trans[z64[i + 3] & 0x7f];
        zData[j++] = ((a << 2) & 0xfc) | ((b >> 4) & 0x03);
        zData[j++] = ((b << 4) & 0xf0) | ((c >> 2) & 0x0f);
        zData[j++] = ((c << 6) & 0xc0) | (d & 0x3f);
    }
    if (i + 2 < n64)
    {
        a = trans[z64[i] & 0x7f];
        b = trans[z64[i + 1] & 0x7f];
        c = trans[z64[i + 2] & 0x7f];
        zData[j++] = ((a << 2) & 0xfc) | ((b >> 4) & 0x03);
        zData[j++] = ((b << 4) & 0xf0) | ((c >> 2) & 0x0f);
    }
    else if (i + 1 < n64)
    {
        a = trans[z64[i] & 0x7f];
        b = trans[z64[i + 1] & 0x7f];
        zData[j++] = ((a << 2) & 0xfc) | ((b >> 4) & 0x03);
    }
    zData[j] = 0;
}

int main()
{
    const char *input = "TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu===============";
    const int len = strlen(input);
    char *test = malloc(len);
    memcpy(test, input, len);
    Decode64(test);
    printf("Encoded:'%s'\n", input);
    printf("Decoded:'%s'\n", test);
    return 0;
}
