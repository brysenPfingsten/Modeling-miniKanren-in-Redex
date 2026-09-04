#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in corpus: "../../../corpus/source-correspondence-cases.rkt")
         (prefix-in lean-mk-d: "../../../reference/lean/mk/decomposition.rkt")
         (prefix-in lean-mk-s: "../../../reference/lean/mk/source.rkt")
         (prefix-in lean-toy-d: "../../../reference/lean/toy/decomposition.rkt")
         (prefix-in lean-toy-s: "../../../reference/lean/toy/source.rkt")
         (prefix-in marked-mk-d: "../../../reference/marked/mk/decomposition.rkt")
         (prefix-in marked-mk-s: "../../../reference/marked/mk/source.rkt")
         (prefix-in marked-mk-wf: "../../../reference/marked/mk/wf.rkt")
         (prefix-in marked-toy-d: "../../../reference/marked/toy/decomposition.rkt")
         (prefix-in marked-toy-s: "../../../reference/marked/toy/source.rkt")
         (prefix-in marked-toy-wf: "../../../reference/marked/toy/wf.rkt")
         (prefix-in q: "../shared-host.rkt")
         (prefix-in q-mk: "../mk.rkt")
         (prefix-in q-toy: "../toy.rkt"))

(provide reference-Q-decomposition-tests)

(struct decomposition-instance
        (marked-initial marked-decompose
                        marked-plug
                        marked-step
                        source-Q
                        decomposition-Q
                        lean-initial
                        lean-decompose
                        lean-plug
                        lean-step
                        lean-D?)
  #:transparent)

(define (only who values)
  (check-equal? (length values) 1 who)
  (match values
    [(list value) value]
    [_ (error 'only "~a: expected one value, received ~e" who values)]))

(define (marked-toy-decompose frontier)
  (judgment-holds (marked-toy-d:decompose/toy ,frontier D) D))

(define (lean-toy-decompose frontier)
  (judgment-holds (lean-toy-d:decompose/lean-toy ,frontier D) D))

(define (marked-mk-decompose frontier)
  (judgment-holds (marked-mk-d:decompose/mk ,frontier D) D))

(define (lean-mk-decompose frontier)
  (judgment-holds (lean-mk-d:decompose/lean-mk ,frontier D) D))

(define (marked-toy-step decomposition)
  (judgment-holds (marked-toy-d:decomposed-step/spec/toy ,decomposition ell D_next) (ell D_next)))

(define (lean-toy-step decomposition)
  (judgment-holds (lean-toy-d:decomposed-step/spec/lean-toy ,decomposition ell D_next) (ell D_next)))

(define (marked-mk-step decomposition)
  (judgment-holds (marked-mk-d:decomposed-step/spec/mk ,decomposition ell D_next) (ell D_next)))

(define (lean-mk-step decomposition)
  (judgment-holds (lean-mk-d:decomposed-step/spec/lean-mk ,decomposition ell D_next) (ell D_next)))

(define (Q-D/toy decomposition)
  (judgment-holds (q-toy:Q-D/toy ,decomposition D_lean) D_lean))

(define (Q-D/mk decomposition)
  (judgment-holds (q-mk:Q-D/mk ,decomposition D_lean) D_lean))

(define toy-instance
  (decomposition-instance (lambda (goal) (term (marked-toy-s:initial-tree/toy ,goal)))
                          marked-toy-decompose
                          (lambda (decomposition) (term (marked-toy-d:plug-D/toy ,decomposition)))
                          marked-toy-step
                          (lambda (frontier) (term (q-toy:Q-R/toy ,frontier)))
                          Q-D/toy
                          (lambda (goal) (term (lean-toy-s:initial-tree/lean-toy ,goal)))
                          lean-toy-decompose
                          (lambda (decomposition) (term (lean-toy-d:plug-D/lean-toy ,decomposition)))
                          lean-toy-step
                          (lambda (decomposition)
                            (redex-match? lean-toy-d:lean-toy-decomposition-lang D decomposition))))

(define mk-instance
  (decomposition-instance (lambda (goal) (term (marked-mk-s:initial-tree/mk ,goal)))
                          marked-mk-decompose
                          (lambda (decomposition) (term (marked-mk-d:plug-D/mk ,decomposition)))
                          marked-mk-step
                          (lambda (frontier) (term (q-mk:Q-R/mk ,frontier)))
                          Q-D/mk
                          (lambda (goal) (term (lean-mk-s:initial-tree/lean-mk ,goal)))
                          lean-mk-decompose
                          (lambda (decomposition) (term (lean-mk-d:plug-D/lean-mk ,decomposition)))
                          lean-mk-step
                          (lambda (decomposition)
                            (redex-match? lean-mk-d:lean-mk-decomposition-lang D decomposition))))

(define (case-instance candidate)
  (match (corpus:source-correspondence-case-kernel candidate)
    ['toy toy-instance]
    ['mk mk-instance]))

(define (check-decomposition-trace candidate)
  (match-define (decomposition-instance marked-initial
                                        marked-decompose
                                        marked-plug
                                        marked-step
                                        source-Q
                                        decomposition-Q
                                        lean-initial
                                        lean-decompose
                                        lean-plug
                                        lean-step
                                        lean-D?)
    (case-instance candidate))
  (define goal (corpus:source-correspondence-case-goal candidate))
  (define initial-marked
    (only "initial marked decomposition" (marked-decompose (marked-initial goal))))
  (define initial-lean (only "initial lean decomposition" (lean-decompose (lean-initial goal))))

  (let trace ([marked-D initial-marked]
              [lean-D initial-lean]
              [remaining 256]
              [reverse-marked-labels '()]
              [reverse-lean-labels '()]
              [reverse-stutter-labels '()])
    (unless (positive? remaining)
      (error 'check-decomposition-trace
             "step cap reached in ~a"
             (corpus:source-correspondence-case-name candidate)))
    (define projected-D (only "Q_D multiplicity" (decomposition-Q marked-D)))
    (check-true (lean-D? projected-D))
    (check-true (q:alpha-equivalent? projected-D lean-D))
    (check-true (q:alpha-equivalent? (lean-plug projected-D) (source-Q (marked-plug marked-D))))

    (match (marked-step marked-D)
      ['()
       (check-equal? (lean-step lean-D) '())
       (define marked-labels (reverse reverse-marked-labels))
       (define lean-labels (reverse reverse-lean-labels))
       (define stutter-labels (reverse reverse-stutter-labels))
       (check-equal? marked-labels (corpus:source-correspondence-case-source-labels candidate))
       (check-equal? lean-labels (q:visible-source-labels marked-labels))
       stutter-labels]
      [marked-next*
       (match-define (list label marked-D-next) (only "marked D successor multiplicity" marked-next*))
       (define projected-D-next (only "successor Q_D multiplicity" (decomposition-Q marked-D-next)))
       (cond
         [(q:fresh-stutter-label? label)
          (check-true (q:alpha-equivalent? projected-D projected-D-next))
          (check-true (< (q:fresh-marker-rank (marked-plug marked-D-next))
                         (q:fresh-marker-rank (marked-plug marked-D))))
          (trace marked-D-next
                 lean-D
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 reverse-lean-labels
                 (cons label reverse-stutter-labels))]
         [else
          (match-define (list lean-label lean-D-next)
            (only "lean D successor multiplicity" (lean-step lean-D)))
          (check-equal? lean-label label)
          (check-true (q:alpha-equivalent? projected-D-next lean-D-next))
          (trace marked-D-next
                 lean-D-next
                 (sub1 remaining)
                 (cons label reverse-marked-labels)
                 (cons lean-label reverse-lean-labels)
                 reverse-stutter-labels)])])))

(define (generated-step-square? instance marked-D)
  (match-define (decomposition-instance _marked-initial
                                        _marked-decompose
                                        marked-plug
                                        marked-step
                                        _source-Q
                                        decomposition-Q
                                        _lean-initial
                                        _lean-decompose
                                        _lean-plug
                                        lean-step
                                        lean-D?)
    instance)
  (match (decomposition-Q marked-D)
    [(list projected-D)
     (and (lean-D? projected-D)
          (match (marked-step marked-D)
            ['() (null? (lean-step projected-D))]
            [(list (list label marked-D-next))
             (match (decomposition-Q marked-D-next)
               [(list projected-D-next)
                (if (q:fresh-stutter-label? label)
                    (and (q:alpha-equivalent? projected-D projected-D-next)
                         (< (q:fresh-marker-rank (marked-plug marked-D-next))
                            (q:fresh-marker-rank (marked-plug marked-D))))
                    (match (lean-step projected-D)
                      [(list (list lean-label lean-D-next))
                       (and (equal? lean-label label)
                            (q:alpha-equivalent? projected-D-next lean-D-next))]
                      [_ #f]))]
               [_ #f])]
            [_ #f]))]
    [_ #f]))

(define boundary-fresh-frontier
  '(More (WorkFresh (u:0) (Work (succeed (label "body")) (state unit)) (label "fresh"))))

(define erase-dead-fresh-frontier
  '(More (DisjL (WorkFresh (u:0) Dead (label "local-fresh"))
                (Work (succeed (label "alternate")) (state unit)))))

(define reference-Q-decomposition-tests
  (test-suite "marked-to-lean reference decomposition Q"

    (test-case "Q_D re-decomposes rather than homomorphically retaining a marked focus"
      (define marked-D
        (only "boundary fresh decomposition" (marked-toy-decompose boundary-fresh-frontier)))
      (check-equal?
       marked-D
       (term (DecWork (WorkFresh (u:0) (Work (succeed (label "body")) (state unit)) (label "fresh"))
                      (More hole))))
      (define projected-D (only "boundary fresh Q_D" (Q-D/toy marked-D)))
      (check-equal? projected-D
                    (term (DecWork (Work (succeed (label "body")) (state unit)) (More hole))))
      (check-equal? (term (lean-toy-d:plug-D/lean-toy ,projected-D))
                    (term (q-toy:Q-R/toy ,boundary-fresh-frontier))))

    (test-case "all fixed traces satisfy weak alpha-aware Q_D simulation"
      (define observed-stutters
        (append-map check-decomposition-trace corpus:source-correspondence-cases))

      ;; The fixed corpus exercises four ownership-administration labels.
      ;; Supply the branch-local failed scope for the fifth.
      (define before-D
        (only "failed fresh decomposition" (marked-toy-decompose erase-dead-fresh-frontier)))
      (match-define (list erase-label after-D)
        (only "failed fresh D successor" (marked-toy-step before-D)))
      (check-equal? erase-label '(erase-dead-fresh core))
      (define before-Q (only "failed fresh Q_D before" (Q-D/toy before-D)))
      (define after-Q (only "failed fresh Q_D after" (Q-D/toy after-D)))
      (check-equal? before-Q after-Q)
      (check-equal? (sort (remove-duplicates (cons erase-label observed-stutters)) string<? #:key ~s)
                    (sort q:fresh-stutter-labels string<? #:key ~s)))

    (test-case "Q_D is total, single-valued, and reconstructs the Q_R square"
      (check-true (redex-check
                   marked-toy-d:pk-toy-decomposition-lang
                   D
                   (let* ([marked-D (term D)]
                          [projected* (Q-D/toy marked-D)])
                     (match projected*
                       [(list projected-D)
                        (and (redex-match? lean-toy-d:lean-toy-decomposition-lang D projected-D)
                             (equal? (term (lean-toy-d:plug-D/lean-toy ,projected-D))
                                     (term (q-toy:Q-R/toy (marked-toy-d:plug-D/toy ,marked-D)))))]
                       [_ #f]))
                   #:attempts 1000
                   #:print? #f))
      (check-true (redex-check
                   marked-mk-d:pk-mk-decomposition-lang
                   D
                   (let* ([marked-D (term D)]
                          [projected* (Q-D/mk marked-D)])
                     (match projected*
                       [(list projected-D)
                        (and (redex-match? lean-mk-d:lean-mk-decomposition-lang D projected-D)
                             (equal? (term (lean-mk-d:plug-D/lean-mk ,projected-D))
                                     (term (q-mk:Q-R/mk (marked-mk-d:plug-D/mk ,marked-D)))))]
                       [_ #f]))
                   #:attempts 1000
                   #:print? #f)))

    (test-case "generated marked D steps satisfy the weak Q_D square"
      (check-true (redex-check marked-toy-d:pk-toy-decomposition-lang
                               D
                               (let* ([marked-D (term D)]
                                      [frontier (term (marked-toy-d:plug-D/toy ,marked-D))])
                                 (or (not (judgment-holds (marked-toy-wf:wf-frontier/toy ,frontier)))
                                     (not (member marked-D (marked-toy-decompose frontier)))
                                     (generated-step-square? toy-instance marked-D)))
                               #:attempts 1000
                               #:print? #f))
      (check-true (redex-check marked-mk-d:pk-mk-decomposition-lang
                               D
                               (let* ([marked-D (term D)]
                                      [frontier (term (marked-mk-d:plug-D/mk ,marked-D))])
                                 (or (not (judgment-holds (marked-mk-wf:wf-frontier/mk ,frontier)))
                                     (not (member marked-D (marked-mk-decompose frontier)))
                                     (generated-step-square? mk-instance marked-D)))
                               #:attempts 1000
                               #:print? #f)))))

(module+ test
  (run-tests reference-Q-decomposition-tests))
