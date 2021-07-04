+++
title = "DRAFT: States of Computations"
date = 2021-07-03
+++

## Disclaimer

This is just my opinion on the matter.
I am still learning it myself (when does one ever stop?).
If you have any objection, comments, or corrections, please raise an issue in the the Github source for this page :).

## Introduction

In programming, we have to deal with a lot of complexities.
There some tools to help us narrow down the set of possible issues/states that we have to deal with.
Types is possibly the most reliable and most used static analysis tool.

## We Beging With Dynamic Types

Dynamic languages will "allow" us to write anything we like.
I say in quotes because this is actually not true.
It's more like letting you make silly mistakes and make you pay for it later.

I think dynamic languages is the perfect tool for writing small scripts.
However, the moment you want the program to span for more than 2 files or when you want to refactor/enhance the functionality; you will start having issues.

In my experience, what ended up happening is some sort of ad-hoc type-checking anyways.

First, you perform a manual check on the functions.
You do this by going through all the possible states of the program to convince yourself that the function does what you think it does.

Then, in languages like JavaScript you can do a type-guard to check that the values given to you are what you think it is.

```javascript
...
if (typeof value === "string") {
    // Okay...its a string
} else {
    // What the hell is this?
}
```

Another one is to just run the program or write a bunch of tests to simulate most situations.
This is very cumbersome.
Sometimes, you even need to asinine tests just to make sure.

## Enter Types

To me, type is just a way to constraint the possible states that a variable can take.
If I annotated a variable as a `number`, then I don't have to think about it being anything other than a `number`.
This alone removes a huge cognitive load from anyone attempting to understand the behavior of the program.

Additionally, types also provides you hint about the implementation of any given function.
For example, a function that takes 2 `number`s and returning a `number` will probably do some sort of calculations on them.
Given a function like,

```typescript
const HighestBidder = (bids: [String, number][]) -> [String, number] => {...}
```

I can already expect what the function does.
If I want to be extra sure and really understand the implementation, the function name and the types will guide me through it.

However, types alone is not powerful enough to constraint the possible states and especially unique/bad ones.

## Function + Values = Consequence

Eventhough we have narrowed down a variable to just one type, some types can take on many different values with varying meanings. For example, if we have a type `number` it includes all the possible 64-bit floating points.

Therefore, we can think of a type as having a set of values.
And within this set, the values are divided into what we consider as "normal values" and some "problematic values".

But, these values existing by itself isn't the problem.
I can declare any values I want, `nullptr`, `NaN`, `-Inf` or whatever and if it's just sitting there not interacting with anything, it's by definition is doing nothing except maybe take up stack space.

However, applying functions to values have consequences.

The problem arises when we interact with these values using functions.
When we write a function, we are attempting to express some idea of computation.
The arguments type indicate what possible values the function can take and the result type indicate what possible values it will spit out.

Let's consider an addition function,

```typescript
const addition = (a: number, b: number): number => {
  return a + b;
};
```

But we have a problem here.
We are interacting with the whole set of possible values of `number`.
And some of them are not as nice to work as we have discovered.
What does `NaN + 3` means? What about `3 + -Inf`?
All of these are values that we _really_ don't care.

I mean sure, someone will come up and say they know every possible interactions by hand.
But it's still silly to worry about that every single time I want to do anything meaningful.
I am just trying to write an addition function here!

One easy way to go around this is to,

```typescript
const addition = (a: number, b: number): number | undefined => {
  if (a === NaN || a === Infinity || a === -Infinity /* and the rest */) {
    return undefined;
  } else {
    return a + b;
  }
};
```

At this point, you are pretty happy about the safety of this function.
You are sure that any time I call this function, if the result is _not_ undefined, we are confident that we are performing what we consider as "addition".

But then, a new requirement comes in and we need to implement a substraction function.
Fine, we can just copy and paste the implementation before and replace `+` with `-`.

```typescript
const substraction = (a: number, b: number): number | undefined => {
  if (a === NaN || a === Infinity || a === -Infinity /* and the rest */) {
    return undefined;
  } else {
    return a - b;
  }
};
```

Then multiple new requirement comes in, multiplication, division, factorial...
We will need to do this _every_ single time.

Surely there's some way to abstract/pull out these common checks into a class.

## Don't Repeat Yourself

Let's digress a bit and talk about function that accepts pointers as its argument.
A pointer can take on many values, so the function itself has to deal with the states.
From the function's point of view, the pointer could take on any values so it has to check if its `NULL` or not.
This is bad because:

1. We need to always do it.
2. We need to always do it right.
3. We need to pinky promise that we will do it all the time.

It is simply nigh impossible to know when/where any given pointers are valid throughout its existence.
From my experience, what ended up happening is that people create macros that will check for null pointers and panic otherwise.
This macros would then be plastered around everywhere at the beginning of every function that uses pointers.
Some of them are manually removed if the author is convinced enough that its not needed.

Can we do better? Aren't we taugh to pull out common abstraction into a function and reuse that instead?

## Hide Behind the Container

It turns that there is a way to deal with all this repetitiveness.
The strategy is that we hide the values behind a container and the only way you can interact with the contained value is by passing it a function.
Let's call it a `MaybeNumber`.

```typescript
class MaybeNumber {
  value: number;
  constructor(v: number) {
    this.value = v;
  }
  use(f: (t: number) => MaybeNumber): MaybeNumber {
    if (
      this.value === NaN ||
      this.value === Infinity ||
      this.value === -Infinity /* and the rest */
    ) {
      return undefined;
    } else {
      return f(this.value);
    }
  }
}
```

Let's go through the class slowly.
First, we note that the class contains 1 member variable, `value` which contains the `number` that we want to hide.
Then we have a simply constructor to create this container from a pure `number`.
Lastly, we have the `use` function that takes a `number` and returns the `MaybeNumber`.
You might be thinking, why does it return a `MaybeNumber` and not a I`number`?

This is a deliberate choice because we want to force the user of this value to always deal with this class and it enables nice composition ala `Promise`s.

First, lets deal with the fact that the signature requires us to return a `MaybeNumber`.
Does this mean that we need to reimplement all the functions that didn't use `MaybeNumber` into one?
Fear not, for we can lift these functions.

We can simply "lift" any given function using the pure function.
`lift` takes any function from `T -> number` into `T -> MaybeNumber`

```typescript
const lift =
  <T>(f: (a: T) => number): ((a: T) => MaybeNumber) =>
  (a: T) =>
    pure(f(a));
```

And so if we have functions like,

```typescript
const times2 = (v: number) => v * 2;
const adds2 = (v: number) => v + 2;
```

We can simply lifts them and use them like so,

```typescript
const times2M = lift(times2);
const adds2M = lift(adds2);

const b = pure(10);
const b2 = b.use(times2M);
const b2M = b2.use(times2M).use(adds2M).use(times2M).use(adds2M);
```

## Enter Monads

In my (humble) opinion, monads is just a way to express computations as types.
Computations produces result and instead of actually using the result, we just provide a function `f` to the type that performs the computation itself.

A monad is not any specific type, it is more like an instance.
In Haskell, `Monad` is a class defined as,

```haskell
class  Monad m  where
    -- The () indicates that this is an infix operator, so it closely resembles a class having a method.
    (>>=)  :: m a -> (a -> m b) -> m b
    return :: a -> m a
```

TypeScript cannot express this concept but let's pretend we have one that can.
In this hypothetical TypeScript, it could be written like this,

```typescript
export interface Monad<T> {
  // also called pure
  static return(t: T): Monad<T>;
  // The monad's >== function is also called bind
  bind(f: (t: T) => Monad<R>): Monad<R>;
}
```

And any class `M<T>` that implements `Monad<T>` (satisfying the monadic laws which we will not cover here) is a monad.
What is so powerful about this?
Well, it enables you to abstract one computation from another.

Let's look at some example.

### Maybe Monad

The maybe monad is used to represent a "computation" or "behavior" where a value may or may not exist.
Let's implement it in our imaginary TypeScript,

```typescript
// An enum to express existence of a value

type Option<T> =
  | {
      kind: "Some";
      value: T;
    }
  | {
      kind: "Nothing";
    };

// Helper functions

const createSome = <T>(t: T) => {
    kind : "Some",
    value : t
}

const createNone = <T>() => {
    kind : "Nothing",
}

class Maybe<Option<T>> implements Monad<Option<T>> {
    t : Option<T>
    static return(t: Option<T>) => new Maybe(t)
    bind(f: (t: T) => Maybe<Option<R>>): Maybe<Option<R>> {
        if (this.t.kind === "Nothing") {
            return createNone();
        } else {
            return f(this.t.value);
        }
    }
}
```

And using it looks like,

```typescript
// Here we implement the behavior that division by 0 is bad.
const safeAddition = (a: PositiveInteger, b: PositiveInteger) => {
  if (MAX_POSITIVE_INT - b > a) {
      // Overflow, returns none
      return Maybe::return(createNone());
  } else {
      // Addition does not overflow
      return Maybe::return(createSome(a / b));
  }
}
```

```typescript
// Here we implement a funct
const multiplication = (
  a: Maybe<Option<T>>,
  b: Maybe<Option<T>>
): Maybe<Option<T>> => {
  return a.bind((l) =>
    b.bind((r) => (l === 1 ?
      r : r === 1 ? l : safeAddition(l, l).bind((v) =>
        multiplication(
          Maybe::return(createSome(v)),
          Maybe::return(createSome(r - 1)))))
    ));
};
```

I am going to be honest, it doesn't look as great.
This is mostly because you need to jump through lot of syntax to do anything meaningful.
This is why Haskell does away with almost all syntax to function application (the only thing that matters really is the position).
This makes Haskell's implementation of this concept a lot more compact.

One thing to notice is that we didn't have to perform any check on the behavior that "division by 0 is bad" anywhere in `multiplication`.
The error handling is done automatically and we only concern ourselves with the details to implement multiplication.

### Implement allCombinations

## List Monad

## State Monad
