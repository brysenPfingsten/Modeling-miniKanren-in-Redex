#lang racket
(require rackunit "../test-support/witnesses.rkt" "partial-oracle.rkt" "../test-support/frontiers.rkt" "03-data.rkt" "correspondence.rkt"
         (only-in "machine-correspondence.rkt" functional-step-label)
         (prefix-in f: "04-machine.rkt")
         (prefix-in s: "../matrix/source-s.rkt")
         (prefix-in q: "../shared/maps.rkt")
         (prefix-in a: "../shared/stages/schema.rkt")
         (prefix-in rows: "../matrix/stages/instances.rkt")
         (prefix-in maps: "../shared/stages/maps.rkt"))
(provide readback check-transition-trace)

(define (readback configuration)
  (match configuration
    [(f:Call pc operands) (readback-call pc operands)]
    [(f:Halted value) (readback-halted value)]))

(define (finish-reference current)
  (match (a:m-step rows:S current)
    [#f
     (check-true (a:m-final? rows:S current))
     (a:readback-M current)]
    [(list label next)
     (check-equal? label "admin")
     (check-equal? (a:readback-M next) (a:readback-M current))
     (check-equal? (a:m-step rows:E (maps:M-SE current)) (list label (maps:M-SE next)))
     (check-equal? (a:m-step rows:N (maps:M-SN current)) (list label (maps:M-SN next)))
     (finish-reference next)]))

;; Traverse only administrative edges before the one prescribed contraction.
;; Matching the future readback cannot authorize another source reduction.
(define (contract-reference current expected [fuel 200] [labels '()])
  (when (zero? fuel) (error 'contract-reference "administrative fuel exhausted"))
  (match (a:m-step rows:S current)
    [#f (error 'contract-reference "reference halted before ~a" expected)]
    [(list label next)
     (check-equal? (a:m-step rows:E (maps:M-SE current)) (list label (maps:M-SE next)))
     (check-equal? (a:m-step rows:N (maps:M-SN current)) (list label (maps:M-SN next)))
     (check-equal? (maps:M-EN (maps:M-SE current)) (maps:M-SN current))
     (match label
       ["admin"
        (check-equal? (a:readback-M current) (a:readback-M next))
        (contract-reference next expected (sub1 fuel) (cons label labels))]
       [_
        (check-equal? label expected)
        (values next (reverse (cons label labels)))])]))

(define (check-transition-trace current reference [fuel 100000] [spans '()])
  (define before (readback current))
  (check-equal? before (a:readback-M reference))
  ;; This square uses the existing field-wise machine maps; both sides retain
  ;; pending siblings, future bind goals, and suspended computations.
  (define canonical (a:initial-M rows:S before))
  (check-equal? (maps:M-SE canonical) (a:initial-M rows:E (q:Q-SE before)))
  (check-equal? (maps:M-SN canonical) (a:initial-M rows:N (q:Q-SN before)))
  (check-equal? (q:Q-SN before) (q:Q-EN (q:Q-SE before)))
  (match current
    [(f:Halted value)
     ;; Even More(Delay) is now an actual source Frontier normal form. The
     ;; refocused machine finishes by its own rules, without an external cut.
     (check-equal? (finish-reference reference) before)
     (values value (reverse spans))]
    [_
     (when (zero? fuel) (error 'check-transition-trace "functional fuel exhausted"))
     (define next (f:step current))
     (define after (readback next))
     (define-values (reference* labels)
       (match (functional-step-label current)
         [#f (values reference '())]
         [expected (contract-reference reference expected)]))
     (check-equal? (a:readback-M reference*) after)
     (check-transition-trace next reference* (sub1 fuel) (cons labels spans))]))

(define (check-operation initial)
  (define source (readback initial))
  (check-transition-trace initial (a:initial-M rows:S source)))

(define (check-boundary-operations frontier [fuel 1000])
  (when (zero? fuel) (error 'check-boundary-operations "boundary fuel exhausted"))
  (define-values (_completed collect-spans)
    (check-operation (f:Call 'collect/d (list frontier (KDone)))))
  (define-values (next advance-spans)
    (check-operation (f:Call 'advance/d (list frontier (KDone)))))
  (append collect-spans advance-spans
          (if (pending? frontier)
              (check-boundary-operations next (sub1 fuel))
              (begin (check-equal? next frontier) '()))))

(module+ test
  (define all-spans
    (for/list ([w (in-list validation-witnesses)])
      (define initial
        (f:initial (witness-goal w) #:owners (witness-owners w)
                    #:state (witness-state w)))
      (check-equal? (readback initial) `(commit ,(witness-initial w)))
      (define-values (frontier run-spans) (check-operation initial))
      (append run-spans (check-boundary-operations frontier))))
  ;; Every semantic functional step now has one named source contraction;
  ;; the remaining functional steps only dispatch or reconstruct contexts.
  (define flat-spans (apply append all-spans))
  (check-not-false (member '() flat-spans))
  (check-true (for/and ([span (in-list flat-spans)])
                (<= (length (filter (lambda (label) (not (equal? label "admin"))) span)) 1)))
  ;; Captured supports are proof-relevant checks, not unused cached fields.
  (check-false
   (valid-call? 'eval/d
                (list '(succeed (label "bad")) '(state () () () (label "initial"))
                      '(Owners) '(u:99) (KCommit (KDone)))))
  (check-exn #rx"disagrees with structural ancestry"
             (lambda ()
               (readback-halted `(More (Delay (Owners) ,(REval '(succeed (label "bad"))
                                                               '(state () () () (label "initial"))
                                                               '(u:99)))))))
  (check-exn #rx"disagrees with structural ancestry"
             (lambda ()
               (readback-halted
                `(More (Delay (Owners (Owner (u:9 u:2) (label "ancestry")))
                              ,(REval '(succeed (label "bad"))
                                      '(state () () () (label "initial")) '(u:2 u:9)))))))
  (check-false
   (valid-call? 'return/d
                (list '(One (Owners) (state () () () (label "initial")))
                      (KDisjRight `(Delay (Owners)
                                         ,(REval '(succeed (label "saved"))
                                                 '(state () () () (label "initial"))
                                                 '(u:1)))
                                  '(Owners) '() (KCommit (KDone))))))
  (check-false
   (valid-call? 'outcome/d
                (list (Failure) (FEmpty '(Owners) (KCommit (KDone)))
                      (SOne '(Owners (Owner () (label "wrong"))) (KCommit (KDone))))))
  ;; Disjoint grammars prevent caller-selected reinterpretation of a value.
  (check-false
   (valid-call? 'return/d (list '(Done (Owners)) (KCommit (KDone)))))
  (check-false
   (valid-call? 'return/d (list '(Empty (Owners)) (KDone))))
  (check-exn exn:fail?
             (lambda ()
               (reify-frontier '(More (One (Owners) (state () () () (label "bad")))))))
  (check-exn exn:fail?
             (lambda ()
               (reify-search '(Emit (Owners)
                                    (Answer (Owners) (state () () () (label "bad")))
                                    (Done (Owners)))))))
