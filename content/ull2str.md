---
title: "Intuitions in Converting Integers to Strings"
date: 2022-12-21
author: "Hanif Bin Ariffin"
draft: true
---

# Prelude

I came across an interesting function in redis's `util.c`,

```c
/* Convert a unsigned long long into a string. Returns the number of
 * characters needed to represent the number.
 * If the buffer is not big enough to store the string, 0 is returned.
 *
 * Based on the following article (that apparently does not provide a
 * novel approach but only publicizes an already used technique):
 *
 * https://www.facebook.com/notes/facebook-engineering/three-optimization-tips-for-c/10151361643253920 */
int ull2string(char *dst, size_t dstlen, unsigned long long value) {
    static const char digits[201] =
        "0001020304050607080910111213141516171819"
        "2021222324252627282930313233343536373839"
        "4041424344454647484950515253545556575859"
        "6061626364656667686970717273747576777879"
        "8081828384858687888990919293949596979899";

    /* Check length. */
    uint32_t length = digits10(value);
    if (length >= dstlen) goto err;;

    /* Null term. */
    uint32_t next = length - 1;
    dst[next + 1] = '\0';
    while (value >= 100) {
        int const i = (value % 100) * 2;
        value /= 100;
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
        next -= 2;
    }

    /* Handle last 1-2 digits. */
    if (value < 10) {
        dst[next] = '0' + (uint32_t) value;
    } else {
        int i = (uint32_t) value * 2;
        dst[next] = digits[i + 1];
        dst[next - 1] = digits[i];
    }
    return length;
err:
    /* force add Null termination */
    if (dstlen > 0)
        dst[0] = '\0';
    return 0;
}
```

`util.c` is a low-level utility file that contains many functions that are regularly used by redis so it is important to be very efficient.
This means that it is not surprising to see weird functions like this and I find that you can learn a lot of things from them.

This is an approximate transcript of my talk at Facebook NYC on December 4, 2012, which discusses optimization tips for C++ programs. The video of the talk is here and the accompanying slides are here.

So in this article, we will go through the function above in several steps.

# Scope

Commonly given advice about approaching optimization in general, and optimization of C++ code in particular, includes:

Quoting Knuth more or less out of context
The classic one-two punch: (a) Don't do it; (b) Don't do it yet
Focus on algorithms, not on micro-optimization
Most programs are I/O bound
Avoid constructing objects unnecessarily
Use C++11's rvalue references to implement move constructors

That's great advice, save for two issues. First, it has becomed hackneyed by overuse and is often wielded to dogmatically smother new discussions before they even happen. Second, some of it is vague. For example, "choose the right algorithm" is vacuous without a good understanding of what algorithms are best supported by the computing fabric, which is complex enough to make certain algorithmic approaches better than others overall. So I won't focus on the above at all; I assume familiarity with such matters and a general "Ok, now what to do?" attitude.

With that in mind, I'll discuss simple high-level pieces of advice that are likely to lead to better code on modern computing architectures. There is no guarantee, but these are good rules of thumb to keep in mind for efficiently exploring a large optimization space.

Things I shouldn't even

As mentioned, many of us are familiar with the classic advice regarding optimization. Nevertheless, a recap of a few "advanced basics" is useful for setting the stage properly.

Today's CPUs are complex in a whole different way than CPUs were complex a few decades ago. Those older CPUs were complex in a rather deterministic way: there was a clock; each operation took a fixed number of cycles; each memory access was zero-wait; and generally there was little environmental influence on the implacable ticking--no pipelining, no speculation, no cache, no register renaming, and few unmaskable interrupts if at all. That was a relatively simple model to optimize against. Today's CPUs, however, have long abandoned simplicity of their performance model in favor of achieving good performance statistically. Today's deep cache hierarchies, deep pipelines, speculative execution, and many amenities for detecting and exploiting instruction-level parallelism make for faster execution on average--at the cost of deterministic, reproducible performance and a simple mental model of the machine.

But no worries. All we need to remember is that intuition is an ineffective approach to writing efficient code. Everything should be validated by measurements; at the very best, intuition is a good guide in deciding approaches to try when optimizing something (and therefore pruning the search space). And the best intution to be ever had is "I should measure this." As Walter Bright once said, measuring gives you a leg up on experts who are too good to measure.

Aside from not measuring, there are a few common pitfalls to be avoided:

    Measuring the speed of debug builds. We've all done that, and people showing puzzling results may have done that too, so keep it in mind whenever looking at numbers.
    Setting up the stage such that the baseline and the benchmarked code work under different conditions. (Stereotypical example: the baseline runs first and changes the memory allocator state for the benchmarked code.)
    Including ancillary work in measurement. Typical noise is added by ancillary calls to the likes of malloc and printf, or dealing with clock primitives and performance counters. Try to eliminate such noise from measurements, or make sure it's present in equal amounts in the baseline code and the benchmarked code.
    Optimizing code for statistically rare cases. Making sort work faster for sorted arrays to the detriment of all other arrays is a bad idea (http://stackoverflow.com/questions/6567326/does-stdsort-check-if-a-vector-is-already-sorted).

A few good, but less known, things to do for fast code:

    Prefer static linking and position-dependent code (as opposed to PIC, position-independent code).
    Prefer 64-bit code and 32-bit data.
    Prefer array indexing to pointers (this one seems to reverse every ten years).
    Prefer regular memory access patterns.
    Minimize control flow.
    Avoid data dependencies.

This writeup won't get into these, but the video presentation has a few words about each.

Reduce strength

The first tip is simple: When implementing an algorithm, use operations of the minimum strength possible. The poster child of strength reduction is replacing x / 2 with x >> 1 in source code. In 1985, that was a good thing to do; nowadays, you're just making your compiler yawn.

The speed hierarchy of operations is:

    comparisons
    (u)int add, subtract, bitops, shift
    floating point add, sub (separate unit!)
    indexed array access (caveat: cache effects)
    (u)int32 mul
    FP mul
    FP division, remainder
    (u)int division, remainder

Interestingly, there are operations on integers that are in fact slower than operations on floating point numbers, with integral division, and remainder as a worst offender.

Let's spin some code with a realistic example. For example, consider we want to figure the number of digits a number has. This is a classic - just divide the number by 10 until it goes down to zero, counting the number of steps. Without further ado:

uint32_t digits10(uint64_t v) {

    uint32_t result = 0;

    do {

        ++result;

         v /= 10;

    } while (v);

     return result;

}

The dominant cost is the division. (Truth be told, it's a multiplication because many compilers transform all divisions by a constant into multiplications; see e.g. http://goo.gl/LhPeH.) To reduce the strength of that operation, let's make the observation that digit counting can be reframed as a cascade of comparisons against powers of 10. Following the adage "most numbers are small,"we expect to encounter small numbers more often. When the number gets too large we divide by a large amount and continue.

uint32_t digits10(uint64_t v) {

uint32_t result = 1;

for (;;) {

    if (v < 10) return result;

    if (v < 100) return result + 1;

    if (v < 1000) return result + 2;

    if (v < 10000) return result + 3;

    // Skip ahead by 4 orders of magnitude

    v /= 10000U;

    result += 4;

}

}

This looks like partial loop unrolling, but it's not; it's a reformulation of the algorithm to use comparison instead of division as the core operation. Let's take a look at the performance:

The horizontal axis is the number of digits and the vertical axis is relative performance of the new function against the old one. The new digits10 is 1.7x to 6.5 faster.

Minimize array writes

To be faster, code should reduce the number of array writes, and more generally, writes through pointers.

On modern machines with large register files and ample register renaming hardware, you can assume that most named individual variables (numbers, pointers) end up sitting in registers. Operating with registers is fast and plays into the strengths of the hardware setup. Even when data dependencies--a major enemy of instruction--level parallelism - come into play, CPUs have special hardware dedicated to managing various dependency patterns. Operating with registers (i.e. named variables) is betting on the house. Do it.

In contrast, array operations (and general indirect accesses) are less natural across the entire compiler-processor-cache hierarchy. Save for a few obvious patterns, array accesses are not registered. Also, whenever pointers are involved, the compiler must assume the pointers could point to global data, meaning any function call may change pointed-to data arbitrarily. And of array operations, array writes are the worst of the pack. Given that all traffic with memory is done at cache-line granularity, writing one word to memory is essentially a cache line read followed by a cache line write. So given that to a good extent array reads are inevitable anyway, this piece of advice boils down to "avoid array writes wherever possible."

Here's an example where an alternative approach to a classic algorithm saves a lot of array wites. Consider the classic "integer to string" interview question. Here's the stock solution:

uint32_t u64ToAsciiClassic(uint64_t value, char\* dst) {

    // Write backwards.

    auto start = dst;

    do {

        *dst++ = ’0’ + (value % 10);

        value /= 10;

    } while (value != 0);

    const uint32_t result = dst - start;

    // Reverse in place.

    for (dst--; dst > start; start++, dst--) {

        std::iter_swap(dst, start);

    }

    return result;

}

The loop produces the digits in increasing order, which is why we need a reverse at the end. Reversing does extra writes to the array so we better avoid it. To do so, we'd need to take a gambit: We make an additional "pass" through the number, which is extra work. But then that work will be rewarded with--you guessed-- ewer array writes because we get to write the digits last to first. To count digits, we conveniently avail ourselves of digits10, which we just carefully optimized.

uint32_t uint64ToAscii(uint64_t v, char \*const buffer) {

    auto const result = digits10(v);

    uint32_t pos = result - 1;

    while (v >= 10) {

        auto const q = v / 10;

        auto const r = static_cast<uint32_t>(v % 10);</uint32_t>

        buffer[pos--] = ’0’ + r;

        v = q;

    }    assert(pos == 0); // Last digit is trivial to handle

    *buffer = static_cast<uint32_t>(v) + ’0’;</uint32_t>

    return result;

}

Results? To quote a classic: "not bad."

More computation and less array writes helps. Don't forget--computers are good at computation. The whole business of dealing with memory is more awkward.

One last pass

Let's make a final pass through uint64ToAscii from a different angle. One simple insight is that digits10 is not counting; it's search. We must look for a number between 1 and 20 whose magnitude grows logarithmically with the magnitude of the input. Let's take a look (P01, P02,..., are the respective powers of 10):

uint32_t digits10(uint64_t v) {

if (v < P01) return 1;

if (v < P02) return 2;

if (v < P03) return 3;

if (v < P12) {

    if (v < P08) {

      if (v < P06) {

        if (v < P04) return 4;

        return 5 + (v >= P05);

      }

      return 7 + (v >= P07);

    }

    if (v < P10) {

      return 9 + (v >= P09);

    }

    return 11 + (v >= P11);

}

return 12 + digits10(v / P12);

}

The search starts with a short gallop favoring small numbers, after which it goes into a hand-woven binary search. The second insight is that at best the conversion itself would proceed two digits at a time, as opposed to one. That cuts in half the number of expensive operations.

unsigned u64ToAsciiTable(uint64_t value, char\* dst) {

static const char digits[201] =

    "0001020304050607080910111213141516171819"

    "2021222324252627282930313233343536373839"

    "4041424344454647484950515253545556575859"

    "6061626364656667686970717273747576777879"

    "8081828384858687888990919293949596979899";

uint32_t const length = digits10(value);

uint32_t next = length - 1;

while (value >= 100) {

    auto const i = (value % 100) * 2;

    value /= 100;

    dst[next] = digits[i + 1];

    dst[next - 1] = digits[i];

    next -= 2;

}

// Handle last 1-2 digits

if (value < 10) {

    dst[next] = '0' + uint32_t(value);

} else {

    auto i = uint32_t(value) * 2;

    dst[next] = digits[i + 1];

    dst[next - 1] = digits[i];

}

return length;

}

The results are nothing to sneeze at! For comparison, the plot below shows the performance of both improved implementations, relative to the baseline. The best of the breed is the latest implementation, which hovers at an average of 4x over the baseline.

Summary

A quest to improving something should start by measuring it. It is surprising how often this near-tautology is ignored in optimizing software for speed. To accelerate code, try to reduce strength of operations--which may lead you to a whole 'nother algorithm. Also, be stingy with indirect writes (such as array writes)--of all memory operations, they are the most expensive.
