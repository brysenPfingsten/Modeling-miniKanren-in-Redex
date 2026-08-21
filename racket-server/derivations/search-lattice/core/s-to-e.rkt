#lang racket

(require racket/list
         redex/reduction-semantics
         (only-in "../../../src/search-lattice/reduction-relations/core-red.rkt"
                  core-red)
         (only-in "../../../src/search-lattice/wf/core-wf.rkt"
                  wf-cfg/core?)
         "./s/decomposition.rkt"
         "./e/language.rkt"
         "./e/source.rkt"
         "./e/decomposition.rkt")

(provide core-se-lang
         erase-owners
         Q-SE/A-at
         Q-SE/W-at
         Q-SE/F-at
         Q-SE/A
         Q-SE/W
         Q-SE/F
         Q-SE/WorkPath-at
         Q-SE/WorkPath
         Q-SE/WorkFocus
         Q-SE/SpineContext
         SWorkPath-hole-support
         SWorkFocus-hole-support
         Q-SE/D
         Q-SE/C
         S-allocation-cumulative-support
         allocation-support-sides/s->e
         allocation-support-agrees?/s->e
         source-square-premise?/s->e
         source-square-sides/s->e
         source-square/raw?/s->e
         decomposition-square-sides/s->e
         decomposition-square/raw?/s->e
         contract-square-sides/s->e
         contract-square/raw?/s->e
         decomposed-step-square-sides/s->e
         decomposed-step-square/raw?/s->e)

(check-redundancy #t)

;; One combined grammar lets the vertical map be stated as Redex
;; metafunctions without making either source column depend on the other.
;; The S-prefixed categories are the current Owners carrier and its D/C
;; shells; the unprefixed categories are the support-decorated-node prototype
;; E column.  This bridge stops at R/D and does not select the future
;; state-local E representation.
(define-extended-language core-se-lang
  core-e-decomposition-lang

  [SA (Answer owners σ)]

  [SS (Returned owners σ)]

  [SW (Work owners g σ)
      (Returned owners σ)
      (Dead owners)
      (Conj owners SW g)]

  [SF (Last owners SA)
      (Done owners)
      (More SW)]

  [SWorkPath hole
             (Conj owners SWorkPath g)]

  [SSpineContext hole]

  [SWorkFocus (in-hole SSpineContext (More SWorkPath))]

  [SWR (Work owners (g ∧ g tag) σ)
       (Work owners (succeed tag) σ)
       (Work owners (fail tag) σ)
       (Conj owners (Returned owners σ) g)
       (Conj owners (Dead owners) g)
       (Work owners (t =? t tag) σ)
       (Work owners (t != t tag) σ)]

  [SFR (More (Returned owners σ))
       (More (Dead owners))]

  [SAR (Work owners (∃ d g tag) σ)]

  [ST (Last owners SA)
      (Done owners)]

  [SD (Final ST)
      (DecWork SWR SWorkFocus)
      (DecFrontier SFR SSpineContext)
      (DecAllocate SAR SWorkFocus)]

  [SC (ContractWork RuleName SW SWorkFocus)
      (ContractFrontier RuleName SF SSpineContext)])

;; Erasure preserves the owner order, while forgetting both the grouping of
;; introductions into Owner records and their provenance tags.
(define-metafunction core-se-lang
  erase-owners : owners -> support
  [(erase-owners (Owners))
   (Support)]
  [(erase-owners
    (Owners (Owner (u ...) tag) owner_rest ...))
   (support-append
    (Support u ...)
    (erase-owners (Owners owner_rest ...)))])

;; Prototype E is not merely S with tags deleted: every Support is cumulative
;; at that carrier position.  The -at maps therefore thread the incoming
;; support through nested carriers.
(define-metafunction core-se-lang
  Q-SE/A-at : SA support -> A
  [(Q-SE/A-at (Answer owners σ) support_in)
   (Answer support_here σ)
   (where support_here
          (support-append support_in (erase-owners owners)))])

(define-metafunction core-se-lang
  Q-SE/W-at : SW support -> W
  [(Q-SE/W-at (Work owners g σ) support_in)
   (Work support_here g σ)
   (where support_here
          (support-append support_in (erase-owners owners)))]
  [(Q-SE/W-at (Returned owners σ) support_in)
   (Returned support_here σ)
   (where support_here
          (support-append support_in (erase-owners owners)))]
  [(Q-SE/W-at (Dead owners) support_in)
   (Dead support_here)
   (where support_here
          (support-append support_in (erase-owners owners)))]
  [(Q-SE/W-at (Conj owners SW g) support_in)
   (Conj support_here
         (Q-SE/W-at SW support_here)
         g)
   (where support_here
          (support-append support_in (erase-owners owners)))])

(define-metafunction core-se-lang
  Q-SE/F-at : SF support -> F
  [(Q-SE/F-at (More SW) support_in)
   (More (Q-SE/W-at SW support_in))]
  [(Q-SE/F-at (Done owners) support_in)
   (Done support_here)
   (where support_here
          (support-append support_in (erase-owners owners)))]
  [(Q-SE/F-at (Last owners SA) support_in)
   (Last support_here
         (Q-SE/A-at SA support_here))
   (where support_here
          (support-append support_in (erase-owners owners)))])

(define-metafunction core-se-lang
  Q-SE/A : SA -> A
  [(Q-SE/A SA) (Q-SE/A-at SA (Support))])

(define-metafunction core-se-lang
  Q-SE/W : SW -> W
  [(Q-SE/W SW) (Q-SE/W-at SW (Support))])

(define-metafunction core-se-lang
  Q-SE/F : SF -> F
  [(Q-SE/F SF) (Q-SE/F-at SF (Support))])

;; A separated work redex must be translated at the scope of its context's
;; hole.  These two folds compute that scope and translate the same context,
;; respectively.  This is what prevents D/C translation from silently
;; treating a focused redex as a new root.
(define-metafunction core-se-lang
  SWorkPath-hole-support : SWorkPath support -> support
  [(SWorkPath-hole-support hole support_in)
   support_in]
  [(SWorkPath-hole-support
    (Conj owners SWorkPath g)
    support_in)
   (SWorkPath-hole-support SWorkPath support_here)
   (where support_here
          (support-append support_in (erase-owners owners)))])

(define-metafunction core-se-lang
  SWorkFocus-hole-support : SWorkFocus -> support
  [(SWorkFocus-hole-support (More SWorkPath))
   (SWorkPath-hole-support SWorkPath (Support))])

(define-metafunction core-se-lang
  Q-SE/WorkPath-at : SWorkPath support -> WorkPath
  [(Q-SE/WorkPath-at hole support_in)
   hole]
  [(Q-SE/WorkPath-at
    (Conj owners SWorkPath g)
    support_in)
   (Conj support_here
         (Q-SE/WorkPath-at SWorkPath support_here)
         g)
   (where support_here
          (support-append support_in (erase-owners owners)))])

(define-metafunction core-se-lang
  Q-SE/WorkPath : SWorkPath -> WorkPath
  [(Q-SE/WorkPath SWorkPath)
   (Q-SE/WorkPath-at SWorkPath (Support))])

(define-metafunction core-se-lang
  Q-SE/WorkFocus : SWorkFocus -> WorkFocus
  [(Q-SE/WorkFocus (More SWorkPath))
   (More (Q-SE/WorkPath SWorkPath))])

(define-metafunction core-se-lang
  Q-SE/SpineContext : SSpineContext -> SpineContext
  [(Q-SE/SpineContext hole) hole])

(define-metafunction core-se-lang
  Q-SE/D : SD -> D
  [(Q-SE/D (Final ST))
   (Final (Q-SE/F-at ST (Support)))]
  [(Q-SE/D (DecWork SWR SWorkFocus))
   (DecWork
    (Q-SE/W-at
     SWR
     (SWorkFocus-hole-support SWorkFocus))
    (Q-SE/WorkFocus SWorkFocus))]
  [(Q-SE/D (DecFrontier SFR SSpineContext))
   (DecFrontier
    (Q-SE/F-at SFR (Support))
    (Q-SE/SpineContext SSpineContext))]
  [(Q-SE/D (DecAllocate SAR SWorkFocus))
   (DecAllocate
    (Q-SE/W-at
     SAR
     (SWorkFocus-hole-support SWorkFocus))
    (Q-SE/WorkFocus SWorkFocus))])

(define-metafunction core-se-lang
  Q-SE/C : SC -> C
  [(Q-SE/C (ContractWork RuleName SW SWorkFocus))
   (ContractWork
    RuleName
    (Q-SE/W-at
     SW
     (SWorkFocus-hole-support SWorkFocus))
    (Q-SE/WorkFocus SWorkFocus))]
  [(Q-SE/C (ContractFrontier RuleName SF SSpineContext))
   (ContractFrontier
    RuleName
    (Q-SE/F-at SF (Support))
    (Q-SE/SpineContext SSpineContext))])

;; The premise needed by the operational square is visible independently of
;; the square itself.  For an allocation decomposition, this is the Support E
;; reads locally after translating the focused S Work at its context's hole.
(define-metafunction core-se-lang
  S-allocation-cumulative-support : SAR SWorkFocus -> support
  [(S-allocation-cumulative-support
    (Work owners (∃ d g tag) σ)
    SWorkFocus)
   (support-append
    (SWorkFocus-hole-support SWorkFocus)
    (erase-owners owners))])

(define (canonical-proof-multiset proofs)
  (sort proofs string<? #:key ~s))

(define (canonical-intro intro)
  (sort (remove-duplicates intro) symbol<?))

(define (support->canonical-intro support)
  (match support
    [`(Support ,u ...)
     (canonical-intro u)]))

(define (map-Q/F source)
  (term (Q-SE/F ,source)))

(define (map-Q/D decomposition)
  (term (Q-SE/D ,decomposition)))

(define (map-Q/C contractum)
  (term (Q-SE/C ,contractum)))

(define (map-named-Q/F named-successor)
  (match named-successor
    [(list name target)
     (list name (map-Q/F target))]))

;; judgment-holds returns distinct answers, not proof occurrences.  The square
;; helpers below intentionally retain one conclusion per derivation so two
;; identical raw proofs remain two multiset elements.
(define (unary-output derivation)
  (last (derivation-term derivation)))

(define (named-output derivation)
  (match (derivation-term derivation)
    [(list _judgment _input name target)
     (list name target)]))

(define (decomposition-proofs/s source)
  (for/list ([derivation
              (in-list
               (build-derivations (decompose/s ,source D)))])
    (unary-output derivation)))

(define (decomposition-proofs/e source)
  (for/list ([derivation
              (in-list
               (build-derivations (decompose/e ,source D)))])
    (unary-output derivation)))

(define (contract-proofs/s decomposition)
  (for/list ([derivation
              (in-list
               (build-derivations (contract/s ,decomposition C)))])
    (unary-output derivation)))

(define (contract-proofs/e decomposition)
  (for/list ([derivation
              (in-list
               (build-derivations (contract/e ,decomposition C)))])
    (unary-output derivation)))

(define (decomposed-proofs/s decomposition)
  (for/list ([derivation
              (in-list
               (build-derivations
                (decomposed-step/direct/s
                 ,decomposition
                 RuleName
                 D)))])
    (named-output derivation)))

(define (decomposed-proofs/e decomposition)
  (for/list ([derivation
              (in-list
               (build-derivations
                (decomposed-step/e
                 ,decomposition
                 RuleName
                 D)))])
    (named-output derivation)))

(define (well-formed-s-source? source)
  (judgment-holds (wf-cfg/core? ,source)))

(define (well-formed-s-decomposition? decomposition)
  (well-formed-s-source?
   (term (plug-D/s ,decomposition))))

(define (allocation-decomposition? decomposition)
  (match decomposition
    [`(DecAllocate ,_ ,_) #t]
    [_ #f]))

(define (allocation-support-sides/s->e decomposition)
  (match decomposition
    [`(DecAllocate ,work ,work-focus)
     (list
      (canonical-intro
       (term
        (whole-frontier-support/s
         (in-hole ,work-focus ,work))))
      (support->canonical-intro
       (term
        (S-allocation-cumulative-support
         ,work
         ,work-focus))))]
    [_ #f]))

(define (allocation-support-agrees?/s->e decomposition)
  (match (allocation-support-sides/s->e decomposition)
    [(list whole-frontier active-cumulative)
     (equal? whole-frontier active-cumulative)]
    [#f #f]))

;; This is the actual domain of the dynamic square.  The representation maps
;; themselves are partial outside WF: repeated introductions in distinct Owner
;; records can erase to a duplicate Support, which is intentionally outside
;; E.  Diagnostic side functions remain useful on ill-WF inputs only when the
;; quotient map is defined (as in the counterexample below).
(define (source-square-premise?/s->e source)
  (and
   (well-formed-s-source? source)
   (for/and
       ([decomposition
         (in-list (decomposition-proofs/s source))]
        #:when (allocation-decomposition? decomposition))
     (allocation-support-agrees?/s->e decomposition))))

(define (source-square-sides/s->e source)
  (list
   (map map-named-Q/F
        (apply-reduction-relation/tag-with-names core-red source))
   (apply-reduction-relation/tag-with-names
    core-e-red
    (map-Q/F source))))

(define (source-square/raw?/s->e source)
  (and
   (source-square-premise?/s->e source)
   (match-let ([(list transported direct)
                (source-square-sides/s->e source)])
     (equal? (canonical-proof-multiset transported)
             (canonical-proof-multiset direct)))))

(define (decomposition-square-sides/s->e source)
  (list
   (map map-Q/D
        (decomposition-proofs/s source))
   (decomposition-proofs/e (map-Q/F source))))

(define (decomposition-square/raw?/s->e source)
  (match-define (list transported direct)
    (decomposition-square-sides/s->e source))
  (equal? (canonical-proof-multiset transported)
          (canonical-proof-multiset direct)))

(define (contract-square-sides/s->e decomposition)
  (list
   (map map-Q/C
        (contract-proofs/s decomposition))
   (contract-proofs/e (map-Q/D decomposition))))

(define (contract-square/raw?/s->e decomposition)
  (and
   (well-formed-s-decomposition? decomposition)
   (or (not (allocation-decomposition? decomposition))
       (allocation-support-agrees?/s->e decomposition))
   (match-let ([(list transported direct)
                (contract-square-sides/s->e decomposition)])
     (equal? (canonical-proof-multiset transported)
             (canonical-proof-multiset direct)))))

(define (map-named-Q/D named-successor)
  (match named-successor
    [(list name target)
     (list name (map-Q/D target))]))

(define (decomposed-step-square-sides/s->e decomposition)
  (list
   (map map-named-Q/D
        (decomposed-proofs/s decomposition))
   (decomposed-proofs/e (map-Q/D decomposition))))

(define (decomposed-step-square/raw?/s->e decomposition)
  (and
   (well-formed-s-decomposition? decomposition)
   (or (not (allocation-decomposition? decomposition))
       (allocation-support-agrees?/s->e decomposition))
   (match-let ([(list transported direct)
                (decomposed-step-square-sides/s->e decomposition)])
     (equal? (canonical-proof-multiset transported)
             (canonical-proof-multiset direct)))))

(module+ test
  (require rackunit)

  (define sigma
    (term (state () () () (label "state"))))

  (define nested-source
    (term
     (More
      (Conj
       (Owners (Owner (u:outer) (label "outer")))
       (Work
        (Owners (Owner (u:inner) (label "inner")))
        (succeed (label "succeed"))
        ,sigma)
       (fail (label "later"))))))

  (check-equal?
   (term (Q-SE/F ,nested-source))
   (term
    (More
     (Conj
      (Support u:outer)
      (Work
       (Support u:outer u:inner)
       (succeed (label "succeed"))
       ,sigma)
      (fail (label "later"))))))

  (check-true (source-square/raw?/s->e nested-source))
  (check-true (decomposition-square/raw?/s->e nested-source))

  (define nested-decomposition
    (first
     (judgment-holds (decompose/s ,nested-source D) D)))

  (check-true (contract-square/raw?/s->e nested-decomposition))
  (check-true
   (decomposed-step-square/raw?/s->e nested-decomposition))

  (define allocation-source
    (term
     (More
      (Conj
       (Owners (Owner (u:0) (label "outer")))
       (Work
        (Owners (Owner (u:1) (label "inner")))
        (∃ (x:q)
           (x:q =? u:0 (label "body"))
           (label "fresh"))
        ,sigma)
       (u:0 =? u:0 (label "later"))))))

  (define allocation-decomposition
    (first
     (judgment-holds
      (decompose/s ,allocation-source D)
      D)))

  (check-equal?
   (allocation-support-sides/s->e allocation-decomposition)
   '((u:0 u:1) (u:0 u:1)))
  (check-true
   (allocation-support-agrees?/s->e allocation-decomposition))
  (check-true (source-square-premise?/s->e allocation-source))
  (check-true (source-square/raw?/s->e allocation-source))
  (check-true (contract-square/raw?/s->e allocation-decomposition))

  ;; This malformed state mentions an unowned u:0.  The current S scan sees it
  ;; while prototype E's cumulative Support does not.  The differing successors
  ;; are a counterexample outside the stated square premise, not a choice of
  ;; eventual allocation policy.
  (define ill-formed-allocation-source
    (term
     (More
      (Work
       (Owners)
       (∃ (x:q)
          (x:q =? x:q (label "body"))
          (label "fresh"))
       (state ((u:0 (nat 0)))
              ()
              ((u:0 =? (nat 0) (label "old")))
              (label "state"))))))

  (check-false
   (source-square-premise?/s->e ill-formed-allocation-source))
  (check-false
   (source-square/raw?/s->e ill-formed-allocation-source))
  (check-not-equal?
   (first (source-square-sides/s->e ill-formed-allocation-source))
   (second (source-square-sides/s->e ill-formed-allocation-source))))
