#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         redex/reduction-semantics
         (prefix-in mk-d: "../mk/decomposition.rkt")
         (prefix-in mk-lang: "../mk/language.rkt")
         (prefix-in mk-z: "../mk/refocused.rkt")
         (prefix-in mk-zs: "../mk/refocused-spec.rkt")
         (prefix-in mk-s: "../mk/source.rkt")
         (prefix-in toy-d: "../toy/decomposition.rkt")
         (prefix-in toy-lang: "../toy/language.rkt")
         (prefix-in toy-z: "../toy/refocused.rkt")
         (prefix-in toy-zs: "../toy/refocused-spec.rkt")
         (prefix-in toy-s: "../toy/source.rkt"))

(provide grammar-litmus-tests)

(define-runtime-path source-schema-path "../source-schema.rkt")
(define-runtime-path toy-source-path "../toy/source.rkt")
(define-runtime-path mk-source-path "../mk/source.rkt")
(define-runtime-path decomposition-schema-path "../decomposition-schema.rkt")
(define-runtime-path refocused-schema-path "../refocused-schema.rkt")

(define (match-count matches)
  (if matches (length matches) 0))

;; These matchers deliberately bypass `decompose`.  The sum of their raw
;; matches therefore measures a property of the redex/context grammars, not a
;; choice made by judgment-clause or host-language order.
(define toy-boundary-factorizations
  (redex-match toy-d:pk-toy-decomposition-lang (in-hole BF BR)))
(define toy-local-fresh-factorizations
  (redex-match toy-d:pk-toy-decomposition-lang (in-hole LF LFR)))
(define toy-local-factorizations
  (redex-match toy-d:pk-toy-decomposition-lang (in-hole WF LR)))
(define toy-terminal-factorizations
  (redex-match toy-d:pk-toy-decomposition-lang (in-hole FF T)))

(define mk-boundary-factorizations
  (redex-match mk-d:pk-mk-decomposition-lang (in-hole BF BR)))
(define mk-local-fresh-factorizations
  (redex-match mk-d:pk-mk-decomposition-lang (in-hole LF LFR)))
(define mk-local-factorizations
  (redex-match mk-d:pk-mk-decomposition-lang (in-hole WF LR)))
(define mk-terminal-factorizations
  (redex-match mk-d:pk-mk-decomposition-lang (in-hole FF T)))

(define (factorization-count frontier
                             boundary-factorizations
                             local-fresh-factorizations
                             local-factorizations
                             terminal-factorizations)
  (+ (match-count (boundary-factorizations frontier))
     (match-count (local-fresh-factorizations frontier))
     (match-count (local-factorizations frontier))
     (match-count (terminal-factorizations frontier))))

(define-judgment-form
  toy-d:pk-toy-decomposition-lang
  #:contract (pop-frame/toy WF WF WFrame)
  #:mode (pop-frame/toy I O O)
  [---------------------------------------------------- "pop toy frame"
   (pop-frame/toy
    (in-hole WF_outer WFrame_inner)
    WF_outer
    WFrame_inner)])

(define-judgment-form
  mk-d:pk-mk-decomposition-lang
  #:contract (pop-frame/mk WF WF WFrame)
  #:mode (pop-frame/mk I O O)
  [---------------------------------------------------- "pop mk frame"
   (pop-frame/mk
    (in-hole WF_outer WFrame_inner)
    WF_outer
    WFrame_inner)])

(define cell-source-rule-names
  '(expose-frontier-fresh/core
    finish-success/core
    finish-failure/core
    force-delay/delay
    commit-choice-answer/disj
    commit-right-choice-answer/search-join
    allocate-fresh/core
    expand-conjunction/core
    expand-disjunction/disj
    suspend-goal/delay
    expose-choice-through-work-fresh/disj
    expose-choice-through-work-fresh/search-join
    erase-dead-fresh/core
    bubble-delay-through-fresh/delay
    conj-return/core
    conj-fail/core
    bubble-delay-through-conj/delay
    late-distribute-settled/disj
    late-distribute-right-settled/search-join
    skip-left-failure/disj
    rail-enter-right/search-join
    reassociate-left-result/disj
    skip-right-failure/search-join
    rail-return-left/search-join
    reassociate-right-result/search-join))

(define toy-source-rule-names
  (append cell-source-rule-names
          '(work-succeed/core
            work-fail/core
            work-put/core)))

(define mk-source-rule-names
  (append cell-source-rule-names
          '(kernel:succeed/core
            kernel:fail/core
            kernel:unify-success/core
            kernel:unify-violates-disequality/core
            kernel:unify-fail/core
            kernel:disequality-success/core
            kernel:disequality-fail/core)))

(define (canonical-rule-names names)
  (sort names string<? #:key symbol->string))

(define (uncommented-source path)
  (call-with-input-file
   path
   (lambda (input)
     (string-join
      (for/list ([line (in-lines input)]
                 #:unless (regexp-match? #rx"^[[:space:]]*;" line))
        line)
      "\n"))))

(define grammar-litmus-tests
  (test-suite
   "whole-tree P[K] grammatical focus litmus"

   (test-case
    "the four grammar factorizations form a unique cover of F"
    (redex-check
     toy-d:pk-toy-decomposition-lang
     F
     (= 1
        (factorization-count
         (term F)
         toy-boundary-factorizations
         toy-local-fresh-factorizations
         toy-local-factorizations
         toy-terminal-factorizations))
     #:attempts 5000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     F
     (= 1
        (factorization-count
         (term F)
         mk-boundary-factorizations
         mk-local-fresh-factorizations
         mk-local-factorizations
         mk-terminal-factorizations))
     #:attempts 5000))

   (test-case
    "decomposition has one raw derivation, not just one result"
    (redex-check
     toy-d:pk-toy-decomposition-lang
     F
     (= 1
        (length
         (build-derivations (toy-d:decompose/toy F D))))
     #:attempts 5000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     F
     (= 1
        (length
         (build-derivations (mk-d:decompose/mk F D))))
     #:attempts 5000))

   (test-case
    "BF has no work-frame pop and LF has exactly one raw pop"
    (redex-check
     toy-d:pk-toy-decomposition-lang
     BF
     (null?
      (build-derivations
       (pop-frame/toy BF WF_outer WFrame_inner)))
     #:attempts 2000)
    (redex-check
     toy-d:pk-toy-decomposition-lang
     LF
     (= 1
        (length
         (build-derivations
          (pop-frame/toy LF WF_outer WFrame_inner))))
     #:attempts 2000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     BF
     (null?
      (build-derivations
       (pop-frame/mk BF WF_outer WFrame_inner)))
     #:attempts 2000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     LF
     (= 1
        (length
         (build-derivations
          (pop-frame/mk LF WF_outer WFrame_inner))))
     #:attempts 2000))

   (test-case
    "R and NW are a disjoint exhaustive partition of W"
    (redex-check
     toy-lang:pk-toy-lang
     W
     (not
      (equal?
       (redex-match? toy-lang:pk-toy-lang R (term W))
       (redex-match? toy-lang:pk-toy-lang NW (term W))))
     #:attempts 5000)
    (redex-check
     mk-lang:pk-mk-lang
     W
     (not
      (equal?
       (redex-match? mk-lang:pk-mk-lang R (term W))
       (redex-match? mk-lang:pk-mk-lang NW (term W))))
     #:attempts 5000))

   (test-case
    "direct and slow refocusing each have one raw derivation"
    (redex-check
     toy-z:pk-toy-refocused-lang
     Q
     (= 1
        (length
         (build-derivations
          (toy-z:refocus-query/direct/toy Q Z))))
     #:attempts 2000)
    (redex-check
     toy-z:pk-toy-refocused-lang
     C
     (and
      (= 1
         (length
          (build-derivations
           (toy-z:refocus-direct/toy C Z))))
      (= 1
         (length
          (build-derivations
           (toy-zs:refocus-spec/toy C Z)))))
     #:attempts 2000)
    (redex-check
     mk-z:pk-mk-refocused-lang
     Q
     (= 1
        (length
         (build-derivations
          (mk-z:refocus-query/direct/mk Q Z))))
     #:attempts 2000)
    (redex-check
     mk-z:pk-mk-refocused-lang
     C
     (and
      (= 1
         (length
          (build-derivations
           (mk-z:refocus-direct/mk C Z))))
      (= 1
         (length
          (build-derivations
           (mk-zs:refocus-spec/mk C Z)))))
     #:attempts 2000))

   (test-case
    "source relations expose their complete static rule inventories"
    (check-equal?
     (canonical-rule-names
      (reduction-relation->rule-names toy-s:source-red/toy))
     (canonical-rule-names toy-source-rule-names))
    (check-equal?
     (canonical-rule-names
      (reduction-relation->rule-names mk-s:source-red/mk))
     (canonical-rule-names mk-source-rule-names)))

   (test-case
    "semantic schemas contain no host priority dispatcher"
    (for ([path (in-list (list source-schema-path
                               decomposition-schema-path
                               refocused-schema-path))])
      (define source (uncommented-source path))
      (check-false (regexp-match? #rx"more-redex\\?" source)
                   (path->string path))
      (check-false (regexp-match? #rx"work-redex\\?" source)
                   (path->string path))))

   (test-case
    "the primary source is not a computed judgment projection"
    (define source (uncommented-source source-schema-path))
    (define toy-source (uncommented-source toy-source-path))
    (define mk-source (uncommented-source mk-source-path))
    (check-equal? (length (regexp-match* #rx"\\[-->" source)) 25)
    (check-equal? (length (regexp-match* #rx"\\[-->" toy-source)) 3)
    (check-equal? (length (regexp-match* #rx"\\[-->" mk-source)) 7)
    (check-false (regexp-match? #rx"computed-name" source))
    (check-false (regexp-match? #rx"judgment-holds" source))
    (check-false (regexp-match? #rx"define-judgment-form" source)))))

(module+ test
  (run-tests grammar-litmus-tests))
