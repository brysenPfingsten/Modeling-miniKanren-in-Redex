#lang racket

(require rackunit redex/reduction-semantics
         "source.rkt" "inspection.rkt"
         (prefix-in direct: "interpreter.rkt")
         (prefix-in cps: "cps.rkt")
         "../shared/kernel-equations.rkt"
         "../test-support/witnesses.rkt"
         "../test-support/corpus.rkt"
         "../shared/wf.rkt"
         "../shared/maps.rkt")

(define initial-state '(state () () () (label "initial")))
(define yes '(succeed (label "yes")))
(define no '(fail (label "no")))
(define fresh '(∃ (x:y) (x:y =? (sym "new") (label "new")) (label "fresh-y")))

;; These force a locally owned Delay internally; a lone public Delay retains
;; its ownership on Forced and would not exercise the changed entry protocol.
(define (owned-resumption body [binders '(x:x)])
  `((∃ ,binders (suspend ,body (label "pause")) (label "fresh-x"))
    ∨ ,no (label "choice")))

(define extra-goals
  (append
   (for/list ([body (in-list
                    (list yes no `(,yes ∨ ,yes (label "more"))
                          `(,no ∨ ,yes (label "reuse-right"))
                          `(suspend ,yes (label "nested"))
                          `(x:x =? (sym "old") (label "old")) fresh
                          `(suspend (x:x =? (sym "old") (label "old"))
                                    (label "nested-old"))))])
     (owned-resumption body))
   (list (owned-resumption yes '())
         `(,(owned-resumption yes) ∧ ,fresh (label "fresh-after-return"))
         `(,(owned-resumption `(x:x =? (sym "old") (label "old")))
           ∧ ,fresh (label "delayed-bind")))))

(define cases
  (append validation-witnesses
          (for/list ([goal (in-list (remove-duplicates (append search-corpus extra-goals)))]
                     [index (in-naturals)])
            (witness (string->symbol (format "goal-~a" index)) goal '(Owners)
                     initial-state "strict and allocation regression"))))

(define atomic-focus
  (term-match/single ScopeS
    [(in-hole C (eval owners a σ)) (list (term a) (term σ))]))

(define (source-work initial steps)
  (for/list ([before (in-list (cons initial (map second steps)))]
             [step (in-list steps)]
             #:when (equal? (first step) "eval-atom"))
    (atomic-focus before)))

(define (observe-work compute)
  (define reversed '())
  (define value
    (parameterize ([current-atomic-observer
                    (lambda (goal state) (set! reversed (cons (list goal state) reversed)))])
      (compute)))
  (values value (reverse reversed)))

(define (check-boundary descriptions compute initial)
  (define steps (retained-trace initial))
  (define expected (if (null? steps) initial (second (last steps))))
  (define-values (frontier work) (observe-work compute))
  (define actual (reify-frontier descriptions frontier))
  (check-equal? actual expected "exact Frontier, including unexecuted Delay bodies")
  (check-equal? work (source-work initial steps) "actual atom work before this boundary")
  (check-true (wf-s? actual))
  (check-true (wf-e? (Q-SE actual)))
  (check-true (wf-n? (Q-SN actual)))
  (values frontier actual))

(define (check-advances descriptions advance frontier source [fuel 100])
  (cond
    [(retained-observation? source) (void)]
    [else
     (when (zero? fuel) (error 'check-advances "unexpected unproductive fixture"))
     (define-values (next next-source)
       (check-boundary descriptions (lambda () (advance frontier)) `(advance ,source)))
     (check-advances descriptions advance next next-source (sub1 fuel))]))

(define (check-runner name run advance collect arity)
  (for ([sample (in-list cases)])
    (test-case (format "~a: ~a" name (witness-name sample))
      (define descriptions (make-weak-hasheq))
      (parameterize
          ([direct:current-closure-observer
            (lambda (family procedure captures)
              (when (member family '(resume-eval resume-merge resume-bind))
                (check-true (procedure-arity-includes? procedure arity)))
              (record-closure! descriptions family procedure captures))])
        (define initial
          (retained-query-initial (witness-goal sample)
                                  #:owners (witness-owners sample)
                                  #:state (witness-state sample)))
        (define-values (frontier source)
          (check-boundary
           descriptions
           (lambda () (run (witness-goal sample) #:owners (witness-owners sample)
                          #:state (witness-state sample)))
           initial))
        (check-advances descriptions advance frontier source)
        (define-values (_all _all-source)
          (check-boundary descriptions (lambda () (collect frontier)) `(collect ,source)))
        (void)))))

(module+ test
  (check-runner 'direct direct:run direct:resume-once direct:collect-all 2)
  (check-runner 'cps cps:run cps:resume-once cps:collect-all 3))
