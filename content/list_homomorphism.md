---
title: "Some Examples of List Homomorphism (draft)"
date: 2022-12-20
author: "Hanif Bin Ariffin"
draft: false
---

## Introduction

List homomorphism is a powerful concept that allows us to turn certain computations into embarrassingly parallel problems. But what does that actually mean?

Imagine you have a big list of numbers and you want to find their sum. Normally, you'd go through them one by one:

```typescript
const sum = numbers.reduce((acc, x) => acc + x, 0);
```

But what if you could split the list into chunks, calculate the sum of each chunk separately (maybe on different CPU cores), and then combine those partial sums? That's the idea behind list homomorphism.

A list homomorphism is a function that can be "split up" and computed in parallel, then combined back together to get the same result as if you'd processed the whole list at once.

## What Makes a Function a List Homomorphism?

For a function to be a list homomorphism, it needs to satisfy this equation:

```
f(list1 + list2) = combine(f(list1), f(list2))
```

Where:
- `f` is our function
- `list1 + list2` means concatenating two lists
- `combine` is some way to merge the results

In simple terms: processing two lists separately and combining the results should give the same answer as processing them together.

## Example: Finding the Maximum

Let's say we want to find the maximum number in a list. Is this a list homomorphism?

```typescript
const max = (numbers: number[]): number => Math.max(...numbers);
```

Let's test: if we have `[1, 5, 3]` and `[2, 7, 4]`, then:
- `max([1, 5, 3, 2, 7, 4])` gives us `7`
- `max([1, 5, 3])` gives us `5`, `max([2, 7, 4])` gives us `7`
- `Math.max(5, 7)` gives us `7`

Yes! Finding the maximum is a list homomorphism because we can process parts of the list separately and then take the maximum of those results.

## Example: Maximum Subarray Sum

Here's a more complex example: finding the maximum sum of any contiguous subarray. This is a classic computer science problem.

## Code

```typescript
// Basically need to satisfy this constraint
// f(list_one + list_two) === homo_list(f(list_one), f(list_two));
// The function 'f' is a list homomorphism if there exists a function `homo_list` that satisfy the above equation

type IntermediateState = {
  mss: number; // the actual MSS of a given array
  mss_from_left: number; // the MSS if we force subarray to include the first element
  mss_from_right: number; // the MSS if we force the subarray to include the last element
  total_sum: number; // simply the total sum of the array
};

// Transforming a single element into intermediate state is trivial
const f = (input: number): IntermediateState => {
  return {
    mss: input,
    mss_from_left: input,
    mss_from_right: input,
    total_sum: input,
  };
};

const dot = (
  lhs: IntermediateState,
  rhs: IntermediateState
): IntermediateState => {
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
};

const h = (input: Array<number>): IntermediateState => {
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
};
```

## Breaking Down the Maximum Subarray Algorithm

The code above might look complex, but the idea is elegant. To make maximum subarray sum work as a list homomorphism, we need to track more than just the final answer.

The `IntermediateState` keeps track of four things:
1. **mss**: The maximum subarray sum we've found so far
2. **mss_from_left**: The maximum sum of any subarray that starts at the beginning
3. **mss_from_right**: The maximum sum of any subarray that ends at the last element  
4. **total_sum**: The sum of all elements

Why do we need all this information? Because when we combine two parts of a list, the maximum subarray might span across the boundary between them.

For example, if we have `[-1, 2, 3]` and `[4, -1]`:
- The left part has maximum subarray sum `5` (elements 2,3)
- The right part has maximum subarray sum `4` (just element 4)
- But the optimal subarray is actually `[2, 3, 4]` which spans both parts!

The `dot` function handles this by considering:
1. The best subarray entirely in the left part
2. The best subarray entirely in the right part  
3. The best subarray that spans across both parts (using `mss_from_right` + `mss_from_left`)

## Why This Matters

List homomorphisms are important because they let us:

1. **Parallelize computations**: Split work across multiple CPU cores
2. **Process streaming data**: Handle data as it arrives without storing everything
3. **Optimize algorithms**: Sometimes the homomorphic version is faster even on a single core

Many useful operations are list homomorphisms:
- Sum, product, maximum, minimum
- Counting elements that match a condition
- Checking if all/any elements satisfy a condition
- Finding the length of a list

## Testing Our Implementation

Let's verify our maximum subarray implementation works:

```typescript
// Test case: [-2, 1, -3, 4, -1, 2, 1, -5, 4]
// Expected maximum subarray: [4, -1, 2, 1] with sum = 6

const testArray = [-2, 1, -3, 4, -1, 2, 1, -5, 4];
const result = h(testArray);
console.log(result.mss); // Should output 6

// Test splitting and combining
const left = testArray.slice(0, 5);   // [-2, 1, -3, 4, -1]
const right = testArray.slice(5);    // [2, 1, -5, 4]

const leftResult = h(left);
const rightResult = h(right);
const combinedResult = dot(leftResult, rightResult);

console.log(combinedResult.mss); // Should also output 6
```

The beauty is that both approaches give the same answer, but the second approach could run the left and right parts on different processors simultaneously.

## The Bigger Picture

List homomorphisms show us that some problems that seem inherently sequential can actually be parallelized if we're clever about what information we track. This is a powerful technique for building efficient, scalable algorithms.

Next time you're processing a large dataset, ask yourself: "Is this operation a list homomorphism?" If so, you might be able to make it much faster by processing it in parallel chunks.
