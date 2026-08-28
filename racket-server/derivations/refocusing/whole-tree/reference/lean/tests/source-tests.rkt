#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         redex/reduction-semantics
         (prefix-in mk-k: "../mk/kernel.rkt")
         (prefix-in mk-l: "../mk/labels.rkt")
         (prefix-in mk-lang: "../mk/language.rkt")
         (prefix-in mk-s: "../mk/source.rkt")
         (prefix-in mk-wf: "../mk/wf.rkt")
         (prefix-in toy-k: "../toy/kernel.rkt")
         (prefix-in toy-l: "../toy/labels.rkt")
         (prefix-in toy-lang: "../toy/language.rkt")
         (prefix-in toy-s: "../toy/source.rkt")
         (prefix-in toy-wf: "../toy/wf.rkt"))

(provide lean-source-tests)

(define-runtime-path source-schema-path "../source-schema.rkt")
(define-runtime-path toy-source-path "../toy/source.rkt")
(define-runtime-path mk-source-path "../mk/source.rkt")

(define control-rule-names
  '(finish-success/core
    finish-failure/core
    force-delay/delay
    commit-choice-answer/disj
    commit-right-choice-answer/search-join
    allocate-fresh/core
    expand-conjunction/core
    expand-disjunction/disj
    suspend-goal/delay
    conj-return/core
    conj-fail/core
    bubble-delay-through-conj/delay
    late-distribute-settled/disj
    late-distribute-right-settled/search-join
    skip-left-failure/disj
    rail-enter-right/search-join
    reassociate-left-result/disj
    skip-right-failure/search-join
    rail-return-left/search-join
    reassociate-right-result/search-join))

(define toy-rule-names
  (append control-rule-names
          '(work-succeed/core
            work-fail/core
            work-put/core)))

(define mk-rule-names
  (append control-rule-names
          '(kernel:succeed/core
            kernel:fail/core
            kernel:unify-success/core
            kernel:unify-violates-disequality/core
            kernel:unify-fail/core
            kernel:disequality-success/core
            kernel:disequality-fail/core)))

(define cell-labels
  '((finish-success core)
    (finish-failure core)
    (force-delay delay)
    (commit-choice-answer disj)
    (commit-right-choice-answer search-join)
    (allocate-fresh core)
    (expand-conjunction core)
    (expand-disjunction disj)
    (suspend-goal delay)
    (conj-return core)
    (conj-fail core)
    (bubble-delay-through-conj delay)
    (late-distribute-settled disj)
    (late-distribute-right-settled search-join)
    (skip-left-failure disj)
    (rail-enter-right search-join)
    (reassociate-left-result disj)
    (skip-right-failure search-join)
    (rail-return-left search-join)
    (reassociate-right-result search-join)))

(define (canonical-rule-names names)
  (sort names string<? #:key symbol->string))

(define (raw-successors relation frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names relation frontier))])
    (match-define (list name next) named)
    (list (string->symbol (~a name)) next)))

(define (labeled-successors relation name->label frontier)
  (for/list ([successor (in-list (raw-successors relation frontier))])
    (match-define (list name next) successor)
    (list (name->label (symbol->string name)) next)))

(define (toy-name->label name)
  (term (toy-l:redex-name->label/lean-toy ,name)))

(define (mk-name->label name)
  (term (mk-l:redex-name->label/lean-mk ,name)))

(define (uncommented-source path)
  (call-with-input-file
   path
   (lambda (input)
     (string-join
      (for/list ([line (in-lines input)]
                 #:unless (regexp-match? #rx"^[[:space:]]*;" line))
        line)
      "\n"))))

(define toy-state '(state unit))
(define toy-answer `(Returned ,toy-state))
(define toy-work `(Work (succeed (label "work")) ,toy-state))
(define toy-other-work `(Work (fail (label "other")) ,toy-state))
(define toy-goal '(put (sym "next") (label "goal")))

(define control-witnesses
  (list
   (list 'finish-success/core
         `(More ,toy-answer))
   (list 'finish-failure/core
         '(More Dead))
   (list 'force-delay/delay
         `(More (PendingDelay ,toy-work)))
   (list 'commit-choice-answer/disj
         `(More (DisjL ,toy-answer ,toy-work)))
   (list 'commit-right-choice-answer/search-join
         `(More (DisjR ,toy-work ,toy-answer)))
   (list 'allocate-fresh/core
         `(More
           (Work
            (fresh (x:q)
                   (put x:q (label "put"))
                   (label "fresh"))
            ,toy-state)))
   (list 'expand-conjunction/core
         `(More
           (Work
            (conj (succeed (label "left"))
                  (fail (label "right"))
                  (label "conj"))
            ,toy-state)))
   (list 'expand-disjunction/disj
         `(More
           (Work
            (disj (succeed (label "left"))
                  (fail (label "right"))
                  (label "disj"))
            ,toy-state)))
   (list 'suspend-goal/delay
         `(More
           (Work
            (suspend (succeed (label "body")) (label "delay"))
            ,toy-state)))
   (list 'conj-return/core
         `(More (Conj ,toy-answer ,toy-goal)))
   (list 'conj-fail/core
         `(More (Conj Dead ,toy-goal)))
   (list 'bubble-delay-through-conj/delay
         `(More (Conj (PendingDelay ,toy-work) ,toy-goal)))
   (list 'late-distribute-settled/disj
         `(More
           (Conj (DisjL ,toy-answer ,toy-work) ,toy-goal)))
   (list 'late-distribute-right-settled/search-join
         `(More
           (Conj (DisjR ,toy-work ,toy-answer) ,toy-goal)))
   (list 'skip-left-failure/disj
         `(More (DisjL Dead ,toy-work)))
   (list 'rail-enter-right/search-join
         `(More
           (DisjL (PendingDelay ,toy-work) ,toy-other-work)))
   (list 'reassociate-left-result/disj
         `(More
           (DisjL (DisjL ,toy-answer ,toy-work) ,toy-other-work)))
   (list 'skip-right-failure/search-join
         `(More (DisjR ,toy-work Dead)))
   (list 'rail-return-left/search-join
         `(More
           (DisjR ,toy-work (PendingDelay ,toy-other-work))))
   (list 'reassociate-right-result/search-join
         `(More
           (DisjR ,toy-work (DisjR ,toy-other-work ,toy-answer))))))

(define empty-mk-state '(state () () () (label "s")))

(define mk-kernel-cases
  (list
   (list '(succeed (label "succeed"))
         empty-mk-state
         '(kernel succeed core))
   (list '(fail (label "fail"))
         empty-mk-state
         '(kernel fail core))
   (list '(u:0 =? (sym "cat") (label "unify"))
         empty-mk-state
         '(kernel unify-success core))
   (list '(u:0 =? (sym "cat") (label "blocked"))
         '(state () ((u:0 (sym "cat"))) () (label "s"))
         '(kernel unify-violates-disequality core))
   (list '((sym "cat") =? (sym "dog") (label "unify-fail"))
         empty-mk-state
         '(kernel unify-fail core))
   (list '((sym "cat") != (sym "dog") (label "diseq"))
         empty-mk-state
         '(kernel disequality-success core))
   (list '((sym "cat") != (sym "cat") (label "diseq-fail"))
         empty-mk-state
         '(kernel disequality-fail core))))

(define compound-toy-goal
  '(fresh
    (x:q)
    (disj
     (suspend
      (put x:q (label "later"))
      (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "query")))

(define (finite-trace relation initial [fuel 80])
  (let trace ([current initial]
              [remaining fuel]
              [names '()]
              [states (list initial)])
    (define successors (raw-successors relation current))
    (match successors
      ['() (values (reverse names) (reverse states) current)]
      [_ #:when (zero? remaining)
       (error 'finite-trace "fuel exhausted at ~e" current)]
      [(list (list name next))
       (trace next
              (sub1 remaining)
              (cons name names)
              (cons next states))]
      [_ (error 'finite-trace
                "expected deterministic source step, got ~e"
                successors)])))

(define lean-source-tests
  (test-suite
   "independent lean whole-tree source"

   (test-case
    "source relations expose exactly 23 and 27 static rules"
    (check-equal?
     (canonical-rule-names
      (reduction-relation->rule-names toy-s:source-red/lean-toy))
     (canonical-rule-names toy-rule-names))
    (check-equal?
     (canonical-rule-names
      (reduction-relation->rule-names mk-s:source-red/lean-mk))
     (canonical-rule-names mk-rule-names)))

   (test-case
    "the primary source contains 20 direct clauses and no computed projection"
    (define source (uncommented-source source-schema-path))
    (define toy-source (uncommented-source toy-source-path))
    (define mk-source (uncommented-source mk-source-path))
    (check-equal? (length (regexp-match* #rx"\\[-->" source)) 20)
    (check-equal? (length (regexp-match* #rx"\\[-->" toy-source)) 3)
    (check-equal? (length (regexp-match* #rx"\\[-->" mk-source)) 7)
    (check-false (regexp-match? #rx"judgment-holds" source))
    (check-false (regexp-match? #rx"computed-name" source))
    (check-false (regexp-match? #rx"WorkFresh|AnswerFresh|FrontierFresh"
                                source)))

   (test-case
    "lean grammar erases fresh wrappers but retains frontier history"
    (check-false
     (toy-lang:work-in-language?/lean-toy
      `(WorkFresh (u:0) ,toy-work (label "fresh"))))
    (check-false
     (toy-lang:frontier-in-language?/lean-toy
      `(FrontierFresh (u:0) (More ,toy-work) (label "fresh"))))
    (check-false
     (toy-lang:frontier-in-language?/lean-toy
      `(Last
        (AnswerFresh (u:0) (Answer ,toy-state) (label "fresh")))))
    (check-true
     (toy-lang:frontier-in-language?/lean-toy
      `(Emit (Answer ,toy-state) (Forced Done)))))

   (test-case
    "both precise languages reject the other kernel"
    (check-false
     (toy-lang:frontier-in-language?/lean-toy
      `(More
        (Work
         (u:0 =? (sym "cat") (label "eq"))
         ,empty-mk-state))))
    (check-false
     (mk-lang:frontier-in-language?/lean-mk
      `(More (Work (put unit (label "put")) ,toy-state)))))

   (test-case
    "lean WF retains lexical closure and intentionally forgets ownership"
    (check-true
     (judgment-holds
      (toy-wf:wf-frontier/lean-toy
       (More
        (Work (put u:0 (label "runtime")) (state unit))))))
    (check-false
     (judgment-holds
      (toy-wf:wf-frontier/lean-toy
       (More
        (Work (put x:free (label "lexical")) (state unit))))))
    (check-true
     (judgment-holds
      (mk-wf:wf-frontier/lean-mk
       (More
        (Work
         (u:7 =? (sym "cat") (label "runtime"))
         (state () () () (label "s"))))))))

   (test-case
    "all 20 control clauses have direct deterministic witnesses"
    (for ([witness (in-list control-witnesses)])
      (match-define (list expected-name frontier) witness)
      (check-true
       (judgment-holds (toy-wf:wf-frontier/lean-toy ,frontier))
       (format "WF witness for ~a" expected-name))
      (check-equal?
       (map first (raw-successors toy-s:source-red/lean-toy frontier))
       (list expected-name)
       (format "source witness for ~a" expected-name))))

   (test-case
    "lean fresh allocation scans actual whole-frontier occurrences"
    (define with-used-name
      `(More
        (DisjL
         (Work
          (fresh (x:q)
                 (put x:q (label "put"))
                 (label "fresh"))
          ,toy-state)
         (Work (put u:0 (label "used")) ,toy-state))))
    (check-equal?
     (term (toy-s:whole-runtime-support/lean-toy ,with-used-name))
     '(u:0))
    (check-equal?
     (raw-successors toy-s:source-red/lean-toy with-used-name)
     `((allocate-fresh/core
        (More
         (DisjL
          (Work (put u:1 (label "put")) ,toy-state)
          (Work (put u:0 (label "used")) ,toy-state))))))
    (define without-used-name
      `(More
        (Work
         (fresh (x:q)
                (put x:q (label "put"))
                (label "fresh"))
         ,toy-state)))
    (check-equal?
     (raw-successors toy-s:source-red/lean-toy without-used-name)
     `((allocate-fresh/core
        (More (Work (put u:0 (label "put")) ,toy-state))))))

   (test-case
    "every label round-trips as semantic data"
    (for ([label (in-list cell-labels)])
      (define toy-name
        (term (toy-l:label->redex-name/lean-toy ,label)))
      (define mk-name
        (term (mk-l:label->redex-name/lean-mk ,label)))
      (check-equal?
       (term (toy-l:redex-name->label/lean-toy ,toy-name))
       label)
      (check-equal?
       (term (mk-l:redex-name->label/lean-mk ,mk-name))
       label)))

   (test-case
    "Kmk retains all seven distinct atomic outcomes"
    (define observed
      (for/list ([case (in-list mk-kernel-cases)])
        (match-define (list atomic state expected-label) case)
        (define frontier `(More (Work ,atomic ,state)))
        (check-true
         (judgment-holds (mk-wf:wf-frontier/lean-mk ,frontier))
         (format "~e" frontier))
        (define successors
          (labeled-successors
           mk-s:source-red/lean-mk
           mk-name->label
           frontier))
        (check-equal? (length successors) 1)
        (check-equal? (first (first successors)) expected-label)
        (define next (second (first successors)))
        (check-true
         (judgment-holds (mk-wf:wf-frontier/lean-mk ,next)))
        expected-label))
    (check-equal? (length (remove-duplicates observed)) 7))

   (test-case
    "compound lean trace preserves WF, Forced, Emit, and exact labels"
    (define initial
      (term (toy-s:initial-tree/lean-toy ,compound-toy-goal)))
    (define-values (names states final)
      (finite-trace toy-s:source-red/lean-toy initial))
    (check-true (> (length names) 8))
    (for ([state (in-list states)])
      (check-true
       (judgment-holds (toy-wf:wf-frontier/lean-toy ,state))
       (format "~e" state)))
    (for ([required
           (in-list
            '(allocate-fresh/core
              expand-disjunction/disj
              suspend-goal/delay
              rail-enter-right/search-join
              force-delay/delay
              commit-right-choice-answer/search-join))])
      (check-not-false (member required names) (symbol->string required)))
    (check-true (toy-lang:frontier-in-language?/lean-toy final))
    (check-true (redex-match? toy-lang:lean-toy-lang V final))
    (check-not-false (member 'force-delay/delay names))
    (check-true (regexp-match? #rx"Forced" (~s final)))
    (check-true (regexp-match? #rx"Emit" (~s final)))
    (check-false
     (regexp-match? #rx"WorkFresh|AnswerFresh|FrontierFresh" (~s final))))

   (test-case
    "bounded generated source steps are deterministic and preserve lean WF"
    (redex-check
     toy-lang:lean-toy-lang
     F
     (let ([frontier (term F)])
       (or
        (not (judgment-holds (toy-wf:wf-frontier/lean-toy F)))
        (let ([successors
               (apply-reduction-relation
                toy-s:source-red/lean-toy
                frontier)])
          (and (<= (length successors) 1)
               (for/and ([next (in-list successors)])
                 (judgment-holds
                  (toy-wf:wf-frontier/lean-toy ,next)))))))
     #:attempts 300)
    (redex-check
     mk-lang:lean-mk-lang
     F
     (let ([frontier (term F)])
       (or
        (not (judgment-holds (mk-wf:wf-frontier/lean-mk F)))
        (let ([successors
               (apply-reduction-relation
                mk-s:source-red/lean-mk
                frontier)])
          (and (<= (length successors) 1)
               (for/and ([next (in-list successors)])
                 (judgment-holds
                  (mk-wf:wf-frontier/lean-mk ,next)))))))
     #:attempts 300))))

(module+ test
  (run-tests lean-source-tests))
