#lang racket

(require rackunit redex/reduction-semantics
         "../../shared/stages/schema.rkt" "instances.rkt" "tests.rkt" "../../test-support/stage-checks.rkt"
         "../../test-support/corpus.rkt"
         (prefix-in q: "../../shared/maps.rkt")
         (prefix-in f: "../features.rkt")
         (prefix-in s: "../source-s.rkt")
         (prefix-in e: "../source-e.rkt")
         (prefix-in n: "../source-n.rkt")
         (only-in "../../test-support/witnesses.rkt"
                  validation-witnesses witness-name witness-initial)
         (only-in "../../test-support/frontiers.rkt" pending?))

;; Use the existing independently checked D/R, Z/M, B/M, and S/E/N squares
;; on the new source operations. No runner stops at an externally chosen tip.
(define (check-operation computation
                         [stage-s S] [source-s s:strict-s-red]
                         [stage-e E] [source-e e:strict-e-red]
                         [stage-n N] [source-n n:strict-n-red])
  (check-row stage-s source-s computation)
  (check-row stage-e source-e (q:Q-SE computation))
  (check-row stage-n source-n (q:Q-SN computation))
  (check-all-vertical computation stage-s stage-e stage-n)
  (define frontier (run-M stage-s computation))
  (check-true (s:s-frontier? frontier))
  (check-equal? (apply-reduction-relation source-s frontier) '())
  (check-true (DFinal? (decompose stage-s frontier)))
  (check-false (z-step stage-s (initial-Z stage-s frontier)))
  (check-true (m-final? stage-s (initial-M stage-s frontier)))
  (check-false (m-step stage-s (initial-M stage-s frontier)))
  (check-false (b-step stage-s (initial-B stage-s frontier)))
  frontier)

(define (check-boundaries frontier completed [fuel 100])
  (when (zero? fuel) (error 'check-boundaries "too many public boundaries"))
  (check-equal? (check-operation `(collect ,frontier)) completed)
  (define next (check-operation `(advance ,frontier)))
  (if (pending? frontier)
      (check-boundaries next completed (sub1 fuel))
      (begin
        (check-equal? next frontier)
        (check-equal? frontier completed))))

(module+ test
  ;; A source-level pending prefix independently derives its own frame. Its
  ;; saved owners govern allocation while the body runs, then attach only
  ;; when that body returns Search. No functional continuation is imported.
  (define outer-owners '(Owners (Owner (u:9) (label "outer"))))
  (define saved-owners '(Owners (Owner (u:2 u:0) (label "saved"))))
  (define state '(state () () () (label "initial")))
  (define fresh-body
    `(eval (Owners)
           (∃ (x:q) (x:q =? (sym "answer") (label "use")) (label "fresh"))
           ,state))
  (define pending `(Forced ,outer-owners (commit (prefix ,saved-owners ,fresh-body))))
  (for ([coordinate
         (in-list
          (list (list SDelay f:strict-s-delay-red
                      EDelay f:strict-e-delay-red NDelay f:strict-n-delay-red)
                (list S s:strict-s-red E e:strict-e-red N n:strict-n-red)))])
    (match-define (list stage-s source-s stage-e source-e stage-n source-n) coordinate)
    (test-case (format "pending prefix is derived at every stage: ~a" (Stage-name stage-s))
      (define continuation
        (K (Frame 'prefix `(prefix ,saved-owners) '() saved-owners)
           (K (Frame 'commit '(commit) '() #f)
              (K (Frame 'forced `(Forced ,outer-owners) '() outer-owners) 'halt))))
      (check-equal? (initial-M stage-s pending) (M fresh-body continuation))
      (check-equal? (decompose stage-s pending)
                    (D fresh-body (Z-frames (decode-MZ (M fresh-body continuation)))))
      (check-equal? (initial-B stage-s pending) (BRun fresh-body continuation))
      (check-equal? (continuation-support stage-s continuation) '(u:9 u:2 u:0))
      (check-equal? (s:context-support/s (readback-M (M (term hole) continuation)))
                    '(u:9 u:2 u:0))
      ;; Sparse names make loss of the prefix observable: the first unused
      ;; name is u:1, while omitting the saved owners would allocate u:0.
      (match-define (list "allocate-fresh" (M allocated kept))
        (m-step stage-s (initial-M stage-s pending)))
      (check-equal? kept continuation)
      (check-equal?
       allocated
       `(eval (Owners (Owner (u:1) (label "fresh")))
              (u:1 =? (sym "answer") (label "use")) ,state))
      (check-equal?
       (map first (d-trace stage-s (decompose stage-s pending)))
       '("allocate-fresh" "eval-atom" "prefix-value" "commit-one"))
      (for ([row (in-list (list (list stage-e q:Q-SE) (list stage-n q:Q-SN)))])
        (match-define (list stage map-source) row)
        (check-equal?
         (M-continuation (initial-M stage (map-source pending)))
         (K (Frame 'prefix '(prefix) '() #f)
            (K (Frame 'commit '(commit) '() #f)
               (K (Frame 'forced '(Forced) '() #f) 'halt)))))
      (check-operation pending stage-s source-s stage-e source-e stage-n source-n)))
  (for ([row (in-list (list (list SDelay S values)
                            (list EDelay E q:Q-SE)
                            (list NDelay N q:Q-SN)))])
    (match-define (list child parent map-source) row)
    (test-case (format "pending prefix preserves feature inclusion: ~a" (Stage-name child))
      (check-inclusion child parent (map-source pending))))

  (test-case "internal force creates a pending prefix before evaluating the body"
    (define computation `(Forced ,outer-owners (commit (force (Delay ,saved-owners ,fresh-body)))))
    (match-define (M _ continuation) (initial-M S computation))
    (match-define (list "force-delay" next) (m-step S (initial-M S computation)))
    (check-equal? next (M `(prefix ,saved-owners ,fresh-body) continuation))
    (check-equal?
     (m-step S next)
     (list "admin" (M fresh-body (K (Frame 'prefix `(prefix ,saved-owners) '() saved-owners)
                                    continuation))))
    (check-operation computation)
    (check-equal? (map first (d-trace S (decompose S computation)))
                  '("force-delay" "allocate-fresh" "eval-atom" "prefix-value" "commit-one")))

  (test-case "public resumption and delayed bind expose the stored computation directly"
    (define delay `(Delay ,saved-owners ,fresh-body))
    (for ([computation (in-list (list `(advance (More ,delay))
                                     `(collect (More ,delay))
                                     `(render ,delay)
                                     `(collect (commit (bind (Owners) ,delay
                                                            (succeed (label "bound")))))))])
      (check-operation computation)
      (define labels (map first (d-trace S (decompose S computation))))
      (check-false (member "force-delay" labels))
      (check-false (member "prefix-value" labels))))

  (test-case "returning through prefix preserves a newly produced Delay boundary"
    (define body
      `(eval (Owners)
             (suspend (∃ (x:q) (x:q =? (sym "later") (label "use")) (label "fresh"))
                      (label "inner-delay"))
             ,state))
    (define computation `(commit (force (Delay ,saved-owners ,body))))
    (check-true (pending? (check-operation computation)))
    (check-equal? (map first (d-trace S (decompose S computation)))
                  '("force-delay" "eval-suspend" "prefix-value" "commit-delay")))

  (for ([w (in-list validation-witnesses)])
    (test-case (format "explicit commit/advance/collect R-D-Z-M-B and S/E/N: ~a"
                       (witness-name w))
      (define evaluation (witness-initial w))
      (define frontier (check-operation `(commit ,evaluation)))
      ;; Legacy render remains the separate full-consumption comparison.
      (define completed (s:s-run `(render ,evaluation)))
      (check-boundaries frontier completed)))

  ;; Commitment and each consumer are genuine coordinates in all twelve
  ;; native feature cells; lower feature languages keep their own domains.
  (for ([coordinate
         (in-list
          (list
           (list core-corpus SCore f:strict-s-core-red
                 ECore f:strict-e-core-red NCore f:strict-n-core-red)
           (list delay-corpus SDelay f:strict-s-delay-red
                 EDelay f:strict-e-delay-red NDelay f:strict-n-delay-red)
           (list disjunction-corpus SDisjunction f:strict-s-disjunction-red
                 EDisjunction f:strict-e-disjunction-red NDisjunction f:strict-n-disjunction-red)
           (list search-corpus S s:strict-s-red E e:strict-e-red N n:strict-n-red)))])
    (match-define (list goals stage-s source-s stage-e source-e stage-n source-n) coordinate)
    (for ([goal (in-list goals)])
      (test-case (format "native feature observation operations: ~a ~s" (Stage-name stage-s) goal)
        (define (check computation)
          (check-operation computation stage-s source-s stage-e source-e stage-n source-n))
        (define frontier (check `(commit ,(s:s-initial goal))))
        (define next (check `(advance ,frontier)))
        (define complete (check `(collect ,frontier)))
        (check-equal? (check `(collect ,next)) complete)
        (check-equal? complete (s:s-run `(render ,(s:s-initial goal))))))))
