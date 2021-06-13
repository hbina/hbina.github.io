#define _XOPEN_SOURCE
#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

typedef struct tm tm;

static const char *FORMAT = "%a, %d %b %Y %H:%M:%S %Z";

static char *generateDateString(char *bytes, const int byteLen, const time_t t)
{
    struct tm *tm = gmtime(&t);
    strftime(bytes, byteLen, FORMAT, tm);
    return bytes;
}

static tm parseDateString(const char *zDate)
{
    tm result = {0};
    assert(*strptime(zDate, FORMAT, &result) == '\0');
    return result;
}

int main(void)
{
    time_t currentValue = time(NULL);
    char date1[500];
    char date2[500];
    memset(date1, 0, sizeof(date1));
    tm timeStruct = parseDateString(generateDateString(date1, sizeof(date1), currentValue));
    puts(date1);
    memset(date2, 0, sizeof(date2));
    parseDateString(generateDateString(date2, sizeof(date2), timegm(&timeStruct)));
    puts(date2);
    assert(memcmp(date1, date2, sizeof(date1)) == 0);
    return (0);
}