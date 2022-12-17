---
title: "althttpd: From Top to Bottom"
author: "Hanif Bin Ariffin"
draft: false
---

# Before Venturing Further...

It's nice to have the codebase open as reference.
Each chapters will cover mostly 1 function and I wouldn't go through every single bit.
Just the parts that I find interesting.
I will cover the global variables as we go through.

Sometimes there will be backtracking and jumping ahead of the source code as I see necessary.

Please read about the design philosophy [here](https://sqlite.org/althttpd/doc/trunk/althttpd.md).

Check out the source code [here](/althttpd/althttpd.c).

With that out of the way...Let's go!

# Functions

## Escape

This function accepts a C-string and returns another C-string with every double-quote doubled.

```c
/*
** Double any double-quote characters in a string.
*/
static char *Escape(char *z){
  size_t i, j;
  size_t n;
  char c;
  char *zOut;
  for(i=0; (c=z[i])!=0 && c!='"'; i++){}
  if( c==0 ) return z;
  n = 1;
  for(i++; (c=z[i])!=0; i++){ if( c=='"' ) n++; }
  zOut = malloc( i+n+1 );
  if( zOut==0 ) return "";
  for(i=j=0; (c=z[i])!=0; i++){
    zOut[j++] = c;
    if( c=='"' ) zOut[j++] = c;
  }
  zOut[j] = 0;
  return zOut;
}
```

First we have the variable declarations at the top of the function...
So its one of those code. _sigh_.
Second, we can see that there is 0 calls to `strlen`.
We perform a single pass on the original strings and a second one on the output string.
Pretty cool.

Notice that the caller of this function have no real way to know if allocations have been made.
However, from the design philosophy,

```
Because each althttpd process only needs to service a single connection, althttpd is single threaded.
Furthermore, each process only lives for the duration of a single connection, which means that althttpd does not need to worry too much about memory leaks.
These design factors help keep the althttpd source code simple, which facilitates security auditing and analysis.
```

So this seems like a conscious desicion.
If you grep for this function, its only being used in one place.

```bash
bash-3.2$ rg 'Escape' ./content/althttpd.c
387:static char *Escape(char *z){
481:        zDate, zRemoteAddr, zHttp, Escape(zHttpHost), Escape(zScript),
482:        Escape(zReferer), zReplyStatus, nIn, nOut,
488:        nRequest, Escape(zAgent), Escape(zRM),
```

Notice that they don't even assign the pointer returned by this function!
I will let you judge whether this is good idea or not.

## tvms

This function is pretty much self explanatory.
It is what is...
I guess I can start reading about the time utility in libc.

```c
/*
** Convert a struct timeval into an integer number of microseconds
*/
static long long int tvms(struct timeval *p){
  return ((long long int)p->tv_sec)*1000000 + (long long int)p->tv_usec;
}
```

### References

1. [gettimeofday](https://man7.org/linux/man-pages/man3/gettimeofday.3p.html)

## MakeLogEntry

This function is quite big.
Lets dig in.

```c
/*
** Make an entry in the log file.  If the HTTP connection should be
** closed, then terminate this process.  Otherwise return.
*/
static void MakeLogEntry(int exitCode, int lineNum){
  FILE *log;
  if( zTmpNam ){
    unlink(zTmpNam);
  }
  if( zLogFile && !omitLog ){
    struct timeval now;
    struct tm *pTm;
    struct rusage self, children;
    int waitStatus;
    char *zRM = zRemoteUser ? zRemoteUser : "";
    char *zFilename;
    size_t sz;
    char zDate[200];
    char zExpLogFile[500];

    if( zScript==0 ) zScript = "";
    if( zRealScript==0 ) zRealScript = "";
    if( zRemoteAddr==0 ) zRemoteAddr = "";
    if( zHttpHost==0 ) zHttpHost = "";
    if( zReferer==0 ) zReferer = "";
    if( zAgent==0 ) zAgent = "";
    gettimeofday(&now, 0);
    pTm = localtime(&now.tv_sec);
    strftime(zDate, sizeof(zDate), "%Y-%m-%d %H:%M:%S", pTm);
    sz = strftime(zExpLogFile, sizeof(zExpLogFile), zLogFile, pTm);
    if( sz>0 && sz<sizeof(zExpLogFile)-2 ){
      zFilename = zExpLogFile;
    }else{
      zFilename = zLogFile;
    }
    waitpid(-1, &waitStatus, WNOHANG);
    getrusage(RUSAGE_SELF, &self);
    getrusage(RUSAGE_CHILDREN, &children);
    if( (log = fopen(zFilename,"a"))!=0 ){
#ifdef COMBINED_LOG_FORMAT
      strftime(zDate, sizeof(zDate), "%d/%b/%Y:%H:%M:%S %Z", pTm);
      fprintf(log, "%s - - [%s] \"%s %s %s\" %s %d \"%s\" \"%s\"\n",
              zRemoteAddr, zDate, zMethod, zScript, zProtocol,
              zReplyStatus, nOut, zReferer, zAgent);
#else
      strftime(zDate, sizeof(zDate), "%Y-%m-%d %H:%M:%S", pTm);
      /* Log record files:
      **  (1) Date and time
      **  (2) IP address
      **  (3) URL being accessed
      **  (4) Referer
      **  (5) Reply status
      **  (6) Bytes received
      **  (7) Bytes sent
      **  (8) Self user time
      **  (9) Self system time
      ** (10) Children user time
      ** (11) Children system time
      ** (12) Total wall-clock time
      ** (13) Request number for same TCP/IP connection
      ** (14) User agent
      ** (15) Remote user
      ** (16) Bytes of URL that correspond to the SCRIPT_NAME
      ** (17) Line number in source file
      */
      fprintf(log,
        "%s,%s,\"%s://%s%s\",\"%s\","
           "%s,%d,%d,%lld,%lld,%lld,%lld,%lld,%d,\"%s\",\"%s\",%d,%d\n",
        zDate, zRemoteAddr, zHttp, Escape(zHttpHost), Escape(zScript),
        Escape(zReferer), zReplyStatus, nIn, nOut,
        tvms(&self.ru_utime) - tvms(&priorSelf.ru_utime),
        tvms(&self.ru_stime) - tvms(&priorSelf.ru_stime),
        tvms(&children.ru_utime) - tvms(&priorChild.ru_utime),
        tvms(&children.ru_stime) - tvms(&priorChild.ru_stime),
        tvms(&now) - tvms(&beginTime),
        nRequest, Escape(zAgent), Escape(zRM),
        (int)(strlen(zHttp)+strlen(zHttpHost)+strlen(zRealScript)+3),
        lineNum
      );
      priorSelf = self;
      priorChild = children;
#endif
      fclose(log);
      nIn = nOut = 0;
    }
  }
  if( closeConnection ){
    exit(exitCode);
  }
  statusSent = 0;
}
```

Grepping for the usage of this function, we get:

```bash
bash-3.2$ rg 'MakeLogEntry' ./content/althttpd/althttpd.c
417:static void MakeLogEntry(int exitCode, int lineNum){
514:    MakeLogEntry(1,100);  /* LOG: Malloc() failed */
708:  MakeLogEntry(0, lineno);
723:  MakeLogEntry(0, lineno);
741:  MakeLogEntry(0, 110);  /* LOG: Not authorized */
756:  MakeLogEntry(0, 120);  /* LOG: CGI Error */
773:      MakeLogEntry(0, 130);  /* LOG: Timeout */
789:  MakeLogEntry(0, 140);  /* LOG: CGI script is writable */
809:  MakeLogEntry(0, linenum);
840:    MakeLogEntry(0, lineno);
1323:    MakeLogEntry(0, 470);  /* LOG: ETag Cache Hit */
1347:    MakeLogEntry(0, 2); /* LOG: Normal HEAD reply */
1684:    MakeLogEntry(0, 200); /* LOG: bad protocol in HTTP header */
1709:    MakeLogEntry(0, 220); /* LOG: Unknown request method */
1908:      MakeLogEntry(0, 270); /* LOG: Request too large */
1926:      MakeLogEntry(0, 290); /* LOG: cannot create temp file for POST */
2219:  MakeLogEntry(0, 0);  /* LOG: Normal reply */
```

It seems that most (if not all) of these usages are related to logging before killing the connection process.
It accepts the `exitCode` that the process should return, and a `lineNum`.

The second parameter is supposed to indicate the approximate line number this function is called.
Probably for debugging purposes.

The first thing we do in the function is to unlink a file.

```c
if( zTmpNam ){
  unlink(zTmpNam);
}
```

Grepping for `zTmpNam` yields,

```bash
bash-3.2$ rg 'zTmpNam' ./content/althttpd/althttpd.c
290:static char *zTmpNam = 0;        /* Name of a temporary file */
291:static char zTmpNamBuf[500];     /* Space to hold the temporary filename */
419:  if( zTmpNam ){
420:    unlink(zTmpNam);
1310:  if( zTmpNam ) unlink(zTmpNam);
1610:   && (in = fopen(zTmpNam,"r"))!=0 ){
1912:    sprintf(zTmpNamBuf, "/tmp/-post-data-XXXXXX");
1913:    zTmpNam = zTmpNamBuf;
1914:    if( mkstemp(zTmpNam)<0 ){
1918:    out = fopen(zTmpNam,"wb");
1924:        "Could not open \"%s\" for writing\n", zTmpNam
2155:      open(zTmpNam, O_RDONLY);
```

So `zTmpNam` is basically a temporary file created from `mkstemp`.
Then, if `zLogFile` is provided and `omitLog` is false, we start some logging procedures.
This block of statements here:

```c
if( zScript==0 ) zScript = "";
if( zRealScript==0 ) zRealScript = "";
if( zRemoteAddr==0 ) zRemoteAddr = "";
if( zHttpHost==0 ) zHttpHost = "";
if( zReferer==0 ) zReferer = "";
if( zAgent==0 ) zAgent = "";
gettimeofday(&now, 0);
pTm = localtime(&now.tv_sec);
strftime(zDate, sizeof(zDate), "%Y-%m-%d %H:%M:%S", pTm);
sz = strftime(zExpLogFile, sizeof(zExpLogFile), zLogFile, pTm);
if( sz>0 && sz<sizeof(zExpLogFile)-2 ){
  zFilename = zExpLogFile;
}else{
  zFilename = zLogFile;
}
waitpid(-1, &waitStatus, WNOHANG);
getrusage(RUSAGE_SELF, &self);
getrusage(RUSAGE_CHILDREN, &children);
```

Is basically to get the current state of the process that will be logged.
The other interesting part of the program is in the logging itself.

```c
fprintf(log,
  "%s,%s,\"%s://%s%s\",\"%s\","
      "%s,%d,%d,%lld,%lld,%lld,%lld,%lld,%d,\"%s\",\"%s\",%d,%d\n",
  zDate, zRemoteAddr, zHttp, Escape(zHttpHost), Escape(zScript),
  Escape(zReferer), zReplyStatus, nIn, nOut,
  tvms(&self.ru_utime) - tvms(&priorSelf.ru_utime),
  tvms(&self.ru_stime) - tvms(&priorSelf.ru_stime),
  tvms(&children.ru_utime) - tvms(&priorChild.ru_utime),
  tvms(&children.ru_stime) - tvms(&priorChild.ru_stime),
  tvms(&now) - tvms(&beginTime),
  nRequest, Escape(zAgent), Escape(zRM),
  (int)(strlen(zHttp)+strlen(zHttpHost)+strlen(zRealScript)+3),
  lineNum
);
```

Remember the function `Escape`?
This is the ony place where its being used and the pointer returned isn't assigned to anything.
So we can't possibly free any of the allocations made.

However, just after this, we have:

```c
if( closeConnection ){
  exit(exitCode);
}
```

Additionally based on the grepped usage of this function above.
We saw that most of the time, they immediately exit process.
So all those "memory leaks" previously (AFAIK) will be inconsequential.

### References

1. [mkstemp](https://man7.org/linux/man-pages/man3/mkstemp.3.html)
2. [unlink](https://man7.org/linux/man-pages/man2/unlink.2.html)
3. [gettimeofday](https://man7.org/linux/man-pages/man2/gettimeofday.2.html)
4. [localtime](https://man7.org/linux/man-pages/man3/localtime.3p.html)
5. [strftime](https://man7.org/linux/man-pages/man3/strftime.3.html)
6. [exit](https://man7.org/linux/man-pages/man3/exit.3.html)

## SafeMalloc

This function is a wrapper for malloc where it will exit the process if it fails.
I think the function itself is self-explanatory.
Nothing really interesting is happening here.

```c
/*
** Allocate memory safely
*/
static char *SafeMalloc( size_t size ){
  char *p;

  p = (char*)malloc(size);
  if( p==0 ){
    strcpy(zReplyStatus, "998");
    MakeLogEntry(1,100);  /* LOG: Malloc() failed */
    exit(1);
  }
  return p;
}
```

### References

1. [strcpy](https://man7.org/linux/man-pages/man3/strcpy.3.html)
2. [exit](https://man7.org/linux/man-pages/man3/exit.3.html)

## SetEnv

This function sets the environment variables.

```c
/*
** Set the value of environment variable zVar to zValue.
*/
static void SetEnv(const char *zVar, const char *zValue){
  char *z;
  size_t len;
  if( zValue==0 ) zValue="";
  /* Disable an attempted bashdoor attack */
  if( strncmp(zValue,"() {",4)==0 ) zValue = "";
  len = strlen(zVar) + strlen(zValue) + 2;
  z = SafeMalloc(len);
  sprintf(z,"%s=%s",zVar,zValue);
  putenv(z);
}
```

There's some issues with this function.

1. It does not free the memory held by `z`.
2. I think their implementation to prevent [bashdoor](<https://en.wikipedia.org/wiki/Shellshock_(software_bug)>) (Whatever that is) attack is somewhat naive?
   I am pretty sure one can bypass this check by simply prepending whitespaces.
3. It does not check if `zVar` is a `NULL`.
   Granted, if you grep for its usage, you will find that it only uses statically allocated memory.

```bash
bash-3.2$ rg 'SetEnv' ./static/althttpd/althttpd.c
523:static void SetEnv(const char *zVar, const char *zValue){
2136:        SetEnv(cgienv[i].zEnvName,*cgienv[i].pzEnvValue);
```

The `cgienv` here is an array of CGI environment variables defined at the top of the file.
These are all statically allocated, so no problem here.
However, the performance could have been improved in this case by passing the length of the arrays into the function.
I am not sure if compilers are smart enough (or allowed to) optimized the call to `strlen` by evaluating the size at compile time.

### References

1. [setenv](https://man7.org/linux/man-pages/man3/setenv.3.html)

## GetFirstElement

This function is basically `strtok` with a slightly different interface.
It accepts:

1. `zInput`, the C-string to be tokenized.
2. `zLeftOver`, an output pointer that points to to the leftover C-string.

And returns the parsed token.

```c
/*
** Remove the first space-delimited token from a string and return
** a pointer to it.  Add a NULL to the string to terminate the token.
** Make *zLeftOver point to the start of the next token.
*/
static char *GetFirstElement(char *zInput, char **zLeftOver){
  char *zResult = 0;
  if( zInput==0 ){
    if( zLeftOver ) *zLeftOver = 0;
    return 0;
  }
  while( isspace(*(unsigned char*)zInput) ){ zInput++; }
  zResult = zInput;
  while( *zInput && !isspace(*(unsigned char*)zInput) ){ zInput++; }
  if( *zInput ){
    *zInput = 0;
    zInput++;
    while( isspace(*(unsigned char*)zInput) ){ zInput++; }
  }
  if( zLeftOver ){ *zLeftOver = zInput; }
  return zResult;
}
```

### Visualization

```
h | e | l | l | o | NULL | | | | w | o | r | l | d |
|--------------------|-----------|------------------...
a                    b           c
```

Mark the beginning of the pointer as `a`.
The implementation is similar to `strtok`, it loops through the string until it encounters a whitespace.
It then loop again until it encounters non-whitespace and mark this as `c`.
Assign `c` to the `zLeftOver` pointer and returns `a` as the result.
To get the next token, pass `zLeftOver` token in `zInput`.

Note that because this function will litter the original C-string with `NULL`s, it will become unusable by `strlen`.
You can audit whether or not the author ever uses `strlen` on the C-strings that have been passed into this function.

Obviously the above algorithm needs to take into consideration the `NULL` value that marks the end of a C-string.

### References

1. [strtok](https://man7.org/linux/man-pages/man3/strtok.3.html)

## StrDup

This function basically copies a C-string.
Nothing special.

```c
/*
** Make a copy of a string into memory obtained from malloc.
*/
static char *StrDup(const char *zSrc){
  char *zDest;
  size_t size;

  if( zSrc==0 ) return 0;
  size = strlen(zSrc) + 1;
  zDest = (char*)SafeMalloc( size );
  strcpy(zDest,zSrc);
  return zDest;
}
```

However, I personally think that using `memcpy` is better here because we already calculated the string length here.

### References

1. [strlen](https://man7.org/linux/man-pages/man3/strlen.3.html)
2. [strcpy](https://man7.org/linux/man-pages/man3/strcpy.3.html)
3. [memcpy](https://man7.org/linux/man-pages/man3/memcpy.3.html)

## StrAppend

This function basically takes 3 C-string and concatenates them.

```c
static char *StrAppend(char *zPrior, const char *zSep, const char *zSrc){
  char *zDest;
  size_t size;
  size_t n0, n1, n2;

  if( zSrc==0 ) return 0;
  if( zPrior==0 ) return StrDup(zSrc);
  n0 = strlen(zPrior);
  n1 = strlen(zSep);
  n2 = strlen(zSrc);
  size = n0+n1+n2+1;
  zDest = (char*)SafeMalloc( size );
  memcpy(zDest, zPrior, n0);
  free(zPrior);
  memcpy(&zDest[n0],zSep,n1);
  memcpy(&zDest[n0+n1],zSrc,n2+1);
  return zDest;
}
```

### Visualization

Take 3 C-strings:

1. `zPrior` as `hello`.
2. `zSep` as `my`.
3. `zSrc` as `world`.

After this function, we will get something like,

```
h | e | l | l | o |  | m | y | | w | o | r | l | d | NULL |
|-----------------|------------|---------------------------...
<     zPrior      ><    zSep   ><         zSrc          >
```

And the original `zPrior` is freed, for whatever reason.

### References

1. [strlen](https://man7.org/linux/man-pages/man3/strlen.3.html).
2. [memcpy](https://man7.org/linux/man-pages/man3/memcpy.3.html).
3. [free](https://man7.org/linux/man-pages/man3/free.3p.html).

## CompareEtags

This function compares 2 C-strings and returns 0 if they differ and non-zero otherwise.

```c
/*
** Compare two ETag values. Return 0 if they match and non-zero if they differ.
**
** The one on the left might be a NULL pointer and it might be quoted.
*/
static int CompareEtags(const char *zA, const char *zB){
  if( zA==0 ) return 1;
  if( zA[0]=='"' ){
    int lenB = (int)strlen(zB);
    if( strncmp(zA+1, zB, lenB)==0 && zA[lenB+1]=='"' ) return 0;
  }
  return strcmp(zA, zB);
}
```

Notice that the function never checks the length of `lenB`, so it might seem problematic that we perform an arbitrary index `zA[lenB + 1]` here.
I think this is totally safe because the check is implicitly done by the fact that:

1. All C-strings ends with a `NULL`.
   This is kind of hard to verify.
2. In the `if` logic, we will only evaluate the right-hand side iff the call to `strncmp`here succeed.
   This means that `zA` is at least as long as `lenB`.
   Coupled with the fact that its a C-string, we can be sure that there's at least _another_ character beyond that, namely the `NULL` character.

### References

1. [strlen](https://man7.org/linux/man-pages/man3/strlen.3.html).
2. [strncmp](https://man7.org/linux/man-pages/man3/strncmp.3p.html).

## RemoveNewline

This function replaces newline (`\n` or `\r`) with `NULL`.

```c
/*
** Break a line at the first \n or \r character seen.
*/
static void RemoveNewline(char *z){
  if( z==0 ) return;
  while( *z && *z!='\n' && *z!='\r' ){ z++; }
  *z = 0;
}
```

This is probably done so that C-string appears as if it ends there.
But this is highly problematic because it does not return the `z`.
The caller have no way of knowing where that `NULL` was assigned.
Even if they loop through again and find that `NULL`, how do they know that this `NULL` is the one that we assigned or this is the _actual_ the end of the C-string?

In my opinion, it should return the pointer to the next character if its part of the C-string.

## Rfc822Date

This function converts a `time_t` into its RFC822 representation.

```c
/* Render seconds since 1970 as an RFC822 date string.  Return
** a pointer to that string in a static buffer.
*/
static char *Rfc822Date(time_t t){
  struct tm *tm;
  static char zDate[100];
  tm = gmtime(&t);
  strftime(zDate, sizeof(zDate), "%a, %d %b %Y %H:%M:%S %Z", tm);
  return zDate;
}
```

The interesting (in a bad way) is that it returns a pointer to a statically allocated memory.
So any time you make 2 calls to this bad boy, just remember that the first pointer returned is now invalid :).

One way to solve this is to make the caller of this function provides the bytes to write to.
This makes this function free from being responsible for memory; which it shouldn't.

### Testing

Let's try to use this function and see what we get.

```c
#include <stdio.h>
#include <time.h>

static char *Rfc822Date(time_t t)
{
    struct tm *tm;
    static char zDate[100];
    tm = gmtime(&t);
    strftime(zDate, sizeof(zDate), "%a, %d %b %Y %H:%M:%S %Z", tm);
    return zDate;
}

int main(void)
{
    time_t t = time(NULL);
    char *zDate = Rfc822Date(t);
    const int r = printf("%s\r\n", zDate);
    return r < 0 ? -1 : 0;
}
```

Compiling and running this small program yields,

```bash
Sat, 12 Jun 2021 16:24:15 GMT
```

### References

1. [strftime](https://man7.org/linux/man-pages/man3/strftime.3.html)
2. [gmtime](https://man7.org/linux/man-pages/man3/gmtime.3p.html)

## DateTag

Nothing really special about this function. It just appends the `zTag` and the `Rfc822Date` of the given time.
The result is then printed to `stdout`.

```c
/*
** Print a date tag in the header.  The name of the tag is zTag.
** The date is determined from the unix timestamp given.
*/
static int DateTag(const char *zTag, time_t t){
  return printf("%s: %s\r\n", zTag, Rfc822Date(t));
}
```

### References

1. [printf](https://man7.org/linux/man-pages/man3/printf.3.html)

## ParseRfc822Date

This function is quite complicated.
I don't pretend to know half of how it works.
However, as the comment said, its supposed to parse an RFC822 formatted strings.
It just appends the `zTag` and the `Rfc822Date` of the given time.

```c
/*
** Parse an RFC822-formatted timestamp as we'd expect from HTTP and return
** a Unix epoch time. <= zero is returned on failure.
*/
time_t ParseRfc822Date(const char *zDate){
  int mday, mon, year, yday, hour, min, sec;
  char zIgnore[4];
  char zMonth[4];
  static const char *const azMonths[] =
    {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  if( 7==sscanf(zDate, "%3[A-Za-z], %d %3[A-Za-z] %d %d:%d:%d", zIgnore,
                       &mday, zMonth, &year, &hour, &min, &sec)){
    if( year > 1900 ) year -= 1900;
    for(mon=0; mon<12; mon++){
      if( !strncmp( azMonths[mon], zMonth, 3 )){
        int nDay;
        int isLeapYr;
        static int priorDays[] =
         {  0, 31, 59, 90,120,151,181,212,243,273,304,334 };
        isLeapYr = year%4==0 && (year%100!=0 || (year+300)%400==0);
        yday = priorDays[mon] + mday - 1;
        if( isLeapYr && mon>1 ) yday++;
        nDay = (year-70)*365 + (year-69)/4 - year/100 + (year+300)/400 + yday;
        return ((time_t)(nDay*24 + hour)*60 + min)*60 + sec;
      }
    }
  }
  return 0;
}
```

Given how complex the notion of timezones and time itself, I bet this function is broken.
Its much easier to just rely on the standard libc function --- and likely more reliable.
See the [C code here](../althttpd/c_time_back_and_forth.c) to see parsing dates back and forth,

### References

1. [gmtime](https://man7.org/linux/man-pages/man3/gmtime.3p.html)
2. [strftime](https://man7.org/linux/man-pages/man3/strftime.3.html)
3. [strptime](https://man7.org/linux/man-pages/man3/strptime.3.html)
4. [time](https://man7.org/linux/man-pages/man3/time.3p.html)
5. [memset](https://man7.org/linux/man-pages/man3/memset.3.html)
6. [memcmp](https://man7.org/linux/man-pages/man3/memcmp.3p.html)

## TestParseRfc822Date

This function only exists for testing purposes.
I wonder how plausible it is to test _all_ the possible values by forking a bunch of process...

```c
/*
** Test procedure for ParseRfc822Date
*/
void TestParseRfc822Date(void){
  time_t t1, t2;
  for(t1=0; t1<0x7fffffff; t1 += 127){
    t2 = ParseRfc822Date(Rfc822Date(t1));
    assert( t1==t2 );
  }
}
```

To show that its only used once,

```bash
hbina.github.io on  master [?⇡]
❯ cat ./static/althttpd/althttpd.c | rg --line-number 'TestParseRfc822Date'
666:void TestParseRfc822Date(void){
2425:      TestParseRfc822Date();
```

### References

1. [assert](https://man7.org/linux/man-pages/man3/assert.3.html)

## StartResponse

The way this program generates the response to HTTP requests is by printing to `stdout`.
This function will setup the HTTP request header with the protocol and the status.
It will also do some additional stuff based on the status response.

```c
/*
** Print the first line of a response followed by the server type.
*/
static void StartResponse(const char *zResultCode){
  time_t now;
  time(&now);
  if( statusSent ) return;
  nOut += printf("%s %s\r\n", zProtocol, zResultCode);
  strncpy(zReplyStatus, zResultCode, 3);
  zReplyStatus[3] = 0;
  if( zReplyStatus[0]>='4' ){
    closeConnection = 1;
  }
  if( closeConnection ){
    nOut += printf("Connection: close\r\n");
  }else{
    nOut += printf("Connection: keep-alive\r\n");
  }
  nOut += DateTag("Date", now);
  statusSent = 1;
}
```

One thing to notice that is that if the first digit in the reply status is `>=4`, it will append the HTTP header with `Connection: close`. It probably means that if there's _any_ issue with the request, the server will just close the connection.

Let's see how its being used,

```bash
hbina.github.io on  master [!?⇡]
❯ cat ./static/althttpd/althttpd.c | rg --line-number 'StartResponse'
677:static void StartResponse(const char *zResultCode){
700:  StartResponse("404 Not Found");
716:  StartResponse("403 Forbidden");
732:  StartResponse("401 Authorization Required");
748:  StartResponse("500 Error");
783:  StartResponse("500 CGI Configuration Error");
799:  StartResponse("500 Server Malfunction");
821:      StartResponse("301 Permanent Redirect");
824:      StartResponse("308 Permanent Redirect");
827:      StartResponse("302 Temporary Redirect");
1317:    StartResponse("304 Not Modified");
1329:    StartResponse("206 Partial Content");
1337:    StartResponse("200 OK");
1389:      StartResponse("302 Redirect");
1424:    StartResponse("206 Partial Content");
1432:    StartResponse("200 OK");
1678:    StartResponse("400 Bad Request");
1703:    StartResponse("501 Not Implemented");
1902:      StartResponse("500 Request too large");
1920:      StartResponse("500 Cannot create /tmp file");
```

As you can see, these are all HTTP headers.
All of them are also statically allocated, I think its worth creating a list of possible HTTP headers and use that.
Some extra safety!

Another interesting to note is that if the browser uses `HTTP/2`, this response header can/should be considered malformed according to the [spec](https://datatracker.ietf.org/doc/html/rfc7540#section-8.1.2.2).

### References

1. [HTTP Response Header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#http_responses)

## NotFound

This is just a generic "404 NOT FOUND" template.
The only 2 values that it need to complete the document is:

1. `lineno` which depends on the caller of this function.
   As I said in previous entries, I think every compiler have a C macro for this already.
2. `zScript` which is the document that the user is attempting to retrieve.
   This is probably the string after the domain in the URL.

```c
/*
** Tell the client that there is no such document
*/
static void NotFound(int lineno){
  StartResponse("404 Not Found");
  nOut += printf(
    "Content-type: text/html; charset=utf-8\r\n"
    "\r\n"
    "<head><title lineno=\"%d\">Not Found</title></head>\n"
    "<body><h1>Document Not Found</h1>\n"
    "The document %s is not available on this server\n"
    "</body>\n", lineno, zScript);
  MakeLogEntry(0, lineno);
  exit(0);
}
```

Note that before ending the process, it will create a log entry.
It's used in quite a few places,

```bash
hbina.github.io on  master [!?]
❯ cat static/althttpd/althttpd.c | rg --line-number 'NotFound'
699:static void NotFound(int lineno){
917:    NotFound(150);  /* LOG: Cannot open -auth file */
943:        NotFound(160);  /* LOG:  http request on https-only page */
958:      NotFound(180);  /* LOG:  malformed entry in -auth file */
1327:  if( in==0 ) NotFound(480); /* LOG: fopen() failed for static content */
1687:  if( zScript[0]!='/' ) NotFound(210); /* LOG: Empty request URI */
1860:        NotFound(260);  /* LOG: Disallowed referrer */
1962:      NotFound(300); /* LOG: Path element begins with "." or "-" */
1974:    NotFound(310); /* LOG: URI does not start with "/" */
1977:    NotFound(320); /* LOG: URI too long */
1980:    NotFound(330);  /* LOG: Missing HOST: parameter */
1982:    NotFound(340);  /* LOG: HOST parameter too long */
2007:        NotFound(350);  /* LOG: *.website permissions */
2049:      if( stillSearching ) NotFound(380); /* LOG: URI not found */
2054:        NotFound(390);  /* LOG: File not readable */
2071:        NotFound(400); /* LOG: URI is a directory w/o index.html */
2211:    NotFound(460); /* LOG: Excess URI content past static file name */
```

### References

1. [printf](https://man7.org/linux/man-pages/man3/printf.3.html)
2. [exit](https://man7.org/linux/man-pages/man3/exit.3.html)

## Forbidden

Another HTTP response template.
This time its to indicate that the request is forbidden.

```c
/*
** Tell the client that they are not welcomed here.
*/
static void Forbidden(int lineno){
  StartResponse("403 Forbidden");
  nOut += printf(
    "Content-type: text/plain; charset=utf-8\r\n"
    "\r\n"
    "Access denied\n"
  );
  closeConnection = 1;
  MakeLogEntry(0, lineno);
  exit(0);
}
```

### What is Forbidden?

I think its amusing to look at the usage of this function.
It's being used at several places,

```c
hbina.github.io on  master took 4s
❯ cat ./static/althttpd/althttpd.c | rg --line-number 'Forbidden'
715:static void Forbidden(int lineno){
716:  StartResponse("403 Forbidden");
1764:        Forbidden(230); /* LOG: Referrer is devids.net */
1778:        Forbidden(240);  /* LOG: Illegal content in HOST: parameter */
1838:        Forbidden(250);  /* LOG: Disallowed user agent */
1846:      Forbidden(251);  /* LOG: Disallowed user agent (20190424) */
```

### Forbidden Referer

HTTP headers have a "referer" value when making requests so that the server can know who made the request.
For whatever reason, the author decides to forbid anyone from `devids.net`!

```c
    }else if( strcasecmp(zFieldName,"Referer:")==0 ){
      zReferer = StrDup(zVal);
      if( strstr(zVal, "devids.net/")!=0 ){ zReferer = "devids.net.smut";
        Forbidden(230); /* LOG: Referrer is devids.net */
      }
```

### Forbidden Host

When parsing the `Host` header value, the server will also reply with forbidden if there's illegal content in it.
We will cover what `sanitizeString` is later.

```c
    }else if( strcasecmp(zFieldName,"Host:")==0 ){
      int inSquare = 0;
      char c;
      if( sanitizeString(zVal) ){
        Forbidden(240);  /* LOG: Illegal content in HOST: parameter */
      }
```

### Forbidden Agents

There's also a list of disallowed agents.
I am not sure why half of these are in here...
I guess its just what the author had accumulated after over 20 years of running this program.

```c
if( zAgent ){
    const char *azDisallow[] = {
      "Windows 9",
      "Download Master",
      "Ezooms/",
      "HTTrace",
      "AhrefsBot",
      "MicroMessenger",
      "OPPO A33 Build",
      "SemrushBot",
      "MegaIndex.ru",
      "MJ12bot",
      "Chrome/0.A.B.C",
      "Neevabot/",
      "BLEXBot/",
    };
    size_t ii;
    for(ii=0; ii<sizeof(azDisallow)/sizeof(azDisallow[0]); ii++){
      if( strstr(zAgent,azDisallow[ii])!=0 ){
        Forbidden(250);  /* LOG: Disallowed user agent */
      }
    }
```

### Forbidden Spiders

This one is disabled and its actually quite new!
I am not sure what this is?
I suppose there's a specific misbehaving/malicious website crawler attack the author's server at that time.

```c
#if 0
    /* Spider attack from 2019-04-24 */
    if( strcmp(zAgent,
            "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36")==0 ){
      Forbidden(251);  /* LOG: Disallowed user agent (20190424) */
    }
#endif
```

### References

1. [printf](https://man7.org/linux/man-pages/man3/printf.3.html).
2. [exit](https://man7.org/linux/man-pages/man3/exit.3.html).
3. [HTTP Header Referer](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer).
4. [HTTP Header Host](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Host).
5. [HTTP Header User-Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent).

## NotAuthorized

Yet another HTTP response template.
This time its to indicate that the request is unauthorised to access that resource.

```c
/*
** Tell the client that authorization is required to access the
** document.
*/
static void NotAuthorized(const char *zRealm){
  StartResponse("401 Authorization Required");
  nOut += printf(
    "WWW-Authenticate: Basic realm=\"%s\"\r\n"
    "Content-type: text/html; charset=utf-8\r\n"
    "\r\n"
    "<head><title>Not Authorized</title></head>\n"
    "<body><h1>401 Not Authorized</h1>\n"
    "A login and password are required for this document\n"
    "</body>\n", zRealm);
  MakeLogEntry(0, 110);  /* LOG: Not authorized */
}
```

There's nothing much to be said about this function.
So let's take a look at its usage.
There's only 1 of them.

```bash
hbina.github.io on  master [?]
❯ cat ./static/althttpd/althttpd.c | rg --line-number 'NotAuthorized'
731:static void NotAuthorized(const char *zRealm){
964:  NotAuthorized(zRealm);
```

### Configuring Authorization

The function that made the call is `CheckBasicAuthorization`.
This function parses an authorization file that may or may not exist in the directory that the resources is in.
One of the parameters that can be added in this configuration file is `realm`.
The documentation says,

```c
**    *  "realm TEXT" sets the realm to TEXT.
```

So while parsing this configuration file, we assign the "`TEXT`" above to `zRealm` here,

```c
    if( strcmp(zFieldName, "realm")==0 ){
      zRealm = StrDup(zVal);
```

But `zRealm` is never used!

```bash
hbina.github.io on  master [?]
❯ cat ./static/althttpd/althttpd.c | rg --line-number 'zRealm'
731:static void NotAuthorized(const char *zRealm){
740:    "</body>\n", zRealm);
910:  char *zRealm = "unknown realm";
930:      zRealm = StrDup(zVal);
964:  NotAuthorized(zRealm);
```

So I assume its just a way for the author to determine what kind of files were being requested.

According to the actual [HTTP/1.0 specification for authentication](https://datatracker.ietf.org/doc/html/rfc1945#section-11), we can see that realms are basically used to tell the requester that the same realm should require the same kind of authentication.
Probably for caching purposes?

So it kinda makes sense that this value is not being used anywhere.
It's more like a guideline, not a strict spec.
It depends entirely if the resources are properly configured.

### References

1. [printf](https://man7.org/linux/man-pages/man3/printf.3.html).
2. [exit](https://man7.org/linux/man-pages/man3/exit.3.html).
3. [HTTP Header Referer](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer).
4. [HTTP Header Host](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Host).
5. [HTTP Header User-Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent).

## CgiError

Another simple template to indicate CGI error.

```c
/*
** Tell the client that there is an error in the script.
*/
static void CgiError(void){
  StartResponse("500 Error");
  nOut += printf(
    "Content-type: text/html; charset=utf-8\r\n"
    "\r\n"
    "<head><title>CGI Program Error</title></head>\n"
    "<body><h1>CGI Program Error</h1>\n"
    "The CGI program %s generated an error\n"
    "</body>\n", zScript);
  MakeLogEntry(0, 120);  /* LOG: CGI Error */
  exit(0);
}
```

Its only being used once,

```bash
hbina.github.io on  master [!?]
❯ cat static/althttpd/althttpd.c | rg --line-number 'CgiError'
747:static void CgiError(void){
2197:      CgiError();
```

## Timeout

A function that will be called to handle timeouts.
AFAIK, the server is set up such that each request must be handled in a set amount of time.
Beyond that, the server will just timeout.

```c
/*
** This is called if we timeout or catch some other kind of signal.
** Log an error code which is 900+iSig and then quit.
*/
static void Timeout(int iSig){
  if( !debugFlag ){
    if( zScript && zScript[0] ){
      char zBuf[10];
      zBuf[0] = '9';
      zBuf[1] = '0' + (iSig/10)%10;
      zBuf[2] = '0' + iSig%10;
      zBuf[3] = 0;
      strcpy(zReplyStatus, zBuf);
      MakeLogEntry(0, 130);  /* LOG: Timeout */
    }
    exit(0);
  }
}
```

There's 2 things that I am unsure here.

1. Why do we need 10 bytes when we only use 4 of them?
2. Why is the the error code here `9XX` when there's already a HTTP request code for this.
   It appears to be for logging purposes only, which is weird because its only enabled when `debugFlag` is false.

Let's see how it's bein used,

```bash
hbina.github.io on  master [!?]
❯ cat static/althttpd/althttpd.c | rg --line-number 'Timeout'
333:static int useTimeout = 1;       /* True to use times */
764:static void Timeout(int iSig){
773:      MakeLogEntry(0, 130);  /* LOG: Timeout */
1352:  if( useTimeout ) alarm(30 + pStat->st_size/1000);
1381:  if( useTimeout ){
1657:  signal(SIGALRM, Timeout);
1658:  signal(SIGSEGV, Timeout);
1659:  signal(SIGPIPE, Timeout);
1660:  signal(SIGXCPU, Timeout);
1661:  if( useTimeout ) alarm(15);
1930:    if( useTimeout ) alarm(15 + len/2000);
1939:  if( useTimeout ) alarm(10);
2224:  if( useTimeout ) alarm(30);
2417:        useTimeout = 0;
2540:INSERT INTO xref VALUES(130,'Timeout');
```

So it seems to register itself to a bunch of signals and that's pretty much it.

### References

1. [signal](https://man7.org/linux/man-pages/man3/signal.3p.html).
2. [HTTP Status Request Timeout](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/408).

## CgiScriptWritable

Just another HTTP response template for CGI errors.

```c
/*
** Tell the client that there is an error in the script.
*/
static void CgiScriptWritable(void){
  StartResponse("500 CGI Configuration Error");
  nOut += printf(
    "Content-type: text/plain; charset=utf-8\r\n"
    "\r\n"
    "The CGI program %s is writable by users other than its owner.\n",
    zRealScript);
  MakeLogEntry(0, 140);  /* LOG: CGI script is writable */
  exit(0);
}
```

As the function name implies, it's being used whenever a script is writable by group and other have write permission to the file.
See "The file type and mode" section in the inode manual below.

### References

1. [inode](https://man7.org/linux/man-pages/man7/inode.7.html).

## Malfunction

This is a template for a generic error in the server.

```c
/*
** Tell the client that the server malfunctioned.
*/
static void Malfunction(int linenum, const char *zFormat, ...){
  va_list ap;
  va_start(ap, zFormat);
  StartResponse("500 Server Malfunction");
  nOut += printf(
    "Content-type: text/plain; charset=utf-8\r\n"
    "\r\n"
    "Web server malfunctioned; error number %d\n\n", linenum);
  if( zFormat ){
    nOut += vprintf(zFormat, ap);
    printf("\n");
    nOut++;
  }
  MakeLogEntry(0, linenum);
  exit(0);
}
```

The strange part about this is that it exit the process with 0.
If its malfunctioning, I assume it's supposed to return a negative value.
It's being used in a variety of places, covering various kinds of errors.

```bash
hbina.github.io on  master [!?]
❯ cat static/althttpd/althttpd.c | rg --line-number --fixed-strings "Malfunction"796:static void Malfunction(int linenum, const char *zFormat, ...){
799:  StartResponse("500 Server Malfunction");
1413:          Malfunction(600, "Out of memory: %d bytes", nMalloc);
1451:           Malfunction(610, "Out of memory: %d bytes", nMalloc);
1492:    Malfunction(700, "cannot open \"%s\"\n", zFile);
1495:    Malfunction(701, "cannot read \"%s\"\n", zFile);
1498:    Malfunction(702, "misformatted SCGI spec \"%s\"\n", zFile);
1504:    Malfunction(703, "misformatted SCGI spec \"%s\"\n", zFile);
1521:    Malfunction(704, "unrecognized line in SCGI spec: \"%s %s\"\n",
1531:    Malfunction(704, "cannot resolve SCGI server name %s:%s\n%s\n",
1546:          Malfunction(721,"Relight failed with %d: \"%s\"\n",
1560:          Malfunction(720, /* LOG: chdir() failed */
1571:          Malfunction(706, "bad fallback file: \"%s\"\n", zFallback);
1574:      Malfunction(707, "cannot open socket to SCGI server %s\n",
1593:        Malfunction(706, "out of memory");
1648:    Malfunction(190,   /* LOG: chdir() failed */
1915:      Malfunction(280,  /* LOG: mkstemp() failed */
2017:    Malfunction(360,  /* LOG: chdir() failed */
2122:      Malfunction(420, /* LOG: chdir() failed */
2151:        Malfunction(430,  /* LOG: dup(0) failed */
2177:        Malfunction(440, /* LOG: pipe() failed */
2184:          Malfunction(450, /* LOG: dup(1) failed */
2408:        Malfunction(500,  /* LOG: unknown IP protocol */
2421:        Malfunction(501, /* LOG: cannot open --input file */
2429:      Malfunction(510, /* LOG: unknown command-line argument on launch */
2439:      Malfunction(520, /* LOG: --root argument missing */
2448:    Malfunction(530, /* LOG: chdir() failed */
2458:      Malfunction(540, /* LOG: chroot() failed */
2467:    Malfunction(550, /* LOG: server startup failed */
2485:        Malfunction(560, /* LOG: setgid() failed */
2489:        Malfunction(570, /* LOG: setuid() failed */
2493:      Malfunction(580, /* LOG: unknown user */
2498:    Malfunction(590, /* LOG: cannot run as root */
```

### References

1. [exit](https://man7.org/linux/man-pages/man3/exit.3.html)

## Redirect

```c
/*
** Do a server redirect to the document specified.  The document
** name not contain scheme or network location or the query string.
** It will be just the path.
*/
static void Redirect(const char *zPath, int iStatus, int finish, int lineno){
  switch( iStatus ){
    case 301:
      StartResponse("301 Permanent Redirect");
      break;
    case 308:
      StartResponse("308 Permanent Redirect");
      break;
    default:
      StartResponse("302 Temporary Redirect");
      break;
  }
  if( zServerPort==0 || zServerPort[0]==0 || strcmp(zServerPort,"80")==0 ){
    nOut += printf("Location: %s://%s%s%s\r\n",
                   zHttp, zServerName, zPath, zQuerySuffix);
  }else{
    nOut += printf("Location: %s://%s:%s%s%s\r\n",
                   zHttp, zServerName, zServerPort, zPath, zQuerySuffix);
  }
  if( finish ){
    nOut += printf("Content-length: 0\r\n");
    nOut += printf("\r\n");
    MakeLogEntry(0, lineno);
  }
  fflush(stdout);
}
```

This function simply redirects using the [StartResponse](#startresponse) that we have previously seen.

### The Different Kinds of HTTP Status Code for Redirection

The first it does is to map the integer given in `iStatus` to their complete HTTP status code.
I would like to not however that the first and the last statuses in use here are incorrect.

Using [IANA](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml) itself as reference, we can see that we should change:

1. "301 Permanent Redirect" => "301 Moved Permanently"

2. "302 Temporary Redirect" => "302 Found"

If the intention is to used indicate "temporary redirect", then the correct status code for that is "307 Temporary Indirect".
As far as I know, the standard says that only the first 3 letters (the numeric part of the status code) actually matters.
I have already raised a ticket for this [here](https://sqlite.org/althttpd/tktview?name=2ac5f38c13).

### Where to Redirect

The way a client determine where it should retry is provided in the `Location` header.
This is what the second part of this function is doing.

If a port is provided (and it is not port 80 which is already used by the HTTP server), then it will append the port to the domain.

If there are no additional data to be included into this response, then it will add the header "Content-Length" with the value 0 to indicate an empty body.
However, if we grep for the usage of this function, we can see that we will _always_ finish here.

```bash
hbina@akarin:~/git/hbina.github.io$ rg 'Redirect\(' ./static/althttpd/althttpd.c
819:static void Redirect(const char *zPath, int iStatus, int finish, int lineno){
951:        Redirect(zScript, 301, 1, 170); /* LOG: -auth redirect */
2044:          Redirect(zRealScript, 302, 1, 370); /* LOG: redirect to not-found */
2080:        Redirect(zRealScript,301,1,410); /* LOG: redirect to add trailing / */
```

Finally, we will flush the buffer to stdout.
However, I am not particularly sure why we explicitly do it here and not before we finally want to exit from this fork.

## Decode64

```c
/*
** This function treats its input as a base-64 string and returns the
** decoded value of that string.  Characters of input that are not
** valid base-64 characters (such as spaces and newlines) are ignored.
*/
void Decode64(char *z64){
  char *zData;
  int n64;
  int i, j;
  int a, b, c, d;
  static int isInit = 0;
  static int trans[128];
  static unsigned char zBase[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  if( !isInit ){
    for(i=0; i<128; i++){ trans[i] = 0; }
    for(i=0; zBase[i]; i++){ trans[zBase[i] & 0x7f] = i; }
    isInit = 1;
  }
  n64 = strlen(z64);
  while( n64>0 && z64[n64-1]=='=' ) n64--;
  zData = z64;
  for(i=j=0; i+3<n64; i+=4){
    a = trans[z64[i] & 0x7f];
    b = trans[z64[i+1] & 0x7f];
    c = trans[z64[i+2] & 0x7f];
    d = trans[z64[i+3] & 0x7f];
    zData[j++] = ((a<<2) & 0xfc) | ((b>>4) & 0x03);
    zData[j++] = ((b<<4) & 0xf0) | ((c>>2) & 0x0f);
    zData[j++] = ((c<<6) & 0xc0) | (d & 0x3f);
  }
  if( i+2<n64 ){
    a = trans[z64[i] & 0x7f];
    b = trans[z64[i+1] & 0x7f];
    c = trans[z64[i+2] & 0x7f];
    zData[j++] = ((a<<2) & 0xfc) | ((b>>4) & 0x03);
    zData[j++] = ((b<<4) & 0xf0) | ((c>>2) & 0x0f);
  }else if( i+1<n64 ){
    a = trans[z64[i] & 0x7f];
    b = trans[z64[i+1] & 0x7f];
    zData[j++] = ((a<<2) & 0xfc) | ((b>>4) & 0x03);
  }
  zData[j] = 0;
}
```

This function decodes [base64](https://en.wikipedia.org/wiki/Base64) C-string input into its binary data.
Interestingly, this function does not perform any allocation.
The decoding is done in-place in the original buffer.

Here's a [test program](../althttpd/decode_base64_test.c) to see the result of decoding some data.

```bash
hbina@akarin:~/git/hbina.github.io$ clang ./static/althttpd/decode_base64_test.c  && ./a.out
Encoded:'TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu==============='
Decoded:'Many hands make light work.'
```

Note that this is for illustrative purpose only.
The `base64` encoding is used to encode binary data which may contain a bunch of `O`s and/or non-printable characters.
Thefore, the result of decoded data cannot be trivially printed.
