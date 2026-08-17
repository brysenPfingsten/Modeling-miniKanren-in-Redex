#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in kernel-corpus:
                    "../../../whole-tree/corpus/kernel-cases.rkt")
         (prefix-in mk-d: "../mk/decomposition.rkt")
         (prefix-in mk-k: "../mk/kernel.rkt")
         (prefix-in mk-l: "../mk/labels.rkt")
         (prefix-in mk-lang: "../mk/language.rkt")
         (prefix-in mk-s: "../mk/source.rkt")
         (prefix-in mk-wf: "../mk/wf.rkt")
         (prefix-in toy-d: "../toy/decomposition.rkt")
         (prefix-in toy-k: "../toy/kernel.rkt")
         (prefix-in toy-l: "../toy/labels.rkt")
         (prefix-in toy-lang: "../toy/language.rkt")
         (prefix-in toy-s: "../toy/source.rkt")
         (prefix-in toy-wf: "../toy/wf.rkt"))

(provide front-half-tests)

(define (toy-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          toy-s:source-red/toy
          frontier))])
    (match-define (list name next) named)
    (list (term (toy-l:redex-name->label/toy ,(~a name))) next)))

(define (mk-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          mk-s:source-red/mk
          frontier))])
    (match-define (list name next) named)
    (list (term (mk-l:redex-name->label/mk ,(~a name))) next)))

(define (mk-decompositions frontier)
  (judgment-holds (mk-d:decompose/mk ,frontier D) D))

(define (mk-contract-successors frontier)
  (for*/list
      ([decomposition (in-list (mk-decompositions frontier))]
       [contractum
        (in-list
         (judgment-holds
          (mk-d:contract/mk ,decomposition C)
          C))])
    (list (term (mk-d:contract-label/mk ,contractum))
          (term (mk-d:plug-C/mk ,contractum)))))

(define (mk-spec-successors decomposition)
  (judgment-holds
   (mk-d:decomposed-step/spec/mk
    ,decomposition
    ell
    D_next)
   (ell D_next)))

(define (mk-direct-successors decomposition)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          mk-d:decomposed-red/direct/mk
          decomposition))])
    (match-define (list name next) named)
    (list (term (mk-l:redex-name->label/mk ,(~a name))) next)))

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

(define (mk-kernel-results atomic state)
  (judgment-holds
   (mk-k:kernel-step/mk ,atomic ,state kresult kell)
   (kresult kell)))

(define (with-mk-ambient atomic state ambient)
  (match ambient
    ['() `(More (Work ,atomic ,state))]
    [_ `(FrontierFresh
         ,ambient
         (More (Work ,atomic ,state))
         (label "ambient"))]))

(define-syntax-rule
  (check-generated-front-half
   language-id
   wf-frontier-id
   decompose-id
   plug-D-id
   contract-id
   plug-C-id
   contract-label-id
   source-red-id
   redex-name->label-id
   decomposed-step/spec-id
   decomposed-step/direct-id)
  (redex-check
   language-id
   F
   (let ([frontier (term F)])
     (or
      (not (judgment-holds (wf-frontier-id F)))
      (let ([decomposition*
             (judgment-holds (decompose-id F D) D)]
            [source*
             (for/list
                 ([named
                   (in-list
                    (apply-reduction-relation/tag-with-names
                     source-red-id
                     frontier))])
               (match-define (list name next) named)
               (list
                (term (redex-name->label-id ,(~a name)))
                next))])
        (match decomposition*
          [(list decomposition)
           (define contract*
             (for/list
                 ([contractum
                   (in-list
                    (judgment-holds
                     (contract-id ,decomposition C)
                     C))])
               (list (term (contract-label-id ,contractum))
                     (term (plug-C-id ,contractum)))))
           (define spec*
             (judgment-holds
              (decomposed-step/spec-id
               ,decomposition
               ell
               D_next)
              (ell D_next)))
           (define direct*
             (judgment-holds
              (decomposed-step/direct-id
               ,decomposition
               ell
               D_next)
              (ell D_next)))
           (and
            (equal? (term (plug-D-id ,decomposition)) frontier)
            (equal? contract* source*)
            (equal? direct* spec*)
            (for/and ([successor (in-list source*)])
              (match-define (list _label next) successor)
              (judgment-holds (wf-frontier-id ,next))))]
          [_ #f]))))
   #:attempts 1000))

(define complex-mk-goal
  '(fresh
    (x:q)
    (disj
     (conj
      (x:q =? (sym "cat") (label "bind"))
      (suspend
       (succeed (label "resume"))
       (label "delay"))
      (label "and"))
     (x:q != (sym "dog") (label "neq"))
     (label "or"))
    (label "query")))

(define (mk-trace-states initial [limit 256] [states (list initial)])
  (match (mk-source-successors initial)
    ['() (reverse states)]
    [(list (list _label next))
     (unless (positive? limit)
       (error 'mk-trace-states "step cap reached"))
     (mk-trace-states next (sub1 limit) (cons next states))]
    [other
     (error 'mk-trace-states "nondeterministic source: ~e" other)]))

(define front-half-tests
  (test-suite
   "whole-tree P[K] front half"

   (test-case
    "BF/LF are disjoint full contexts with a unique local pop"
    (for ([language (in-list
                     (list toy-d:pk-toy-decomposition-lang
                           mk-d:pk-mk-decomposition-lang))])
      (check-not-false language))
    (redex-check
     toy-d:pk-toy-decomposition-lang
     BF
     (null?
      (judgment-holds
       (pop-frame/toy BF WF_outer WFrame_inner)
       (WF_outer WFrame_inner)))
     #:attempts 1000)
    (redex-check
     toy-d:pk-toy-decomposition-lang
     LF
     (= 1
        (length
         (judgment-holds
          (pop-frame/toy LF WF_outer WFrame_inner)
          (WF_outer WFrame_inner))))
     #:attempts 1000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     BF
     (null?
      (judgment-holds
       (pop-frame/mk BF WF_outer WFrame_inner)
       (WF_outer WFrame_inner)))
     #:attempts 1000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     LF
     (= 1
        (length
         (judgment-holds
          (pop-frame/mk LF WF_outer WFrame_inner)
          (WF_outer WFrame_inner))))
     #:attempts 1000))

   (test-case
    "shared phase refinements admit structural goals without outcomes"
    (define structural-work
      '(Work
        (fresh (x:q)
               (put x:q (label "put"))
               (label "fresh"))
        (state unit)))
    (check-true
     (redex-match? toy-lang:pk-toy-lang NR structural-work))
    (check-true
     (redex-match? toy-lang:pk-toy-lang NW structural-work))
    (check-false
     (redex-match?
      toy-lang:pk-toy-lang
      NW
      '(Returned (state unit))))
    (check-true
     (redex-match?
      toy-lang:pk-toy-lang
      R
      '(DisjL (Returned (state unit)) Dead)))
    (check-false
     (redex-match?
      toy-lang:pk-toy-lang
      NF
      '(WorkFresh (u:0) Dead (label "scope")))))

   (test-case
    "precise instance languages reject mixed source and D terms"
    (define toy-frontier
      '(More (Work (put unit (label "put")) (state unit))))
    (define mk-frontier
      `(More
        (Work
         ((sym "cat") =? (sym "cat") (label "eq"))
         ,kernel-corpus:empty-mk-state)))
    (check-true
     (redex-match? toy-lang:pk-toy-lang F toy-frontier))
    (check-false
     (redex-match? mk-lang:pk-mk-lang F toy-frontier))
    (check-true
     (redex-match? mk-lang:pk-mk-lang F mk-frontier))
    (check-false
     (redex-match? toy-lang:pk-toy-lang F mk-frontier))
    (check-true
     (redex-match?
     toy-d:pk-toy-decomposition-lang
      D
      (term
       (DecWork
        (Work (put unit (label "put")) (state unit))
        (More hole)))))
    (check-false
     (redex-match?
     mk-d:pk-mk-decomposition-lang
      D
      (term
       (DecWork
        (Work (put unit (label "put")) (state unit))
        (More hole)))))
    (check-true
     (redex-match?
     mk-d:pk-mk-decomposition-lang
      D
      (term
       (DecWork
        (Work
         ((sym "cat") =? (sym "cat") (label "eq"))
         ,kernel-corpus:empty-mk-state)
        (More hole)))))
    (check-false
     (redex-match?
     toy-d:pk-toy-decomposition-lang
      D
      (term
       (DecWork
        (Work
         ((sym "cat") =? (sym "cat") (label "eq"))
         ,kernel-corpus:empty-mk-state)
        (More hole)))))
    (check-false
     (toy-lang:label-in-language?/toy
      '(kernel unify-success core)))
    (check-false
     (mk-lang:label-in-language?/mk
      '(kernel work-put core))))

   (test-case
    "marker-indexed WF enforces ownership in both kernels"
    (define scoped-toy
      '(FrontierFresh
        (u:0)
        (More
         (Work (put u:0 (label "put")) (state unit)))
        (label "scope")))
    (define unscoped-toy
      '(More
        (Work (put u:0 (label "put")) (state unit))))
    (check-true
     (judgment-holds (toy-wf:wf-frontier/toy ,scoped-toy)))
    (check-false
     (judgment-holds (toy-wf:wf-frontier/toy ,unscoped-toy)))
    (check-false
     (judgment-holds
      (toy-wf:wf-frontier/toy
       (More
        (Work
         (fresh (x:q x:q)
                (put x:q (label "put"))
                (label "duplicate"))
         (state unit))))))
    (define canonical-mk
      '(∃ (x:q)
          (x:q =? (sym "cat") (label "eq"))
          (label "query")))
    (define control-mk
      (term (mk-k:canonical-goal->control/mk ,canonical-mk)))
    (define initial-mk
      (term (mk-s:initial-tree/mk ,control-mk)))
    (check-true
     (judgment-holds (mk-wf:wf-frontier/mk ,initial-mk)))
    (check-false
     (judgment-holds
      (mk-wf:wf-frontier/mk
       (More
        (Work
         (u:0 =? (sym "cat") (label "free"))
         ,kernel-corpus:empty-mk-state))))))

   (test-case
    "fresh allocation uses global whole-frontier marker support"
    (define tree
      '(More
        (DisjL
         (Work
          (fresh (x:q)
                 (put x:q (label "put"))
                 (label "fresh"))
          (state unit))
         (WorkFresh (u:0) Dead (label "sibling")))))
    (check-equal?
     (term (toy-k:whole-marker-support/toy ,tree))
     '(u:0))
    (check-equal?
     (toy-source-successors tree)
     '(((allocate-fresh core)
        (More
         (DisjL
          (WorkFresh
           (u:1)
           (Work (put u:1 (label "put")) (state unit))
           (label "fresh"))
          (WorkFresh (u:0) Dead (label "sibling"))))))))

   (test-case
    "Kmk retains all seven exact tagged atomic labels"
    (define observed
      (for/list ([case (in-list kernel-corpus:mk-kernel-cases)])
        (match-define (list atomic state _ambient expected-label) case)
        (define results (mk-kernel-results atomic state))
        (check-equal? (length results) 1)
        (define label (second (first results)))
        (check-equal? label expected-label)
        (define name
          (term (mk-l:label->redex-name/mk ,label)))
        (check-equal?
         (term (mk-l:redex-name->label/mk ,name))
         label)
        label))
    (check-equal? (length (remove-duplicates observed)) 7))

   (test-case
    "Kmk source, contraction, and direct D agree on every atomic label"
    (for ([case (in-list kernel-corpus:mk-kernel-cases)])
      (match-define (list atomic state ambient expected-label) case)
      (define frontier (with-mk-ambient atomic state ambient))
      (check-true
       (judgment-holds (mk-wf:wf-frontier/mk ,frontier))
       (format "~e" frontier))
      (define source* (mk-source-successors frontier))
      (check-equal? (length source*) 1)
      (check-equal? (first (first source*)) expected-label)
      (check-equal?
       (mk-contract-successors frontier)
       source*)
      (define decomposition (first (mk-decompositions frontier)))
      (check-equal?
       (mk-direct-successors decomposition)
       (mk-spec-successors decomposition))))

   (test-case
    "Kmk compound trace preserves WF and every front-half arrow square"
    (define initial
      (term (mk-s:initial-tree/mk ,complex-mk-goal)))
    (define states (mk-trace-states initial))
    (check-true (> (length states) 10))
    (for ([frontier (in-list states)])
      (check-true
       (judgment-holds (mk-wf:wf-frontier/mk ,frontier))
       (format "~e" frontier))
      (define decomposition* (mk-decompositions frontier))
      (check-equal? (length decomposition*) 1)
      (define decomposition (first decomposition*))
      (check-equal?
       (term (mk-d:plug-D/mk ,decomposition))
       frontier)
      (check-equal?
       (mk-contract-successors frontier)
       (mk-source-successors frontier))
      (check-equal?
       (mk-direct-successors decomposition)
       (mk-spec-successors decomposition))))

   (test-case
    "the same generated front-half arrow suite runs for Ktoy and Kmk"
    (check-generated-front-half
     toy-d:pk-toy-decomposition-lang
     toy-wf:wf-frontier/toy
     toy-d:decompose/toy
     toy-d:plug-D/toy
     toy-d:contract/toy
     toy-d:plug-C/toy
     toy-d:contract-label/toy
     toy-s:source-red/toy
     toy-l:redex-name->label/toy
     toy-d:decomposed-step/spec/toy
     toy-d:decomposed-step/direct/toy)
    (check-generated-front-half
     mk-d:pk-mk-decomposition-lang
     mk-wf:wf-frontier/mk
     mk-d:decompose/mk
     mk-d:plug-D/mk
     mk-d:contract/mk
     mk-d:plug-C/mk
     mk-d:contract-label/mk
     mk-s:source-red/mk
     mk-l:redex-name->label/mk
     mk-d:decomposed-step/spec/mk
     mk-d:decomposed-step/direct/mk))

   (test-case
    "generated D decomposition is total, unique, and reconstructing in both instances"
    (redex-check
     toy-d:pk-toy-decomposition-lang
     F
     (match (judgment-holds (toy-d:decompose/toy F D) D)
       [(list decomposition)
        (equal? (term (toy-d:plug-D/toy ,decomposition))
                (term F))]
       [_ #f])
     #:attempts 1000)
    (redex-check
     mk-d:pk-mk-decomposition-lang
     F
     (match (judgment-holds (mk-d:decompose/mk F D) D)
       [(list decomposition)
        (equal? (term (mk-d:plug-D/mk ,decomposition))
                (term F))]
       [_ #f])
     #:attempts 1000))))

(module+ test
  (run-tests front-half-tests))
