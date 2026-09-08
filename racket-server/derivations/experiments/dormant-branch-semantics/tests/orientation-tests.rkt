#lang racket

(require rackunit
         redex/reduction-semantics
         "../derivation/orientation.rkt"
         (prefix-in rail: "../source/reduction-relations/rail-relcall-red.rkt")
         (prefix-in flip: "../source/reduction-relations/search-flip-relcall-red.rkt")
         (prefix-in rail-lang: "../source/languages/rail-relcall-lang.rkt")
         (prefix-in flip-lang: "../source/languages/search-relcall-lang.rkt")
         (prefix-in rail-wf: "../source/wf/rail-relcall-wf.rkt")
         (prefix-in flip-wf: "../source/wf/search-relcall-wf.rkt")
         "../../../test-support/witnesses.rkt")

(define empty-owners '(Owners))
(define empty-state '(state () () () (label "initial")))
(define succeed '(succeed (label "yes")))
(define fail '(fail (label "no")))
(define work `(Work ,empty-owners ,succeed ,empty-state))
(define returned `(Returned ,empty-owners ,empty-state))
(define outer '(Owners (Owner (u:9) (label "outer"))))
(define inner '(Owners (Owner (u:7) (label "inner"))))
(define private '(Owners (Owner (u:2) (label "answer-private"))))
(define residual '(Owners (Owner (u:0) (label "residual-private"))))
(define private-returned `(Returned ,private ,empty-state))
(define residual-work `(Work ,residual ,succeed ,empty-state))

(define definitions
  '((r:id (x:q) (x:q =? (sym "A") (label "id-body")))
    (r:later (x:q)
             (∃ (x:unused)
                  (suspend (r:id x:q (label "resumed-call")) (label "pause"))
                  (label "unused-introduction")))
    (r:even (x:xs)
            ((x:xs =? empty (label "even-empty")) ∨
             (∃ (x:h x:t)
                  ((x:xs =? (x:h : x:t) (label "even-pair")) ∧
                   (r:odd x:t (label "to-odd")) (label "even-body"))
                  (label "even-fresh")) (label "even-choice")))
    (r:odd (x:xs)
           (∃ (x:h x:t)
                ((x:xs =? (x:h : x:t) (label "odd-pair")) ∧
                 (r:even x:t (label "to-even")) (label "odd-body"))
                (label "odd-fresh")))))

;; One well-formed input per named rule, including rules that ordinary finite
;; examples rarely enter. Owner-bearing nested cases test exact attachment,
;; not just the constructor names with every owner field empty.
(define work-rule-fixtures
  (list
   (list "expand-conjunction" `(Work ,empty-owners (,succeed ∧ ,succeed (label "and")) ,empty-state))
   (list "succeed" work)
   (list "fail" `(Work ,empty-owners ,fail ,empty-state))
   (list "conj-return" `(Conj ,outer ,private-returned ,succeed))
   (list "conj-fail" `(Conj ,outer (Dead ,private) ,succeed))
   (list "unify-success" `(Work ,empty-owners ((nat 0) =? (nat 0) (label "eq")) ,empty-state))
   (list "unify-violates-disequality"
         '(Work (Owners (Owner (u:0) (label "variable")))
                (u:0 =? (nat 1) (label "violates"))
                (state () ((u:0 (nat 1))) () (label "initial"))))
   (list "unify-fail" `(Work ,empty-owners ((nat 0) =? (nat 1) (label "eq")) ,empty-state))
   (list "disequality-success" `(Work ,empty-owners ((nat 0) != (nat 1) (label "neq")) ,empty-state))
   (list "disequality-fail" `(Work ,empty-owners ((nat 0) != (nat 0) (label "neq")) ,empty-state))
   (list "allocate-fresh" `(Work ,outer (∃ (x:unused) ,succeed (label "fresh")) ,empty-state))
   (list "expand-disjunction" `(Work ,empty-owners (,succeed ∨ ,fail (label "or")) ,empty-state))
   (list "skip-left-failure" `(DisjL ,outer (Dead ,private) ,residual-work))
   (list "reassociate-left-result"
         `(DisjL ,outer (DisjL ,inner ,private-returned ,residual-work) ,work))
   (list "resume-left-choice-success"
         `(Conj ,outer (DisjL ,inner ,private-returned ,residual-work) ,succeed))
   (list "suspend-goal" `(Work ,outer (suspend ,succeed (label "delay")) ,empty-state))
   (list "bubble-delay-through-conj"
         `(Conj ,outer (PendingDelay ,inner ,residual-work) ,succeed))
   (list "expand-relcall" `(Work ,empty-owners (r:id (sym "A") (label "call")) ,empty-state))
   (list "skip-right-failure" `(DisjR ,outer ,residual-work (Dead ,private)))
   (list "reassociate-left-result/search-join"
         `(DisjL ,outer (DisjR ,inner ,residual-work ,private-returned) ,work))
   (list "reassociate-right-result/left-nested"
         `(DisjR ,outer ,work (DisjL ,inner ,private-returned ,residual-work)))
   (list "reassociate-right-result/right-nested"
         `(DisjR ,outer ,work (DisjR ,inner ,residual-work ,private-returned)))
   (list "resume-right-choice-success"
         `(Conj ,outer (DisjR ,inner ,residual-work ,private-returned) ,succeed))
   (list "rail-enter-right"
         `(DisjL ,outer (PendingDelay ,inner ,residual-work) ,work))
   (list "rail-return-left"
         `(DisjR ,outer ,work (PendingDelay ,inner ,residual-work)))))

(define frontier-rule-fixtures
  (list
   (list "finish-success" `(More ,private-returned))
   (list "finish-failure" `(More (Dead ,private)))
   (list "commit-choice-answer" `(More (DisjL ,outer ,private-returned ,residual-work)))
   (list "force-delay" `(More (PendingDelay ,outer ,residual-work)))
   (list "commit-right-choice-answer" `(More (DisjR ,outer ,residual-work ,private-returned)))))

(define (logical-names term [names '()])
  (match term
    [(? symbol?)
     (if (and (regexp-match? #rx"^u:" (symbol->string term)) (not (member term names)))
         (cons term names) names)]
    [(cons first rest) (logical-names rest (logical-names first names))]
    [_ names]))

(define (frontier-observation frontier)
  (match frontier
    [`(Done ,_) frontier]
    [`(Last ,_ ,_) frontier]
    [`(Emit ,owners ,answer ,rest) `(Emit ,owners ,answer ,(frontier-observation rest))]
    [`(Forced ,owners ,rest) `(Forced ,owners ,(frontier-observation rest))]
    [`(More (PendingDelay ,owners ,_)) `(paused ,owners)]
    [`(More ,_) 'running]))

(define (paused? frontier)
  (match frontier
    [`(Forced ,_ ,rest) (paused? rest)]
    [`(Emit ,_ ,_ ,rest) (paused? rest)]
    [`(More (PendingDelay ,_ ,_)) #t]
    [_ #f]))

(define rail-active
  (term-match rail-lang:rail-relcall-lang
    [(Γ (in-hole WorkFocus (Work owners g σ))) (term (owners g σ))]))

(define flip-active
  (term-match flip-lang:search-relcall-lang
    [(Γ (in-hole WorkFocus (Work owners g σ))) (term (owners g σ))]))

(define (check-configuration configuration)
  (define target (rail->flip/config configuration))
  (check-true (redex-match? rail-lang:rail-relcall-lang config configuration))
  (check-true (redex-match? flip-lang:search-relcall-lang config target))
  (check-true (judgment-holds (rail-wf:wf-config/rail-relcall? ,configuration)))
  (check-true (judgment-holds (flip-wf:wf-config/search-relcall? ,target)))
  (check-equal? (sort (logical-names configuration) symbol<?)
                (sort (logical-names target) symbol<?))
  (check-equal? (frontier-observation (second configuration))
                (frontier-observation (second target)))
  ;; Check the actual work input, including source tags and store/trail, rather
  ;; than treating identical generic names such as unify-success as work order.
  (check-equal? (rail-active configuration) (flip-active target))
  target)

(define (check-square configuration [expected-label #f])
  (define target (check-configuration configuration))
  (define source-steps
    (apply-reduction-relation/tag-with-names rail:rail-relcall-red configuration))
  (define target-steps
    (apply-reduction-relation/tag-with-names flip:search-flip-relcall-red target))
  ;; Equality of complete successor lists checks reflection as well as forward
  ;; preservation. It also checks terminal/stopping configurations, not merely
  ;; squares for transitions that happen to have been found on the source side.
  (check-equal? target-steps (rail->flip/named-successors source-steps))
  (check-true (<= (length source-steps) 1))
  (when expected-label
    (check-equal? (map first source-steps) (list expected-label)))
  (check-equal? (paused? (second configuration))
                (equal? (map first source-steps) '("force-delay")))
  (for ([successor (in-list source-steps)])
    (check-configuration (second successor)))
  source-steps)

;; Bounded trace checking never searches for a later matching result: every
;; iteration validates the immediately corresponding native successor.
(define (check-trace configuration fuel [labels '()] #:complete? [complete? #t])
  (define successors (check-square configuration))
  (match successors
    ['() (values configuration (reverse labels))]
    [(list (list label next))
     (cond
       [(zero? fuel)
        (when complete? (fail-check "finite trace exhausted its explicit step bound"))
        (values configuration (reverse labels))]
       [else (check-trace next (sub1 fuel) (cons label labels) #:complete? complete?)])]))

(define (initial goal [owners empty-owners] [state empty-state] [relations '()])
  `(,relations (More (Work ,owners ,goal ,state))))

(module+ test
  (test-case "constructor map preserves payloads and erases only scheduler orientation"
    (define original `(,definitions (Forced ,outer (More (DisjR ,inner ,residual-work ,private-returned)))))
    (check-equal? (rail->flip/config original)
                  `(,definitions (Forced ,outer (More (DisjL ,inner ,private-returned ,residual-work)))))
    (define oriented `(DisjR ,inner ,work ,returned))
    (check-equal? (erase-work (erase-work oriented)) (erase-work oriented))
    (check-equal? (erase-work `(PendingDelay ,outer (DisjR ,inner ,work ,returned)))
                  `(PendingDelay ,outer (DisjL ,inner ,returned ,work)))
    (check-exn exn:fail:contract? (lambda () (erase-work '(DisjR))))
    (check-exn exn:fail:contract? (lambda () (erase-frontier '(Yield (Owners) answer rest))))
    (check-exn exn:fail:contract? (lambda () (rail->flip/config '(program () frontier))))
    (check-exn exn:fail:contract? (lambda () (rail->flip-label "unknown-rule"))))

  (test-case "every native rule has an exact named square and a well-formed target"
    (define source-names (sort (map ~a (reduction-relation->rule-names rail:rail-relcall-red)) string<?))
    (define target-names (sort (map ~a (reduction-relation->rule-names flip:search-flip-relcall-red)) string<?))
    (define fixture-names (append (map first work-rule-fixtures) (map first frontier-rule-fixtures)))
    (check-equal? (sort (map car rail->flip-label-table) string<?) source-names)
    (check-equal? (sort (remove-duplicates (map cdr rail->flip-label-table)) string<?) target-names)
    (check-equal? (sort fixture-names string<?) source-names)
    (for ([fixture (in-list work-rule-fixtures)])
      (match-define (list name body) fixture)
      (with-check-info (['rule name])
        (check-square `(,definitions (More ,body)) name)))
    (for ([fixture (in-list frontier-rule-fixtures)])
      (match-define (list name frontier) fixture)
      (with-check-info (['rule name])
        (check-square `(,definitions ,frontier) name))))

  (test-case "completed and suspended Frontiers preserve exact owners and public boundaries"
    (for ([frontier (in-list
                    (list `(Done ,outer)
                          `(Last ,outer (Answer ,private ,empty-state))
                          `(Emit ,outer (Answer ,private ,empty-state)
                                 (Forced ,inner (Done ,residual)))
                          `(Emit ,outer (Answer ,private ,empty-state)
                                 (Forced ,inner (More (PendingDelay ,residual ,work))))))])
      (check-square `(,definitions ,frontier))))

  (test-case "all retained-scope witnesses compare intermediate work and allocation exactly"
    (for ([example (in-list validation-witnesses)])
      (with-check-info (['witness (witness-name example)])
        (define-values (final labels)
          (check-trace (initial (witness-goal example) (witness-owners example) (witness-state example)) 350))
        (check-equal? (rail->flip/config final) final)
        (check-false (eq? (frontier-observation (second final)) 'running)))))

  (test-case "freshness scans common, private, sparse, dormant, and completed ownership"
    (define fresh-goal '(∃ (x:unused x:q) (x:q =? (sym "A") (label "bind")) (label "fresh")))
    (define configuration
      `(() (Emit ,outer (Answer ,private ,empty-state)
                 (More (DisjR ,inner
                              (PendingDelay ,residual ,work)
                              (Work ,empty-owners ,fresh-goal ,empty-state))))))
    (define successors (check-square configuration "allocate-fresh"))
    (check-equal? (sort (logical-names (second (first successors))) symbol<?)
                  '(u:0 u:1 u:2 u:3 u:7 u:9))
    (define-values (final labels) (check-trace configuration 60))
    (check-not-false (member "commit-right-choice-answer" labels))
    (check-not-false (member "force-delay" labels))
    (check-equal? (rail->flip/config final) final))

  (test-case "full named calls, fresh across Delay, and mutual recursion preserve each edge"
    (for ([goal (in-list
                 (list '(∃ (x:q) (r:later x:q (label "call")) (label "query"))
                       '(r:even ((sym "a") : ((sym "b") : empty)) (label "even"))
                       '(r:odd ((sym "a") : empty) (label "odd"))
                       '(∃ (x:q)
                            ((suspend (r:id x:q (label "left")) (label "delay-left")) ∨
                             ((r:later x:q (label "right")) ∧
                              (x:q != (sym "B") (label "pending")) (label "bind"))
                             (label "choice")) (label "query"))))])
      (define-values (final labels) (check-trace (initial goal empty-owners empty-state definitions) 160))
      (check-not-false (member "expand-relcall" labels))
      (check-equal? (rail->flip/config final) final)))

  (test-case "guarded infinite alternation agrees for every checked work and forcing edge"
    (define guarded
      '((r:a (x:q)
              ((x:q =? (sym "A") (label "answer-A")) ∨
               (suspend (r:b x:q (label "call-B")) (label "delay-A")) (label "choice-A")))
        (r:b (x:q)
              ((x:q =? (sym "B") (label "answer-B")) ∨
               (suspend (r:a x:q (label "call-A")) (label "delay-B")) (label "choice-B")))))
    (define-values (prefix labels)
      (check-trace (initial '(∃ (x:q) (r:a x:q (label "start")) (label "query"))
                            empty-owners empty-state guarded)
                   90 #:complete? #f))
    (check-equal? (length labels) 90)
    (check-true (>= (count (lambda (name) (equal? name "force-delay")) labels) 5))
    (check-true (>= (count (lambda (name) (equal? name "commit-choice-answer")) labels) 5))
    (check-false (null? (apply-reduction-relation rail:rail-relcall-red prefix))))

  (test-case "the map distinguishes stable branch positions from scheduler observations"
    (define original `(() (More (DisjL ,outer (PendingDelay ,inner ,residual-work) ,work))))
    (match-define (list (list "rail-enter-right" next)) (check-square original "rail-enter-right"))
    (check-equal? next `(() (More (PendingDelay (Owners)
                                               (DisjR ,outer
                                                      (Work (Owners ,@(cdr inner) ,@(cdr residual)) ,succeed ,empty-state)
                                                      ,work)))))
    (check-not-equal? next (rail->flip/config next))))
