#lang racket

(require rackunit redex/reduction-semantics
         "../../shared/stages/schema.rkt" "instances.rkt" "../../shared/stages/maps.rkt"
         "../../test-support/corpus.rkt"
         "../../test-support/stage-checks.rkt"
         "../../test-support/generated-goals.rkt"
         (prefix-in f: "../features.rkt")
         (prefix-in q: "../../shared/maps.rkt")
         (prefix-in s: "../source-s.rkt")
         (prefix-in e: "../source-e.rkt")
         (prefix-in n: "../source-n.rkt"))

(provide check-all-vertical check-inclusion)

(define (check-vertical initial step trace map-SE map-EN map-SN readback computation
                        stage-s stage-e stage-n)
  (define start (initial stage-s computation))
  (check-equal? (map-SE start) (initial stage-e (q:Q-SE computation)))
  (check-equal? (map-SN start) (initial stage-n (q:Q-SN computation)))
  (for ([configuration (in-list (cons start (map second (trace stage-s start #:fuel 10000))))])
    (define e-state (map-SE configuration))
    (define n-state (map-SN configuration))
    (check-equal? (map-EN e-state) n-state)
    (check-equal? (readback e-state) (q:Q-SE (readback configuration)))
    (check-equal? (readback n-state) (q:Q-SN (readback configuration)))
    (check-equal? (successor-list (map-edge (step stage-s configuration) map-SE))
                  (successor-list (step stage-e e-state)))
    (check-equal? (successor-list (map-edge (step stage-s configuration) map-SN))
                  (successor-list (step stage-n n-state)))
    (check-equal? (successor-list (map-edge (step stage-e e-state) map-EN))
                  (successor-list (step stage-n n-state)))))

(define (check-all-vertical computation [stage-s S] [stage-e E] [stage-n N])
  (check-vertical decompose d-step d-trace D-SE D-EN D-SN readback-D computation stage-s stage-e stage-n)
  (check-vertical initial-Z z-step z-trace Z-SE Z-EN Z-SN readback-Z computation stage-s stage-e stage-n)
  (check-vertical initial-M m-step m-trace M-SE M-EN M-SN readback-M computation stage-s stage-e stage-n)
  (check-vertical initial-B b-step b-trace B-SE B-EN B-SN readback-B computation stage-s stage-e stage-n))

(define (check-inclusion child parent computation)
  (for ([operations (in-list (list (list decompose d-step d-trace)
                                    (list initial-Z z-step z-trace)
                                    (list initial-M m-step m-trace)
                                    (list initial-B b-step b-trace)))])
    (match-define (list initial step trace) operations)
    (define start (initial child computation))
    (check-equal? start (initial parent computation))
    (for ([configuration (in-list (cons start (map second (trace child start))))])
      (check-equal? (successor-list (step child configuration))
                    (successor-list (step parent configuration))))))

(module+ test
  ;; Each feature coordinate executes all four downstream stages in each
  ;; native carrier. The corpora are executable witnesses, not a claim that
  ;; bounded enumeration is a general theorem or productivity proof.
  (for ([coordinate
         (in-list
          (list (list 'core core-corpus SCore f:strict-s-core-red ECore f:strict-e-core-red NCore f:strict-n-core-red)
                (list 'delay delay-corpus SDelay f:strict-s-delay-red EDelay f:strict-e-delay-red NDelay f:strict-n-delay-red)
                (list 'disjunction disjunction-corpus SDisjunction f:strict-s-disjunction-red
                      EDisjunction f:strict-e-disjunction-red NDisjunction f:strict-n-disjunction-red)
                (list 'search search-corpus S s:strict-s-red E e:strict-e-red N n:strict-n-red)))])
    (match-define (list feature goals stage-s source-s stage-e source-e stage-n source-n) coordinate)
    (for ([goal (in-list goals)] [index (in-naturals)])
      (define s-term `(render ,(s:s-initial goal)))
      (for ([row (in-list (list (list stage-s source-s s-term)
                                (list stage-e source-e (q:Q-SE s-term))
                                (list stage-n source-n (q:Q-SN s-term))))])
        (match-define (list stage relation computation) row)
        (test-case (format "~a/~a strict downstream squares ~a" feature (Stage-name stage) index)
          (check-row stage relation computation)))
      (test-case (format "~a direct stage Q squares and composition ~a" feature index)
        (check-all-vertical s-term stage-s stage-e stage-n))))

  ;; Feature inclusions are identity on native retained states and their exact
  ;; successor lists. The active Search interaction is not smuggled into a
  ;; lower coordinate by a full-language value predicate.
  (for ([row (in-list (list (list SCore SDelay SDisjunction S values)
                            (list ECore EDelay EDisjunction E q:Q-SE)
                            (list NCore NDelay NDisjunction N q:Q-SN)))])
    (match-define (list core delay disjunction search map-source) row)
    (for ([edge (in-list (list (list core delay core-corpus)
                               (list core disjunction core-corpus)
                               (list delay search delay-corpus)
                               (list disjunction search disjunction-corpus)))])
      (match-define (list child parent goals) edge)
      (test-case (format "feature inclusion ~a -> ~a at every native stage" (Stage-name child) (Stage-name parent))
        (for ([goal (in-list goals)])
          (check-inclusion child parent (map-source `(render ,(s:s-initial goal))))))))

  (for ([row (in-list (list (list SCore SDelay SDisjunction s:s-initial values)
                            (list ECore EDelay EDisjunction e:e-initial q:Q-SE)
                            (list NCore NDelay NDisjunction n:n-initial q:Q-SN)))])
    (match-define (list core delay disjunction initial map-source) row)
    (define suspend '(suspend (succeed (label "body")) (label "delay")))
    (define choice '((succeed (label "left")) ∨ (succeed (label "right")) (label "choice")))
    (for ([bad (in-list (list (list core suspend) (list core choice)
                              (list delay choice) (list disjunction suspend)))])
      (match-define (list stage goal) bad)
      (for ([run (in-list (list run-D run-Z run-M run-B))])
        (check-exn exn:fail:contract? (lambda () (run stage (initial goal))))))
    (define forbidden-delay
      (map-source `(Delay (Owners) ,(s:s-initial '(succeed (label "body"))))))
    (check-exn exn:fail:contract? (lambda () ((Stage-view core) forbidden-delay)))
    (check-exn exn:fail:contract? (lambda () ((Stage-view disjunction) forbidden-delay))))

  ;; Reuse the separately generated, scope-aware depth-4/5 source corpus.
  ;; Sparse ordered ownership, alias chains, and pending disequalities probe
  ;; the direct stage maps beyond their defining constructor witnesses.
  (for* ([goal (in-list generated-goals)] [sparse? (in-list '(#f #t))])
    (test-case (format "generated sparse=~a downstream stage squares: ~s" sparse? goal)
      (define owners
        (if sparse?
            '(Owners (Owner (u:2) (label "ancestor"))
                     (Owner () (label "empty-ancestor"))
                     (Owner (u:0 u:8) (label "shared")))
            '(Owners)))
      (define state
        (if sparse?
            '(state ((u:8 u:2)) ((u:2 (sym "avoid")))
                    ((u:8 =? u:2 (label "seed-alias"))) (label "initial"))
            '(state () () () (label "initial"))))
      (define computation `(render ,(s:s-initial goal #:owners owners #:state state)))
      (check-row S s:strict-s-red computation)
      (check-row E e:strict-e-red (q:Q-SE computation))
      (check-row N n:strict-n-red (q:Q-SN computation))
      (check-all-vertical computation)))

  (define initial-state '(state () () () (label "initial")))
  (define sparse
    `(render ,(s:s-initial
               '(∃ (x:q) (x:q =? (sym "new") (label "use")) (label "fresh"))
               #:owners '(Owners (Owner (u:9) (label "preexisting"))))))
  (define answer-local
    `(render
      (Yield (Owners (Owner (u:9) (label "shared")))
            (Answer (Owners (Owner (u:0) (label "head-only"))) ,initial-state)
            (eval (Owners)
                  (∃ (x:q) (x:q =? (sym "tail") (label "use")) (label "fresh"))
                  ,initial-state))))
  (for ([computation (in-list (list sparse answer-local))])
    (test-case "sparse and answer-local Owners are preserved through every stage"
      (check-row S s:strict-s-red computation)
      (check-row E e:strict-e-red (q:Q-SE computation))
      (check-row N n:strict-n-red (q:Q-SN computation))
      (check-all-vertical computation)))

  ;; Check the retained-frame support calculation against the independently
  ;; defined source context calculation at all intermediate zipper states.
  (for ([goal (in-list search-corpus)])
    (define start (initial-Z S `(render ,(s:s-initial goal))))
    (for ([configuration (in-list (cons start (map second (z-trace S start))))])
      (match-define (Z _ frames) configuration)
      (check-equal? (frame-support S frames)
                    (s:context-support/s (plug-frames (term hole) frames)))))

  ;; Certificates expose a nontrivial compressed corridor and reject missing,
  ;; wrong, extra, or reordered exact edges.
  (define start
    (initial-B S `(render ,(s:s-initial
                           '((succeed (label "left")) ∨ (succeed (label "right"))
                             (label "choice"))))))
  (match-define (list span next) (b-step S start))
  (check-equal? (Span-labels span) '("eval-disj" "admin"))
  (check-equal? (replay-span S (decode-BM start) span) (decode-BM next))
  (check-false (replay-span S (decode-BM start) (Span '("eval-conj" "admin"))))
  (check-not-equal? (replay-span S (decode-BM start) (Span '("eval-disj"))) (decode-BM next))
  (check-false (replay-span S (decode-BM start) (Span '("eval-disj" "admin" "admin"))))
  (check-exn exn:fail:contract? (lambda () (Span '())))
  (check-exn exn:fail:contract? (lambda () (Span '("admin" "eval-disj"))))

  ;; Explicit Delay and eager Yield distinguish values from pending work in
  ;; every row, independently of observer normalization.
  (for ([row (in-list (list (list S s:s-initial) (list E e:e-initial) (list N n:n-initial)))])
    (match-define (list stage initial) row)
    (define delay (initial '(suspend (succeed (label "later")) (label "delay"))))
    (for ([run (in-list (list run-D run-Z run-M run-B))])
      (check-true (Value? ((Stage-view stage) (run stage delay)))))
    (check-exn #rx"fuel exhausted" (lambda () (run-B stage delay #:fuel 0)))))
