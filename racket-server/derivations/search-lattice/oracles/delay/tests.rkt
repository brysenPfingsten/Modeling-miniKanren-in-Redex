#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         racket/runtime-path
         (prefix-in sl: "s/language.rkt")
         (prefix-in ss: "s/source.rkt")
         (prefix-in swf: "s/wf.rkt")
         (prefix-in el: "e/language.rkt")
         (prefix-in es: "e/source.rkt")
         (prefix-in ewf: "e/wf.rkt")
         (prefix-in nl: "n/language.rkt")
         (prefix-in ns: "n/source.rkt")
         (prefix-in nwf: "n/wf.rkt")
         "vertical.rkt")

(provide DELAY-ORACLE-TESTS)

(define sigma-empty/s
  '(state () () () (label "state")))

(define sigma-empty/e
  '(state (Support) () () () (label "state")))
(define sigma-u0/e
  '(state (Support u:0) () () () (label "state")))
(define sigma-u0-u1/e
  '(state (Support u:0 u:1) () () () (label "state")))
(define sigma-u0-u1-u2/e
  '(state (Support u:0 u:1 u:2) () () () (label "state")))

(define sigma-0/n
  '(state 0 () () () (label "state")))
(define sigma-1/n
  '(state 1 () () () (label "state")))
(define sigma-2/n
  '(state 2 () () () (label "state")))
(define sigma-3/n
  '(state 3 () () () (label "state")))

(define owners-empty '(Owners))
(define owners-u0 '(Owners (Owner (u:0) (label "u0"))))
(define owners-u1 '(Owners (Owner (u:1) (label "u1"))))
(define owners-u2 '(Owners (Owner (u:2) (label "u2"))))

(define expected-rule-names
  '(allocate-fresh
    bubble-delay-through-conj
    conj-fail
    conj-return
    disequality-fail
    disequality-success
    expand-conjunction
    fail
    finish-failure
    finish-success
    force-delay
    succeed
    suspend-goal
    unify-fail
    unify-success
    unify-violates-disequality))

(define suspend-source/s
  `(More
    (Work
     ,owners-u0
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-empty/s)))

(define bubble-source/s
  `(More
    (Conj
     ,owners-u0
     (PendingDelay
      ,owners-u1
      (Work ,owners-u2 (succeed (label "delayed")) ,sigma-empty/s))
     (succeed (label "right")))))

(define force-source/s
  `(More
    (PendingDelay
     ,owners-u0
     (Work ,owners-u1 (succeed (label "forced-body")) ,sigma-empty/s))))

;; This representative is also the regression for the allocation seam: the
;; inherited allocation equation must substitute beneath suspend.
(define allocate-source/s
  `(More
    (Work
     ,owners-empty
     (∃ (x:q)
        (suspend
         (x:q =? (sym "cat") (label "inside-suspend"))
         (label "suspend"))
        (label "fresh"))
     ,sigma-empty/s)))

(define rule-representatives/s
  (list
   (list
    'expand-conjunction
    `(More
      (Work
       ,owners-u0
       ((succeed (label "left"))
        ∧
        (u:0 =? u:0 (label "right"))
        (label "conjunction"))
       ,sigma-empty/s)))
   (list
    'succeed
    `(More (Work ,owners-u0 (succeed (label "yes")) ,sigma-empty/s)))
   (list
    'fail
    `(More (Work ,owners-u0 (fail (label "no")) ,sigma-empty/s)))
   (list
    'conj-return
    `(More
      (Conj
       ,owners-u0
       (Returned ,owners-u1 ,sigma-empty/s)
       (u:0 =? u:0 (label "continue")))))
   (list
    'conj-fail
    `(More
      (Conj
       ,owners-u0
       (Dead ,owners-u1)
       (u:0 =? u:0 (label "inert-continuation")))))
   (list
    'unify-success
    `(More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "unify"))
       ,sigma-empty/s)))
   (list
    'unify-violates-disequality
    `(More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "violates"))
       (state () ((u:0 (nat 0))) () (label "violates-state")))))
   (list
    'unify-fail
    `(More
      (Work
       ,owners-empty
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,sigma-empty/s)))
   (list
    'disequality-success
    `(More
      (Work
       ,owners-u0
       (u:0 != (nat 0) (label "disequality-success"))
       ,sigma-empty/s)))
   (list
    'disequality-fail
    `(More
      (Work
       ,owners-empty
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,sigma-empty/s)))
   (list
    'finish-success
    `(More (Returned ,owners-u0 ,sigma-empty/s)))
   (list
    'finish-failure
    `(More (Dead ,owners-u0)))
   (list 'allocate-fresh allocate-source/s)
   (list 'suspend-goal suspend-source/s)
   (list 'bubble-delay-through-conj bubble-source/s)
   (list 'force-delay force-source/s)))

(define expected-suspend-target/s
  `(More
    (PendingDelay
     ,owners-u0
     (Work ,owners-empty (succeed (label "body")) ,sigma-empty/s))))

(define expected-bubble-target/s
  `(More
    (PendingDelay
     ,owners-u0
     (Conj
      ,owners-empty
      (Work
       (Owners
        (Owner (u:1) (label "u1"))
        (Owner (u:2) (label "u2")))
       (succeed (label "delayed"))
       ,sigma-empty/s)
      (succeed (label "right"))))))

(define expected-force-target/s
  `(Forced
    ,owners-u0
    (More
     (Work ,owners-u1 (succeed (label "forced-body")) ,sigma-empty/s))))

(define expected-allocate-target/s
  `(More
    (Work
     (Owners (Owner (u:0) (label "fresh")))
     (suspend
      (u:0 =? (sym "cat") (label "inside-suspend"))
      (label "suspend"))
     ,sigma-empty/s)))

(define (rule-names relation)
  (map (lambda (name) (string->symbol (~a name)))
       (reduction-relation->rule-names relation)))

(define (wf-proofs/s frontier)
  (build-derivations (swf:wf-delay-oracle/s? ,frontier)))

(define (wf-proofs/e frontier)
  (build-derivations (ewf:wf-delay-oracle/e? ,frontier)))

(define (wf-proofs/n frontier)
  (build-derivations (nwf:wf-delay-oracle/n? ,frontier)))

(define (only-raw-successor raw-successors source)
  (match (raw-successors source)
    [(list only) only]
    [results
     (error 'only-raw-successor
            "expected one raw named derivation for ~e, received ~e"
            source
            results)]))

(define trace-source/s
  `(More
    (Work
     ,owners-empty
     (∃ (x:q)
        (suspend
         ((x:q =? (sym "cat") (label "bind"))
          ∧
          (succeed (label "finish"))
          (label "and"))
         (label "suspend"))
        (label "fresh"))
     ,sigma-empty/s)))

(define expected-trace-names
  '(allocate-fresh
    suspend-goal
    force-delay
    expand-conjunction
    unify-success
    conj-return
    succeed
    finish-success))

;; Literal E/N representatives make the independently stated row equations an
;; oracle in their own right.  These coordinates are not constructed by Q.
(define suspend-source/e
  `(More
    (Work
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-u0/e)))
(define expected-suspend-target/e
  `(More
    (PendingDelay
     (Work (succeed (label "body")) ,sigma-u0/e))))
(define suspend-source/n
  `(More
    (Work
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-1/n)))
(define expected-suspend-target/n
  `(More
    (PendingDelay
     (Work (succeed (label "body")) ,sigma-1/n))))

(define bubble-source/e
  `(More
    (Conj
     (PendingDelay
      (Work (succeed (label "delayed")) ,sigma-u0-u1-u2/e))
     (succeed (label "right")))))
(define expected-bubble-target/e
  `(More
    (PendingDelay
     (Conj
      (Work (succeed (label "delayed")) ,sigma-u0-u1-u2/e)
      (succeed (label "right"))))))
(define bubble-source/n
  `(More
    (Conj
     (PendingDelay
      (Work (succeed (label "delayed")) ,sigma-3/n))
     (succeed (label "right")))))
(define expected-bubble-target/n
  `(More
    (PendingDelay
     (Conj
      (Work (succeed (label "delayed")) ,sigma-3/n)
      (succeed (label "right"))))))

(define force-source/e
  `(More
    (PendingDelay
     (Work (succeed (label "forced-body")) ,sigma-u0-u1/e))))
(define expected-force-target/e
  `(Forced
    (More
     (Work (succeed (label "forced-body")) ,sigma-u0-u1/e))))
(define force-source/n
  `(More
    (PendingDelay
     (Work (succeed (label "forced-body")) ,sigma-2/n))))
(define expected-force-target/n
  `(Forced
    (More
     (Work (succeed (label "forced-body")) ,sigma-2/n))))

(define suspend-success-source/s
  `(More
    (Work
     ,owners-empty
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-empty/s)))
(define suspend-success-source/e
  `(More
    (Work
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-empty/e)))
(define suspend-success-source/n
  `(More
    (Work
     (suspend (succeed (label "body")) (label "suspend"))
     ,sigma-0/n)))
(define suspend-success-final/s
  `(Forced
    ,owners-empty
    (Last ,owners-empty (Answer ,owners-empty ,sigma-empty/s))))
(define suspend-success-final/e
  `(Forced (Last (Answer ,sigma-empty/e))))
(define suspend-success-final/n
  `(Forced (Last (Answer ,sigma-0/n))))

(define bubble-success-final/s
  `(Forced
    ,owners-u0
    (Last
     (Owners
      (Owner (u:1) (label "u1"))
      (Owner (u:2) (label "u2")))
     (Answer ,owners-empty ,sigma-empty/s))))
(define bubble-success-final/e
  `(Forced (Last (Answer ,sigma-u0-u1-u2/e))))
(define bubble-success-final/n
  `(Forced (Last (Answer ,sigma-3/n))))

(define suspend-failure-source/s
  `(More
    (Work
     ,owners-empty
     (suspend (fail (label "body")) (label "suspend"))
     ,sigma-empty/s)))
(define suspend-failure-source/e
  `(More
    (Work
     (suspend (fail (label "body")) (label "suspend"))
     ,sigma-empty/e)))
(define suspend-failure-source/n
  `(More
    (Work
     (suspend (fail (label "body")) (label "suspend"))
     ,sigma-0/n)))
(define suspend-failure-final/s
  `(Forced ,owners-empty (Done ,owners-empty)))
(define suspend-failure-final/e
  '(Forced (Done (Support))))
(define suspend-failure-final/n
  '(Forced (Done 0)))

(define nested-suspend-source/s
  `(More
    (Work
     ,owners-empty
     (suspend
      (suspend (succeed (label "body")) (label "inner-suspend"))
      (label "outer-suspend"))
     ,sigma-empty/s)))
(define nested-suspend-source/e
  `(More
    (Work
     (suspend
      (suspend (succeed (label "body")) (label "inner-suspend"))
      (label "outer-suspend"))
     ,sigma-empty/e)))
(define nested-suspend-source/n
  `(More
    (Work
     (suspend
      (suspend (succeed (label "body")) (label "inner-suspend"))
      (label "outer-suspend"))
     ,sigma-0/n)))
(define nested-suspend-final/s
  `(Forced
    ,owners-empty
    (Forced
     ,owners-empty
     (Last ,owners-empty (Answer ,owners-empty ,sigma-empty/s)))))
(define nested-suspend-final/e
  `(Forced (Forced (Last (Answer ,sigma-empty/e)))))
(define nested-suspend-final/n
  `(Forced (Forced (Last (Answer ,sigma-0/n)))))

(define fresh-inside-source/s
  `(More
    (Work
     ,owners-empty
     (suspend
      (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
      (label "suspend"))
     ,sigma-empty/s)))
(define fresh-inside-source/e
  `(More
    (Work
     (suspend
      (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
      (label "suspend"))
     ,sigma-empty/e)))
(define fresh-inside-source/n
  `(More
    (Work
     (suspend
      (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
      (label "suspend"))
     ,sigma-0/n)))
(define fresh-inside-final/s
  `(Forced
    ,owners-empty
    (Last
     (Owners (Owner (u:0) (label "fresh-inside")))
     (Answer ,owners-empty ,sigma-empty/s))))
(define fresh-inside-final/e
  `(Forced (Last (Answer ,sigma-u0/e))))
(define fresh-inside-final/n
  `(Forced (Last (Answer ,sigma-1/n))))

(define unused-fresh-failure-source/s
  `(More
    (Work
     ,owners-empty
     (∃ (x:q)
        (suspend (fail (label "body")) (label "suspend"))
        (label "fresh-outside"))
     ,sigma-empty/s)))
(define unused-fresh-failure-source/e
  `(More
    (Work
     (∃ (x:q)
        (suspend (fail (label "body")) (label "suspend"))
        (label "fresh-outside"))
     ,sigma-empty/e)))
(define unused-fresh-failure-source/n
  `(More
    (Work
     (∃ (x:q)
        (suspend (fail (label "body")) (label "suspend"))
        (label "fresh-outside"))
     ,sigma-0/n)))
(define unused-fresh-failure-final/s
  `(Forced
    (Owners (Owner (u:0) (label "fresh-outside")))
    (Done ,owners-empty)))
(define unused-fresh-failure-final/e
  '(Forced (Done (Support u:0))))
(define unused-fresh-failure-final/n
  '(Forced (Done 1)))

(define delay-trace-families
  (list
   (list 'suspend-success
         suspend-success-source/s
         suspend-success-source/e
         suspend-success-source/n
         '(suspend-goal force-delay succeed finish-success)
         suspend-success-final/s
         suspend-success-final/e
         suspend-success-final/n)
   (list 'bubble-success
         bubble-source/s
         bubble-source/e
         bubble-source/n
         '(bubble-delay-through-conj
           force-delay
           succeed
           conj-return
           succeed
           finish-success)
         bubble-success-final/s
         bubble-success-final/e
         bubble-success-final/n)
   (list 'suspend-failure
         suspend-failure-source/s
         suspend-failure-source/e
         suspend-failure-source/n
         '(suspend-goal force-delay fail finish-failure)
         suspend-failure-final/s
         suspend-failure-final/e
         suspend-failure-final/n)
   (list 'nested-suspend
         nested-suspend-source/s
         nested-suspend-source/e
         nested-suspend-source/n
         '(suspend-goal
           force-delay
           suspend-goal
           force-delay
           succeed
           finish-success)
         nested-suspend-final/s
         nested-suspend-final/e
         nested-suspend-final/n)
   (list 'fresh-inside-suspend
         fresh-inside-source/s
         fresh-inside-source/e
         fresh-inside-source/n
         '(suspend-goal
           force-delay
           allocate-fresh
           succeed
           finish-success)
         fresh-inside-final/s
         fresh-inside-final/e
         fresh-inside-final/n)
   (list 'unused-fresh-outside-delayed-failure
         unused-fresh-failure-source/s
         unused-fresh-failure-source/e
         unused-fresh-failure-source/n
         '(allocate-fresh
           suspend-goal
           force-delay
           fail
           finish-failure)
         unused-fresh-failure-final/s
         unused-fresh-failure-final/e
         unused-fresh-failure-final/n)))

(define (trace-final source trace)
  (match trace
    ['() source]
    [_ (second (last trace))]))

(define-runtime-path s-language-path "s/language.rkt")
(define-runtime-path s-source-path "s/source.rkt")
(define-runtime-path s-wf-path "s/wf.rkt")
(define-runtime-path e-language-path "e/language.rkt")
(define-runtime-path e-source-path "e/source.rkt")
(define-runtime-path e-wf-path "e/wf.rkt")
(define-runtime-path n-language-path "n/language.rkt")
(define-runtime-path n-source-path "n/source.rkt")
(define-runtime-path n-wf-path "n/wf.rkt")
(define-runtime-path vertical-path "vertical.rkt")
(define-runtime-path shared-path "private/shared.rkt")

(define DELAY-ORACLE-TESTS
  (test-suite
   "independent Delay source/WF oracle"

   (test-case
    "S/E/N grammars state the intended carriers and scheduler exclusions"
    (check-true
     (redex-match? sl:delay-s-oracle-lang
                   W
                   '(PendingDelay (Owners) (Dead (Owners)))))
    (check-true
     (redex-match? sl:delay-s-oracle-lang
                   F
                   '(Forced (Owners) (Done (Owners)))))
    (check-true
     (redex-match? el:delay-e-oracle-lang
                   W
                   '(PendingDelay (Dead (Support)))))
    (check-true
     (redex-match? el:delay-e-oracle-lang
                   F
                   '(Forced (Done (Support)))))
    (check-true
     (redex-match? nl:delay-n-oracle-lang
                   W
                   '(PendingDelay (Dead 0))))
    (check-true
     (redex-match? nl:delay-n-oracle-lang
                   F
                   '(Forced (Done 0))))
    (check-true
     (redex-match? sl:delay-s-oracle-lang
                   WorkOwnerSlot
                   (term (PendingDelay hole (Dead (Owners))))))
    (check-true
     (redex-match? sl:delay-s-oracle-lang
                   SpineContext
                   (term (Forced (Owners) hole))))
    (check-true
     (redex-match? el:delay-e-oracle-lang
                   SpineContext
                   (term (Forced hole))))
    (check-true
     (redex-match? nl:delay-n-oracle-lang
                   SpineContext
                   (term (Forced hole))))

    ;; Delay carriers do not cross the W/F phase boundary or the suspended
    ;; WorkPath barrier.
    (check-false
     (redex-match? sl:delay-s-oracle-lang
                   F
                   '(PendingDelay (Owners) (Dead (Owners)))))
    (check-false
     (redex-match? sl:delay-s-oracle-lang
                   W
                   '(Forced (Owners) (Done (Owners)))))
    (check-false
     (redex-match? sl:delay-s-oracle-lang
                   WorkPath
                   (term (PendingDelay (Owners) hole))))
    (check-false
     (redex-match? el:delay-e-oracle-lang
                   WorkPath
                   (term (PendingDelay hole))))
    (check-false
     (redex-match? nl:delay-n-oracle-lang
                   WorkPath
                   (term (PendingDelay hole))))

    ;; E/N wrappers carry neither copied Support nor copied next.
    (check-false
     (redex-match? el:delay-e-oracle-lang
                   W
                   '(PendingDelay (Support u:0) (Dead (Support u:0)))))
    (check-false
     (redex-match? nl:delay-n-oracle-lang
                   W
                   '(PendingDelay 1 (Dead 1))))

    ;; Branching, scheduler, and relation-call constructors remain outside
    ;; this source feature grammar.
    (for ([excluded
           (in-list
            '(((succeed (label "l"))
               ∨
               (fail (label "r"))
               (label "or"))
              (relcall r (x:a) (label "call"))))])
      (check-false (redex-match? sl:delay-s-oracle-lang g excluded))
      (check-false (redex-match? el:delay-e-oracle-lang g excluded))
      (check-false (redex-match? nl:delay-n-oracle-lang g excluded)))
    (for ([excluded-s
           (in-list
            '((DisjL (Owners) (Dead (Owners)) (Dead (Owners)))
              (DisjR (Owners) (Dead (Owners)) (Dead (Owners)))
              (Emit (Owners)
                    (Answer (Owners) (state () () () (label "state")))
                    (Done (Owners)))))])
      (check-false (redex-match? sl:delay-s-oracle-lang W excluded-s))
      (check-false (redex-match? sl:delay-s-oracle-lang F excluded-s)))
    (for ([excluded-e
           (in-list
            '((DisjL (Dead (Support)) (Dead (Support)))
              (DisjR (Dead (Support)) (Dead (Support)))
              (Emit (Answer (state (Support) () () () (label "state")))
                    (Done (Support)))))]
          [excluded-n
           (in-list
            '((DisjL (Dead 0) (Dead 0))
              (DisjR (Dead 0) (Dead 0))
              (Emit (Answer (state 0 () () () (label "state")))
                    (Done 0))))])
      (check-false (redex-match? el:delay-e-oracle-lang W excluded-e))
      (check-false (redex-match? el:delay-e-oracle-lang F excluded-e))
      (check-false (redex-match? nl:delay-n-oracle-lang W excluded-n))
      (check-false (redex-match? nl:delay-n-oracle-lang F excluded-n))))

   (test-case
    "each direct relation contains 13 inherited labels and three Delay labels"
    (for ([actual
           (in-list
            (list (rule-names ss:delay-s-oracle-red)
                  (rule-names es:delay-e-oracle-red)
                  (rule-names ns:delay-n-oracle-red)))])
      (check-equal? (length actual) 16)
      (check-equal? (length actual)
                    (length (remove-duplicates actual)))
      (check-equal? (sort actual symbol<?) expected-rule-names)))

   (test-case
    "the three Delay equations have exact direct S/E/N targets"
    (check-equal?
     (ss:raw-successors/delay/s suspend-source/s)
     (list (list 'suspend-goal expected-suspend-target/s)))
    (check-equal?
     (ss:raw-successors/delay/s bubble-source/s)
     (list (list 'bubble-delay-through-conj expected-bubble-target/s)))
    (check-equal?
     (ss:raw-successors/delay/s force-source/s)
     (list (list 'force-delay expected-force-target/s)))
    (check-equal?
     (ss:raw-successors/delay/s allocate-source/s)
     (list (list 'allocate-fresh expected-allocate-target/s)))

    (check-equal?
     (es:raw-successors/delay/e suspend-source/e)
     (list (list 'suspend-goal expected-suspend-target/e)))
    (check-equal?
     (es:raw-successors/delay/e bubble-source/e)
     (list (list 'bubble-delay-through-conj expected-bubble-target/e)))
    (check-equal?
     (es:raw-successors/delay/e force-source/e)
     (list (list 'force-delay expected-force-target/e)))

    (check-equal?
     (ns:raw-successors/delay/n suspend-source/n)
     (list (list 'suspend-goal expected-suspend-target/n)))
    (check-equal?
     (ns:raw-successors/delay/n bubble-source/n)
     (list (list 'bubble-delay-through-conj expected-bubble-target/n)))
    (check-equal?
     (ns:raw-successors/delay/n force-source/n)
     (list (list 'force-delay expected-force-target/n))))

   (test-case
    "lexical substitution crosses suspend and respects nested shadowing"
    (define shadowed-goal
      '(∃ (x:outer)
          (suspend
           ((x:outer =? x:free (label "inside"))
            ∧
            (suspend
             (x:free != x:outer (label "nested"))
             (label "nested-suspend"))
            (label "and"))
           (label "outer-suspend"))
          (label "shadow")))
    (define expected-s
      '(∃ (x:outer)
          (suspend
           ((x:outer =? u:8 (label "inside"))
            ∧
            (suspend
             (u:8 != x:outer (label "nested"))
             (label "nested-suspend"))
            (label "and"))
           (label "outer-suspend"))
          (label "shadow")))
    (define expected-n
      '(∃ (x:outer)
          (suspend
           ((x:outer =? 8 (label "inside"))
            ∧
            (suspend
             (8 != x:outer (label "nested"))
             (label "nested-suspend"))
            (label "and"))
           (label "outer-suspend"))
          (label "shadow")))
    (check-equal?
     (ss:subst-goal/delay/s shadowed-goal
                            '((x:outer u:7) (x:free u:8)))
     expected-s)
    (check-equal?
     (es:subst-goal/delay/e shadowed-goal
                            '((x:outer u:7) (x:free u:8)))
     expected-s)
    (check-equal?
     (term
      (ns:subst-goal/delay/n
       ,shadowed-goal
       ((x:outer 7) (x:free 8))))
     expected-n))

   (test-case
    "raw WF derivations preserve proof multiplicity for all 16 equations"
    (for ([representative (in-list rule-representatives/s)])
      (match-define (list expected-name source/s) representative)
      (define source/e (Q-SE/F/delay source/s))
      (define source/n (Q-SN/F/delay source/s))
      (define step/s
        (only-raw-successor ss:raw-successors/delay/s source/s))
      (define step/e
        (only-raw-successor es:raw-successors/delay/e source/e))
      (define step/n
        (only-raw-successor ns:raw-successors/delay/n source/n))
      (match-define (list name/s target/s) step/s)
      (match-define (list name/e target/e) step/e)
      (match-define (list name/n target/n) step/n)

      (check-equal? name/s expected-name)
      (check-equal? name/e expected-name)
      (check-equal? name/n expected-name)
      ;; These are raw build-derivations lists.  The exact length checks are
      ;; multiplicity checks; no proof or target is deduplicated.
      (check-equal? (length (wf-proofs/s source/s)) 1)
      (check-equal? (length (wf-proofs/e source/e)) 1)
      (check-equal? (length (wf-proofs/n source/n)) 1)
      (check-equal? (length (wf-proofs/s target/s)) 1)
      (check-equal? (length (wf-proofs/e target/e)) 1)
      (check-equal? (length (wf-proofs/n target/n)) 1)))

   (test-case
    "Delay WF recurses through suspend and both runtime wrappers"
    (define ill-scoped/s
      `(Forced
        ,owners-empty
        (More
         (PendingDelay
          ,owners-empty
          (Work
           ,owners-empty
           (suspend
            (u:9 =? (nat 0) (label "unbound"))
            (label "suspend"))
           ,sigma-empty/s)))))
    (define ill-scoped/e
      '(Forced
        (More
         (PendingDelay
          (Work
           (suspend
            (u:9 =? (nat 0) (label "unbound"))
            (label "suspend"))
           (state (Support) () () () (label "state")))))))
    (define ill-scoped/n
      '(Forced
        (More
         (PendingDelay
          (Work
           (suspend
            (9 =? (nat 0) (label "unbound"))
            (label "suspend"))
           (state 0 () () () (label "state")))))))
    (check-equal? (wf-proofs/s ill-scoped/s) '())
    (check-equal? (wf-proofs/e ill-scoped/e) '())
    (check-equal? (wf-proofs/n ill-scoped/n) '()))

   (test-case
    "direct S/E/N maps commute on every inherited and Delay equation"
    (for ([representative (in-list rule-representatives/s)])
      (match-define (list _ source/s) representative)
      (define source/e (Q-SE/F/delay source/s))
      (match-define (list _ target/s)
        (only-raw-successor ss:raw-successors/delay/s source/s))
      (match-define (list _ target/e)
        (only-raw-successor es:raw-successors/delay/e source/e))
      (match-define (list _ target/n)
        (only-raw-successor
         ns:raw-successors/delay/n
         (Q-SN/F/delay source/s)))
      (check-true (Q-SE-step-square/raw?/delay source/s))
      (check-true (Q-EN-step-square/raw?/delay source/e))
      (check-true (Q-SN-step-square/raw?/delay source/s))
      (check-true (Q-SN-composition?/delay source/s))
      (check-equal? (Q-SE/F/delay target/s) target/e)
      (check-equal? (Q-SN/F/delay target/s) target/n)
      (check-equal? (Q-EN/F/delay target/e) target/n)))

   (test-case
    "vertical observations expose ownerful S and ownerless E/N Delay rows"
    (check-equal?
     (delay-row-observation force-source/s)
     (list
      (list 'S force-source/s)
      (list
       'E
       '(More
         (PendingDelay
          (Work
           (succeed (label "forced-body"))
           (state
            (Support u:0 u:1)
            ()
            ()
            ()
            (label "state"))))))
      (list
       'N
       '(More
         (PendingDelay
          (Work
           (succeed (label "forced-body"))
           (state 2 () () () (label "state"))))))))
    (check-equal?
     (delay-row-observation expected-force-target/s)
     (list
      (list 'S expected-force-target/s)
      (list
       'E
       '(Forced
         (More
          (Work
           (succeed (label "forced-body"))
           (state
            (Support u:0 u:1)
            ()
            ()
            ()
            (label "state"))))))
      (list
       'N
       '(Forced
         (More
          (Work
           (succeed (label "forced-body"))
           (state 2 () () () (label "state")))))))))

   (test-case
    "a bounded Delay program has the same finite named trace in S/E/N"
    (define trace-source/e (Q-SE/F/delay trace-source/s))
    (define trace-source/n (Q-SN/F/delay trace-source/s))
    (define trace/s (ss:trace/delay/s trace-source/s))
    (define trace/e (es:trace/delay/e trace-source/e))
    (define trace/n (ns:trace/delay/n trace-source/n))
    (check-equal? (map first trace/s) expected-trace-names)
    (check-equal? (map first trace/e) expected-trace-names)
    (check-equal? (map first trace/n) expected-trace-names)
    (check-equal? (length trace/s) 8)
    (check-equal? (length trace/e) 8)
    (check-equal? (length trace/n) 8)
    (for ([step/s (in-list trace/s)]
          [step/e (in-list trace/e)]
          [step/n (in-list trace/n)])
      (match-define (list name/s target/s) step/s)
      (match-define (list name/e target/e) step/e)
      (match-define (list name/n target/n) step/n)
      (check-equal? name/s name/e)
      (check-equal? name/s name/n)
      (check-equal? (Q-SE/F/delay target/s) target/e)
      (check-equal? (Q-SN/F/delay target/s) target/n)))

   (test-case
    "six finite Delay trace families preserve exact labels and final evidence"
    (for ([family (in-list delay-trace-families)])
      (match-define
        (list family-name
              source/s
              source/e
              source/n
              expected-names
              expected-final/s
              expected-final/e
              expected-final/n)
        family)
      (define trace/s (ss:trace/delay/s source/s))
      (define trace/e (es:trace/delay/e source/e))
      (define trace/n (ns:trace/delay/n source/n))
      (define message (~a family-name))

      ;; Each row begins from an independently written coordinate.  Q is used
      ;; here only for the commuting observations, never to create a source.
      (check-equal? (Q-SE/F/delay source/s) source/e message)
      (check-equal? (Q-SN/F/delay source/s) source/n message)
      (check-equal? (Q-EN/F/delay source/e) source/n message)
      (check-equal? (map first trace/s) expected-names message)
      (check-equal? (map first trace/e) expected-names message)
      (check-equal? (map first trace/n) expected-names message)
      (check-equal? (trace-final source/s trace/s) expected-final/s message)
      (check-equal? (trace-final source/e trace/e) expected-final/e message)
      (check-equal? (trace-final source/n trace/n) expected-final/n message)
      (for ([step/s (in-list trace/s)]
            [step/e (in-list trace/e)]
            [step/n (in-list trace/n)])
        (match-define (list name/s target/s) step/s)
        (match-define (list name/e target/e) step/e)
        (match-define (list name/n target/n) step/n)
        (check-equal? name/s name/e message)
        (check-equal? name/s name/n message)
        (check-equal? (Q-SE/F/delay target/s) target/e message)
        (check-equal? (Q-SN/F/delay target/s) target/n message)
        (check-equal? (Q-EN/F/delay target/e) target/n message))))

   (test-case
    "oracle declarations remain independent of generated and production Delay"
    (for ([path
           (in-list
            (list s-language-path
                  s-source-path
                  s-wf-path
                  e-language-path
                  e-source-path
                  e-wf-path
                  n-language-path
                  n-source-path
                  n-wf-path
                  vertical-path
                  shared-path))])
      (define contents (file->string path))
      (check-false (regexp-match? #rx"generated/" contents))
      (check-false (regexp-match? #rx"src/search-lattice" contents))
      (check-false (regexp-match? #rx"stage-generators" contents))))))

(module+ test
  (run-tests DELAY-ORACLE-TESTS))

(module+ main
  (define failures (run-tests DELAY-ORACLE-TESTS))
  (unless (zero? failures)
    (error 'delay-oracle-tests "~a test failure(s)" failures)))
