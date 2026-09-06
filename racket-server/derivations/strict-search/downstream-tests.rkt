#lang racket

(require rackunit redex/reduction-semantics
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in r: "source.rkt")
         (prefix-in d: "decomposition.rkt")
         (prefix-in z: "refocused.rkt")
         (prefix-in m: "machine.rkt")
         (prefix-in b: "compressed.rkt")
         (only-in "tests.rkt" finite-goals))

;; Fresh bodies in finite-goals return already-existing goal syntax, allowing
;; exact callback replay. The allocating closure-producing witness below is
;; checked by full resulting State and work trace, not procedure identity.
(define goals (append finite-goals (list direct:nested-rail-witness)))

(define (check-D configuration [fuel 5000])
  (define before (d:readback configuration))
  (check-equal? (d:readback (d:decompose before)) before)
  (match (d:decomposed-step/tagged configuration)
    [#f (check-true (or (r:search-value? before) (r:observation-value? before)))]
    [(list label next)
     (when (zero? fuel) (error 'check-D "fuel exhausted"))
     ;; Complete raw successor/proof list: no deduplication or endpoint-only
     ;; comparison can conceal overlapping context rules here.
     (check-equal?
      (apply-reduction-relation/tag-with-names r:strict-red before)
      (list (list label (d:readback next))))
     (check-D next (sub1 fuel))]))

(define (check-ZM configuration [fuel 5000])
  (define machine (m:encode-ZM configuration))
  (check-equal? (m:decode-MZ machine) configuration)
  (check-equal? (m:encode-ZM (m:decode-MZ machine)) machine)
  (match-define (z:Focus control frames) configuration)
  (check-equal? (m:readback-M machine) (z:plug control frames))
  (match* ((z:machine-step/tagged configuration) (m:machine-step/tagged machine))
    [(#f #f) (check-true (m:machine-final? machine))]
    [((list label next) (list actual target))
     (when (zero? fuel) (error 'check-ZM "fuel exhausted"))
     (check-equal? label actual)
     (check-equal? (m:encode-ZM next) target)
     (check-equal? (m:decode-MZ target) next)
     (check-ZM next (sub1 fuel))]
    [(left right) (fail-check (format "Z/M successor mismatch: ~e / ~e" left right))]))

(define (check-B configuration [fuel 5000])
  (check-false (m:machine-admin? (b:decode-BM configuration)))
  (check-true (b:compression-square? configuration))
  (match (b:compressed-step/tagged configuration)
    [#f (check-true (b:BFinal? configuration))]
    [(list span next)
     (when (zero? fuel) (error 'check-B "fuel exhausted"))
     (define before (b:readback-B configuration))
     (check-equal? (length (b:semantic-labels span)) 1)
     (check-equal?
      (apply-reduction-relation/tag-with-names r:strict-red before)
      (list (list (first (b:semantic-labels span)) (b:readback-B next))))
     (check-B next (sub1 fuel))]))

(define (identity tag) (direct:Atom direct:success-outcome tag))

(define eager-sibling
  (direct:Disj
   (direct:put 'A)
   (direct:Conj (identity 'p)
                (direct:Conj (identity 'q)
                             (direct:Suspend (identity 'h) 'delay)
                             'then-delay)
                'right)
   'choice))

(define eager-bind
  (direct:Conj
   (direct:Disj (direct:put 'A) (direct:put 'B) 'choice)
   (direct:Conj (identity 'continuation)
                (direct:Suspend (identity 'resumed) 'delay)
                'body)
   'bind))

(define (record-kernel events)
  (lambda (goal state)
    (match goal
      [(direct:Atom _ tag)
       (set-box! events (cons (list tag (direct:State-tag state)) (unbox events)))]
      [_ (void)])
    (direct:basic-kernel goal state)))

(define (b-event-trace goal)
  (define events (box '()))
  (define K
    (lambda (atomic state)
      (match atomic
        [(direct:Atom _ (and tag (or 'p 'q 'h)))
         (set-box! events (cons tag (unbox events)))]
        [_ (void)])
      (direct:basic-kernel atomic state)))
  (define (visit configuration)
    (match (b:compressed-step/tagged configuration #:kernel K)
      [#f (reverse (unbox events))]
      [(list span next)
       (match (b:semantic-labels span)
         ['("render-yield") (set-box! events (cons 'emit (unbox events)))]
         ['("render-delay") (set-box! events (cons 'force (unbox events)))]
         ['("render-one") (set-box! events (cons 'last (unbox events)))]
         ['("render-empty") (set-box! events (cons 'done (unbox events)))]
         [_ (void)])
       (visit next)]))
  (visit (b:initial-compressed goal)))

(module+ test
  (for ([goal (in-list goals)] [index (in-naturals)])
    (test-case (format "D/source exact step list, ~a" index)
      (check-D (d:initial-decomposition goal)))
    (test-case (format "Z/M exact representation and transition, ~a" index)
      (check-ZM (z:initial-machine goal)))
    (test-case (format "B direct/spec/exact replay square, ~a" index)
      (check-B (b:initial-compressed goal)))
    (test-case (format "strict downstream complete traces and observations, ~a" index)
      (define expected (direct:run goal))
      (check-equal? (d:run goal) expected)
      (check-equal? (m:run goal) expected)
      (check-equal? (b:run goal) expected)
      (define source-labels (map first (r:trace `(render ,(r:initial goal)))))
      (define d-labels (map first (d:trace (d:initial-decomposition goal))))
      (define m-labels (map first (m:trace (m:initial-machine goal))))
      (define b-spans (map first (b:trace (b:initial-compressed goal))))
      (check-equal? d-labels source-labels)
      (check-equal? (append-map b:Span-labels b-spans) m-labels)
      (check-equal? (append-map b:semantic-labels b-spans) source-labels)))

  (for ([goal (in-list (list eager-sibling eager-bind))])
    (check-D (d:initial-decomposition goal))
    (check-ZM (z:initial-machine goal))
    (check-B (b:initial-compressed goal)))
  (check-equal? (b-event-trace eager-sibling) '(p q emit force h last))

  (define engines
    (list (list 'D d:run d:run-search)
          (list 'M m:run m:run-search)
          (list 'B b:run b:run-search)))
  (define (omega) (direct:Fresh 0 omega 'unguarded))
  (define unguarded (direct:Disj (direct:put 'A) (omega) 'strict-right))
  (define guarded
    (direct:Disj (direct:put 'A) (direct:Suspend (omega) 'guard) 'choice))

  (for ([engine (in-list engines)])
    (match-define (list name run search) engine)
    (test-case (format "~a strict eager work and Delay barrier" name)
      (define sibling-events (box '()))
      (void (search eager-sibling #:kernel (record-kernel sibling-events)))
      (check-equal? (reverse (unbox sibling-events))
                    '((put initial) (p initial) (q initial)))
      (define bind-events (box '()))
      (void (search eager-bind #:kernel (record-kernel bind-events)))
      (check-equal? (reverse (unbox bind-events))
                    '((put initial) (put initial) (continuation A) (continuation B)))
      (define delay-events (box '()))
      (void (search (direct:Suspend (identity 'h) 'delay)
                    #:kernel (record-kernel delay-events)))
      (check-equal? (unbox delay-events) '()))

    (test-case (format "~a fresh identity, constraints and nonzero allocation" name)
      (define start (direct:State 7 '((old value)) '((left right)) '(prefix) 'start))
      (define goal
        (direct:Fresh
         2 (lambda (x y)
             (direct:Fresh
              1 (lambda (z)
                  (direct:Atom
                   (lambda (state)
                     (direct:success-outcome
                      (struct-copy direct:State state
                                   [substitution (cons (list x z) (direct:State-substitution state))]
                                   [trail (append (direct:State-trail state) (list x y z))])))
                   'remember))
              'inner))
         'outer))
      (check-equal? (run goal #:state start) (direct:run goal #:state start)))

    (test-case (format "~a keeps divergence and guarded prefix boundaries" name)
      (check-exn #rx"fuel exhausted" (lambda () (search unguarded #:fuel 64)))
      (check-not-exn (lambda () (search guarded #:fuel 64)))
      (check-exn #rx"fuel exhausted" (lambda () (run guarded #:fuel 64))))
    (test-case (format "~a rejects unsupported relcalls" name)
      (check-exn #rx"relcall|Call|call" (lambda () (run (direct:Call 'r '() 'call))))))

  ;; A finite prefix of the unguarded right branch contains no observer event;
  ;; B never hides an unbounded eager chunk inside a compressed edge.
  (define (unguarded-prefix current count)
    (unless (zero? count)
      (match-define (list span next) (b:compressed-step/tagged current))
      (check-false (ormap (lambda (label) (regexp-match? #rx"^render-" label))
                          (b:Span-labels span)))
      (check-equal? (length (b:semantic-labels span)) 1)
      (unguarded-prefix next (sub1 count))))
  (unguarded-prefix (b:initial-compressed unguarded) 64)

  ;; Nontrivial compression and its negative certificates.
  (define start (b:initial-compressed eager-sibling))
  (match-define (list span next) (b:compressed-step/tagged start))
  (check-equal? (b:Span-labels span) '("eval-disj" "admin"))
  (check-equal? (b:replay-span (b:decode-BM start) span) (b:decode-BM next))
  (check-false (b:replay-span (b:decode-BM start) (b:Span '("eval-conj" "admin"))))
  (check-not-equal? (b:replay-span (b:decode-BM start) (b:Span '("eval-disj")))
                    (b:decode-BM next))
  (check-false (b:replay-span (b:decode-BM start)
                             (b:Span '("eval-disj" "admin" "admin"))))
  (check-exn exn:fail:contract? (lambda () (b:Span '())))
  (check-exn exn:fail:contract? (lambda () (b:Span '("admin" "eval-disj"))))
  (check-exn exn:fail:contract? (lambda () (b:Span '("eval-disj" "eval-atom"))))

  ;; Pending Yield tails must be evaluated, whereas Delay is already mature.
  (define state (direct:empty-state))
  (define pending (r:initial (identity 'pending)))
  (define term `(Yield ,state ,pending))
  (check-equal? (d:run-decomposition (d:decompose term)) `(Yield ,state (One ,state)))
  (check-equal? (m:run-machine (m:Machine term 'halt)) `(Yield ,state (One ,state)))
  (define delayed `(Delay ,pending))
  (check-true (d:Final? (d:decompose delayed)))
  (check-true (m:machine-final? (m:Machine delayed 'halt)))
  (check-equal? (m:machine-step/tagged (m:Machine delayed 'halt)) #f))
