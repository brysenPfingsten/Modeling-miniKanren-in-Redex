#lang racket

(require redex/reduction-semantics
         (only-in "./decomposition.rkt"
                  decompose/s)
         (only-in "./machine.rkt"
                  D->M/s)
         "./compressed.rkt"
         "./fixed-point.rkt")

(provide core-s-fixed-point-spec-lang
         initialize-B/spec/s
         close-B/spec/s
         flatten-BTrace/s
         promote-B/direct/s
         big-evaluate/spec/s
         B-Big-unfold-square/s
         B-Big-closure-square/s
         B-Big-root-square/s)

(check-redundancy #t)

;; This is the compositional side of fixed-point promotion.  Unlike the direct
;; evaluator, the specification is allowed to retain the complete sequence of
;; certified compressed spans.
(define-extended-language core-s-fixed-point-spec-lang
  core-s-compressed-lang
  [Big (BigFinal T)]
  [BTrace (TransitionSpan ...)])

(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (initialize-B/spec/s F B)
  #:mode (initialize-B/spec/s I O)

  [(decompose/s F D)
   (where M (D->M/s D))
   (where B (encode-MB/s M))
   ---------------------------------------------------- "compositional compressed initialization/S"
   (initialize-B/spec/s F B)])

;; This strict closure is intentionally confined to the specification.  The
;; direct evaluator contains neither this recursion nor a compressed state.
(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (close-B/spec/s B BTrace T)
  #:mode (close-B/spec/s I O O)

  [---------------------------------------------------- "close final compressed state/S"
   (close-B/spec/s (BFinal T) () T)]

  [(compressed-step/direct/s
    B_0
    TransitionSpan_0
    B_1)
   (close-B/spec/s
    B_1
    (TransitionSpan_rest ...)
    T)
   ---------------------------------------------------- "close one compressed span/S"
   (close-B/spec/s
    B_0
    (TransitionSpan_0 TransitionSpan_rest ...)
    T)])

(define-metafunction core-s-fixed-point-spec-lang
  flatten-BTrace/s : BTrace -> MLabels
  [(flatten-BTrace/s ())
   ()]
  [(flatten-BTrace/s
    (TransitionSpan_0 TransitionSpan_rest ...))
   (RuleName_span ... RuleName_rest ...)
   (where (RuleName_span ...)
          (transition-span-labels/s TransitionSpan_0))
   (where (RuleName_rest ...)
          (flatten-BTrace/s (TransitionSpan_rest ...)))])

;; The adapter merely selects the corresponding public promoted entry.  It is
;; kept here because it necessarily inspects the compressed constructors.
(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (promote-B/direct/s B Big)
  #:mode (promote-B/direct/s I O)

  [(big-run/direct/s
    (Work owners g σ)
    WorkFocus
    Big)
   ---------------------------------------------------- "promote compressed run/S"
   (promote-B/direct/s
    (BRun (Work owners g σ) WorkFocus)
    Big)]

  [(big-settled/direct/s
    (Returned owners σ)
    WorkFocus
    Big)
   ---------------------------------------------------- "promote compressed settled/S"
   (promote-B/direct/s
    (BSettled (Returned owners σ) WorkFocus)
    Big)]

  [(big-dead/direct/s
    owners
    WorkFocus
    Big)
   ---------------------------------------------------- "promote compressed dead/S"
   (promote-B/direct/s
    (BDead owners WorkFocus)
    Big)]

  [(big-final/direct/s T Big)
   ---------------------------------------------------- "promote compressed final/S"
   (promote-B/direct/s (BFinal T) Big)])

(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (big-evaluate/spec/s F BTrace Big)
  #:mode (big-evaluate/spec/s I O O)

  [(initialize-B/spec/s F B)
   (close-B/spec/s B BTrace T)
   ---------------------------------------------------- "compressed closure specification/S"
   (big-evaluate/spec/s F BTrace (BigFinal T))])

;; One unfolding of the compressed driver leaves the promoted result fixed.
(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (B-Big-unfold-square/s B TransitionSpan B Big)
  #:mode (B-Big-unfold-square/s I O O O)

  [(compressed-step/direct/s
    B_0
    TransitionSpan
    B_1)
   (promote-B/direct/s B_0 Big)
   (promote-B/direct/s B_1 Big)
   ---------------------------------------------------- "one-step compressed/Big unfold square/S"
   (B-Big-unfold-square/s
    B_0
    TransitionSpan
    B_1
    Big)])

(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (B-Big-closure-square/s B BTrace Big)
  #:mode (B-Big-closure-square/s I O O)

  [(close-B/spec/s B BTrace T)
   (promote-B/direct/s B (BigFinal T))
   ---------------------------------------------------- "compressed closure/Big square/S"
   (B-Big-closure-square/s
    B
    BTrace
    (BigFinal T))])

(define-judgment-form
  core-s-fixed-point-spec-lang
  #:contract (B-Big-root-square/s F BTrace Big)
  #:mode (B-Big-root-square/s I O O)

  [(big-evaluate/spec/s F BTrace Big)
   (big-evaluate/direct/s F Big)
   ---------------------------------------------------- "root compressed/Big square/S"
   (B-Big-root-square/s F BTrace Big)])

(module+ test
  (require rackunit)

  (define sigma/s
    (term (state () () () (label "state"))))

  (define succeed-source/s
    (term
     (More
      (Work
       (Owners)
       (succeed (label "yes"))
       ,sigma/s))))

  (define succeed-B/s
    (term
     (BRun
      (Work
       (Owners)
       (succeed (label "yes"))
       ,sigma/s)
      (More hole))))

  (define succeed-Big/s
    (term
     (BigFinal
      (Last
       (Owners)
       (Answer (Owners) ,sigma/s)))))

  (check-equal?
   (judgment-holds
    (initialize-B/spec/s ,succeed-source/s B)
    B)
   (list succeed-B/s))
  (check-equal?
   (judgment-holds
    (close-B/spec/s ,succeed-B/s BTrace T)
    (BTrace T))
   (list
    (term
     (((transition-span succeed finish-success))
      (Last
       (Owners)
       (Answer (Owners) ,sigma/s))))))
  (check-equal?
   (judgment-holds
    (big-evaluate/spec/s
     ,succeed-source/s
     BTrace
     Big)
    (BTrace Big))
   (list
    (list
     (term ((transition-span succeed finish-success)))
     succeed-Big/s)))
  (check-equal?
   (judgment-holds
    (B-Big-root-square/s
     ,succeed-source/s
     BTrace
     Big)
    (BTrace Big))
   (list
    (list
     (term ((transition-span succeed finish-success)))
     succeed-Big/s)))

  (check-equal?
   (length
    (build-derivations
     (close-B/spec/s ,succeed-B/s BTrace T)))
   1)
  (check-equal?
   (length
    (build-derivations
     (big-evaluate/spec/s
      ,succeed-source/s
      BTrace
      Big)))
   1)
  (check-equal?
   (length
    (build-derivations
     (B-Big-unfold-square/s
      ,succeed-B/s
      TransitionSpan
      B_1
      Big)))
   1)
  (check-equal?
   (length
    (build-derivations
     (B-Big-closure-square/s
      ,succeed-B/s
      BTrace
      Big)))
   1)
  (check-equal?
   (length
    (build-derivations
     (B-Big-root-square/s
      ,succeed-source/s
      BTrace
      Big)))
   1)

  (check-equal?
   (judgment-holds
    (big-evaluate/spec/s
     (Done (Owners))
     BTrace
     Big)
    (BTrace Big))
   (list
    (list
     (term ())
     (term (BigFinal (Done (Owners)))))))

  (define finite-source/s
    (term
     (More
      (Work
       (Owners)
       (∃ (x:q x:r)
          (((x:q =? (sym "cat") (label "bind-x"))
            ∧
            (x:r != (sym "dog") (label "exclude-dog"))
            (label "inner-conjunction"))
           ∧
           (succeed (label "done"))
           (label "outer-conjunction"))
          (label "allocate-two"))
       ,sigma/s))))

  (define golden-spans/s
    (term
     ((transition-span allocate-fresh)
      (transition-span expand-conjunction)
      (transition-span expand-conjunction)
      (transition-span unify-success conj-return)
      (transition-span disequality-success conj-return)
      (transition-span succeed finish-success))))

  (define golden-labels/s
    (term
     (allocate-fresh
      expand-conjunction
      expand-conjunction
      unify-success
      conj-return
      disequality-success
      conj-return
      succeed
      finish-success)))

  (define golden-Big/s
    (term
     (BigFinal
      (Last
       (Owners
        (Owner (u:0 u:1) (label "allocate-two")))
       (Answer
        (Owners)
        (state
         ((u:0 (sym "cat")))
         ((u:1 (sym "dog")))
         ((u:0 =? (sym "cat") (label "bind-x")))
         (label "state")))))))

  (check-equal?
   (judgment-holds
    (B-Big-root-square/s
     ,finite-source/s
     BTrace
     Big)
    (BTrace Big))
   (list (list golden-spans/s golden-Big/s)))
  (check-equal?
   (term (flatten-BTrace/s ,golden-spans/s))
   golden-labels/s))
