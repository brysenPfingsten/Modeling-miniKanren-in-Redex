#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in rt: "../../../test-support/random-test-support.rkt")
         (prefix-in gk: "../../../test-support/generator-kernel.rkt")
         "../source/picture.rkt"
         "../source/structural-observations.rkt"
         "../source/languages/core-lang.rkt"
         "../source/wf/core-wf.rkt"
         "../source/reduction-relations/core-red.rkt"
         "./frontier-observable-support.rkt")

;; Randomized test tuning constants.
;; Edit these values directly when you want different pressure/coverage.
(define PROPERTY-ATTEMPTS 200)
(define PROPERTY-TERM-SIZE 8)
(define PROPERTY-MAX-DEPTH 4)
(define PROPERTY-SEED 424242)
(define PROPERTY-U-POOL-SIZE 24)
(define PROPERTY-X-POOL-SIZE 16)
(define PROPERTY-VISIBLE-INTRO-MAX 4)
(define PROPERTY-INTRO-EXTRA-MAX 2)
(define PROPERTY-MIN-NONEMPTY-INTRO-HITS 1)
(define PROPERTY-MIN-EXISTS-HITS 1)
(define PROPERTY-MIN-CONJ-HITS 1)

(gk:require-positive 'PROPERTY-ATTEMPTS PROPERTY-ATTEMPTS 'property-core)
(gk:require-positive 'PROPERTY-TERM-SIZE PROPERTY-TERM-SIZE 'property-core)
(gk:require-positive 'PROPERTY-U-POOL-SIZE PROPERTY-U-POOL-SIZE 'property-core)
(gk:require-positive 'PROPERTY-X-POOL-SIZE PROPERTY-X-POOL-SIZE 'property-core)
(gk:require-positive
 'PROPERTY-VISIBLE-INTRO-MAX
 PROPERTY-VISIBLE-INTRO-MAX
 'property-core)
(gk:require-nonnegative
 'PROPERTY-INTRO-EXTRA-MAX
 PROPERTY-INTRO-EXTRA-MAX
 'property-core)
(unless (<= PROPERTY-VISIBLE-INTRO-MAX PROPERTY-U-POOL-SIZE)
  (error 'property-core
         (format "PROPERTY-VISIBLE-INTRO-MAX must be <= PROPERTY-U-POOL-SIZE, got ~a > ~a"
                 PROPERTY-VISIBLE-INTRO-MAX
                 PROPERTY-U-POOL-SIZE)))
(unless (<= 1 PROPERTY-MAX-DEPTH 4)
  (error 'property-core
         (format "PROPERTY-MAX-DEPTH must be in [1,4], got ~a"
                 PROPERTY-MAX-DEPTH)))
(unless (<= 0 PROPERTY-MIN-NONEMPTY-INTRO-HITS PROPERTY-ATTEMPTS)
  (error 'property-core
         (format "PROPERTY-MIN-NONEMPTY-INTRO-HITS must be in [0, PROPERTY-ATTEMPTS], got ~a"
                 PROPERTY-MIN-NONEMPTY-INTRO-HITS)))
(unless (<= 0 PROPERTY-MIN-EXISTS-HITS PROPERTY-ATTEMPTS)
  (error 'property-core
         (format "PROPERTY-MIN-EXISTS-HITS must be in [0, PROPERTY-ATTEMPTS], got ~a"
                 PROPERTY-MIN-EXISTS-HITS)))
(unless (<= 0 PROPERTY-MIN-CONJ-HITS PROPERTY-ATTEMPTS)
  (error 'property-core
         (format "PROPERTY-MIN-CONJ-HITS must be in [0, PROPERTY-ATTEMPTS], got ~a"
                 PROPERTY-MIN-CONJ-HITS)))

(define PROPERTY-RNG (rt:make-seeded-rng PROPERTY-SEED))

(define (final-frontier? f)
  (match f
    [`(Done ,_) #t]
    [`(Last ,_ (Answer ,_ ,_)) #t]
    [_ #f]))

(define (final-config? cfg)
  (final-frontier? cfg))

(define (wf-config-term? cfg)
  (judgment-holds (wf-cfg/core? ,cfg)))

(define (core-shape-term? cfg)
  (redex-match? core-lang F cfg))

(define (next-cfg* cfg)
  (remove-duplicates
   (apply-reduction-relation core-red cfg)))

(define (tagged-next* cfg)
  (remove-duplicates
   (apply-reduction-relation/tag-with-names core-red cfg)))

(define (unique-decomposition? cfg)
  (define next* (next-cfg* cfg))
  (cond
    [(final-config? cfg) (null? next*)]
    [else (= (length next*) 1)]))

(define (progress? cfg)
  (or (final-config? cfg)
      (not (null? (next-cfg* cfg)))))

(define (wf-preserved? cfg)
  (for/and ([cfg^ (in-list (next-cfg* cfg))])
    (wf-config-term? cfg^)))

(define (trace-wf-preserved? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (wf-config-term? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-wf-preserved? cfg^ (sub1 remaining))]
       [_ #f])]))

(define (core-shape-preserved? cfg)
  (and (core-shape-term? cfg)
       (for/and ([cfg^ (in-list (next-cfg* cfg))])
         (core-shape-term? cfg^))))

(define (trace-core-shape-preserved? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (core-shape-term? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-core-shape-preserved? cfg^ (sub1 remaining))]
       [_ #f])]))

(define SOURCE-TRACE-CAP 64)

(define (trace-structurally-well-formed? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (structurally-well-formed? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
       (trace-structurally-well-formed? cfg^ (sub1 remaining))]
       [_ #f])]))

(define (count-step-name steps expected [count 0])
  (match steps
    ['() count]
    [(cons step-name rest)
     (count-step-name rest
                      expected
                      (if (string=? step-name expected)
                          (add1 count)
                          count))]))

(define (owner-record-occurrence-count datum)
  (term (structural-owner-record-occurrence-count ,datum)))

(define (introduced-name-occurrence-count datum)
  (term (structural-introduced-name-occurrence-count ,datum)))

(define (owner-occurrence-delta? cfg step-name cfg^)
  (define records (owner-record-occurrence-count cfg))
  (define records^ (owner-record-occurrence-count cfg^))
  (define names (introduced-name-occurrence-count cfg))
  (define names^ (introduced-name-occurrence-count cfg^))
  (match step-name
    ["allocate-fresh"
     (and (= records^ (add1 records))
          (>= names^ names))]
    [_
     (and (= records^ records)
          (= names^ names))]))

(define (trace-owner-occurrence-deltas? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list name cfg^))
        (and (owner-occurrence-delta? cfg (~a name) cfg^)
             (trace-owner-occurrence-deltas? cfg^ (sub1 remaining)))]
       [_ #f])]))

(define (owner-record-balance? cfg)
  (define-values (steps final-cfg status)
    (trace-deterministic core-red cfg))
  (and (eq? status 'done)
       (structurally-well-formed? final-cfg)
       (= (owner-record-occurrence-count final-cfg)
          (+ (owner-record-occurrence-count cfg)
             (count-step-name steps "allocate-fresh")))
       (zero-forced? final-cfg)))

;; Core has no branch-pruning rule. Owner records and the introduced-name
;; occurrences they contain therefore grow only at allocation and otherwise
;; move intact between constructors.
(define (trace-owner-occurrences-monotone?
         cfg
         [remaining SOURCE-TRACE-CAP]
         [record-count (owner-record-occurrence-count cfg)]
         [name-count (introduced-name-occurrence-count cfg)])
  (cond
    [(negative? remaining) #f]
    [(or (< (owner-record-occurrence-count cfg) record-count)
         (< (introduced-name-occurrence-count cfg) name-count))
     #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-owner-occurrences-monotone?
         cfg^
         (sub1 remaining)
         (owner-record-occurrence-count cfg)
         (introduced-name-occurrence-count cfg))]
       [_ #f])]))

(define (trace-zero-forced? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (zero? (term (structural-forced-count ,cfg)))) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
       (trace-zero-forced? cfg^ (sub1 remaining))]
       [_ #f])]))

(define (zero-forced? cfg)
  (zero? (term (structural-forced-count ,cfg))))

(define (zero-owner-occurrences? cfg)
  (and (zero? (owner-record-occurrence-count cfg))
       (zero? (introduced-name-occurrence-count cfg))))

(define boundary-fresh-failure-config
  (term
   (More
    (Work (Owners)
     (∃ (x:0)
        (fail (label "fail"))
        (label "boundary-fresh"))
     (state () () () (label "initial"))))))

(define local-fresh-failure-config
  (term
   (More
    (Work (Owners)
     (((∃ (x:0)
           (succeed (label "seed"))
           (label "local-fresh"))
        ∧
        ((sym "left") =? (sym "right") (label "fail-unify"))
        (label "inner-and"))
      ∧
      (succeed (label "outside"))
      (label "outer-and"))
     (state () () () (label "initial"))))))

(define (operational/extensional-agree? cfg)
  (equal? (cfg->operational-picture cfg)
          (cfg->extensional-picture cfg)))

(define (trace-operational/extensional-agree? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (operational/extensional-agree? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-operational/extensional-agree? cfg^ (sub1 remaining))]
       [_ #f])]))

(define (extensional-visible-json-wf/cfg? cfg)
  (visible-json-wf? (cfg->extensional-picture cfg)))

(define (trace-extensional-visible-json-wf/cfg? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (extensional-visible-json-wf/cfg? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-extensional-visible-json-wf/cfg? cfg^ (sub1 remaining))]
       [_ #f])]))

(define (cfg->visible-json cfg)
  (cfg->operational-picture cfg))

(define (visible-json-wf/cfg? cfg)
  (visible-json-wf? (cfg->visible-json cfg)))

(define (trace-visible-json-wf/cfg? cfg [remaining SOURCE-TRACE-CAP])
  (cond
    [(negative? remaining) #f]
    [(not (visible-json-wf/cfg? cfg)) #f]
    [else
     (match (tagged-next* cfg)
       ['() #t]
       [(list (list _ cfg^))
        (trace-visible-json-wf/cfg? cfg^ (sub1 remaining))]
       [_ #f])]))

;; Pool sizes bound generated test-data diversity only; they do not bound the
;; semantic logic-variable/name space of the language.
(define U-POOL
  (gk:make-u-pool PROPERTY-U-POOL-SIZE))

(define X-POOL
  (gk:make-x-pool PROPERTY-X-POOL-SIZE))

(define (fresh-introduction-extension visible-intros)
  (define unused
    (filter (lambda (u) (not (member u visible-intros))) U-POOL))
  (define room
    (min PROPERTY-INTRO-EXTRA-MAX
         (- PROPERTY-VISIBLE-INTRO-MAX (length visible-intros))
         (length unused)))
  (cond
    [(zero? room)
     (values '() visible-intros)]
    [else
     (define intro
       (rt:random-distinct/rng PROPERTY-RNG
                               unused
                               (add1 (rt:rng-random PROPERTY-RNG room))))
     (values intro (append visible-intros intro))]))

(define (make-label prefix)
  (gk:make-label/rng PROPERTY-RNG prefix))

(define (pick-one xs)
  (gk:pick-one/rng PROPERTY-RNG xs))

(define (gen-term x-env visible-intros depth)
  (gk:gen-term/rng PROPERTY-RNG x-env visible-intros depth))

(define (gen-eq-goal x-env visible-intros depth)
  `(,(gen-term x-env visible-intros depth)
    =?
    ,(gen-term x-env visible-intros depth)
    ,(make-label "eq")))

(define (fresh-x-list x-env)
  (gk:fresh-x-list/rng PROPERTY-RNG x-env X-POOL))

(define (gen-goal x-env visible-intros depth)
  (define options
    (append '(succeed eq)
            (if (zero? depth) '() '(conj exists))))
  (case (pick-one options)
    [(succeed) `(succeed ,(make-label "ok"))]
    [(eq) (gen-eq-goal x-env visible-intros depth)]
    [(conj)
     `(,(gen-goal x-env visible-intros (sub1 depth))
       ∧
       ,(gen-goal x-env visible-intros (sub1 depth))
       ,(make-label "and"))]
    [(exists)
     (define d (fresh-x-list x-env))
     (define body
       (if (null? d)
           `(succeed ,(make-label "ok"))
             `(,(car d)
             =?
             ,(rt:gen-primitive/rng PROPERTY-RNG)
             ,(make-label "eq"))))
     `(∃
       ,d
       ,body
       ,(make-label "ex"))]))

(define (gen-state)
  `(state () () () ,(make-label "st")))

(define (generate-source-config)
  `(More
    (Work (Owners)
          ,(gen-goal '() '() (max-depth))
          ,(gen-state))))

(define (max-depth)
  PROPERTY-MAX-DEPTH)

(define (prepend-owner-to-work owner work)
  (match work
    [`(Work (Owners . ,owners) ,g ,st)
     `(Work (Owners ,owner ,@owners) ,g ,st)]
    [`(Returned (Owners . ,owners) ,st)
     `(Returned (Owners ,owner ,@owners) ,st)]
    [`(Dead (Owners . ,owners))
     `(Dead (Owners ,owner ,@owners))]
    [`(Conj (Owners . ,owners) ,work^ ,g)
     `(Conj (Owners ,owner ,@owners) ,work^ ,g)]))

(define (prepend-owner-to-frontier owner frontier)
  (match frontier
    [`(More ,work)
     `(More ,(prepend-owner-to-work owner work))]
    [`(Done (Owners . ,owners))
     `(Done (Owners ,owner ,@owners))]
    [`(Last (Owners . ,owners) ,answer)
     `(Last (Owners ,owner ,@owners) ,answer)]))

(define (gen-work visible-intros depth)
  (define options
    (append '(atomic returned dead)
            (if (zero? depth) '() '(conj fresh))))
  (case (pick-one options)
    [(atomic)
     `(Work (Owners)
            ,(gen-goal '() visible-intros depth)
            ,(gen-state))]
    [(returned)
     `(Returned (Owners) ,(gen-state))]
    [(dead) '(Dead (Owners))]
    [(conj)
     `(Conj (Owners)
            ,(gen-work visible-intros (sub1 depth))
            ,(gen-goal '() visible-intros (sub1 depth)))]
    [(fresh)
     (define-values (intro visible-intros^)
       (fresh-introduction-extension visible-intros))
     (if (null? intro)
         (gen-work visible-intros (sub1 depth))
         (prepend-owner-to-work
          `(Owner ,intro ,(make-label "fresh"))
          (gen-work visible-intros^ (sub1 depth))))]))

(define (gen-frontier visible-intros depth)
  (define options
    (append '(more done last)
            (if (zero? depth) '() '(fresh))))
  (case (pick-one options)
    [(more) `(More ,(gen-work visible-intros depth))]
    [(done) '(Done (Owners))]
    [(last) `(Last (Owners) (Answer (Owners) ,(gen-state)))]
    [(fresh)
     (define-values (intro visible-intros^)
       (fresh-introduction-extension visible-intros))
     (if (null? intro)
         (gen-frontier visible-intros (sub1 depth))
         (prepend-owner-to-frontier
          `(Owner ,intro ,(make-label "fresh"))
          (gen-frontier visible-intros^ (sub1 depth))))]))

(define (generate-wf-config/constructive)
  (define cfg
    (gen-frontier '() (max-depth)))
  (unless (wf-config-term? cfg)
    (error 'generate-wf-config/constructive
           (format "constructed non-wf config: ~s" cfg)))
  cfg)

(define (goal-flags g)
  (match g
    [`(∃ ,_ ,g2 ,_) (define-values (hex hconj) (goal-flags g2))
                    (values #t hconj)]
    [`(,g1 ∧ ,g2 ,_) (define-values (hex1 hconj1) (goal-flags g1))
                     (define-values (hex2 hconj2) (goal-flags g2))
                     (values (or hex1 hex2) #t)]
    [_ (values #f #f)]))

(define (state-coverage st visible-intros)
  (match st
    [`(state ,_ ,_ ,_ ,_)
     (values (pair? visible-intros) #f #f (length visible-intros))]
    [_ (values #f #f #f 0)]))

(define (extend-visible-intros owners visible-intros)
  (match owners
    [`(Owners . ,owner*)
     (for/fold ([visible-intros visible-intros])
               ([owner (in-list owner*)])
       (match owner
         [`(Owner ,intro ,_)
          (append visible-intros intro)]))]))

(define (owner-stack-has-introductions? owners)
  (match owners
    [`(Owners . ,owner*)
     (for/or ([owner (in-list owner*)])
       (match owner
         [`(Owner ,intro ,_) (pair? intro)]))]))

(define (work-coverage work [visible-intros '()])
  (match work
    [`(Work ,owners ,g ,st)
     (define visible-intros^ (extend-visible-intros owners visible-intros))
     (define-values (has-exists? has-conj?) (goal-flags g))
     (values (pair? visible-intros^)
             has-exists?
             has-conj?
             (length visible-intros^))]
    [`(Returned ,owners ,st)
     (state-coverage st (extend-visible-intros owners visible-intros))]
    [`(Dead ,owners)
     (define visible-intros^ (extend-visible-intros owners visible-intros))
     (values (pair? visible-intros^) #f #f (length visible-intros^))]
    [`(Conj ,owners ,work^ ,g)
     (define visible-intros^ (extend-visible-intros owners visible-intros))
     (define-values (nonempty? has-exists? _has-conj? intro-max)
       (work-coverage work^ visible-intros^))
     (define-values (goal-exists? _goal-conj?) (goal-flags g))
     (values (or (owner-stack-has-introductions? owners) nonempty?)
             (or has-exists? goal-exists?)
             #t
             (max (length visible-intros^) intro-max))]
    [_ (values #f #f #f 0)]))

(define (frontier-coverage frontier [visible-intros '()])
  (match frontier
    [`(More ,work)
     (work-coverage work visible-intros)]
    [`(Done ,owners)
     (define visible-intros^ (extend-visible-intros owners visible-intros))
     (values (pair? visible-intros^) #f #f (length visible-intros^))]
    [`(Last ,owners-last (Answer ,owners-answer ,st))
     (define visible-last
       (extend-visible-intros owners-last visible-intros))
     (state-coverage st
                     (extend-visible-intros owners-answer visible-last))]
    [_ (values #f #f #f 0)]))

(define (config-coverage cfg)
  (frontier-coverage cfg))

(define (check-wf-guarded-property label pred)
  (define-values (wf-hits
                  fail-count
                  nonempty-intro-hits
                  exists-node-hits
                  conj-node-hits
                  max-visible-intro-count
                  fail-samples)
    (for/fold ([wf-hits 0]
               [fail-count 0]
               [nonempty-intro-hits 0]
               [exists-node-hits 0]
               [conj-node-hits 0]
               [max-visible-intro-count 0]
               [fail-samples '()])
              ([_ (in-range PROPERTY-ATTEMPTS)])
      (define cfg
        (generate-wf-config/constructive))
      (define-values (nonempty-intros? has-exists? has-conj? intro-max)
        (config-coverage cfg))
      (define ok?
        (pred cfg))
      (values (add1 wf-hits)
              (if ok? fail-count (add1 fail-count))
              (if nonempty-intros?
                  (add1 nonempty-intro-hits)
                  nonempty-intro-hits)
              (if has-exists? (add1 exists-node-hits) exists-node-hits)
              (if has-conj? (add1 conj-node-hits) conj-node-hits)
              (max max-visible-intro-count intro-max)
              (cond
                [(or ok? (>= (length fail-samples) 3))
                 fail-samples]
                [else
                 ;; Store only the first three failures for readable output truncation.
                 (cons cfg fail-samples)]))))

  (displayln
   (format "[property-core] ~a attempts=~a wf-hits=~a (~a%%) fails=~a nonempty-intros=~a exists=~a conj=~a max-visible-intros=~a seed=~a"
           label
           PROPERTY-ATTEMPTS
           wf-hits
           (real->decimal-string (* 100.0
                                    (/ (exact->inexact wf-hits) PROPERTY-ATTEMPTS))
                                2)
           fail-count
           nonempty-intro-hits
           exists-node-hits
           conj-node-hits
           max-visible-intro-count
           PROPERTY-SEED))

  (check-equal? wf-hits
                PROPERTY-ATTEMPTS
                (format "~a: constructive generator violated wf contract." label))

  (check-true (>= nonempty-intro-hits PROPERTY-MIN-NONEMPTY-INTRO-HITS)
              (format "~a: insufficient non-empty-introduction coverage (~a < ~a)."
                      label
                      nonempty-intro-hits
                      PROPERTY-MIN-NONEMPTY-INTRO-HITS))
  (check-true (>= exists-node-hits PROPERTY-MIN-EXISTS-HITS)
              (format "~a: insufficient exists-node coverage (~a < ~a)."
                      label exists-node-hits PROPERTY-MIN-EXISTS-HITS))
  (check-true (>= conj-node-hits PROPERTY-MIN-CONJ-HITS)
              (format "~a: insufficient conjunction-node coverage (~a < ~a)."
                      label conj-node-hits PROPERTY-MIN-CONJ-HITS))

  (check-equal? fail-count
                0
                (format "~a: counterexamples (up to 3): ~s"
                        label
                        (reverse fail-samples))))

(define (check-source-guarded-property label pred)
  (define-values (source-hits
                  fail-count
                  exists-node-hits
                  conj-node-hits
                  fail-samples)
    (for/fold ([source-hits 0]
               [fail-count 0]
               [exists-node-hits 0]
               [conj-node-hits 0]
               [fail-samples '()])
              ([_ (in-range PROPERTY-ATTEMPTS)])
      (define cfg (generate-source-config))
      (define-values (_nonempty-intros? has-exists? has-conj? _intro-max)
        (config-coverage cfg))
      (define ok?
        (and (wf-config-term? cfg)
             (structurally-well-formed? cfg)
             (pred cfg)))
      (values (add1 source-hits)
              (if ok? fail-count (add1 fail-count))
              (if has-exists? (add1 exists-node-hits) exists-node-hits)
              (if has-conj? (add1 conj-node-hits) conj-node-hits)
              (cond
                [(or ok? (>= (length fail-samples) 3))
                 fail-samples]
                [else
                 (cons cfg fail-samples)]))))

  (displayln
   (format "[property-core] ~a attempts=~a source-hits=~a exists=~a conj=~a seed=~a"
           label
           PROPERTY-ATTEMPTS
           source-hits
           exists-node-hits
           conj-node-hits
           PROPERTY-SEED))

  (check-equal? source-hits
                PROPERTY-ATTEMPTS
                (format "~a: source generator violated contract." label))

  (check-true (>= exists-node-hits PROPERTY-MIN-EXISTS-HITS)
              (format "~a: insufficient exists-node coverage (~a < ~a)."
                      label exists-node-hits PROPERTY-MIN-EXISTS-HITS))
  (check-true (>= conj-node-hits PROPERTY-MIN-CONJ-HITS)
              (format "~a: insufficient conjunction-node coverage (~a < ~a)."
                      label conj-node-hits PROPERTY-MIN-CONJ-HITS))

  (check-equal? fail-count
                0
                (format "~a: counterexamples (up to 3): ~s"
                        label
                        (reverse fail-samples))))

(define-test-suite CORE-PROPERTIES
  (test-case "WF-guarded unique decomposition"
    (check-wf-guarded-property "unique-decomposition" unique-decomposition?))
  (test-case "WF-guarded progress"
    (check-wf-guarded-property "progress" progress?))
  (test-case "WF-guarded one-step preservation"
    (check-wf-guarded-property "wf-preserved" wf-preserved?))
  (test-case "WF-guarded trace preservation"
    (check-wf-guarded-property "trace-wf-preserved" trace-wf-preserved?))
  (test-case "WF-guarded core-shape closure"
    (check-wf-guarded-property "core-shape-preserved" core-shape-preserved?))
  (test-case "WF-guarded trace core-shape closure"
    (check-wf-guarded-property "trace-core-shape-preserved"
                               trace-core-shape-preserved?))
  (test-case "Source-guarded structural owner visibility"
    (check-source-guarded-property
     "structurally-well-formed"
     structurally-well-formed?))
  (test-case "Source-guarded structural owner visibility through trace"
    (check-source-guarded-property
     "trace-structurally-well-formed"
     trace-structurally-well-formed?))
  (test-case "boundary and local dead introductions survive in exact Done ownership"
    (define-values (boundary-steps boundary-final boundary-status)
      (trace-deterministic core-red boundary-fresh-failure-config))
    (define-values (local-steps local-final local-status)
      (trace-deterministic core-red local-fresh-failure-config))
    (check-equal? boundary-status 'done)
    (check-equal? local-status 'done)
    (check-true
     (trace-owner-occurrence-deltas? boundary-fresh-failure-config))
    (check-true
     (trace-owner-occurrence-deltas? local-fresh-failure-config))
    (check-true (owner-record-balance? boundary-fresh-failure-config))
    (check-true (owner-record-balance? local-fresh-failure-config))
    (check-equal? (count-step-name boundary-steps "allocate-fresh") 1)
    (check-equal?
     boundary-final
     (term (Done (Owners (Owner (u:0) (label "boundary-fresh"))))))
    (check-equal?
     (owner-record-occurrence-count boundary-final)
     1)
    (check-equal? (introduced-name-occurrence-count boundary-final) 1)
    (check-equal? (count-step-name local-steps "allocate-fresh") 1)
    (check-equal?
     local-final
     (term (Done (Owners (Owner (u:0) (label "local-fresh"))))))
    (check-equal? (owner-record-occurrence-count local-final) 1)
    (check-equal? (introduced-name-occurrence-count local-final) 1))
  (test-case "WF-guarded visible AST shape"
    (check-wf-guarded-property "visible-json-wf" visible-json-wf/cfg?))
  (test-case "WF-guarded extensional picture shape"
    (check-wf-guarded-property "extensional-visible-json-wf"
                               extensional-visible-json-wf/cfg?))
  (test-case "Source-guarded visible AST shape through trace"
    (check-source-guarded-property "trace-visible-json-wf" trace-visible-json-wf/cfg?))
  (test-case "Source-guarded extensional picture shape through trace"
    (check-source-guarded-property "trace-extensional-visible-json-wf"
                                   trace-extensional-visible-json-wf/cfg?))
  (test-case "Source-guarded exact owner occurrence deltas through trace"
    (check-source-guarded-property "trace-owner-occurrence-deltas"
                                   trace-owner-occurrence-deltas?))
  (test-case "Source-guarded allocation and owner-record balance"
    (check-source-guarded-property "owner-record-balance"
                                   owner-record-balance?))
  (test-case "Source-guarded owner occurrences are monotone through core traces"
    (check-source-guarded-property "trace-owner-occurrences-monotone"
                                   trace-owner-occurrences-monotone?))
  (test-case "Source-guarded source states contain no owner occurrences"
    (check-source-guarded-property "zero-owner-occurrences"
                                   zero-owner-occurrences?))
  (test-case "WF-guarded operational and extensional pictures agree in core"
    (check-wf-guarded-property "operational/extensional-agree"
                               operational/extensional-agree?))
  (test-case "Source-guarded operational and extensional pictures agree through trace"
    (check-source-guarded-property "trace-operational/extensional-agree"
                                   trace-operational/extensional-agree?))
  (test-case "Source-guarded core traces never introduce Forced"
    (check-source-guarded-property "trace-zero-forced"
                                   trace-zero-forced?))
  (test-case "WF-guarded core configurations never contain Forced"
    (check-wf-guarded-property "zero-forced"
                               zero-forced?)))

(define/provide-test-suite PROPERTY-CORE
  #:before
  (thunk
   (displayln
    (format "Running core property tests (attempts=~a, term-size=~a, seed=~a, pools u/x=~a/~a, visible-intro-max=~a, intro-extra-max=~a)..."
            PROPERTY-ATTEMPTS
            PROPERTY-TERM-SIZE
            PROPERTY-SEED
            PROPERTY-U-POOL-SIZE
            PROPERTY-X-POOL-SIZE
            PROPERTY-VISIBLE-INTRO-MAX
            PROPERTY-INTRO-EXTRA-MAX)))
  #:after (thunk (displayln "Finished core property tests."))
  CORE-PROPERTIES)

(module+ test
  (define failures (run-tests PROPERTY-CORE))
  (unless (zero? failures)
    (error 'PROPERTY-CORE "~a test case(s) failed" failures)))
