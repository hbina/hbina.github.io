---
title: "Intuitions for List Homomorphism"
date: 2022-12-20
author: "Hanif Bin Ariffin"
draft: false
---

## Introduction

List homomorphism is a powerful concept that enables us to parallelize computation.
Basically need to satisfy this constraint
f(list_one + list_two) === homo_list(f(list_one), f(list_two));
The function 'f' is a list homomorphism if there exists a function `homo_list` that satisfy the above equation

## Code

```typescript
type IntermediateState = {
  mss: number; the actual MSS of a given array
  mss_from_left: number; the MSS if we force subarray to include the first element
  mss_from_right: number; the MSS if we force the subarray to include the last element
  total_sum: number; simply the total sum of the array
};

Transforming a single element into intermediate state is trivial
function f(input: number): IntermediateState {
  return {
    mss: input,
    mss_from_left: input,
    mss_from_right: input,
    total_sum: input,
  };
}

function dot(
  lhs: IntermediateState,
  rhs: IntermediateState
): IntermediateState {
  return {
    mss: Math.max(lhs.mss, rhs.mss, lhs.mss_from_right + rhs.mss_from_left),
    mss_from_left: Math.max(
      lhs.mss_from_left,
      lhs.total_sum + rhs.mss_from_left
    ),
    mss_from_right: Math.max(
      rhs.mss_from_right,
      lhs.mss_from_right + rhs.total_sum
    ),
    total_sum: lhs.total_sum + rhs.total_sum,
  };
}

function h(input: Array<number>): IntermediateState {
  if (input.length === 0) {
    return {
      mss: 0,
      mss_from_left: 0,
      mss_from_right: 0,
      total_sum: 0,
    };
  } else {
    return input.map((x) => f(x)).reduce((acc, curr) => dot(acc, curr));
  }
}
```

# Introduction of Jargons

A list homomorphism is a function `h` on lists for which there exists an associative binary operator `⊙` such that
`h (x ++ y) = h x ⊙ h y`
Let's untangle some jargons here:

1. Binary operator means that the function accepts 2 arguments. For example, addition is a binary operator.
2. Associative means that the function the order of the functions don't matter. For example, addition is also associative (`1 + 2` is equal to `2 + 1`).
3. `++` is list concatenation, for example,

```typescript
const x = [1, 2];
const y = [3, 4];
const z = x.concat(y);
```

Above can be written as `x ++ y`.

# Explanation

Before we begin dechipering this function equation, lets make it more intuitive.
To do this,we will replace `h` and `⊙` which more descriptive names.
We will also rewrite the function in imperative form which will be more familiar to a typical programmer.
Lets replace `h` with `homo` and `⊙` with `connect`.
Also, "list homomorphism" is an adjective of a function like cool, interesting or complicated.
Instead of calling it "list homomorphism" like a nerd, we will simply call it cool.
So instead of figuring out what makes a function a "list homomorphism", we will study what makes a function cool (which is cooler).
With this, let reword the original definition a little bit to make it clearer (at least for me):

A function `homo` is cool if there exists a `connect` function such that `homo(x.concat(y))` is equivalent to `connect(homo(x),homo(x))`

Notice that I haven't bothered to define what the function `homo` returns.
It can be anything as long as the function makes sense i.e. that it passes the type check.

Now let's explore the concept using TypeScript.
Rewriting the above statement that "`homo (x ++ y)` is equivalent to `h x ⊙ h y`" will get us something like:

```typescript
type List = Array<number>;

// What `homo(x.concat(y))` would look like in TypeScript
function left_side<R>(x: List, y: List): R {
  return homo(x.concat(y)); // For some function homo
}

// What `connect(homo(x),homo(x))` would look like in TypeScript
function right_side<R>(x: List, y: List): R {
  const homox = homo(x);
  const homoy = homo(y);
  return connect(homox, homoy); // For some function homo and connect
}

function the_interface<R>(x: List, y: List): R {
  const left_value = left_side(x, y);
  const right_value = right_side(x, y);
  assert(left_value == right_value); // Using left_side or right_side shouldn't matter because they are both implements the same thing
  return left_value;
}
```

So they are equivalent...this is cool..why?
It is cool we calculated `homox` and `homoy` independently.
This means that it is easy to put both of these on seperate threads to leverage parallelism!

What is the simplest cool function homo?
Lets try to find an example to build our intuition.
Well, it turns out the identity function is very cool!!
function identity(x: List): List {
Identity function takes an argument and returns it immediately
return x
}

So, if the function `identity` is cool, then what is its `connect`?
Let's think about the left hand side first,
Replacing `homo` with the identity function we get...

identity(x.concat(y));

But the `identity` of `x.concat(y)` is jut `x.concat(y)`!

x.concat(y);

Now what about the right hand side?
By replacing `homo` with `identity`, we get:

connect(identity(x), identity(y));

Applying the similar elimination for `identity` we will get,

connect(x, y)

TODO: Show examples?

Hm, so how do we make `connect(x,y)` equals to `x.concat(y)`?
Well, `connect` must then be concat function too!!
So, we now know that the identity function is indeed cool (or it is a list homomorphism) where its `connect` function is a list concatenation!

Okay, to be honest, identity function is kinda useless isn't it?
What's an even more interesting function to test?
What about summation?
Lets see if we can show that summation is cool by finding what its possible `connect` function is.

First, lets write a simple summation function
function summation(list: List): number {
let result = 0;
for (const l of list) {
result += l
}
return result;
}

What `summation(x.concat(y))` would look like in TypeScript
function left_summation(x: List, y: List): number {
return summation(x.concat(y))
}

What `connect(summation(x),summation(x))` would look like in TypeScript
function right_summation(x: List, y: List): number {
const homox = summation(x)
const homoy = summation(y)
return connect(homox, homoy) For some function connect
}

Well, if `homox` calculates the summation of `x` and `homoy` calculated the summation of `y` then connect is simply addition!

Lets try a more complicated example: calculating the maximum subarray sum (MSS).

/Problem Statement

I will try to provide some examples here, but you can also just look at the Wikipedia page [here](https://en.wikipedia.org/wiki/Maximum_subarray_problem).
Granted, if you read the wikipedia article, there's an actually a very simple O(n) solution to this.
But lets consider a hypothetical situation where we have a very large dataset spanning gigabytes of data.
Look at the implementation of the O(n) solution here:

```
function max_subarray(numbers: Array<number>): number {
    let best_sum = 0;
    let current_sum = 0;
    for (const n of numbers) {
        current_sum = Math.max(0, current_sum + n)
        best_sum = Math.max(best_sum, current_sum)
    }
    return best_sum;
}
```

Notice how this iteration is stateful?
The next iteration depends on the result of the previous.
