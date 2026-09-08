#lang racket

(require rackunit redex/reduction-semantics
         "data.rkt" "source.rkt" "stages.rkt" "machine-correspondence.rkt"
         "administration.rkt"
         (only-in "readback.rkt" reify-frontier readback-call readback-halted)
         (prefix-in f: "machine.rkt")
         (prefix-in a: "../shared/stages/schema.rkt")
         (prefix-in maps: "../shared/stages/maps.rkt")
         (prefix-in q: "../shared/maps.rkt")
         "../shared/wf.rkt" "../shared/feature-schema.rkt"
         "../test-support/corpus.rkt" "../test-support/witnesses.rkt"
         "../test-support/frontiers.rkt")

;; These tests check configurations and individual prescribed transitions.
;; Neither the frame translation nor this harness searches toward a target.
;; Only native administration may be normalized on either side of a step.
(define observed-labels (make-hash))
(define observed-constructors (make-hash))
(define observed-controls (make-hash))
(define observed-dispatches (make-hash))

(define (record-dispatch! configuration)
  (define selected
    (match configuration
      [(f:Call 'return/d (list _ k)) k]
      [(f:Call 'resume/d (list resume _ _ _)) resume]
      [(f:Call 'continue/d (list continue _ _ _ _)) continue]
      [(f:Call 'outcome/d (list outcome _ _)) outcome]
      [(f:Call 'failure/d (list failure)) failure]
      [(f:Call 'success/d (list success _)) success]
      [_ #f]))
  (when selected
    (hash-set! observed-dispatches (vector-ref (struct->vector selected) 0) #t)))

(define (inspect-data! datum)
  (check-false (procedure? datum) "runtime configurations contain no closures")
  (match datum
    [(cons first rest) (inspect-data! first) (inspect-data! rest)]
    [(? struct?)
     (define fields (struct->vector datum))
     (define constructor (vector-ref fields 0))
     (check-not-equal? constructor 'struct:KPrefix)
     (hash-set! observed-constructors constructor #t)
     (for ([field (in-vector fields 1)]) (inspect-data! field))]
    [_
     (check-true (or (null? datum) (symbol? datum) (string? datum)
                     (number? datum) (boolean? datum))
                 "runtime fields belong to the first-order data grammar")]))

(define (check-native-shape native)
  (define source (a:readback-M native))
  (check-true (redex-match? ScopeS q source))
  (check-true (wf-s? source))
  (define (check-continuation continuation)
    (match continuation
      ['halt (void)]
      [(a:K frame rest)
       (check-not-equal? (a:Frame-kind frame) 'prefix)
       (check-continuation rest)]))
  (check-continuation (a:M-continuation native)))

(define (admin-normalize current [fuel 10000])
  (check-native-shape current)
  (cond
    [(a:m-admin? RetainedS current)
     (when (zero? fuel) (error 'admin-normalize "administrative fuel exhausted"))
     (match-define (list label next) (a:m-step RetainedS current))
     (check-equal? label "admin")
     (check-equal? (a:readback-M current) (a:readback-M next)
                   "native administration preserves the whole computation")
     (admin-normalize next (sub1 fuel))]
    [else current]))

(define (whole-readback current)
  (match current
    [(f:Call pc operands) (readback-call pc operands)]
    [(f:Halted value) (readback-halted value)]))

(define (check-configuration current)
  (inspect-data! current)
  (record-dispatch! current)
  (match current
    [(f:Call pc _) (hash-set! observed-controls pc #t)]
    [_ (void)])
  (define mapped (functional->M current))
  (define whole (whole-readback current))
  (check-equal? (a:readback-M mapped) whole
                "independent whole-tree and constructor translations agree")
  (check-true (wf-s? whole))
  (check-native-shape mapped)
  ;; These local checks establish structural readback squares. The matrix's
  ;; s-reference-tests.rkt independently checks the mapped E/N transitions.
  (define mapped-e (maps:M-SE mapped))
  (define mapped-n (maps:M-SN mapped))
  (check-equal? (maps:M-EN mapped-e) mapped-n)
  (check-equal? (a:readback-M mapped-e) (q:Q-SE whole))
  (check-equal? (a:readback-M mapped-n) (q:Q-SN whole))
  (check-true (wf-e? (a:readback-M mapped-e)))
  (check-true (wf-n? (a:readback-M mapped-n)))
  mapped)

(define (check-trace current reference [fuel 100000])
  (define mapped (check-configuration current))
  (check-equal? (admin-normalize mapped) reference)
  (match current
    [(f:Halted value)
     ;; More(Delay) is a genuine native terminal configuration, not an
     ;; exception that lets the harness pause a still-running oracle.
     (check-true (a:m-final? RetainedS reference))
     (check-false (a:m-step RetainedS reference))
     (check-equal? reference (a:M (reify-frontier value) 'halt))
     value]
    [_
     (when (zero? fuel) (error 'check-trace "functional fuel exhausted"))
     (define expected (functional-step-label current))
     (hash-set! observed-labels expected #t)
     (define next (f:step current))
     (define before-source (whole-readback current))
     (define after-source (whole-readback next))
     (define target (admin-normalize (functional->M next)))
     (define next-reference
       (match expected
         [#f
          (check-true (< (functional-admin-rank next)
                         (functional-admin-rank current))
                      "functional administration strictly decreases its structural rank")
          (check-equal? before-source after-source
                        "functional administration preserves whole-tree readback")
          (check-equal? reference target
                        "functional administration preserves the native checkpoint")
          reference]
         [_
          ;; This independently checks the raw contextual source relation,
          ;; rather than using the functional-to-M map as its own oracle.
          (check-equal?
           (apply-reduction-relation/tag-with-names retained-red before-source)
           (list (list expected after-source))
           "one functional semantic edge is one exact named source contraction")
          (match-define (list label native-next) (a:m-step RetainedS reference))
          (check-equal? label expected)
          (define normalized (admin-normalize native-next))
          (check-equal? normalized target
                        "one prescribed native contraction reaches the next checkpoint")
          normalized]))
     (check-trace next next-reference (sub1 fuel))]))

(define (check-operation initial source)
  (check-equal? (whole-readback initial) source)
  (check-trace initial (admin-normalize (a:initial-M RetainedS source))))

(define (check-boundaries frontier [fuel 100])
  (when (zero? fuel) (error 'check-boundaries "unexpected unproductive fixture"))
  (define native (reify-frontier frontier))
  (define collected
    (check-operation (f:Call 'collect/d (list frontier '() (KDone)))
                     `(collect ,native)))
  (check-true (retained-observation? (reify-frontier collected)))
  (define advanced
    (check-operation (f:Call 'advance/d (list frontier '() (KDone)))
                     `(advance ,native)))
  (cond
    [(pending? frontier) (check-boundaries advanced (sub1 fuel))]
    [else
     (check-equal? advanced frontier "advance is a no-op on a completed Frontier")
     (check-equal? collected frontier "collect is a no-op on a completed Frontier")]))

(define initial-state '(state () () () (label "initial")))
(define yes '(succeed (label "yes")))
(define no '(fail (label "no")))
(define fresh '(∃ (x:y) (x:y =? (sym "new") (label "new")) (label "fresh-y")))

;; A public Delay alone keeps Owners on Forced. These closed goals also
;; force a locally owned Delay internally and reach all three resumption
;; families with inherited names, unused allocations, and nested delays.
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
           ∧ ,fresh (label "delayed-bind"))
         `(,no ∧ (suspend ,yes (label "unreachable-delay"))
               (label "failed-bind")))))

(define (same-input? left right)
  (and (equal? (witness-goal left) (witness-goal right))
       (equal? (witness-owners left) (witness-owners right))
       (equal? (witness-state left) (witness-state right))))

(define cases
  (remove-duplicates
   (append validation-witnesses
           (for/list ([goal (in-list (append search-corpus extra-goals))]
                      [index (in-naturals)])
             (witness (string->symbol (format "corpus-~a" index)) goal '(Owners)
                      initial-state "strict scope and control regression")))
   same-input?))

(module+ test
  (for ([sample (in-list cases)])
    (test-case (format "configuration correspondence: ~a" (witness-name sample))
      (define frontier
        (check-operation
         (f:initial (witness-goal sample) #:owners (witness-owners sample)
                    #:state (witness-state sample))
         `(commit ,(witness-initial sample))))
      (check-boundaries frontier)))

  (test-case "every applicable source control family is witnessed"
    (check-true (hash-has-key? observed-labels #f))
    (check-equal?
     (sort (filter values (hash-keys observed-labels)) string<?)
     (sort (filter (lambda (label)
                     (not (string-prefix? label "render-")))
                   (feature-labels search))
           string<?)))

  (test-case "all continuation, resumption, and outcome constructors are exercised"
    (for ([constructor
           (in-list
            '(struct:Call struct:Halted struct:KDone struct:KConj
              struct:KDisjLeft struct:KDisjRight struct:KMergeYield
              struct:KBindHead struct:KBindTail struct:KMergeForced
              struct:KBindForced struct:KCommit struct:KCommitEmit
              struct:KAdvanceEmit struct:KAdvanceHistory struct:KAdvanceForced
              struct:KCollectEmit struct:KCollectHistory struct:KCollectResume
              struct:KCollectForced struct:GRight struct:REval struct:RMerge
              struct:RBind struct:FEmpty struct:SOne struct:Failure struct:Success))])
      (check-true (hash-has-key? observed-constructors constructor)
                  (format "uncovered data constructor: ~a" constructor))
      (unless (member constructor '(struct:Call struct:Halted))
        (check-true (hash-has-key? observed-dispatches constructor)
                    (format "unapplied data constructor: ~a" constructor))))
    (check-false (hash-has-key? observed-constructors 'struct:KPrefix)))

  (test-case "every generated program counter is exercised"
    (check-equal? (sort (hash-keys observed-controls) symbol<?)
                  (sort (map first f:signatures) symbol<?)))

  (test-case "invalid ancestry and phase configurations are rejected"
    (define owned '(Owners (Owner (u:0) (label "allocated"))))
    (define resume (REval yes initial-state))
    (define delay `(Delay ,owned ,resume))
    (define malformed
      (list
       ;; A support argument cannot invent an ancestor absent from the
       ;; structural continuation, even when the body never uses the name.
       (f:Call 'resume/d (list resume '(Owners) '(u:0) (KCommit (KDone))))
       (f:Call 'force/d (list delay '(u:1) (KCommit (KDone))))
       (f:Call 'force/d
               (list `(One (Owners) ,initial-state) '() (KCommit (KDone))))
       (f:Call 'eval/d
               (list yes initial-state '(Owners) '(u:0)
                     (KDisjRight `(One (Owners) ,initial-state)
                                 '(Owners) '(u:0) (KCommit (KDone)))))
       ;; KCollectResume's cache includes its own retained Forced Owners;
       ;; KMergeForced's inherited cache excludes its own merge Owners.
       (f:Call 'return/d
               (list '(Done (Owners)) (KCollectResume owned '() (KDone))))
       (f:Call 'return/d
               (list `(One (Owners) ,initial-state)
                     (KMergeForced `(One (Owners) ,initial-state)
                                   owned '(u:0) (KCommit (KDone)))))
       ;; Search cannot skip commitment and become a public halted result.
       (f:Call 'return/d (list `(One (Owners) ,initial-state) (KDone)))
       (f:Call 'return/d (list '(Done (Owners)) (KCommit (KDone))))
       (f:Halted `(One (Owners) ,initial-state))
       (f:Halted `(More (Delay (Owners) ,(lambda args '(Empty (Owners))))))
       (f:Call 'unknown/d '())))
    (for ([configuration (in-list malformed)])
      (check-exn exn:fail? (lambda () (functional->M configuration)))
      (check-exn exn:fail? (lambda () (whole-readback configuration))))))
