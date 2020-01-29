#lang scribble/manual

@(require scribble/bnf
          (only-in racket/draw read-bitmap)
          (for-label
           rosette/lib/value-browser
           (only-in racket/gui snip%)
           rosette/base/form/define
           rosette/base/core/term
           (only-in rosette/base/base bv bitvector ~>)
           racket)
          scribble/core scribble/html-properties racket/runtime-path)

@(define-runtime-path root ".")

@title[#:tag "sec:utility-libs"]{Utility Libraries}

The following utility libraries facilitate the development of solver-aided programs.

@section{Value Browser Library}

@defmodule[rosette/lib/value-browser]

Rosette programs often generate complex @seclink["sec:value-reflection"]{symbolic values} that can be difficult to read and debug. One common problem is that the printer truncates their representation when it exceeds the threshold set by @racket[(error-print-width)]. This library provides an interactive @deftech{value browser}  to help programmers navigate and read complex symbolic values.

@defproc[(render-value/snip [val any/c] [#:handler handler (-> any/c (-> any/c (is-a?/c snip%)) #,(tech "layout")) (λ (value rec) #f)]) (is-a?/c snip%)]{
Constructs a @racket[snip%] object that displays a @tech{value browser}. In DrRacket, either evaluating the snip object at the top-level or calling @racket[print] on the snip object will display the value browser in the REPL.

The value browser supports displaying and navigating values of @seclink["ch:built-in-datatypes"]{lifted datatypes}. Values of other types (e.g., @racket[string] or @racket[hash]) are displayed as leaves in the navigation tree, labeled with the kind @code{other}. The optional argument @racket[handler] can be supplied to customize the display of @code{other} values and recover the ability to navigate their structure. See @tech{layout} and the examples below for more details.
}

@defproc[(render-value/window [val any/c] [#:handler handler (-> any/c (-> any/c (is-a?/c snip%)) #,(tech "layout")) (λ (value rec) #f)]) (is-a?/c snip%)]{
Similar to @racket[render-value/snip], but displays the snip object in a new window frame instead of the REPL. This is useful when executing programs from the command line.
}

@subsection{Layout}

A @deftech{layout} is an embedded DSL describing the tabular layout to display a value of an unlifted datatype in the value browser. It has the following grammar: 

@BNF[(list @nonterm{layout}
           @BNF-alt[@litchar{#f}
                    @elem{a @racket[list] of @nonterm{row}s}])
     (list @nonterm{row}
           @BNF-alt[@litchar{'#:gap}
                    @elem{a @racket[list] of @nonterm{col}s}])
     (list @nonterm{col}
           @BNF-alt[
             @elem{a @racket[snip%]}
             @nonterm{string}
             @BNF-seq[@litchar{'(emph} @nonterm{string} @litchar{)}]])
     (list @nonterm{string}
           @elem{a @racket[string]})]

Here, @racket[#f] means the value is atomic (and will be categorized under the kind @code{other}),  @racket['#:gap] means a vertical gap, and @racket[emph] means emphasis.

@subsection{Examples}

The value browser helps navigate values of lifted datatypes as shown below.

@(define (get-image name)
   (call-with-input-file (build-path root name)
                         (lambda (in) (read-bitmap in 'png #:backing-scale 2))))

@racketblock[
#, @elem{>} (define-symbolic n integer?)
#, @elem{>} (render-value/snip (list 1
                                     1.2
                                     #t
                                     n
                                     (bv 1 (bitvector 2))
                                     +))
(code:comment "After expanding the snip:")
#,(get-image "browser-atomic.png")
#, @elem{>} (define-symbolic f (~> integer? integer?))
#, @elem{>} (render-value/snip (list (+ n 1)
                                     (if (= n 0) 1 2)
                                     (f 1)))
#,(get-image "browser-expr.png")
#, @elem{>} (struct foo [a b])
#, @elem{>} (render-value/snip (list (list 1 2)
                                     (foo 1 2)
                                     (vector 1 2)
                                     (box 1)
                                     (if (= n 1) 2 "a")))
#,(get-image "browser-compound.png")
]

But when we try to display an unlifted value like a @racket[hash] or a @racket[set], the browser categorizes it with the kind @code{other}, with navigation disabled.

@racketblock[
#, @elem{>} (render-value/snip (list (hash 1 2 3 4)
                                     (set 1 2 3)))
#,(get-image "browser-unlifted.png")
]

To allow hash navigation, supply a @racket[handler] that
returns a desired @tech{layout} when a hash is passed in (as the first argument).
For instance, we might want @racket[(hash a b c d)] to have the following layout:

@racketblock[
`([(emph "Kind: ") "hash"]
  #:gap
  [,snip-a]
  [,snip-b]
  #:gap
  [,snip-c]
  [,snip-d])
]

In this layout, @racket[snip-a], @racket[snip-b], @racket[snip-c], and @racket[snip-d] can be
obtained by applying the recursive renderer to @racket[a], @racket[b], @racket[c],
and @racket[d] respectively.

Using the above layout, we enable hash navigation as follows:

@racketblock[
#, @elem{>} (render-value/snip (list (hash 1 2 3 4)
                                     (set 1 2 3))
                     #:handler (λ (value rec)
                                 (cond
                                   [(hash? value)
                                    (append*
                                     '([(emph "Kind: ") "hash"])
                                     (for/list ([(k v) (in-hash value)])
                                       `(#:gap
                                         [,(rec k)]
                                         [,(rec v)])))]
                                   [else #f])))
#,(get-image "browser-unlifted-corrected.png")
]

Note that you should use the recursive renderer (provided as the second argument) rather than calling @racket[render-value/snip] directly so that the correct handler is used when rendering sub-value (e.g., a hash of hashes).
