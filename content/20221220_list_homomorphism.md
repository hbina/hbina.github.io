---
title: "Some Examples of List Homomorphism (draft)"
date: 2022-12-20
author: "Hanif Bin Ariffin"
draft: false
---

## Introduction

List homomorphism is a powerful concept that allows us to turn a computation into an embarrasingly parallel problem.

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
