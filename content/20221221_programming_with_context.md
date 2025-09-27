---
title: "Programming with Context (draft)"
date: 2022-12-21
author: "Hanif Bin Ariffin"
draft: false
---

## Disclaimer

I have no formal traning in functional programming so if I have any mistakes here please feel free to correct and educate me!

## Introduction

In programming, we have to deal with a lot of complexities.
In my experience, there are 2 different kinds of complexities:

1. Business complexity.
   This is the complexity of the requirement that have been tasked to us developers. For example, a requirement that says "User can go to our website to browse our catalogue".
   This is inherent.

2. Programming complexity.
   This is the complexity that comes from the implementation of said requirements.
   For example, a requirement to develop a website makes no mention of HTTP but as implementators we have to be aware of it.

One thing about complexity is that they will always exist.
We may be able to reduce the latter kind of complexity (which is why certain abstraction fails and some do not).
However, the former kind of complexity will always be there --- it literally has to do that thing that is required of it.

I think one of the biggest cause of complexity is states.
The problem is that our monkey brain is extremely bad at managing them (Or maybe it's just me).
There some tools to help us narrow down the set of possible issues/states that we have to deal with.
Types is one such tool and it is possibly the most popular and reliable static analysis tool.

The only thing that we can do is to abstract it away the complexity.
Then we just pray that the abstraction doesn't break in a really awful manner down the line.
At the end of the day, _someone_ gotta pay for the complexity.

## We Begin with Dynamic Types

Dynamic languages will "allow" us to make our computers do "anything we like".
I say in quotes because this is actually not true.
The reason is that we most definitely do not want our computers to do "anything we like".
It is very hard for us human to keep a consistent flow of thought.
So if a machine is willing to do anything I tell it to, well, most of time, its going to be doing the wrong thing.
It's very hard for us human to be precise with our desires and even worse to communicate it.
We make a lot of assumptions that things work the way we think it does, not the way it actually does work.

My gripe with untyped languge is that it allows you to do even the stupidest mistake.
It causes the set of possible programs (mostly wrong programs) to be extremely large.
For example, consider the following JavaScript code,

```javascript
let a = "a";
let b = false;
let c = a + b;
```

Does this make any sense?
This piece of code is most definitely meaningless.

Another example is `C`'s [printf](https://en.cppreference.com/w/c/io/fprintf).

```c
const char *pointer = "hello world";
printf("%%p => %p\n", pointer);
printf("%%s => %s\n", pointer);
printf("%%d => %d\n", pointer);
```

Compiling and executing the binary gets us,

```bash
hbina@akarin:~/git/hbina.github.io$ clang ./static/programming_with_context/example_printf_program.c && ./a.out
./static/programming_with_context/example_printf_program.c:8:27: warning: format specifies type 'int' but the argument has type 'const char *' [-Wformat]
    printf("%%d => %d\n", pointer);
                   ~~     ^~~~~~~
                   %s
1 warning generated.
%p => 0x402004
%s => hello world
%d => 4202500
```

The third usage of `printf` is most definitely wrong and meaningless.
Fortunately `clang` does warn us about this.
Regardless, it still pains me that a computer is allowing me to make such mistakes.
The compiler is telling me "This is literally nonsense, it will not do what you think it does" and yet it still happily compiles it for me.
Why?
`printf` is mostly stateless, so it's "not hard" to get it right by looking at individual uses.
However, imagine dealing with `C`'s [tagged union](https://en.cppreference.com/w/c/language/union).

I think dynamic languages is the perfect tool for writing small scripts.
However, the moment you want the program to span for more than 2 files or when you want to refactor/enhance the functionality; you will start having issues or implicit conversions?

In my experience, what ended up happening is some sort of ad-hoc type-checking anyways.

1. Perform a manual check/verification.
   You do this by going through all the possible states of the program to convince yourself that the function does what you think it does.
   Needless to say this is insanely hard to do.
   Most of the time, its just _assumed_ that something works and hope for the best.
   When something does go bad, _then_ we go take a look and fix it.
   This is obviously not ideal.

2. Another way you can narrow down the states (and to verify your assumptions) is to perform some kind of check.
   For example, we can do a type-guard IN JavaScript.
   This way we check that any given value is what you think it is.

```javascript
if (typeof value === "string") {
  // Great! It's a string
} else {
  // Do something else...
}
```

3. Write lots of test cases.
   Loads of them.

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

This is where the second kind of complexity that I mentioned before comes sneaking in.
Most requirements most definitely do not include a specification for how to deal with `NaN` or floating point errors.
Yet it is something that we have to consider.

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
We are sure that any time we call this function, the result is a _number_.
We are confident that the computation we are performing here are what we consider as "addition".

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
Even worse than that, we can clearly see that they are all awfully similar.
Notice that the only thing that "matters" here is the binary operator.
Just that 1 character.

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
If you have ever taken a class in computer science or programming, you will most definitely have come across classes (or containers).
The strategy is that we hide the values behind a container and the only way you can interact with the contained value is by passing it a function.
Let's call this a `MaybeNumber`.

```typescript
class MaybeNumber {
  value: number;
  constructor(v: number) {
    this.value = v;
  }
  bind(f: (t: number) => MaybeNumber): MaybeNumber {
    if (
      this.value === NaN ||
      this.value === Infinity ||
      this.value === -Infinity /* and the rest */
    ) {
      return this;
    } else {
      return f(this.value);
    }
  }
}
```

Let's go through the class slowly.
First, we note that the class contains 1 member variable, `value` which contains the `number` that we want to hide.
Then we have a simply constructor to create this container from a pure `number`.
Lastly, we have the `bind` function that takes a `number` and returns the `MaybeNumber`.
You might be thinking, why does it return a `MaybeNumber` and not a I`number`?

This is a deliberate choice because we want to force the user of this value to always deal with this class and it enables nice composition ala `Promise`s.

First, lets deal with the fact that the signature requires us to return a `MaybeNumber`.
Does this mean that we need to reimplement all the functions that didn't use `MaybeNumber` into one?
Fear not, for we can lift these functions.

We can simply "lift" any given function using the unit function.
`lift` takes any function from `T -> number` into `T -> MaybeNumber`

```typescript
type BindArg = (a: number) => number;
type BindResult = (a: number) => MaybeNumber;
function lift(f: BindArg): BindResult {
  return (a) => unit(f(a));
}
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

const b = unit(10);
const b2 = b.bind(times2M);
const b2M = b2.bind(times2M).bind(adds2M).bind(times2M).bind(adds2M);
```

## Enter Monads

In my (humble) opinion, monads is just a way to express computations as types.
Computations produces result and instead of actually using the result, we just provide a function `f` to the type that performs the computation itself.

A monad is not any specific type, it is more like an instance.
In `Haskell`, `Monad` is a typeclass defined as,

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
  // also called unit
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
