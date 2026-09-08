#lang racket

(require racket/list
         racket/match
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../support.rkt"
         "../../../src/search-strategy.rkt")

(provide SCHEDULER-PROGRESS)

(define TRACE-CAP 128)

(struct trace-edge (before label after) #:transparent)
(struct trace-result (edges final) #:transparent)
(struct owner-observation (intro tag) #:transparent)
(struct answer-observation (event owners) #:transparent)

;; Both durable witnesses enter the historical online carrier directly.
;; There is deliberately no compatibility layer for the former tree/shell
;; vocabulary: the root is F, and unfinished computation sits below More as W.
(define nested-fresh/disj-config
  (term
   (()
    (More
     (Work (Owners)
      (∃ (x:outer)
         ((∃ (x:inner)
             (((sym "inner-left") =? (sym "inner-left") (label "inner-left"))
              ∨
              ((sym "inner-right") =? (sym "inner-right") (label "inner-right"))
              (label "inner-split"))
             (label "branch-fresh"))
          ∨
          ((sym "outer-right") =? (sym "outer-right") (label "outer-right"))
          (label "outer-split"))
         (label "outer-fresh"))
      (state () () () (label "initial")))))))

(define right-active-delay/fresh/conj-config
  (term
   (()
    (More
     (Work (Owners)
      (((∃ (x:owner)
            (succeed (label "seed"))
            (label "fresh"))
         ∧
         ((suspend
           ((sym "later") =? (sym "later") (label "later"))
           (label "delay"))
          ∨
          ((sym "now") =? (sym "now") (label "now"))
          (label "split"))
         (label "seed-and-choice"))
       ∧
       (succeed (label "continue"))
       (label "outer-and"))
      (state () () () (label "initial")))))))

;; DisjR is rail-local syntax. This witness is rejected by the ordinary
;; search carrier used by DFS and flip, but rail owns its pending-delay turn.
(define rail-right-active-frontier
  (term (More (DisjR (Owners) (Dead (Owners)) (PendingDelay (Owners) (Dead (Owners)))))))

(define rail-right-active-config
  (term (() ,rail-right-active-frontier)))

(define rail-right-active-target
  (term (() (More (PendingDelay (Owners) (DisjL (Owners) (Dead (Owners)) (Dead (Owners))))))))

(define/match (strategy-label strategy)
  [((search-strategy scheduler)) scheduler])

(define (tag-name tag)
  (match tag
    [`(label ,(? string? name)) name]
    [_ tag]))

(define (final-answer? answer)
  (match answer
    [`(Answer ,_owners ,_) #t]
    [_ #f]))

(define (final-frontier? frontier)
  (match frontier
    [`(Done ,_owners) #t]
    [`(Last ,_owners ,answer) (final-answer? answer)]
    [`(Forced ,_owners ,frontier^) (final-frontier? frontier^)]
    [`(Emit ,_owners ,answer ,frontier^)
     (and (final-answer? answer)
          (final-frontier? frontier^))]
    [_ #f]))

(define (final-config? config)
  (match config
    [`(,_ ,frontier) (final-frontier? frontier)]
    [_ #f]))

(define (run-strategy strategy config [remaining TRACE-CAP] [rev-edges '()])
  (define who (strategy-label strategy))
  (check-true (online-in-domain? strategy config)
              (format "~a left its grammatical language at ~s" who config))
  (check-true (online-well-formed? strategy config)
              (format "~a violated grammatical well-formedness at ~s" who config))
  (when (negative? remaining)
    (fail-check (format "~a exceeded the ~a-edge cap at ~s"
                        who TRACE-CAP config)))
  (define next* (apply-reduction-relation/tag-with-names (online-relation strategy) config))
  (match next*
    ['()
     (check-true (final-config? config)
                 (format "~a is stuck at a well-formed nonterminal: ~s"
                         who config))
     (trace-result (reverse rev-edges) config)]
    [(list (list label config^))
     (check-false (final-config? config)
                  (format "~a steps from a terminal frontier via ~a"
                          who label))
     (run-strategy strategy
                   config^
                   (sub1 remaining)
                   (cons (trace-edge config (~a label) config^) rev-edges))]
    [_
     ;; The surfaced stepper normally raises before this arm. Keeping the
     ;; explicit check here documents the deterministic progress contract.
     (fail-check
      (format "~a has multiple grammatical successors at ~s: ~s"
              who config next*))]))

(define (answer-event state)
  (match state
    [`(state ,_ ,_ ,trail ,_)
     (match (last trail)
       [`(,_ =? ,_ ,tag) (tag-name tag)]
       [_ (error 'answer-event "unexpected answer trail: ~s" trail)])]
    [_ (error 'answer-event "unexpected answer state: ~s" state)]))

(define (observe-answer answer owners)
  (match answer
    [`(Answer ,answer-owners ,state)
     (answer-observation
      (answer-event state)
      (append owners (observe-owner-stack answer-owners)))]
    [_ (error 'observe-answer "unexpected answer: ~s" answer)]))

(define (observe-owner-stack owners)
  (match owners
    [(list 'Owners owner* ...)
     (for/list ([owner (in-list owner*)])
       (match owner
         [`(Owner ,intro ,tag)
          (owner-observation intro (tag-name tag))]))]
    [_ (error 'observe-owner-stack "unexpected owner stack: ~s" owners)]))

(define (frontier-observations frontier [owners '()])
  (match frontier
    [`(Done ,_owners) '()]
    [`(Last ,local-owners ,answer)
     (list (observe-answer
            answer
            (append owners (observe-owner-stack local-owners))))]
    [`(Forced ,local-owners ,frontier^)
     (frontier-observations
      frontier^
      (append owners (observe-owner-stack local-owners)))]
    [`(Emit ,local-owners ,answer ,frontier^)
     (define owners^
       (append owners (observe-owner-stack local-owners)))
     (cons (observe-answer answer owners^)
           (frontier-observations frontier^ owners^))]
    [_ (error 'frontier-observations "nonterminal frontier: ~s" frontier)]))

(define (config-observations config)
  (match config
    [`(,_ ,frontier) (frontier-observations frontier)]
    [_ (error 'config-observations "unexpected config: ~s" config)]))

(define (trace-labels result)
  (map trace-edge-label (trace-result-edges result)))

(define (label-count result expected)
  (count (lambda (actual) (string=? actual expected))
         (trace-labels result)))

(define (owner-observations datum)
  (match datum
    [`(Owner ,intro ,tag)
     (list (owner-observation intro (tag-name tag)))]
    [(? pair?)
     (append-map owner-observations datum)]
    [_ '()]))

(define (allocation-owners result)
  (for/list ([edge (in-list (trace-result-edges result))]
             #:when (string=? (trace-edge-label edge) "allocate-fresh"))
    (define before-owners
      (owner-observations (trace-edge-before edge)))
    (define introduced-owners
      (remove-duplicates
       (filter (lambda (owner) (not (member owner before-owners)))
               (owner-observations (trace-edge-after edge)))))
    (match introduced-owners
      [(list owner) owner]
      [_
       (fail-check
        (format "allocate-fresh did not introduce exactly one owner: ~s"
                edge))])))

(define (owner-observation-count datum expected-owner)
  (count (lambda (actual) (equal? actual expected-owner))
         (owner-observations datum)))

(define (only-edges-named result rule-name)
  (filter (lambda (edge) (string=? (trace-edge-label edge) rule-name))
          (trace-result-edges result)))

(define (check-owner-duplication result rule-name owner who)
  (define duplication-edges
    (only-edges-named result rule-name))
  (check-equal? (length duplication-edges) 1 who)
  (define edge (first duplication-edges))
  (check-equal? (owner-observation-count (trace-edge-before edge) owner)
                1
                who)
  (check-equal? (owner-observation-count (trace-edge-after edge) owner)
                2
                (format "~a did not duplicate ~s exactly once" who owner)))

(define (check-owner-preserved result rule-name owner who)
  (define movement-edges
    (filter (lambda (edge) (string=? (trace-edge-label edge) rule-name))
            (trace-result-edges result)))
  (check-equal? (length movement-edges) 1 who)
  (define edge (first movement-edges))
  (check-equal? (owner-observation-count (trace-edge-before edge) owner)
                1
                who)
  (check-equal? (owner-observation-count (trace-edge-after edge) owner)
                1
                (format "~a did not preserve ~s across ~a"
                        who owner rule-name)))

(define nested-expected
  (list
   (answer-observation
    "inner-left"
    (list (owner-observation '(u:0) "outer-fresh")
          (owner-observation '(u:1) "branch-fresh")))
   (answer-observation
    "inner-right"
    (list (owner-observation '(u:0) "outer-fresh")
          (owner-observation '(u:1) "branch-fresh")))
   (answer-observation
    "outer-right"
    (list (owner-observation '(u:0) "outer-fresh")))))

(define (right-expected scheduler)
  (define events
    (if (string=? scheduler "dfs")
        '("later" "now")
        '("now" "later")))
  (for/list ([event (in-list events)])
    (answer-observation
     event
     (list (owner-observation '(u:0) "fresh")))))

(define/provide-test-suite SCHEDULER-PROGRESS
  (test-case "nested fresh/disjunction progresses with exact ownership in every surfaced strategy"
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (define who (strategy-label strategy))
      (define result (run-strategy strategy nested-fresh/disj-config))
      (check-equal? (config-observations (trace-result-final result))
                    nested-expected
                    who)
      (check-equal? (allocation-owners result)
                    (list (owner-observation '(u:0) "outer-fresh")
                          (owner-observation '(u:1) "branch-fresh"))
                    who)
      (check-owner-duplication result
                               "reassociate-left-result"
                               (owner-observation '(u:1) "branch-fresh")
                               who)))

  (test-case "right-active delayed fresh conjunction progresses and preserves scheduler evidence"
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (match-define (search-strategy scheduler) strategy)
      (define who (strategy-label strategy))
      (define result
        (run-strategy strategy right-active-delay/fresh/conj-config))
      (check-equal? (config-observations (trace-result-final result))
                    (right-expected scheduler)
                    who)
      (check-equal? (allocation-owners result)
                    (list (owner-observation '(u:0) "fresh"))
                    who)
      (check-equal? (label-count result "force-delay") 1 who)
      (define scheduler-rule
        (match scheduler
          ["dfs" "dfs-delay-left"]
          ["flip" "flip-delay-left"]
          ["rail" "rail-enter-right"]))
      (check-equal? (label-count result scheduler-rule) 1 who)
      (check-owner-preserved result
                             scheduler-rule
                             (owner-observation '(u:0) "fresh")
                             who)
      (cond
        [(string=? scheduler "rail")
         (check-equal? (label-count result "commit-right-choice-answer")
                       1
                       who)
         (check-equal? (label-count result "rail-return-left") 0 who)
         (check-equal? (label-count result "resume-right-choice-success")
                       1
                       who)]
        [else
         (check-equal? (label-count result "rail-enter-right") 0 who)
         (check-equal? (label-count result "rail-return-left") 0 who)])))

  (test-case "right-active syntax belongs only to the rail grammatical domain"
    (for ([scheduler (in-list '("dfs" "flip"))])
      (define strategy (search-strategy scheduler))
      (check-false
       (online-in-domain? strategy rail-right-active-config)
       (format "~a admitted rail-local DisjR syntax" scheduler)))
    (define rail-strategy (search-strategy "rail"))
    (check-true
     (online-in-domain? rail-strategy rail-right-active-config))
    (check-true
     (online-well-formed? rail-strategy rail-right-active-config))
    (check-equal?
     (apply-reduction-relation/tag-with-names (online-relation rail-strategy) rail-right-active-config)
     (list (list "rail-return-left" rail-right-active-target))))
  )

(module+ test
  (run-tests SCHEDULER-PROGRESS))
