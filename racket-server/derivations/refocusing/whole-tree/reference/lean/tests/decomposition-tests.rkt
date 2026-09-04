#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         redex/reduction-semantics
         (prefix-in mk-d: "../mk/decomposition.rkt")
         (prefix-in mk-l: "../mk/labels.rkt")
         (prefix-in mk-s: "../mk/source.rkt")
         (prefix-in mk-wf: "../mk/wf.rkt")
         (prefix-in toy-d: "../toy/decomposition.rkt")
         (prefix-in toy-l: "../toy/labels.rkt")
         (prefix-in toy-s: "../toy/source.rkt")
         (prefix-in toy-wf: "../toy/wf.rkt"))

(provide lean-decomposition-tests)

(define-runtime-path decomposition-language-path "../decomposition-language-schema.rkt")
(define-runtime-path decomposition-schema-path "../decomposition-schema.rkt")

(define (uncommented-source path)
  (call-with-input-file path
                        (lambda (input)
                          (string-join (for/list ([line (in-lines input)]
                                                  #:unless (regexp-match? #rx"^[[:space:]]*;" line))
                                         line)
                                       "\n"))))

(define (source-successors relation name->label frontier)
  (for/list ([named (in-list (apply-reduction-relation/tag-with-names relation frontier))])
    (match-define (list name next) named)
    (list (name->label (~a name)) next)))

(define (toy-name->label name)
  (term (toy-l:redex-name->label/lean-toy ,name)))

(define (mk-name->label name)
  (term (mk-l:redex-name->label/lean-mk ,name)))

(define-syntax-rule (check-generated-decomposition language-id
                                                   wf-frontier-id
                                                   decompose-id
                                                   plug-D-id
                                                   contract-id
                                                   plug-C-id
                                                   contract-label-id
                                                   source-red-id
                                                   name->label-id
                                                   decomposed-step/spec-id
                                                   decomposed-step/direct-id)
  (check-equal?
   #t
   (redex-check
    language-id
    F
    (let ([frontier (term F)])
      (or (not (judgment-holds (wf-frontier-id F)))
          (match (judgment-holds (decompose-id F D) D)
            [(list decomposition)
             (define source* (source-successors source-red-id name->label-id frontier))
             (define contract*
               (for/list ([contractum (in-list (judgment-holds (contract-id ,decomposition C) C))])
                 (list (term (contract-label-id ,contractum)) (term (plug-C-id ,contractum)))))
             (define spec*
               (judgment-holds (decomposed-step/spec-id ,decomposition ell D_next) (ell D_next)))
             (define direct*
               (judgment-holds (decomposed-step/direct-id ,decomposition ell D_next) (ell D_next)))
             (and (equal? (term (plug-D-id ,decomposition)) frontier)
                  (equal? contract* source*)
                  (equal? direct* spec*)
                  (for/and ([successor (in-list source*)])
                    (match-define (list _label next) successor)
                    (judgment-holds (wf-frontier-id ,next))))]
            [_ #f])))
    #:attempts 1000
    #:print? #f)))

(define toy-state '(state unit))
(define toy-answer `(Returned ,toy-state))
(define toy-work `(Work (succeed (label "work")) ,toy-state))
(define toy-other-work `(Work (fail (label "other")) ,toy-state))
(define toy-goal '(put (sym "next") (label "goal")))

(define control-witnesses
  (list
   (list '(finish-success core) `(More ,toy-answer))
   (list '(finish-failure core) '(More Dead))
   (list '(force-delay delay) `(More (PendingDelay ,toy-work)))
   (list '(commit-choice-answer disj) `(More (DisjL ,toy-answer ,toy-work)))
   (list '(commit-right-choice-answer search-join) `(More (DisjR ,toy-work ,toy-answer)))
   (list '(allocate-fresh core)
         `(More (Work (fresh (x:q) (put x:q (label "put")) (label "fresh")) ,toy-state)))
   (list '(expand-conjunction core)
         `(More (Work (conj (succeed (label "left")) (fail (label "right")) (label "conj"))
                      ,toy-state)))
   (list '(expand-disjunction disj)
         `(More (Work (disj (succeed (label "left")) (fail (label "right")) (label "disj"))
                      ,toy-state)))
   (list '(suspend-goal delay)
         `(More (Work (suspend (succeed (label "body")) (label "delay")) ,toy-state)))
   (list '(conj-return core) `(More (Conj ,toy-answer ,toy-goal)))
   (list '(conj-fail core) `(More (Conj Dead ,toy-goal)))
   (list '(bubble-delay-through-conj delay) `(More (Conj (PendingDelay ,toy-work) ,toy-goal)))
   (list '(late-distribute-settled disj) `(More (Conj (DisjL ,toy-answer ,toy-work) ,toy-goal)))
   (list '(late-distribute-right-settled search-join)
         `(More (Conj (DisjR ,toy-work ,toy-answer) ,toy-goal)))
   (list '(skip-left-failure disj) `(More (DisjL Dead ,toy-work)))
   (list '(rail-enter-right search-join) `(More (DisjL (PendingDelay ,toy-work) ,toy-other-work)))
   (list '(reassociate-left-result disj)
         `(More (DisjL (DisjL ,toy-answer ,toy-work) ,toy-other-work)))
   (list '(skip-right-failure search-join) `(More (DisjR ,toy-work Dead)))
   (list '(rail-return-left search-join) `(More (DisjR ,toy-work (PendingDelay ,toy-other-work))))
   (list '(reassociate-right-result search-join)
         `(More (DisjR ,toy-work (DisjR ,toy-other-work ,toy-answer))))))

(define complex-toy-goal
  '(fresh (x:q)
          (conj (disj (suspend (put x:q (label "later")) (label "delay"))
                      (put (sym "now") (label "now"))
                      (label "split"))
                (succeed (label "continue"))
                (label "and"))
          (label "query")))

(define (toy-source-trace initial [remaining 128] [states (list initial)])
  (define successors (source-successors toy-s:source-red/lean-toy toy-name->label initial))
  (match successors
    ['() (reverse states)]
    [(list (list _label next))
     (unless (positive? remaining)
       (error 'toy-source-trace "step cap reached"))
     (toy-source-trace next (sub1 remaining) (cons next states))]
    [_ (error 'toy-source-trace "expected deterministic source, received ~e" successors)]))

(define empty-mk-state '(state () () () (label "s")))

(define mk-atomic-cases
  (list
   (list '(succeed (label "succeed")) empty-mk-state '(kernel succeed core))
   (list '(fail (label "fail")) empty-mk-state '(kernel fail core))
   (list '(u:0 =? (sym "cat") (label "unify")) empty-mk-state '(kernel unify-success core))
   (list '(u:0 =? (sym "cat") (label "blocked"))
         '(state () ((u:0 (sym "cat"))) () (label "s"))
         '(kernel unify-violates-disequality core))
   (list '((sym "cat") =? (sym "dog") (label "unify-fail")) empty-mk-state '(kernel unify-fail core))
   (list '((sym "cat") != (sym "dog") (label "diseq"))
         empty-mk-state
         '(kernel disequality-success core))
   (list '((sym "cat") != (sym "cat") (label "diseq-fail"))
         empty-mk-state
         '(kernel disequality-fail core))))

(define lean-decomposition-tests
  (test-suite "independent lean whole-tree decomposition"

    (test-case "lean D has no fresh-marker focus or local-fresh context class"
      (define language-source (uncommented-source decomposition-language-path))
      (define relation-source (uncommented-source decomposition-schema-path))
      (for ([forbidden (in-list '("WorkFresh" "AnswerFresh" "FrontierFresh" "LFR"))])
        (check-false (regexp-match? (regexp (regexp-quote forbidden)) language-source) forbidden)
        (check-false (regexp-match? (regexp (regexp-quote forbidden)) relation-source) forbidden)))

    (test-case "boundary, local-work, and terminal decompositions are distinct"
      (check-equal?
       (judgment-holds (toy-d:decompose/lean-toy (Forced (More (Returned (state unit)))) D) D)
       (term ((DecWork (Returned (state unit)) (Forced (More hole))))))
      (check-equal? (judgment-holds (toy-d:decompose/lean-toy
                                     (More (Conj (Work (succeed (label "left")) (state unit))
                                                 (put (sym "right") (label "right"))))
                                     D)
                                    D)
                    (term ((DecWork (Work (succeed (label "left")) (state unit))
                                    (More (Conj hole (put (sym "right") (label "right"))))))))
      (check-equal?
       (judgment-holds (toy-d:decompose/lean-toy (Emit (Answer (state unit)) (Forced Done)) D) D)
       (term ((DecFrontier Done (Emit (Answer (state unit)) (Forced hole)))))))

    (test-case "fresh allocation contracts directly to marker-free work"
      (define frontier
        `(More (Work (fresh (x:q) (put x:q (label "body")) (label "fresh")) ,toy-state)))
      (match-define (list decomposition) (judgment-holds (toy-d:decompose/lean-toy ,frontier D) D))
      (define contracta (judgment-holds (toy-d:contract/lean-toy ,decomposition C) C))
      (check-equal? contracta
                    (term ((ContractWork (allocate-fresh core)
                                         (Work (put u:0 (label "body")) (state unit))
                                         (More hole)))))
      (check-false (regexp-match? #rx"Fresh" (~s (first contracta)))))

    (test-case "all 20 control rules cross both source-to-D squares"
      (check-equal? (length control-witnesses) 20)
      (for ([candidate (in-list control-witnesses)])
        (match-define (list expected-label frontier) candidate)
        (match-define (list decomposition) (judgment-holds (toy-d:decompose/lean-toy ,frontier D) D))
        (define source* (source-successors toy-s:source-red/lean-toy toy-name->label frontier))
        (check-equal? (map first source*) (list expected-label))
        (define contract*
          (for/list ([contractum (in-list (judgment-holds (toy-d:contract/lean-toy ,decomposition C)
                                                          C))])
            (list (term (toy-d:contract-label/lean-toy ,contractum))
                  (term (toy-d:plug-C/lean-toy ,contractum)))))
        (check-equal? contract* source*)
        (check-equal?
         (judgment-holds (toy-d:decomposed-step/direct/lean-toy ,decomposition ell D_next)
                         (ell D_next))
         (judgment-holds (toy-d:decomposed-step/spec/lean-toy ,decomposition ell D_next)
                         (ell D_next)))))

    (test-case "source, contraction, and direct D agree along a compound trace"
      (define initial (term (toy-s:initial-tree/lean-toy ,complex-toy-goal)))
      (define states (toy-source-trace initial))
      (check-true (> (length states) 10))
      (for ([frontier (in-list states)])
        (check-true (judgment-holds (toy-wf:wf-frontier/lean-toy ,frontier)))
        (match-define (list decomposition) (judgment-holds (toy-d:decompose/lean-toy ,frontier D) D))
        (check-equal? (term (toy-d:plug-D/lean-toy ,decomposition)) frontier)
        (define source* (source-successors toy-s:source-red/lean-toy toy-name->label frontier))
        (define contract*
          (for/list ([contractum (in-list (judgment-holds (toy-d:contract/lean-toy ,decomposition C)
                                                          C))])
            (list (term (toy-d:contract-label/lean-toy ,contractum))
                  (term (toy-d:plug-C/lean-toy ,contractum)))))
        (define spec*
          (judgment-holds (toy-d:decomposed-step/spec/lean-toy ,decomposition ell D_next)
                          (ell D_next)))
        (define direct*
          (judgment-holds (toy-d:decomposed-step/direct/lean-toy ,decomposition ell D_next)
                          (ell D_next)))
        (check-equal? contract* source*)
        (check-equal? direct* spec*)))

    (test-case "all seven Kmk atomic outcomes cross the source-to-D square"
      (for ([candidate (in-list mk-atomic-cases)])
        (match-define (list atomic state expected-label) candidate)
        (define frontier `(More (Work ,atomic ,state)))
        (match-define (list decomposition) (judgment-holds (mk-d:decompose/lean-mk ,frontier D) D))
        (define source* (source-successors mk-s:source-red/lean-mk mk-name->label frontier))
        (check-equal? (map first source*) (list expected-label))
        (define contract*
          (for/list ([contractum (in-list (judgment-holds (mk-d:contract/lean-mk ,decomposition C)
                                                          C))])
            (list (term (mk-d:contract-label/lean-mk ,contractum))
                  (term (mk-d:plug-C/lean-mk ,contractum)))))
        (check-equal? contract* source*)
        (check-equal? (judgment-holds (mk-d:decomposed-step/direct/lean-mk ,decomposition ell D_next)
                                      (ell D_next))
                      (judgment-holds (mk-d:decomposed-step/spec/lean-mk ,decomposition ell D_next)
                                      (ell D_next)))))

    (test-case "precise D languages reject the other kernel"
      (check-true (redex-match? toy-d:lean-toy-decomposition-lang
                                D
                                (term (DecWork (Work (put unit (label "put")) (state unit))
                                               (More hole)))))
      (check-false (redex-match? mk-d:lean-mk-decomposition-lang
                                 D
                                 (term (DecWork (Work (put unit (label "put")) (state unit))
                                                (More hole)))))
      (check-true (redex-match? mk-d:lean-mk-decomposition-lang
                                D
                                (term (DecWork (Work ((sym "cat") =? (sym "cat") (label "eq"))
                                                     ,empty-mk-state)
                                               (More hole)))))
      (check-false (redex-match? toy-d:lean-toy-decomposition-lang
                                 D
                                 (term (DecWork (Work ((sym "cat") =? (sym "cat") (label "eq"))
                                                      ,empty-mk-state)
                                                (More hole))))))

    (test-case "generated source-to-D squares hold in both precise instances"
      (check-generated-decomposition toy-d:lean-toy-decomposition-lang
                                     toy-wf:wf-frontier/lean-toy
                                     toy-d:decompose/lean-toy
                                     toy-d:plug-D/lean-toy
                                     toy-d:contract/lean-toy
                                     toy-d:plug-C/lean-toy
                                     toy-d:contract-label/lean-toy
                                     toy-s:source-red/lean-toy
                                     toy-name->label
                                     toy-d:decomposed-step/spec/lean-toy
                                     toy-d:decomposed-step/direct/lean-toy)
      (check-generated-decomposition mk-d:lean-mk-decomposition-lang
                                     mk-wf:wf-frontier/lean-mk
                                     mk-d:decompose/lean-mk
                                     mk-d:plug-D/lean-mk
                                     mk-d:contract/lean-mk
                                     mk-d:plug-C/lean-mk
                                     mk-d:contract-label/lean-mk
                                     mk-s:source-red/lean-mk
                                     mk-name->label
                                     mk-d:decomposed-step/spec/lean-mk
                                     mk-d:decomposed-step/direct/lean-mk))

    (test-case "generated decomposition is total, unique, and reconstructing"
      (check-equal? #t
                    (redex-check toy-d:lean-toy-decomposition-lang
                                 F
                                 (match (judgment-holds (toy-d:decompose/lean-toy F D) D)
                                   [(list decomposition)
                                    (equal? (term (toy-d:plug-D/lean-toy ,decomposition)) (term F))]
                                   [_ #f])
                                 #:attempts 1000
                                 #:print? #f))
      (check-equal? #t
                    (redex-check mk-d:lean-mk-decomposition-lang
                                 F
                                 (match (judgment-holds (mk-d:decompose/lean-mk F D) D)
                                   [(list decomposition)
                                    (equal? (term (mk-d:plug-D/lean-mk ,decomposition)) (term F))]
                                   [_ #f])
                                 #:attempts 1000
                                 #:print? #f)))))

(module+ test
  (run-tests lean-decomposition-tests))
