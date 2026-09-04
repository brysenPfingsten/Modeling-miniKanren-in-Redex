#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in corpus: "../../../corpus/source-correspondence-cases.rkt")
         (prefix-in marked-mk-l: "../../../reference/marked/mk/labels.rkt")
         (prefix-in marked-mk-s: "../../../reference/marked/mk/source.rkt")
         (prefix-in marked-toy-l: "../../../reference/marked/toy/labels.rkt")
         (prefix-in marked-toy-s: "../../../reference/marked/toy/source.rkt")
         (prefix-in marked-toy-wf: "../../../reference/marked/toy/wf.rkt")
         (prefix-in lean-mk-l: "../../../reference/lean/mk/labels.rkt")
         (prefix-in lean-mk-s: "../../../reference/lean/mk/source.rkt")
         (prefix-in lean-toy-l: "../../../reference/lean/toy/labels.rkt")
         (prefix-in lean-toy-s: "../../../reference/lean/toy/source.rkt")
         (prefix-in q-mk: "../mk.rkt")
         (prefix-in q-toy: "../toy.rkt")
         (prefix-in q: "../shared-host.rkt"))

(provide reference-Q-source-tests)

(struct source-instance
  (marked-initial
   marked-successors
   Q-R
   Q-output-in-lean-language?
   lean-initial
   lean-successors)
  #:transparent)

(struct trace-result
  (lean-labels stutter-labels)
  #:transparent)

(define (named-successors relation decode-label state)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names relation state))])
    (match-define (list name next) named)
    (list (decode-label (~a name)) next)))

(define (marked-toy-successors frontier)
  (named-successors
   marked-toy-s:source-red/toy
   (lambda (name)
     (term (marked-toy-l:redex-name->label/toy ,name)))
   frontier))

(define (lean-toy-successors frontier)
  (named-successors
   lean-toy-s:source-red/lean-toy
   (lambda (name)
     (term (lean-toy-l:redex-name->label/lean-toy ,name)))
   frontier))

(define (marked-mk-successors frontier)
  (named-successors
   marked-mk-s:source-red/mk
   (lambda (name)
     (term (marked-mk-l:redex-name->label/mk ,name)))
   frontier))

(define (lean-mk-successors frontier)
  (named-successors
   lean-mk-s:source-red/lean-mk
   (lambda (name)
     (term (lean-mk-l:redex-name->label/lean-mk ,name)))
   frontier))

(define toy-instance
  (source-instance
   (lambda (goal)
     (term (marked-toy-s:initial-tree/toy ,goal)))
   marked-toy-successors
   (lambda (frontier)
     (term (q-toy:Q-R/toy ,frontier)))
   q-toy:Q-R-in-lean-language?/toy
   (lambda (goal)
     (term (lean-toy-s:initial-tree/lean-toy ,goal)))
   lean-toy-successors))

(define mk-instance
  (source-instance
   (lambda (goal)
     (term (marked-mk-s:initial-tree/mk ,goal)))
   marked-mk-successors
   (lambda (frontier)
     (term (q-mk:Q-R/mk ,frontier)))
   q-mk:Q-R-in-lean-language?/mk
   (lambda (goal)
     (term (lean-mk-s:initial-tree/lean-mk ,goal)))
   lean-mk-successors))

(define (kernel-instance kernel)
  (match kernel
    ['toy toy-instance]
    ['mk mk-instance]))

(define (case-instance candidate)
  (kernel-instance
   (corpus:source-correspondence-case-kernel candidate)))

(define (only-successor who successors)
  (check-equal? (length successors) 1 who)
  (match successors
    [(list successor) successor]
    [_ (error 'only-successor "~a: expected one successor, received ~e"
              who successors)]))

(define (force-label? label)
  (equal? label '(force-delay delay)))

(define (allocation-label? label)
  (equal? label '(allocate-fresh core)))

(define (check-fixed-trace candidate)
  (define instance (case-instance candidate))
  (match-define
    (source-instance marked-initial
                     marked-successors
                     Q-R
                     Q-output-in-lean-language?
                     lean-initial
                     lean-successors)
    instance)
  (define goal (corpus:source-correspondence-case-goal candidate))
  (define initial-marked (marked-initial goal))
  (define initial-lean (lean-initial goal))
  (define initial-Q (Q-R initial-marked))
  (check-true (Q-output-in-lean-language? initial-Q))
  (check-true (q:alpha-equivalent? initial-Q initial-lean))

  (let trace ([marked-state initial-marked]
              [lean-state initial-lean]
              [remaining 256]
              [reverse-marked-labels '()]
              [reverse-lean-labels '()]
              [reverse-stutter-labels '()])
    (unless (positive? remaining)
      (error 'check-fixed-trace
             "step cap reached in ~a"
             (corpus:source-correspondence-case-name candidate)))
    (define projected-marked (Q-R marked-state))
    (check-true (Q-output-in-lean-language? projected-marked))
    (check-true (q:alpha-equivalent? projected-marked lean-state))
    (define marked-next* (marked-successors marked-state))
    (match marked-next*
      ['()
       (define lean-next* (lean-successors lean-state))
       (check-equal? (length lean-next*) 0 "lean terminal multiplicity")
       (check-equal?
        marked-state
        (corpus:source-correspondence-case-final-frontier candidate))
       (check-true (Q-output-in-lean-language? (Q-R marked-state)))
       (check-true (q:alpha-equivalent? (Q-R marked-state) lean-state))
       (define marked-labels (reverse reverse-marked-labels))
       (define lean-labels (reverse reverse-lean-labels))
       (define stutter-labels (reverse reverse-stutter-labels))
       (check-equal?
        marked-labels
        (corpus:source-correspondence-case-source-labels candidate))
       (check-equal?
        (length marked-labels)
        (corpus:source-correspondence-case-source-edge-count candidate))
       (check-equal?
        (length marked-labels)
        (corpus:source-correspondence-case-rule-cost candidate))
       (check-equal? lean-labels (q:visible-source-labels marked-labels))
       (check-equal?
        (length lean-labels)
        (- (corpus:source-correspondence-case-rule-cost candidate)
           (length stutter-labels)))
       (check-equal?
        (count force-label? marked-labels)
        (corpus:source-correspondence-case-force-count candidate))
       (check-equal?
        (count force-label? lean-labels)
        (corpus:source-correspondence-case-force-count candidate))
       (check-equal?
        (count allocation-label? marked-labels)
        (length
         (corpus:source-correspondence-case-allocation-events candidate)))
       (check-equal?
        (count allocation-label? lean-labels)
        (length
         (corpus:source-correspondence-case-allocation-events candidate)))
       (trace-result lean-labels stutter-labels)]
      [_
       (match-define
         (list label marked-next)
         (only-successor "marked raw successor multiplicity" marked-next*))
       (define projected-next (Q-R marked-next))
       (check-true (Q-output-in-lean-language? projected-next))
       (cond
         [(q:fresh-stutter-label? label)
          (check-equal? projected-marked projected-next)
          (check-true
           (< (q:fresh-marker-rank marked-next)
              (q:fresh-marker-rank marked-state)))
          (trace marked-next
                 lean-state
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 reverse-lean-labels
                 (cons label reverse-stutter-labels))]
         [else
          (match-define
            (list lean-label lean-next)
            (only-successor
             "lean raw successor multiplicity"
             (lean-successors lean-state)))
          (check-equal? lean-label label)
          (check-true (q:alpha-equivalent? projected-next lean-next))
          (trace marked-next
                 lean-next
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 (cons lean-label reverse-lean-labels)
                 reverse-stutter-labels)])])))

(define alpha-allocation-witness-goal
  '(fresh
    (x:unused)
    (fresh
     (x:used)
     (put x:used (label "answer"))
     (label "used-fresh"))
    (label "unused-fresh")))

(define (alpha-allocation-witness-trace)
  (match-define
    (source-instance marked-initial
                     marked-successors
                     Q-R
                     Q-output-in-lean-language?
                     lean-initial
                     lean-successors)
    toy-instance)
  (let trace ([marked-state
               (marked-initial alpha-allocation-witness-goal)]
              [lean-state
               (lean-initial alpha-allocation-witness-goal)]
              [remaining 64]
              [reverse-marked-labels '()]
              [reverse-lean-labels '()]
              [reverse-visible-targets '()])
    (unless (positive? remaining)
      (error 'alpha-allocation-witness-trace "step cap reached"))
    (define projected-marked (Q-R marked-state))
    (check-true (Q-output-in-lean-language? projected-marked))
    (check-true (q:alpha-equivalent? projected-marked lean-state))
    (match (marked-successors marked-state)
      ['()
       (check-equal? (length (lean-successors lean-state)) 0)
       (values (reverse reverse-marked-labels)
               (reverse reverse-lean-labels)
               (reverse reverse-visible-targets)
               marked-state
               lean-state)]
      [marked-next*
       (match-define
         (list label marked-next)
         (only-successor
          "alpha witness marked raw successor multiplicity"
          marked-next*))
       (define projected-next (Q-R marked-next))
       (check-true (Q-output-in-lean-language? projected-next))
       (cond
         [(q:fresh-stutter-label? label)
          (check-equal? projected-marked projected-next)
          (check-true
           (< (q:fresh-marker-rank marked-next)
              (q:fresh-marker-rank marked-state)))
          (trace marked-next
                 lean-state
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 reverse-lean-labels
                 reverse-visible-targets)]
         [else
          (match-define
            (list lean-label lean-next)
            (only-successor
             "alpha witness lean raw successor multiplicity"
             (lean-successors lean-state)))
          (check-equal? lean-label label)
          (check-true (q:alpha-equivalent? projected-next lean-next))
          (trace marked-next
                 lean-next
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 (cons lean-label reverse-lean-labels)
                 (cons (list label projected-next lean-next)
                       reverse-visible-targets))])])))

(define erase-dead-fresh-before
  '(More
    (DisjL
     (WorkFresh (u:0) Dead (label "local-fresh"))
     (Work (succeed (label "alternate")) (state unit)))))

(define nested-marker-stutter-before
  '(More
    (Conj
     (WorkFresh
      (u:0)
      (WorkFresh
       (u:1)
       (DisjL
        (Returned (state unit))
        (Work (fail (label "alternate")) (state unit)))
       (label "inner"))
      (label "outer"))
     (succeed (label "continue")))))

(define direct-visible-cases
  (list
   (list
    'toy
    '(finish-failure core)
    '(More Dead))
   (list
    'toy
    '(conj-fail core)
    '(More (Conj Dead (succeed (label "right")))))
   (list
    'toy
    '(skip-left-failure disj)
    '(More
      (DisjL
       Dead
       (Work (succeed (label "right")) (state unit)))))
   (list
    'toy
    '(skip-right-failure search-join)
    '(More
      (DisjR
       (Work (succeed (label "left")) (state unit))
       Dead)))
   (list
    'toy
    '(reassociate-right-result search-join)
    '(More
      (DisjR
       (Work (succeed (label "left")) (state unit))
       (DisjL
        (Returned (state unit))
        (Work (fail (label "alternate")) (state unit))))))))

(define direct-kernel-cases
  (list
   (list
    'toy
    '(kernel work-fail core)
    '(More
      (Work (fail (label "failure")) (state unit))))
   (list
    'mk
    '(kernel fail core)
    '(More
      (Work
       (fail (label "failure"))
       (state () () () (label "s")))))
   (list
    'mk
    '(kernel unify-violates-disequality core)
    '(More
      (Work
       (u:0 =? (sym "cat") (label "forbidden"))
       (state ()
              ((u:0 (sym "cat")))
              ()
              (label "s")))))
   (list
    'mk
    '(kernel unify-fail core)
    '(More
      (Work
       (u:0 =? (sym "dog") (label "conflict"))
       (state ((u:0 (sym "cat")))
              ()
              ((u:0 =? (sym "cat") (label "bind-cat")))
              (label "s")))))
   (list
    'mk
    '(kernel disequality-fail core)
    '(More
      (Work
       ((sym "cat") != (sym "cat") (label "neq"))
       (state () () () (label "s")))))))

(define (check-visible-direct-case candidate)
  (match-define (list kernel expected-label marked-before) candidate)
  (match-define
    (source-instance _marked-initial
                     marked-successors
                     Q-R
                     Q-output-in-lean-language?
                     _lean-initial
                     lean-successors)
    (kernel-instance kernel))
  (define projected-before (Q-R marked-before))
  (check-true (Q-output-in-lean-language? projected-before))
  (match-define
    (list marked-label marked-after)
    (only-successor
     "direct marked raw successor multiplicity"
     (marked-successors marked-before)))
  (check-equal? marked-label expected-label)
  (match-define
    (list lean-label lean-after)
    (only-successor
     "direct lean raw successor multiplicity"
     (lean-successors projected-before)))
  (check-equal? lean-label expected-label)
  (define projected-after (Q-R marked-after))
  (check-true (Q-output-in-lean-language? projected-after))
  (check-true (q:alpha-equivalent? projected-after lean-after))
  expected-label)

(define expected-visible-control-labels
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

(define expected-toy-source-labels
  (append expected-visible-control-labels
          '((kernel work-succeed core)
            (kernel work-fail core)
            (kernel work-put core))))

(define expected-mk-source-labels
  (append expected-visible-control-labels
          '((kernel succeed core)
            (kernel fail core)
            (kernel unify-success core)
            (kernel unify-violates-disequality core)
            (kernel unify-fail core)
            (kernel disequality-success core)
            (kernel disequality-fail core))))

(define (control-label? label)
  (match label
    [`(kernel ,_name core) #f]
    [_ #t]))

(define (canonical-labels labels)
  (sort (remove-duplicates labels)
        string<?
        #:key ~s))

(define (canonical-label-multiset labels)
  (sort labels string<? #:key ~s))

(define (relation-labels relation decode-label)
  (for/list ([name (in-list (reduction-relation->rule-names relation))])
    (decode-label (~a name))))

(define reference-Q-source-tests
  (test-suite
   "marked-to-lean reference source Q"

   (test-case
    "five fixed traces satisfy the weak alpha-aware source simulation"
    (check-equal? (length corpus:source-correspondence-cases) 5)
    (define results
      (for/list ([candidate
                  (in-list corpus:source-correspondence-cases)])
        (check-fixed-trace candidate)))

    ;; The four retained Ktoy paths exercise four ownership-administration
    ;; labels.  This local failed scope supplies the fifth without broadening
    ;; the source corpus into a rule-by-rule operational oracle.
    (match-define
      (source-instance _marked-initial
                       marked-successors
                       Q-R
                       Q-output-in-lean-language?
                       _lean-initial
                       _lean-successors)
      toy-instance)
    (define projected-before (Q-R erase-dead-fresh-before))
    (check-true (Q-output-in-lean-language? projected-before))
    (match-define
      (list erase-label erase-after)
      (only-successor
       "erase-dead-fresh raw successor multiplicity"
       (marked-successors erase-dead-fresh-before)))
    (check-equal? erase-label '(erase-dead-fresh core))
    (check-equal? projected-before (Q-R erase-after))
    (check-true
     (< (q:fresh-marker-rank erase-after)
        (q:fresh-marker-rank erase-dead-fresh-before)))
    (check-equal?
     (canonical-labels
      (cons erase-label
            (append-map trace-result-stutter-labels results)))
     (canonical-labels q:fresh-stutter-labels)))

   (test-case
    "fixed and direct edges cover every visible source rule"
    (define results
      (for/list ([candidate
                  (in-list corpus:source-correspondence-cases)])
        (check-fixed-trace candidate)))
    (define direct-labels
      (for/list ([candidate (in-list direct-visible-cases)])
        (check-visible-direct-case candidate)))
    (define direct-kernel-labels
      (for/list ([candidate (in-list direct-kernel-cases)])
        (check-visible-direct-case candidate)))
    (define trace-control-labels
      (filter
       control-label?
       (append-map trace-result-lean-labels results)))
    (check-equal?
     (canonical-labels (append trace-control-labels direct-labels))
     (canonical-labels expected-visible-control-labels))
    (check-equal?
     direct-kernel-labels
     (map second direct-kernel-cases)))

   (test-case
    "fresh stutter rank decreases beneath another WorkFresh"
    (check-true
     (judgment-holds
      (marked-toy-wf:wf-frontier/toy
       ,nested-marker-stutter-before)))
    (match-define
      (list label after)
      (only-successor
       "nested marker stutter multiplicity"
       (marked-toy-successors nested-marker-stutter-before)))
    (check-equal?
     label
     '(expose-choice-through-work-fresh disj))
    (check-equal?
     (term (q-toy:Q-R/toy ,nested-marker-stutter-before))
     (term (q-toy:Q-R/toy ,after)))
    (check-true
     (< (q:fresh-marker-rank after)
        (q:fresh-marker-rank nested-marker-stutter-before))))

   (test-case
    "marked and lean sources expose the exact 23/27 visible inventories"
    (define marked-toy-labels
      (relation-labels
       marked-toy-s:source-red/toy
       (lambda (name)
         (term (marked-toy-l:redex-name->label/toy ,name)))))
    (define lean-toy-labels
      (relation-labels
       lean-toy-s:source-red/lean-toy
       (lambda (name)
         (term (lean-toy-l:redex-name->label/lean-toy ,name)))))
    (define marked-mk-labels
      (relation-labels
       marked-mk-s:source-red/mk
       (lambda (name)
         (term (marked-mk-l:redex-name->label/mk ,name)))))
    (define lean-mk-labels
      (relation-labels
       lean-mk-s:source-red/lean-mk
       (lambda (name)
         (term (lean-mk-l:redex-name->label/lean-mk ,name)))))
    (check-equal? (length expected-toy-source-labels) 23)
    (check-equal? (length expected-mk-source-labels) 27)
    (check-equal? (length marked-toy-labels) 28)
    (check-equal? (length lean-toy-labels) 23)
    (check-equal? (length marked-mk-labels) 32)
    (check-equal? (length lean-mk-labels) 27)
    (check-equal?
     (canonical-label-multiset marked-toy-labels)
     (canonical-label-multiset
      (append expected-toy-source-labels q:fresh-stutter-labels)))
    (check-equal?
     (canonical-label-multiset lean-toy-labels)
     (canonical-label-multiset expected-toy-source-labels))
    (check-equal?
     (canonical-label-multiset marked-mk-labels)
     (canonical-label-multiset
      (append expected-mk-source-labels q:fresh-stutter-labels)))
    (check-equal?
     (canonical-label-multiset lean-mk-labels)
     (canonical-label-multiset expected-mk-source-labels)))

   (test-case
    "alpha comparison is required after an erased unused allocation"
    (define-values
      (marked-labels lean-labels visible-targets marked-final lean-final)
      (alpha-allocation-witness-trace))
    (check-equal? lean-labels (q:visible-source-labels marked-labels))
    (check-equal?
     lean-labels
     '((allocate-fresh core)
       (allocate-fresh core)
       (kernel work-put core)
       (finish-success core)))
    (define allocation-targets
      (filter (lambda (target)
                (equal? (first target) '(allocate-fresh core)))
              visible-targets))
    (check-equal? (length allocation-targets) 2)
    (match-define
      (list _first-label first-projected first-lean)
      (first allocation-targets))
    (check-equal? first-projected first-lean)
    (match-define
      (list _second-label second-projected second-lean)
      (second allocation-targets))
    (check-equal?
     second-projected
     '(More
       (Work (put u:1 (label "answer")) (state unit))))
    (check-equal?
     second-lean
     '(More
       (Work (put u:0 (label "answer")) (state unit))))
    (check-not-equal? second-projected second-lean)
    (check-true (q:alpha-equivalent? second-projected second-lean))
    (define projected-final
      (term (q-toy:Q-R/toy ,marked-final)))
    (check-equal?
     projected-final
     '(Last (Answer (state u:1))))
    (check-equal?
     lean-final
     '(Last (Answer (state u:0))))
    (check-not-equal? projected-final lean-final)
    (check-true (q:alpha-equivalent? projected-final lean-final)))

   (test-case
    "Q_R deliberately forgets fresh ownership and is non-injective"
    (define owned
      '(FrontierFresh
        (u:0)
        (Last
         (AnswerFresh
          (u:1)
          (Answer (state unit))
          (label "inner-owner")))
        (label "outer-owner")))
    (define unowned
      '(Last (Answer (state unit))))
    (check-not-equal? owned unowned)
    (define projected-owned
      (term (q-toy:Q-R/toy ,owned)))
    (define projected-unowned
      (term (q-toy:Q-R/toy ,unowned)))
    (check-true (q-toy:Q-R-in-lean-language?/toy projected-owned))
    (check-true (q-toy:Q-R-in-lean-language?/toy projected-unowned))
    (check-equal? projected-owned projected-unowned))))

(module+ test
  (run-tests reference-Q-source-tests))
