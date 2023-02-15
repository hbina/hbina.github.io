---
title: "The Humble Programmer"
date: 2023-02-15
author: "Hanif Bin Ariffin"
draft: false
---

# A Retrospective on The Humble Programmer by Edsger W. Dijkstra

> The article is freely available here: https://dl.acm.org/doi/10.1145/355604.361591

Crazy how much foresight he had 50 years ago.

> The increased power of the hardware, together with the perhaps even more dramatic increase in its reliability, made solutions feasible that the programmer had not dared to dream about a few years before. And now, a few years later, he had to dream about them and, even worse, he had to transform such dreams into reality!

This paragraph describes why programming, or something like it, will always exists. The more powerful our tools become, the more ambitious we will be. So no amount of AI will fix that human condition. There's also a similar observation in economics where the more efficient something is, the more widespread its use. For example, when electricity was hard to produce, people only dreamed of using it to produce light. But now that its abundant, there's desire and ideas to turn everything digital.

> It would be absolutely unfair to blame them for shortcomings that only became apparent after a decade or so of extensive usage: groups with a successful look-ahead of ten years are quite rare! In retrospect we must rate FORTRAN as a successful coding technique, but with very few effective aids to conception, aids which are now so urgently needed that time has come to consider it out of date. The sooner we can forget that FORTRAN has ever existed, the better, for as a vehicle of thought it is no longer adequate: it wastes our brainpower, is too risky and therefore too expensive to use.

Feels like he's talking about legacy languages here _cough_ C++ _cough_.

> The vision is that, well before the seventies have run to completion, we shall be able to design and implement the kind of systems that are now straining our programming ability, at the expense of only a few percent in man-years of what they cost us now, and that besides that, these systems will be virtually free of bugs. [...] Those who want really reliable software will discover that they must find means of avoiding the majority of bugs to start with, and as a result the programming process will become cheaper. If you want more effective programmers, you will discover that they should not waste their time debugging, they should not introduce the bugs to start with.

Here he's either underestimating how hard programming is or overestimating the capability of the average programmer. It seems like he thought that the programming industry would hone and update their tools to eventually arrive at something "perfect". But even now, we still don't know what that is. No one really knows how UI should be done, how async should work, etc etc.

He also thought that software's acceleration will match the hardware's acceleration. But this is simply not true, CPUs have gotten a million times faster but is our tools getting as fast? There's still some delay when I type on a text editor. Is our text editor doing more things today compared to text editor of ye old? Yes, but surely not that bad? For example, take the recent Windows Terminal fiasco (https://github.com/microsoft/terminal/issues/10362). TLDR: Multiple billions dollar company product is shit, someone complained, MS says hard to fix only for said person to implement a fix over a weekend.

> I now suggest that we confine ourselves to the design and implementation of intellectually manageable programs. If someone fears that this restriction is so severe that we cannot live with it, I can reassure him: the class of intellectually manageable programs is still sufficiently rich to contain many very realistic programs for any problem capable of algorithmic solution.

Here he's proposing that we use smaller and more confined language with less foot guns. Something like Rust (does not have UB) or any language with a GC really. In the same paragraph, he's also talking about something like "correct by construction" which is an interesting concept like https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/. He's also predicting the use of static analysis and linters like clangd and ESLint.

> [...] a specific phenomenon occurs that even has a well-established name: it is called “the one-liners”. It takes one of two different forms: one programmer places a one-line program on the desk of another and either he proudly tells what it does and adds the question “Can you code this in less symbols?” —as if this were of any conceptual relevance!— or he just asks “Guess what it does!”.

Feeling a bit attacked, but he's both right and wrong here. There's some utility in one liner, especially when it is used with familiar and regular tools. For example using filter in JS is much more concise and understandable than using raw loops with an if-else inside (IMO).
