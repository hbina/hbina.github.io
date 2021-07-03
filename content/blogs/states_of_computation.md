+++
title = "DRAFT: States of Computations"
date = 2021-07-03
+++

## Disclaimer

This is just my opinion on the matter.
I am still learning the matter myself (when does one ever stop?).
If you have any objection, comments, or corrections, please raise an issue in the the Github source for this page :).

## Introduction

I have been trying to wrap my head around monads for over 6 months.
What was once a mere meme to me,

```text
A monad is just a monoid in the category of endofunctor
```

Now becomes an obsession as I try to understand it.
In this brief article, I will try express what I think monad is beginning with the problem with dynamic languages.

## Dynamic Languages Are Too Chaotic

In my opinion, it is frankly insane why anyone would willingly program/maintain a library/application written in dynamic languages.
I just can't do it.

I mean it's perfectly fine for small scripts.
However, if the program spans for more than 2 programs I am already confused.
I will have to double-check that every thing is indeed the way I think it is and so-on.

In my experience, what ended up happening is some sort of ad-hoc type-checking anyways.

First, you perform a manual check on the functions.
Going through all the possible paths to convince yourself that the function does what you think it does.

Then, in languages like JavaScript you can do a type-guard to check that the values given to you are what you think it is.

```javascript
...
if (typeof value === "string") {
    // Okay...its a string
} else {
    // What the hell is it?
}
```

Another trick is to just running the damn thing and see what happens.
Which is probably the last thing you want to do.

## Enter Types

To me, type is just a way to constraint the possible values that...a value can take.
If I annotated a type as a `Number`, then I don't have to think about it being anything other than a `Number`.
This alone removes a huge load from my brain and one of the reason why types are just so invaluable to me.

Types also tell a story.
A function that takes 2 `Number`s and returning a `Number` will probably do some sort of calculations on them.
Functions like,

```typescript
const HighestBidder = (bids: [String, Number][]) -> [String, Number] => {...}
```

I can already expect what the function does.
If I want to be extra sure and really understand the implementation, the function name and the types will guide me through it.

However, types alone is not powerful enough to solve many programming challenges.

## Function + Values = Consequence

Eventhough we have narrowed down the types to just one type, some types can take on so many different values with varying meanings. For example, if we have a type `i32`, it can take `2^32-1` values.

First, we are limited by physical reality.
I think its a mistake to think about numbers in programming the same way we think about numbers in abstract.
To me, they are 2 very different things and conflating the 2 will prove to be annoying.
What is `1/3`? Should currencies by represented as floats? What about accuracy? What about overflows? Underflows? Sign integers? `NaN`? And so on and so forth which are stuffs that we don't normally think about.

We can think about a type as having a set of values.
And within this set, the values are divided into we consider as "normal values" and some "problematic values".

But, these values existing by itself isn't the problem.
I can declare any value I want, `nullptr`, `NaN`, `-Inf` or whatever and if it's just sitting there not interacting with anything, it's by definition is doing nothing except maybe take up stack space.

Applying functions to values have consequences.

The problem arises when we interact with these values using functions.
When we write a function, we are attempting to express some idea of computation.
The arguments type indicate what possible values the function can take and the result type indicate what possible values it will spit out.

Let's a function that dereference a pointer.
The simplest one is probably,

```c
int dereference(int * p) {
    return *p;
}
```

But we have a problem here.
We are interacting with the whole set of possible values of `int *` which includes the "bad values" that we talked about.
One of them is `NULL`, so we need to check for that.

```c
int dereference(int * p) {
    if (p != NULL) {
        return *p;
    } else {
        // what now?
    }
}
```

Hmmm, what should we do here?
Just from the function signature alone, one could assume that the function will return _something_ anyway, something like `0`?
Who knows.

At this point, the caller of this function have to go through the implementation to know exactly how it behaves.
The problem here is that the function fails to express failure using types.

In modern languages, the function would probably be written this way instead,

```c++
Option<int> dereference(int * p) {
    if (p != NULL) {
        return Some(*p);
    } else {
        return None;
    }
}
```

Here, `Option<int>` is an enum that can either be `Some(int)` to indicate that the operation was successful or `None` to indicate failure.

This indicates to the caller that this function may fail.
Even this is not sufficient to cover other bad pointer values. Could it be a dangling pointer or a freed pointer or was it actually a pointer to an array of `int`s instead?

Assuming that null pointers is the only problem/challenge that we have with pointers, we still have the problem of repeating ourself.

## Don't Repeat Yourself

Because the function accepts a pointer that can take any possible values, the function itself has to deal with the states.
From the function's point of view, the pointer could take on any values so it has to check if its `NULL` or not.
This is bad because:

1. We need to always do it.
2. We need to always do it right.
3. Goddamit, do we really have to do this all the time?

It is simply nigh impossible to know when/where any given pointers are valid throughout its existence.
From my experience, what ended up happening is that people create macros that will check for null pointers and panic otherwise.
This macros would then be plastered around everywhere at the beginning of every function implementations that uses pointers.
Some of them are manually removed if the author is convinced enough that its not needed.

Can we do better? Aren't we taugh to pull out common abstraction into a function and reuse that instead?

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

## State Monad
