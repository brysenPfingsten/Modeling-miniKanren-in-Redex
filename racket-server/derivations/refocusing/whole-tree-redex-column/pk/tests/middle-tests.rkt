#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in toy: "../toy/decomposition.rkt")
         (prefix-in toy: "../toy/labels.rkt")
         (prefix-in toy: "../toy/machine.rkt")
         (prefix-in toy: "../toy/machine-spec.rkt")
         (prefix-in toy: "../toy/refocused.rkt")
         (prefix-in toy: "../toy/refocused-spec.rkt")
         (prefix-in toy: "../toy/wf.rkt")
         (prefix-in mk: "../mk/decomposition.rkt")
         (prefix-in mk: "../mk/labels.rkt")
         (prefix-in mk: "../mk/machine.rkt")
         (prefix-in mk: "../mk/machine-spec.rkt")
         (prefix-in mk: "../mk/refocused.rkt")
         (prefix-in mk: "../mk/refocused-spec.rkt")
         (prefix-in mk: "../mk/wf.rkt"))

(provide middle-tests)

(define (canonical-order values)
  (sort values string<? #:key (lambda (value) (format "~s" value))))

(define (raw-exact-set? actual expected)
  (and (= (length actual)
          (length (remove-duplicates actual)))
       (equal? (canonical-order actual)
               (canonical-order expected))))

(define-syntax-rule
  (define-instance-generated-tests
    suite-id
    description
    language-id
    plug-d-id
    d->z-id
    z->d-id
    readback-z-id
    refocus-query-id
    refocus-direct-id
    refocus-spec-id
    z-step-id
    z-step-spec-id
    encode-id
    decode-id
    readback-m-id
    machine-query-id
    machine-step-id
    machine-step-spec-id
    machine-relation-id
    redex-name->label-id
    square-id)
  (define suite-id
    (test-suite
     description

     (test-case
      "D/Z and Z/M codecs are inverse on raw exact grammars"
      (redex-check
       language-id
       D
       (let ([decomposition (term D)])
         (define z (term (d->z-id ,decomposition)))
         (and (equal? (term (z->d-id ,z)) decomposition)
              (equal? (term (readback-z-id ,z))
                      (term (plug-d-id ,decomposition)))))
       #:attempts 1000)
      (redex-check
       language-id
       Z
       (let ([z (term Z)])
         (and (equal? (term (d->z-id (z->d-id ,z))) z)
              (equal? (term (decode-id (encode-id ,z))) z)
              (equal? (term (readback-m-id (encode-id ,z)))
                      (term (readback-z-id ,z)))))
       #:attempts 1000)
      (redex-check
       language-id
       M
       (let ([machine (term M)])
         (and (equal? (term (encode-id (decode-id ,machine)))
                      machine)
              (equal? (term (readback-z-id (decode-id ,machine)))
                      (term (readback-m-id ,machine)))))
       #:attempts 1000))

     (test-case
      "direct refocusing queries are total and single-valued"
      (redex-check
       language-id
       Q
       (= (length
           (judgment-holds
            (refocus-query-id ,(term Q) Z)
            Z))
          1)
       #:attempts 1000)
      (redex-check
       language-id
       MQ
       (= (length
           (judgment-holds
            (machine-query-id ,(term MQ) M)
            M))
          1)
       #:attempts 1000))

     (test-case
      "direct refocusing equals plug-and-redecompose on raw contracta"
      (redex-check
       language-id
       C
       (let* ([contractum (term C)]
              [direct*
               (judgment-holds
                (refocus-direct-id ,contractum Z)
                Z)]
              [spec*
               (judgment-holds
                (refocus-spec-id ,contractum Z)
                Z)])
         (and (= (length direct*) 1)
              (= (length spec*) 1)
              (equal? direct* spec*)))
       #:attempts 1000))

     (test-case
      "raw Z/M steps form the exact labeled commuting square"
      (redex-check
       language-id
       Z
       (let* ([z (term Z)]
              [machine (term (encode-id ,z))]
              [z-direct*
               (judgment-holds
                (z-step-id ,z ell Z_next)
                (ell Z_next))]
              [z-spec*
               (judgment-holds
                (z-step-spec-id ,z ell Z_next)
                (ell Z_next))]
              [machine-direct*
               (judgment-holds
                (machine-step-id ,machine ell M_next)
                (ell M_next))]
              [machine-spec*
               (judgment-holds
                (machine-step-spec-id ,machine ell M_next)
                (ell M_next))]
              [transported*
               (for/list ([edge (in-list z-direct*)])
                 (match-define (list label z-next) edge)
                 (list label (term (encode-id ,z-next))))]
              [square*
               (judgment-holds
                (square-id ,z ell Z_next M_0 M_1)
                (ell Z_next M_0 M_1))]
              [expected-square*
               (for/list ([edge (in-list z-direct*)])
                 (match-define (list label z-next) edge)
                 (list label
                       z-next
                       machine
                       (term (encode-id ,z-next))))]
              [expected-count
               (if (redex-match?
                    language-id
                    (ZFrontier T FF)
                    z)
                   0
                   1)]
              [named*
               (for/list
                   ([edge
                     (in-list
                      (apply-reduction-relation/tag-with-names
                       machine-relation-id
                       machine))])
                 (match-define (list name next) edge)
                 (list
                  (term (redex-name->label-id ,(~a name)))
                  next))])
         (and (= (length z-direct*) expected-count)
              (= (length z-direct*)
                 (length (remove-duplicates z-direct*)))
              (equal? z-direct* z-spec*)
              (equal? machine-direct* machine-spec*)
              (equal? machine-direct* transported*)
              (equal? machine-direct* named*)
              (equal? square* expected-square*)))
       #:attempts 1000)))))

(define-instance-generated-tests
  toy-generated-tests
  "P[Ktoy] middle arrows"
  toy:pk-toy-machine-lang
  toy:plug-D/toy
  toy:D->Z/toy
  toy:Z->D/toy
  toy:readback-Z/toy
  toy:refocus-query/direct/toy
  toy:refocus-direct/toy
  toy:refocus-spec/toy
  toy:refocused-step/direct/toy
  toy:refocused-step/spec/toy
  toy:encode-ZM/toy
  toy:decode-MZ/toy
  toy:readback-M/toy
  toy:machine-refocus-query/direct/toy
  toy:machine-step/direct/toy
  toy:machine-step/spec/toy
  toy:machine-red/direct/toy
  toy:redex-name->label/toy
  toy:ZM-step-square/toy)

(define-instance-generated-tests
  mk-generated-tests
  "P[Kmk] middle arrows"
  mk:pk-mk-machine-lang
  mk:plug-D/mk
  mk:D->Z/mk
  mk:Z->D/mk
  mk:readback-Z/mk
  mk:refocus-query/direct/mk
  mk:refocus-direct/mk
  mk:refocus-spec/mk
  mk:refocused-step/direct/mk
  mk:refocused-step/spec/mk
  mk:encode-ZM/mk
  mk:decode-MZ/mk
  mk:readback-M/mk
  mk:machine-refocus-query/direct/mk
  mk:machine-step/direct/mk
  mk:machine-step/spec/mk
  mk:machine-red/direct/mk
  mk:redex-name->label/mk
  mk:ZM-step-square/mk)

(define toy-root
  '(More
    (Work
     (fresh
      (x:q)
      (disj
       (put x:q (label "toy-left"))
       (fail (label "toy-right"))
       (label "toy-choice"))
      (label "toy-fresh"))
     (state unit))))

(define mk-root
  '(More
    (Work
     (fresh
      (x:q)
      (disj
       (x:q =? (sym "cat") (label "mk-left"))
       (x:q != (sym "cat") (label "mk-right"))
       (label "mk-choice"))
      (label "mk-fresh"))
     (state () () () (label "s")))))

(define-syntax-rule
  (check-boundary/local-refocus refocus-query-id kernel-state)
  (let ()
    (define pending
      (term
       (WorkFresh
        (u:scope)
        (Work (succeed (label "inside")) kernel-state)
        (label "fresh"))))
    (define outside
      (term (Work (fail (label "outside")) kernel-state)))
    (check-equal?
     (judgment-holds
      (refocus-query-id
       (QWork ,pending (More hole))
       Z)
      Z)
     (list (term (ZWork ,pending (More hole)))))
    (check-equal?
     (judgment-holds
      (refocus-query-id
       (QWork
        ,pending
        (More (DisjL hole ,outside)))
       Z)
      Z)
     (list
      (term
       (ZWork
        (Work (succeed (label "inside")) kernel-state)
        (More
         (DisjL
          (WorkFresh
           (u:scope)
           hole
           (label "fresh"))
          ,outside))))))))

(define-syntax-rule
  (check-instance-reachability
    language-id
    root
    initial-z-id
    initial-m-id
    encode-id
    z-step-id
    machine-step-id
    reachable-z-id
    reachable-m-id)
  (let ()
    (define (walk z machine [reverse-labels '()] [limit 256])
      (define z*
        (judgment-holds
         (z-step-id ,z ell Z_next)
         (ell Z_next)))
      (define machine*
        (judgment-holds
         (machine-step-id ,machine ell M_next)
         (ell M_next)))
      (define record
        (list (reverse reverse-labels) z machine))
      (match* (z* machine*)
        [('() '()) (list record)]
        [((list (list label z-next))
          (list (list machine-label machine-next)))
         (check-true (positive? limit))
         (check-equal? machine-label label)
         (check-equal? machine-next
                       (term (encode-id ,z-next)))
         (cons record
               (walk z-next
                     machine-next
                     (cons label reverse-labels)
                     (sub1 limit)))]
        [(_ _)
         (fail-check
          (format "unmatched middle traces: ~e / ~e"
                  z*
                  machine*))]))

    (define initial-z (term (initial-z-id ,root)))
    (define initial-machine (term (initial-m-id ,root)))
    (define trace (walk initial-z initial-machine))
    (define expected-z
      (for/list ([record (in-list trace)])
        (match-define (list labels z _) record)
        (list labels z)))
    (define expected-machine
      (for/list ([record (in-list trace)])
        (match-define (list labels _ machine) record)
        (list labels machine)))
    (define reachable-z
      (judgment-holds
       (reachable-z-id ,root ZLabels Z)
       (ZLabels Z)))
    (define reachable-machine
      (judgment-holds
       (reachable-m-id ,root MLabels M)
       (MLabels M)))
    (check-true (raw-exact-set? reachable-z expected-z))
    (check-true
     (raw-exact-set? reachable-machine expected-machine))))

(define middle-tests
  (test-suite
   "P[K] refocused and machine schemas"
   toy-generated-tests
   mk-generated-tests

   (test-case
    "precise instances reject mixed kernel states"
    (define toy-machine
      (term
       (MWork
        (Work (succeed (label "toy")) (state unit))
        (More hole))))
    (define mk-machine
      (term
       (MWork
        (Work
         (succeed (label "mk"))
         (state () () () (label "s")))
        (More hole))))
    (check-true
     (redex-match? toy:pk-toy-machine-lang F toy-root))
    (check-false
     (redex-match? toy:pk-toy-machine-lang F mk-root))
    (check-true
     (redex-match? mk:pk-mk-machine-lang F mk-root))
    (check-false
     (redex-match? mk:pk-mk-machine-lang F toy-root))
    (check-true
     (redex-match? toy:pk-toy-machine-lang M toy-machine))
    (check-false
     (redex-match? toy:pk-toy-machine-lang M mk-machine))
    (check-true
     (redex-match? mk:pk-mk-machine-lang M mk-machine))
    (check-false
     (redex-match? mk:pk-mk-machine-lang M toy-machine))
    (check-true (judgment-holds (toy:wf-frontier/toy ,toy-root)))
    (check-true (judgment-holds (mk:wf-frontier/mk ,mk-root))))

   (test-case
    "toy BF/LF queries distinguish boundary and local fresh ownership"
    (check-boundary/local-refocus
     toy:refocus-query/direct/toy
     (state unit)))

   (test-case
    "miniKanren BF/LF queries distinguish boundary and local fresh ownership"
    (check-boundary/local-refocus
     mk:refocus-query/direct/mk
     (state () () () (label "s"))))

   (test-case
    "toy trace reachability is the exact prefix image"
    (check-instance-reachability
     toy:pk-toy-machine-lang
     toy-root
     toy:initial-Z/toy
     toy:initial-M/toy
     toy:encode-ZM/toy
     toy:refocused-step/direct/toy
     toy:machine-step/direct/toy
     toy:reachable-refocused/via/toy
     toy:reachable-machine/via/toy))

   (test-case
    "miniKanren trace reachability is the exact prefix image"
    (check-instance-reachability
     mk:pk-mk-machine-lang
     mk-root
     mk:initial-Z/mk
     mk:initial-M/mk
     mk:encode-ZM/mk
     mk:refocused-step/direct/mk
     mk:machine-step/direct/mk
     mk:reachable-refocused/via/mk
     mk:reachable-machine/via/mk))))

(module+ test
  (run-tests middle-tests))
