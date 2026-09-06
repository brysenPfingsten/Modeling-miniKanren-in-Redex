#lang racket

(require rackunit "03-data.rkt" "../test-support/witnesses.rkt" "partial-oracle.rkt" "../test-support/frontiers.rkt"
         "machine-correspondence.rkt"
         (only-in "correspondence.rkt" reify-frontier readback-call readback-halted)
         (prefix-in f: "04-machine.rkt")
         (prefix-in a: "../shared/stages/schema.rkt")
         (prefix-in rows: "../matrix/stages/instances.rkt")
         (prefix-in maps: "../shared/stages/maps.rkt")
         "../shared/feature-schema.rkt"
         (prefix-in q: "../shared/maps.rkt"))

;; All phase alignment is in this test relation. functional->M itself neither
;; takes administrative steps nor calls decomposition or whole-tree readback.
(define (check-native-edge current label next)
  (check-equal? (a:m-step rows:E (maps:M-SE current))
                (list label (maps:M-SE next)))
  (check-equal? (a:m-step rows:N (maps:M-SN current))
                (list label (maps:M-SN next)))
  (check-equal? (maps:M-EN (maps:M-SE current)) (maps:M-SN current)))

(define (admin-normalize current [fuel 100000])
  (cond
    [(a:m-admin? rows:S current)
     (when (zero? fuel) (error 'admin-normalize "administrative fuel exhausted"))
     (match-define (list label next) (a:m-step rows:S current))
     (check-equal? label "admin")
     (check-native-edge current label next)
     (admin-normalize next (sub1 fuel))]
    [else current]))

;; There is no target-directed search. A classified semantic transition must
;; take exactly one named source step, followed only by native administration.
(define (source-step current target expected)
  (match expected
    [#f
     (check-equal? current target "functional administration preserves the native checkpoint")
     (values current '())]
    [_
     (match-define (list label next) (a:m-step rows:S current))
     (check-equal? label expected)
     (check-native-edge current label next)
     (define normalized (admin-normalize next))
     (check-equal? normalized target "one source contraction reaches the next native checkpoint")
     (values normalized (list label))]))

(define (whole-readback current)
  (match current
    [(f:Call pc operands) (readback-call pc operands)]
    [(f:Halted value) (readback-halted value)]))

(define (check-direct-trace current reference [fuel 100000] [spans '()])
  (define mapped (functional->M current))
  ;; The direct frame map agrees with the separately defined whole-tree map,
  ;; but this equality does not define either map or the machine relation.
  (check-equal? (a:readback-M mapped) (whole-readback current))
  (check-equal? (maps:M-EN (maps:M-SE mapped)) (maps:M-SN mapped))
  (check-equal? (a:readback-M (maps:M-SE mapped)) (q:Q-SE (a:readback-M mapped)))
  (check-equal? (a:readback-M (maps:M-SN mapped)) (q:Q-SN (a:readback-M mapped)))
  (check-equal? (admin-normalize mapped) reference)
  (match current
    [(f:Halted value)
     ;; Partial frontiers are native terminal states, including More(Delay).
     ;; There is no harness exception that pauses a still-running oracle.
     (check-true (a:m-final? rows:S reference))
     (check-false (a:m-step rows:S reference))
     (check-true (a:m-final? rows:E (maps:M-SE reference)))
     (check-true (a:m-final? rows:N (maps:M-SN reference)))
     (check-equal? reference (a:M (reify-frontier value) 'halt))
     (values value (reverse spans))]
    [_
     (when (zero? fuel) (error 'check-direct-trace "functional fuel exhausted"))
     (define next (f:step current))
     (define target (admin-normalize (functional->M next)))
     (define-values (reference* labels)
       (source-step reference target (functional-step-label current)))
     (check-direct-trace next reference* (sub1 fuel) (cons labels spans))]))

(define (check-operation initial source)
  (define reference (admin-normalize (a:initial-M rows:S source)))
  (define-values (value spans) (check-direct-trace initial reference))
  (define expected (reify-frontier value))
  ;; The other syntactic stages terminate by their own native finality rules.
  (check-equal? (a:run-D rows:S source) expected)
  (check-equal? (a:run-Z rows:S source) expected)
  (check-equal? (a:run-B rows:S source) expected)
  (values value spans))

(define (check-boundaries frontier [fuel 1000])
  (when (zero? fuel) (error 'check-boundaries "boundary fuel exhausted"))
  (define native (reify-frontier frontier))
  (define-values (_done collect-spans)
    (check-operation (f:Call 'collect/d (list frontier (KDone))) `(collect ,native)))
  (define-values (next advance-spans)
    (check-operation (f:Call 'advance/d (list frontier (KDone))) `(advance ,native)))
  (append collect-spans advance-spans
          (if (pending? frontier)
              (check-boundaries next (sub1 fuel))
              (begin (check-equal? next frontier) '()))))

(module+ test
  ;; A failed left operand must finish bind without evaluating its right goal.
  (define failed-bind
    '((fail (label "left-failure")) ∧ (suspend (succeed (label "unreachable"))
                                             (label "unreachable-delay"))
      (label "empty-bind")))
  (define-values (failed-result failed-spans)
    (check-operation (f:initial failed-bind)
                     `(commit (eval (Owners) ,failed-bind (state () () () (label "initial"))))))
  (check-equal? failed-result '(Done (Owners)))
  (define spans
    (append failed-spans
     (apply append
           (for/list ([w (in-list validation-witnesses)])
             (define initial
               (f:initial (witness-goal w) #:owners (witness-owners w)
                          #:state (witness-state w)))
             (define source `(commit ,(witness-initial w)))
             (define-values (frontier run-spans) (check-operation initial source))
             (append run-spans (check-boundaries frontier))))))
  (check-not-false (member '() spans))
  (check-true (andmap (lambda (span) (<= (length span) 1)) spans))
  (check-equal?
   (sort (remove-duplicates (apply append spans)) string<?)
   (sort (filter (lambda (label) (not (string-prefix? label "render-")))
                 (feature-labels search)) string<?))

  ;; KPrefix now maps to the frame independently derived from prefix(O,E).
  ;; The resumed control retains its own empty Owners until Search returns.
  (define added '(Owners (Owner (u:9) (label "forced-owner"))))
  (define state '(state () () () (label "initial")))
  (define goal '(∃ (x:inner) (x:inner =? u:9 (label "alias")) (label "inner-owner")))
  (define control `(eval (Owners) ,goal ,state))
  (define pending
    (f:Call 'eval/d (list goal state '(Owners) '(u:9) (KPrefix added (KCommit (KDone))))))
  (define native (a:initial-M rows:S `(commit (prefix ,added ,control))))
  (check-equal? (functional->M pending) native)
  (check-equal? (a:M-control native) control)
  (check-match (a:M-continuation native)
               (a:K (a:Frame 'prefix _ '() (== added))
                    (a:K (a:Frame 'commit _ '() #f) 'halt)))
  (define-values (_result prefix-spans)
    (check-operation
     (f:Call 'force/d (list `(Delay ,added ,(REval goal state '(u:9)))
                           (KCommit (KDone))))
     `(commit (force (Delay ,added ,control)))))
  (check-equal? (apply append prefix-spans)
                '("force-delay" "allocate-fresh" "eval-atom" "prefix-value" "commit-one")))
