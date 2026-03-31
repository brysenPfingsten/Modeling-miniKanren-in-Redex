#lang racket

(require json
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../src/canonical-json.rkt"
         (prefix-in lang:
                    "../src/search-lattice/languages/all.rkt")
         (prefix-in red:
                    "../src/search-lattice/reduction-relations/all.rkt")
         "../src/search-lattice/reduction-relations/private/common.rkt"
         (prefix-in wf:
                    "../src/search-lattice/wf/all.rkt")
         "./search-lattice-support.rkt")

(define (named-step succ*)
  (match succ*
    [(list (list name cfg))
     (values name cfg)]
    [_ (error 'named-step "expected exactly one tagged successor, got ~e" succ*)]))

(define/provide-test-suite SEARCH-LATTICE
  (test-case "feature languages reflect the new split and omit proceed"
    (check-true (redex-match? lang:core-lang QFresh (term (Freshened (u:0) hole (label "fresh")))))
    (check-false (redex-match? lang:delay-lang cfg '(delay (empty-tree))))
    (check-true (redex-match? lang:delay-lang cfg (term ,delayed-left-search)))
    (check-false (redex-match? lang:delay-lang cfg '(proceed (empty-tree))))
    (check-true (redex-match? lang:calls-lang g '(r:delay (label "call"))))
    (check-true (redex-match? lang:disj-seq-lang KBranch (term (hole <-+ (empty-tree)))))
    (check-true
     (redex-match?
      lang:disj-fused-lang
      KLate
      (term (hole × (succeed (label "k")) ()))))
    (check-true (redex-match? lang:rail-lang cfg '((empty-tree) +-> (empty-tree))))
    (check-false
     (redex-match?
      lang:core-lang
      search
      (term (((⊤ ,sigma-a) + (empty-tree))
             × (succeed (label "k"))
             ()))))
    (check-true (redex-match? lang:calls-lang config (term ,cfg-call))))

  (test-case "disj-seq distributes immediately while disj-fused keeps mixed states"
    (define pending-disj
      (term ((((succeed (label "left")) ,sigma-s)
              <-+
              ((succeed (label "right")) ,sigma-s))
             × (succeed (label "k"))
             ())))
    (define-values (seq-name _seq-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-seq-red
        pending-disj)))
    (define-values (fused-pending-name _fused-pending-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-fused-red
        pending-disj)))
    (define-values (fused-answer-name _fused-answer-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-fused-red
        cfg-mixed-answer)))
    (define-values (fused-fail-name _fused-fail-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-fused-red
        cfg-mixed-fail)))
    (check-equal? (~a seq-name) "disj-seq/distribute-over-conj")
    (check-equal? (~a fused-pending-name) "core/succeed")
    (check-equal? (~a fused-answer-name) "disj-fused/continue-left-answer")
    (check-equal? (~a fused-fail-name) "disj-fused/continue-left-fail"))

  (test-case "disj-fused continues freshened answers structurally"
    (define freshened-answer
      (term (((Freshened (u:0) (⊤ ,sigma-a) (label "fresh")) <-+ (⊤ ,sigma-b))
             × (succeed (label "k"))
             ())))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-fused-red
        freshened-answer)))
    (check-equal? (~a step-name) "disj-fused/continue-left-answer")
    (check-equal? next
                  (term ((Freshened (u:0)
                                    ((succeed (label "k")) ,sigma-a)
                                    (label "fresh"))
                         <-+
                         ((⊤ ,sigma-b) × (succeed (label "k")) ())))))

  (test-case "search-base search-only branches handle explicit delay with no relcalls"
    (for ([rel (in-list (list red:search-base-seq-red
                              red:search-base-fused-red))])
      (define-values (step1-name step1)
        (named-step (apply-reduction-relation/tag-with-names rel cfg-delay-goal)))
      (define-values (step2-name _step2)
        (named-step (apply-reduction-relation/tag-with-names rel step1)))
      (check-equal? (~a step1-name) "delay/suspend-goal")
      (check-equal? (~a step2-name) "delay/invoke-delay")))

  (test-case "search-base promotes bare answers and forbids buried +"
    (define-values (seq-name seq-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-seq-red
        cfg-disj)))
    (define-values (fused-name fused-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-fused-red
        cfg-disj)))
    (define illegal-prefix-conj
      (term (((⊤ ,sigma-a) + (empty-tree))
             × (succeed (label "k"))
             ())))
    (check-false
     (redex-match?
      lang:search-base-lang
      cfg
      illegal-prefix-conj))
    (check-false
     (redex-match?
      lang:search-base-lang
      cfg
      (term (((⊤ ,sigma-a) + (empty-tree)) <-+ (⊤ ,sigma-b)))))
    (check-equal? (~a seq-name) "disj/promote-left-answer")
    (check-equal? (~a fused-name) "disj/promote-left-answer")
    (check-true (produced-answer-spine-only? seq-next))
    (check-true (produced-answer-spine-only? fused-next))
    (check-true (redex-match? lang:search-base-lang cfg seq-next))
    (check-true (redex-match? lang:search-base-lang cfg fused-next)))

  (test-case "search-base reassociates then closes bounced segments when an answer appears"
    (define bounced-branch
      (term (Bounced (((⊤ ,sigma-a) <-+ (empty-tree))
                      <-+
                      (⊤ ,sigma-b)))))
    (define bad-bounced-promotion
      (term (Bounced ((((⊤ ,sigma-a) + (empty-tree))
                       <-+
                       (⊤ ,sigma-b))))))
    (define-values (seq-name-1 seq-mid)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-seq-red
        bounced-branch)))
    (define-values (seq-name-2 seq-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-seq-red
        seq-mid)))
    (define-values (fused-name-1 fused-mid)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-fused-red
        bounced-branch)))
    (define-values (fused-name-2 fused-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-fused-red
        fused-mid)))
    (check-equal? (~a seq-name-1) "disj/reassociate-left-answer")
    (check-equal? (~a seq-name-2) "disj/promote-left-answer")
    (check-equal? (~a fused-name-1) "disj/reassociate-left-answer")
    (check-equal? (~a fused-name-2) "disj/promote-left-answer")
    (check-equal? seq-mid
                  (term (Bounced ((⊤ ,sigma-a)
                                  <-+
                                  ((empty-tree) <-+ (⊤ ,sigma-b))))))
    (check-equal? fused-mid
                  (term (Bounced ((⊤ ,sigma-a)
                                  <-+
                                  ((empty-tree) <-+ (⊤ ,sigma-b))))))
    (check-false
     (member bad-bounced-promotion
             (map tagged-successor-cfg
                  (apply-reduction-relation/tag-with-names
                   red:search-base-seq-red
                   bounced-branch))))
    (check-false
     (member bad-bounced-promotion
             (map tagged-successor-cfg
                  (apply-reduction-relation/tag-with-names
                   red:search-base-fused-red
                   bounced-branch))))
    (check-equal? seq-next
                  (term (Bounced ((⊤ ,sigma-a)
                                  +
                                  ((empty-tree) <-+ (⊤ ,sigma-b))))))
    (check-equal? fused-next
                  (term (Bounced ((⊤ ,sigma-a)
                                  +
                                  ((empty-tree) <-+ (⊤ ,sigma-b))))))
    (check-true (produced-answer-spine-only? seq-next))
    (check-true (produced-answer-spine-only? fused-next)))

  (test-case "canonical JSON preserves bounced observables under Freshened prefixes"
    (define rendered
      (string->jsexpr
       (to-json/canonical
        (term (() (Freshened
                   (u:0)
                   (Bounced (empty-tree))
                   (label "fresh"))))
        0)))
    (check-equal? (hash-ref rendered 'name) "Freshened")
    (check-equal? (hash-ref rendered 'id) "fresh")
    (define child (first (hash-ref rendered 'children)))
    (check-equal? (hash-ref child 'name) "Bounced"))

  (test-case "search-only scheduler variants differ only in delayed left-branch policy"
      (for ([entry (in-list
                  (list
                   (list red:search-dfs-seq-red
                         "search-dfs-seq/delay-through-left"
                         (term (delay (((succeed (label "late")) ,sigma-s)
                                       <-+
                                       (⊤ ,sigma-b)))))
                   (list red:search-dfs-fused-red
                         "search-dfs-fused/delay-through-left"
                         (term (delay (((succeed (label "late")) ,sigma-s)
                                       <-+
                                       (⊤ ,sigma-b)))))
                   (list red:search-flip-seq-red
                         "search-flip-seq/delay-swap-left"
                         (term (delay ((⊤ ,sigma-b)
                                       <-+
                                       ((succeed (label "late")) ,sigma-s)))))
                   (list red:search-flip-fused-red
                         "search-flip-fused/delay-swap-left"
                         (term (delay ((⊤ ,sigma-b)
                                       <-+
                                       ((succeed (label "late")) ,sigma-s)))))))])
      (match-define (list rel expected-name expected-template) entry)
      (define-values (step-name next)
        (named-step (apply-reduction-relation/tag-with-names rel cfg-flip)))
      (check-equal? (~a step-name) expected-name)
      (check-equal? next expected-template)))

  (test-case "rail search-only branches enter the railroad from delayed left disjunction"
    (for ([entry (in-list
                  (list (list red:rail-seq-red "rail-seq/enter-right")
                        (list red:rail-fused-red "rail-fused/enter-right")))])
      (match-define (list rel expected-name) entry)
      (define-values (step-name next)
        (named-step (apply-reduction-relation/tag-with-names rel cfg-rail)))
      (check-equal? (~a step-name) expected-name)
      (check-true (redex-match? lang:rail-lang cfg next))))

  (test-case "rail promotes bare right-branch answers and forbids branch-internal +"
    (define-values (seq-name seq-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:rail-seq-red
        (term ((empty-tree) +-> (⊤ ,sigma-b))))))
    (define-values (fused-name fused-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:rail-fused-red
        (term ((empty-tree) +-> (⊤ ,sigma-b))))))
    (check-false
     (redex-match?
      lang:rail-lang
      cfg
      (term ((empty-tree) +-> ((⊤ ,sigma-b) + (empty-tree))))))
    (check-equal? (~a seq-name) "rail-seq/promote-right-observable")
    (check-equal? (~a fused-name) "rail-fused/promote-right-observable")
    (check-true (produced-answer-spine-only? seq-next))
    (check-true (produced-answer-spine-only? fused-next))
    (check-true (redex-match? lang:rail-lang cfg seq-next))
    (check-true (redex-match? lang:rail-lang cfg fused-next)))

  (test-case "calls overlay expands relcalls once and still omits proceed"
    (define-values (step-name next)
      (named-step (apply-reduction-relation/tag-with-names red:calls-red cfg-call)))
    (check-equal? (~a step-name) "calls/expand")
    (check-false (redex-match? lang:calls-lang cfg '(proceed (empty-tree))))
    (check-true (redex-match? lang:calls-lang config next)))

  (test-case "search-base +calls branches expand inside their chosen search discipline"
    (define-values (seq-name seq-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-seq-calls-red
        cfg-call-branch)))
    (define-values (fused-name fused-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-base-fused-calls-red
        cfg-call-branch)))
    (check-equal? (~a seq-name) "search-base-seq-calls/expand")
    (check-equal? (~a fused-name) "search-base-fused-calls/expand")
    (check-true (redex-match? lang:search-base-seq-calls-lang config seq-next))
    (check-true (redex-match? lang:search-base-fused-calls-lang config fused-next)))

  (test-case "scheduled +calls reducers are deterministic and shape-closed"
    (for ([entry (in-list
                  (list (list (lambda (prog) (redex-match? lang:search-base-seq-calls-lang config prog))
                              red:search-dfs-seq-calls-red
                              cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-calls-lang config prog))
                              red:search-dfs-fused-calls-red
                              cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-calls-lang config prog))
                              red:search-flip-seq-calls-red
                              cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-calls-lang config prog))
                              red:search-flip-fused-calls-red
                              cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:rail-seq-calls-lang config prog))
                              red:rail-seq-calls-red
                              cfg-call-rail)
                        (list (lambda (prog) (redex-match? lang:rail-fused-calls-lang config prog))
                              red:rail-fused-calls-red
                              cfg-call-rail)))])
      (match-define (list matcher rel prog) entry)
      (check-true (progress? rel prog))
      (check-true (unique-decomposition? rel prog))
      (check-true (states-wf? prog))
      (check-true (shape-closed? matcher rel prog))
      (check-true (invariant-closed? produced-answer-spine-only? rel prog))))

  (test-case "scheduler/calls assembly commutes on representative seq and fused examples"
    (define alt-search-dfs-seq-calls-expand
      (reduction-relation
       lang:search-base-seq-calls-lang
       #:domain config
       [--> (Γ (in-hole QShell (in-hole KBranch (in-hole KLocal ((r t ... tag) σ)))))
            (Γ (in-hole QShell (in-hole KBranch (in-hole KLocal (g_new σ)))))
            (where g_new
                   ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
            "alt-search-dfs-seq-calls/expand"]))
    (define alt-search-dfs-seq-calls-red
      (union-reduction-relations
       (context-closure
        (extend-reduction-relation red:search-dfs-seq-red lang:search-base-seq-calls-lang)
        lang:search-base-seq-calls-lang
        (Γ hole))
       alt-search-dfs-seq-calls-expand))
    (define alt-rail-fused-calls-expand
      (reduction-relation
       lang:rail-fused-calls-lang
       #:domain config
       [--> (Γ (in-hole QShell (in-hole KLate (in-hole KLocal ((r t ... tag) σ)))))
            (Γ (in-hole QShell (in-hole KLate (in-hole KLocal (g_new σ)))))
            (where g_new
                   ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
            "alt-rail-fused-calls/expand"]))
    (define alt-rail-fused-calls-red
      (union-reduction-relations
       (context-closure
        (extend-reduction-relation red:rail-fused-red lang:rail-fused-calls-lang)
        lang:rail-fused-calls-lang
        (Γ hole))
       alt-rail-fused-calls-expand))
    (check-equal?
     (apply-reduction-relation red:search-dfs-seq-calls-red cfg-call-branch)
     (apply-reduction-relation alt-search-dfs-seq-calls-red cfg-call-branch))
    (check-equal?
     (apply-reduction-relation red:rail-fused-calls-red cfg-call-rail)
     (apply-reduction-relation alt-rail-fused-calls-red cfg-call-rail)))

  (test-case "progress, determinism, state wf, and shape closure hold across the internal lattice"
    (for ([entry (in-list
                  (list (list (lambda (prog) (redex-match? lang:core-lang search prog))
                              red:core-red
                              (term ((succeed (label "ok")) ,sigma-a)))
                        (list (lambda (prog) (redex-match? lang:delay-lang cfg prog))
                              red:delay-red cfg-delay-goal)
                        (list (lambda (prog) (redex-match? lang:disj-seq-lang cfg prog))
                              red:disj-seq-red cfg-mixed-answer)
                        (list (lambda (prog) (redex-match? lang:disj-fused-lang cfg prog))
                              red:disj-fused-red cfg-mixed-answer)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-lang cfg prog))
                              red:search-base-seq-red cfg-delay-goal)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-lang cfg prog))
                              red:search-base-fused-red cfg-delay-goal)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-lang cfg prog))
                              red:search-dfs-seq-red cfg-flip)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-lang cfg prog))
                              red:search-dfs-fused-red cfg-flip)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-lang cfg prog))
                              red:search-flip-seq-red cfg-flip)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-lang cfg prog))
                              red:search-flip-fused-red cfg-flip)
                        (list (lambda (prog) (redex-match? lang:rail-seq-lang cfg prog))
                              red:rail-seq-red cfg-rail)
                        (list (lambda (prog) (redex-match? lang:rail-fused-lang cfg prog))
                              red:rail-fused-red cfg-rail)
                        (list (lambda (prog) (redex-match? lang:calls-lang config prog))
                              red:calls-red cfg-call)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-calls-lang config prog))
                              red:search-dfs-seq-calls-red cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-calls-lang config prog))
                              red:search-dfs-fused-calls-red cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-seq-calls-lang config prog))
                              red:search-flip-seq-calls-red cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:search-base-fused-calls-lang config prog))
                              red:search-flip-fused-calls-red cfg-call-branch)
                        (list (lambda (prog) (redex-match? lang:rail-seq-calls-lang config prog))
                              red:rail-seq-calls-red cfg-call-rail)
                        (list (lambda (prog) (redex-match? lang:rail-fused-calls-lang config prog))
                              red:rail-fused-calls-red cfg-call-rail)))])
      (match-define (list matcher rel prog) entry)
      (check-true (progress? rel prog))
      (check-true (unique-decomposition? rel prog))
      (check-true (states-wf? prog))
      (check-true (shape-closed? matcher rel prog))
      (check-true (invariant-closed? produced-answer-spine-only? rel prog))))

  (test-case "WF judgments align with the new search-only and calls split"
    (check-true
     (judgment-holds
      (wf:wf-cfg/core? (⊤ ,sigma-a))))
    (check-true
     (judgment-holds
      (wf:wf-cfg/delay? ,cfg-delay-goal)))
    (check-true
     (judgment-holds
      (wf:wf-cfg/disj? ,cfg-disj)))
    (check-true
     (judgment-holds
      (wf:wf-cfg/search-base? ,cfg-flip)))
    (check-true
     (judgment-holds
      (wf:wf-cfg/rail?
       (,delayed-left-search +-> (⊤ ,sigma-b)))))
    (check-true
     (judgment-holds
      (wf:wf-config/calls? ,cfg-call)))
    (check-true
     (judgment-holds
      (wf:wf-config/search-base-calls? ,cfg-call-branch)))
    (check-true
     (judgment-holds
      (wf:wf-config/rail-calls?
       (,gamma-delay
        (,delayed-left-search +-> (⊤ ,sigma-b)))))))
  )

(module+ test
  (run-tests SEARCH-LATTICE))
