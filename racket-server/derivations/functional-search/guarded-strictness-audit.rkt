#lang racket

(require racket/list
         rackunit
         redex/reduction-semantics
         (prefix-in direct: "direct-interpreter.rkt")
         (prefix-in rail:
                    "../../src/search-lattice/reduction-relations/rail-red.rkt"))

#|
This is a diagnostic witness, not a production conformance test.

It records the present disconnect between:

  * the guarded, strict direct interpreter, where only Delay suspends; and
  * the production whole-tree rail semantics, where DisjL leaves its right
    Work sibling untouched while the left branch can commit an answer.

The witness is:

  success(A) ∨ (p ∧ q ∧ suspend h)

The direct interpreter executes p and q before returning the first Search
observation.  The Redex semantics commits A before it starts the right-hand
conjunction.  Both still have the same completed finite frontier shape.
|#

(provide guarded-redex-witness
         trace/deterministic)

(define initial-redex-state
  (term (state () () () (label "initial"))))

(define guarded-redex-witness
  (term
   (More
    (Work
     (Owners)
     ((succeed (label "A"))
      ∨
      (((nat 0) =? (nat 0) (label "p"))
       ∧
       (((nat 1) =? (nat 1) (label "q"))
        ∧
        (suspend (succeed (label "h")) (label "delay"))
        (label "q-then-delay"))
       (label "p-then-rest"))
      (label "choice"))
     ,initial-redex-state))))

(define (trace/deterministic relation configuration [fuel 64])
  (cond
    [(zero? fuel)
     (values '() configuration 'fuel)]
    [else
     (match
       (apply-reduction-relation/tag-with-names relation configuration)
       ['()
        (values '() configuration 'done)]
       [(list (list name next))
        (define-values (names final status)
          (trace/deterministic relation next (sub1 fuel)))
        (values (cons (~a name) names) final status)]
       [successors
        (error 'trace/deterministic
               "expected exactly one raw proof, got ~e"
               successors)])]))

(module+ test
  (define-values (redex-names _redex-final redex-status)
    (trace/deterministic rail:rail-red guarded-redex-witness))

  (check-equal? redex-status 'done)
  (check-equal?
   redex-names
   '("expand-disjunction"
     "succeed"
     "commit-choice-answer"
     "expand-conjunction"
     "unify-success"
     "conj-return"
     "expand-conjunction"
     "unify-success"
     "conj-return"
     "suspend-goal"
     "force-delay"
     "succeed"
     "finish-success"))

  (define commit-index
    (index-of redex-names "commit-choice-answer"))
  (define right-work-index
    (index-of redex-names "expand-conjunction"))
  (check-true (< commit-index right-work-index))

  (define direct-events '())

  (define (note! event)
    (set! direct-events (cons event direct-events)))

  (define (recording-put event value)
    (direct:Atom
     (lambda (state)
       (note! event)
       (direct:success-outcome (struct-copy direct:State state [tag value])))
     event))

  (define (render/trace search)
    (match search
      [(direct:Empty next)
       (note! 'done)
       (direct:Done next)]
      [(direct:One state)
       (note! 'last)
       (direct:Last (direct:Answer state))]
      [(direct:Yield state rest)
       (note! 'emit)
       (direct:Emit (direct:Answer state)
                    (render/trace rest))]
      [(direct:Delay resume)
       (note! 'force)
       (direct:Forced
        (render/trace (resume)))]))

  (define direct-witness
    (direct:Disj
     (direct:put 'A)
     (direct:Conj
      (recording-put 'p 'P)
      (direct:Conj
       (recording-put 'q 'Q)
       (direct:Suspend (direct:put 'B) 'delay)
       'q-then-delay)
      'p-then-rest)
     'choice))

  (define direct-search
    (direct:run-search direct-witness))

  ;; Pure work preceding the semantic Delay has already happened.  The body
  ;; beneath Delay has not.
  (check-equal? (reverse direct-events) '(p q))
  (match direct-search
    [(direct:Yield _ (? direct:Delay?))
     (void)]
    [other
     (fail-check
      (format "expected Yield followed by Delay, got ~e" other))])

  (define direct-frontier
    (render/trace direct-search))
  (check-equal?
   (direct:frontier-shape direct-frontier)
   '(Emit A (Forced (Last B))))
  (check-equal?
   (reverse direct-events)
   '(p q emit force last)))
