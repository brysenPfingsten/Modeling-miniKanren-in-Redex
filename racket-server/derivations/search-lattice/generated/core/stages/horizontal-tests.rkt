#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-s: "../source/s.rkt")
         (prefix-in source-e: "../source/e.rkt")
         (prefix-in source-n: "../source/n.rkt")
         (prefix-in stage-s: "./s.rkt")
         (prefix-in stage-s: (submod "./s.rkt" diagnostics))
         (prefix-in stage-e: "./e.rkt")
         (prefix-in stage-e: (submod "./e.rkt" diagnostics))
         (prefix-in stage-n: "./n.rkt")
         (prefix-in stage-n: (submod "./n.rkt" diagnostics))
         (prefix-in oracle-s: "../../../oracles/core/s/source.rkt")
         (prefix-in oracle-e: "../../../oracles/core/e/source.rkt")
         (prefix-in oracle-n: "../../../oracles/core/n/source.rkt")
         (prefix-in ref-d: "../../../core/s/decomposition.rkt")
         (prefix-in ref-z: "../../../core/s/refocused.rkt")
         (prefix-in ref-m: "../../../core/s/machine.rkt")
         (prefix-in ref-b: "../../../core/s/compressed.rkt")
         (prefix-in ref-big: "../../../core/s/fixed-point.rkt")
         "./corpus.rkt")

(provide GENERATED-CORE-STAGES-HORIZONTAL)

(struct stage-api
  (name
   corpus
   source-relation
   source-raw
   decompose
   plug-d
   contract
   contracta
   d-step
   refocus-phase
   d->z
   z->d
   readback-z
   refocus-spec
   refocus-direct
   z-step-spec
   z-step-direct
   machineize
   encode-zm
   decode-mz
   d->m
   m->d
   readback-m
   m-step-spec
   m-step-direct
   zm-square
   compress
   encode-mb
   decode-bm
   readback-b
   span-labels
   b-step-spec
   b-step-direct
   replay
   mb-square
   readback-big
   big-run
   big-settled
   big-dead
   big-final
   big-direct
   big-spec
   flatten
   promote
   close
   unfold
   closure
   root-square
   decompose-count
   contract-count
   d-step-count
   z-step-spec-count
   z-step-direct-count
   m-step-spec-count
   m-step-direct-count
   b-step-spec-count
   b-step-direct-count
   replay-count
   big-direct-count
   big-spec-count
   source-member?
   source-wf?
   d-member?
   z-member?
   m-member?
   b-member?
   big-member?)
  #:transparent)

(define (raw-single-output-results derivations)
  (for/list ([derivation (in-list derivations)])
    (last (derivation-term derivation))))

(define-syntax-rule
  (define-stage-api
    api-id row-name corpus-id source-relation-id source-raw-id
    source-language-id wf-id
    d-language-id z-language-id m-language-id b-language-id big-language-id
    decompose-id plug-d-id plug-c-id contract-label-id contract-id d-step-id
    refocus-phase-id d->z-id z->d-id readback-z-id
    refocus-spec-id refocus-direct-id z-step-spec-id z-step-direct-id
    machineize-id encode-zm-id decode-mz-id d->m-id m->d-id readback-m-id
    m-step-spec-id m-step-direct-id zm-square-id
    compress-id encode-mb-id decode-bm-id readback-b-id span-labels-id
    b-step-spec-id b-step-direct-id replay-id mb-square-id
    readback-big-id
    big-run-id big-settled-id big-dead-id big-final-id
    big-direct-id big-spec-id flatten-id promote-id close-id
    unfold-id closure-id root-square-id)
  (define api-id
    (stage-api
     row-name
     corpus-id
     source-relation-id
     source-raw-id
     (lambda (source)
       (judgment-holds (decompose-id ,source D) D))
     (lambda (decomposition)
       (term (plug-d-id ,decomposition)))
     (lambda (decomposition)
       (for/list ([contractum
                   (in-list
                    (judgment-holds
                     (contract-id ,decomposition C)
                     C))])
         (list (term (contract-label-id ,contractum))
               (term (plug-c-id ,contractum)))))
     (lambda (decomposition)
       (raw-single-output-results
        (build-derivations (contract-id ,decomposition C))))
     (lambda (decomposition)
       (judgment-holds
        (d-step-id ,decomposition RuleName D_next)
        (RuleName D_next)))
     (lambda (decomposition)
       (term (refocus-phase-id ,decomposition)))
     (lambda (decomposition) (term (d->z-id ,decomposition)))
     (lambda (refocused) (term (z->d-id ,refocused)))
     (lambda (refocused) (term (readback-z-id ,refocused)))
     (lambda (contractum)
       (raw-single-output-results
        (build-derivations (refocus-spec-id ,contractum Z))))
     (lambda (contractum)
       (raw-single-output-results
        (build-derivations (refocus-direct-id ,contractum Z))))
     (lambda (refocused)
       (judgment-holds
        (z-step-spec-id ,refocused RuleName Z_next)
        (RuleName Z_next)))
     (lambda (refocused)
       (judgment-holds
        (z-step-direct-id ,refocused RuleName Z_next)
        (RuleName Z_next)))
     (lambda (refocused) (term (machineize-id ,refocused)))
     (lambda (refocused) (term (encode-zm-id ,refocused)))
     (lambda (machine) (term (decode-mz-id ,machine)))
     (lambda (decomposition) (term (d->m-id ,decomposition)))
     (lambda (machine) (term (m->d-id ,machine)))
     (lambda (machine) (term (readback-m-id ,machine)))
     (lambda (machine)
       (judgment-holds
        (m-step-spec-id ,machine RuleName M_next)
        (RuleName M_next)))
     (lambda (machine)
       (judgment-holds
        (m-step-direct-id ,machine RuleName M_next)
        (RuleName M_next)))
     (lambda (refocused)
       (judgment-holds
        (zm-square-id ,refocused RuleName Z_next M_0 M_1)
        (RuleName Z_next M_0 M_1)))
     (lambda (machine) (term (compress-id ,machine)))
     (lambda (machine) (term (encode-mb-id ,machine)))
     (lambda (compressed) (term (decode-bm-id ,compressed)))
     (lambda (compressed) (term (readback-b-id ,compressed)))
     (lambda (span) (term (span-labels-id ,span)))
     (lambda (compressed)
       (judgment-holds
        (b-step-spec-id ,compressed TransitionSpan B_next)
        (TransitionSpan B_next)))
     (lambda (compressed)
       (judgment-holds
        (b-step-direct-id ,compressed TransitionSpan B_next)
        (TransitionSpan B_next)))
     (lambda (machine)
       (judgment-holds
        (replay-id ,machine TransitionSpan M_next)
        (TransitionSpan M_next)))
     (lambda (compressed)
       (judgment-holds
        (mb-square-id
         ,compressed
         TransitionSpan
         B_next
         M_0
         M_1)
        (TransitionSpan B_next M_0 M_1)))
     (lambda (big) (term (readback-big-id ,big)))
     (lambda (work focus)
       (raw-single-output-results
        (build-derivations (big-run-id ,work ,focus Big))))
     (lambda (settled focus)
       (raw-single-output-results
        (build-derivations (big-settled-id ,settled ,focus Big))))
     (lambda (failure-summary focus)
       (raw-single-output-results
        (build-derivations
         (big-dead-id ,failure-summary ,focus Big))))
     (lambda (terminal)
       (raw-single-output-results
        (build-derivations (big-final-id ,terminal Big))))
     (lambda (source)
       (judgment-holds (big-direct-id ,source Big) Big))
     (lambda (source)
       (judgment-holds
        (big-spec-id ,source BTrace Big)
        (BTrace Big)))
     (lambda (trace) (term (flatten-id ,trace)))
     (lambda (compressed)
       (raw-single-output-results
        (build-derivations (promote-id ,compressed Big))))
     (lambda (compressed)
       (judgment-holds
        (close-id ,compressed BTrace T)
        (BTrace T)))
     (lambda (compressed)
       (judgment-holds
        (unfold-id ,compressed TransitionSpan B_next Big)
        (TransitionSpan B_next Big)))
     (lambda (compressed)
       (judgment-holds
        (closure-id ,compressed BTrace Big)
        (BTrace Big)))
     (lambda (source)
       (judgment-holds
        (root-square-id ,source BTrace Big)
        (BTrace Big)))
     (lambda (source)
       (length (build-derivations (decompose-id ,source D))))
     (lambda (decomposition)
       (length (build-derivations (contract-id ,decomposition C))))
     (lambda (decomposition)
       (length
        (build-derivations
         (d-step-id ,decomposition RuleName D_next))))
     (lambda (refocused)
       (length
        (build-derivations
         (z-step-spec-id ,refocused RuleName Z_next))))
     (lambda (refocused)
       (length
        (build-derivations
         (z-step-direct-id ,refocused RuleName Z_next))))
     (lambda (machine)
       (length
        (build-derivations
         (m-step-spec-id ,machine RuleName M_next))))
     (lambda (machine)
       (length
        (build-derivations
         (m-step-direct-id ,machine RuleName M_next))))
     (lambda (compressed)
       (length
        (build-derivations
         (b-step-spec-id ,compressed TransitionSpan B_next))))
     (lambda (compressed)
       (length
        (build-derivations
         (b-step-direct-id ,compressed TransitionSpan B_next))))
     (lambda (machine)
       (length
        (build-derivations
         (replay-id ,machine TransitionSpan M_next))))
     (lambda (source)
       (length (build-derivations (big-direct-id ,source Big))))
     (lambda (source)
       (length
        (build-derivations
         (big-spec-id ,source BTrace Big))))
     (lambda (source)
       (redex-match? source-language-id F source))
     (lambda (source)
       (not (null? (judgment-holds (wf-id ,source)))))
     (lambda (decomposition)
       (redex-match? d-language-id D decomposition))
     (lambda (refocused)
       (redex-match? z-language-id Z refocused))
     (lambda (machine)
       (redex-match? m-language-id M machine))
     (lambda (compressed)
       (redex-match? b-language-id B compressed))
     (lambda (big)
       (redex-match? big-language-id Big big)))))

(define-stage-api
  STAGES/S 'S CORE-CORPUS/S
  source-s:generated-core-s-red source-s:raw-successors/generated/s
  source-s:generated-core-s-lang source-s:wf-core/generated/s?
  stage-s:generated-core-stage-s-decomposition-lang
  stage-s:generated-core-stage-s-refocused-lang
  stage-s:generated-core-stage-s-machine-lang
  stage-s:generated-core-stage-s-compressed-lang
  stage-s:generated-core-stage-s-big-lang
  stage-s:generated-stage-decompose/s
  stage-s:generated-stage-plug-D/s
  stage-s:generated-stage-plug-C/s
  stage-s:generated-stage-contract-label/s
  stage-s:generated-stage-contract/s
  stage-s:generated-stage-decomposed-step/s
  stage-s:generated-stage-refocus-phase/s
  stage-s:generated-stage-D->Z/s
  stage-s:generated-stage-Z->D/s
  stage-s:generated-stage-readback-Z/s
  stage-s:generated-stage-refocus/spec/s
  stage-s:generated-stage-refocus/direct/s
  stage-s:generated-stage-refocused-step/spec/s
  stage-s:generated-stage-refocused-step/direct/s
  stage-s:generated-stage-machineize/s
  stage-s:generated-stage-encode-ZM/s
  stage-s:generated-stage-decode-MZ/s
  stage-s:generated-stage-D->M/s
  stage-s:generated-stage-M->D/s
  stage-s:generated-stage-readback-M/s
  stage-s:generated-stage-machine-step/spec/s
  stage-s:generated-stage-machine-step/direct/s
  stage-s:generated-stage-ZM-step-square/s
  stage-s:generated-stage-compress/s
  stage-s:generated-stage-encode-MB/s
  stage-s:generated-stage-decode-BM/s
  stage-s:generated-stage-readback-B/s
  stage-s:generated-stage-transition-span-labels/s
  stage-s:generated-stage-compressed-step/spec/s
  stage-s:generated-stage-compressed-step/direct/s
  stage-s:generated-stage-replay-transition-span/M/s
  stage-s:generated-stage-MB-step-square/s
  stage-s:generated-stage-readback-Big/s
  stage-s:generated-stage-big-run/direct/s
  stage-s:generated-stage-big-settled/direct/s
  stage-s:generated-stage-big-dead/direct/s
  stage-s:generated-stage-big-final/direct/s
  stage-s:generated-stage-big-evaluate/direct/s
  stage-s:generated-stage-big-evaluate/spec/s
  stage-s:generated-stage-flatten-BTrace/s
  stage-s:generated-stage-promote-B/direct/s
  stage-s:generated-stage-close-B/spec/s
  stage-s:generated-stage-B-Big-unfold-square/s
  stage-s:generated-stage-B-Big-closure-square/s
  stage-s:generated-stage-B-Big-root-square/s)

(define-stage-api
  STAGES/E 'E CORE-CORPUS/E
  source-e:generated-core-e-red source-e:raw-successors/generated/e
  source-e:generated-core-e-lang source-e:wf-core/generated/e?
  stage-e:generated-core-stage-e-decomposition-lang
  stage-e:generated-core-stage-e-refocused-lang
  stage-e:generated-core-stage-e-machine-lang
  stage-e:generated-core-stage-e-compressed-lang
  stage-e:generated-core-stage-e-big-lang
  stage-e:generated-stage-decompose/e
  stage-e:generated-stage-plug-D/e
  stage-e:generated-stage-plug-C/e
  stage-e:generated-stage-contract-label/e
  stage-e:generated-stage-contract/e
  stage-e:generated-stage-decomposed-step/e
  stage-e:generated-stage-refocus-phase/e
  stage-e:generated-stage-D->Z/e
  stage-e:generated-stage-Z->D/e
  stage-e:generated-stage-readback-Z/e
  stage-e:generated-stage-refocus/spec/e
  stage-e:generated-stage-refocus/direct/e
  stage-e:generated-stage-refocused-step/spec/e
  stage-e:generated-stage-refocused-step/direct/e
  stage-e:generated-stage-machineize/e
  stage-e:generated-stage-encode-ZM/e
  stage-e:generated-stage-decode-MZ/e
  stage-e:generated-stage-D->M/e
  stage-e:generated-stage-M->D/e
  stage-e:generated-stage-readback-M/e
  stage-e:generated-stage-machine-step/spec/e
  stage-e:generated-stage-machine-step/direct/e
  stage-e:generated-stage-ZM-step-square/e
  stage-e:generated-stage-compress/e
  stage-e:generated-stage-encode-MB/e
  stage-e:generated-stage-decode-BM/e
  stage-e:generated-stage-readback-B/e
  stage-e:generated-stage-transition-span-labels/e
  stage-e:generated-stage-compressed-step/spec/e
  stage-e:generated-stage-compressed-step/direct/e
  stage-e:generated-stage-replay-transition-span/M/e
  stage-e:generated-stage-MB-step-square/e
  stage-e:generated-stage-readback-Big/e
  stage-e:generated-stage-big-run/direct/e
  stage-e:generated-stage-big-settled/direct/e
  stage-e:generated-stage-big-dead/direct/e
  stage-e:generated-stage-big-final/direct/e
  stage-e:generated-stage-big-evaluate/direct/e
  stage-e:generated-stage-big-evaluate/spec/e
  stage-e:generated-stage-flatten-BTrace/e
  stage-e:generated-stage-promote-B/direct/e
  stage-e:generated-stage-close-B/spec/e
  stage-e:generated-stage-B-Big-unfold-square/e
  stage-e:generated-stage-B-Big-closure-square/e
  stage-e:generated-stage-B-Big-root-square/e)

(define-stage-api
  STAGES/N 'N CORE-CORPUS/N
  source-n:generated-core-n-red source-n:raw-successors/generated/n
  source-n:generated-core-n-lang source-n:wf-core/generated/n?
  stage-n:generated-core-stage-n-decomposition-lang
  stage-n:generated-core-stage-n-refocused-lang
  stage-n:generated-core-stage-n-machine-lang
  stage-n:generated-core-stage-n-compressed-lang
  stage-n:generated-core-stage-n-big-lang
  stage-n:generated-stage-decompose/n
  stage-n:generated-stage-plug-D/n
  stage-n:generated-stage-plug-C/n
  stage-n:generated-stage-contract-label/n
  stage-n:generated-stage-contract/n
  stage-n:generated-stage-decomposed-step/n
  stage-n:generated-stage-refocus-phase/n
  stage-n:generated-stage-D->Z/n
  stage-n:generated-stage-Z->D/n
  stage-n:generated-stage-readback-Z/n
  stage-n:generated-stage-refocus/spec/n
  stage-n:generated-stage-refocus/direct/n
  stage-n:generated-stage-refocused-step/spec/n
  stage-n:generated-stage-refocused-step/direct/n
  stage-n:generated-stage-machineize/n
  stage-n:generated-stage-encode-ZM/n
  stage-n:generated-stage-decode-MZ/n
  stage-n:generated-stage-D->M/n
  stage-n:generated-stage-M->D/n
  stage-n:generated-stage-readback-M/n
  stage-n:generated-stage-machine-step/spec/n
  stage-n:generated-stage-machine-step/direct/n
  stage-n:generated-stage-ZM-step-square/n
  stage-n:generated-stage-compress/n
  stage-n:generated-stage-encode-MB/n
  stage-n:generated-stage-decode-BM/n
  stage-n:generated-stage-readback-B/n
  stage-n:generated-stage-transition-span-labels/n
  stage-n:generated-stage-compressed-step/spec/n
  stage-n:generated-stage-compressed-step/direct/n
  stage-n:generated-stage-replay-transition-span/M/n
  stage-n:generated-stage-MB-step-square/n
  stage-n:generated-stage-readback-Big/n
  stage-n:generated-stage-big-run/direct/n
  stage-n:generated-stage-big-settled/direct/n
  stage-n:generated-stage-big-dead/direct/n
  stage-n:generated-stage-big-final/direct/n
  stage-n:generated-stage-big-evaluate/direct/n
  stage-n:generated-stage-big-evaluate/spec/n
  stage-n:generated-stage-flatten-BTrace/n
  stage-n:generated-stage-promote-B/direct/n
  stage-n:generated-stage-close-B/spec/n
  stage-n:generated-stage-B-Big-unfold-square/n
  stage-n:generated-stage-B-Big-closure-square/n
  stage-n:generated-stage-B-Big-root-square/n)

(define (canonical-proof-multiset proofs)
  (sort proofs string<? #:key ~s))

(define (relation-rule-names relation)
  (sort
   (map (lambda (name) (string->symbol (~a name)))
        (reduction-relation->rule-names relation))
   symbol<?))

(define (only-result who results)
  (match results
    [(list result) result]
    [_
     (error who "expected one raw proof/result, received ~e" results)]))

(define (source->d api source)
  (only-result
   'source->d
   ((stage-api-decompose api) source)))

(define (source->z api source)
  ((stage-api-d->z api) (source->d api source)))

(define (source->m api source)
  ((stage-api-encode-zm api) (source->z api source)))

(define (source->b api source)
  ((stage-api-encode-mb api) (source->m api source)))

(define (source->z/direct api source)
  ((stage-api-refocus-phase api) (source->d api source)))

(define (source->m/direct api source)
  ((stage-api-machineize api) (source->z/direct api source)))

(define (source->b/direct api source)
  ((stage-api-compress api) (source->m/direct api source)))

(define (source-trace raw source [fuel 32] [reversed-labels '()])
  (when (zero? fuel)
    (error 'source-trace "trace exceeded its explicit bound"))
  (match (raw source)
    ['() (values (reverse reversed-labels) source)]
    [(list (list label target))
     (source-trace raw target (sub1 fuel) (cons label reversed-labels))]
    [results
     (error 'source-trace "expected deterministic source step, got ~e" results)]))

(define (machine-trace api machine [fuel 32] [reversed-labels '()])
  (when (zero? fuel)
    (error 'machine-trace "trace exceeded its explicit bound"))
  (define direct ((stage-api-m-step-direct api) machine))
  (define spec ((stage-api-m-step-spec api) machine))
  (check-equal? direct spec)
  (match direct
    ['() (values (reverse reversed-labels) machine)]
    [(list (list label next))
     (machine-trace api next (sub1 fuel) (cons label reversed-labels))]
    [results
     (error 'machine-trace "expected deterministic machine step, got ~e" results)]))

(define (compressed-trace api compressed [fuel 32] [reversed-spans '()])
  (when (zero? fuel)
    (error 'compressed-trace "trace exceeded its explicit bound"))
  (define direct ((stage-api-b-step-direct api) compressed))
  (define spec ((stage-api-b-step-spec api) compressed))
  (check-equal? direct spec)
  (match direct
    ['() (values (reverse reversed-spans) compressed)]
    [(list (list span next))
     (define machine ((stage-api-decode-bm api) compressed))
     (define machine-next ((stage-api-decode-bm api) next))
     (check-equal? ((stage-api-replay api) machine)
                   (list (list span machine-next)))
     (compressed-trace api next (sub1 fuel) (cons span reversed-spans))]
    [results
     (error 'compressed-trace
            "expected deterministic compressed step, got ~e"
            results)]))

(define (compressed-path api compressed [fuel 32])
  (when (zero? fuel)
    (error 'compressed-path "path exceeded its explicit bound"))
  (match ((stage-api-b-step-direct api) compressed)
    ['() (list compressed)]
    [(list (list _span next))
     (cons compressed (compressed-path api next (sub1 fuel)))]
    [results
     (error 'compressed-path
            "expected deterministic compressed step, got ~e"
            results)]))

(define (proofs->frontier api proofs)
  (for/list ([proof (in-list proofs)])
    (match-define (list label decomposition) proof)
    (list label ((stage-api-plug-d api) decomposition))))

(define (steps->readback readback steps)
  (for/list ([step (in-list steps)])
    (match-define (list label next) step)
    (list label (readback next))))

(define (make-row-suite api oracle-raw)
  (define row (stage-api-name api))
  (define corpus (stage-api-corpus api))
  (define representatives (row-corpus-rule-sources corpus))

  (test-suite
   (~a "generated selected core horizontal row " row)

   (test-case "R and D preserve all 13 independent raw oracle proofs"
     (check-equal?
      (relation-rule-names (stage-api-source-relation api))
      CORE-RULE-NAMES)
     (check-equal? (sort (map first representatives) symbol<?)
                   CORE-RULE-NAMES)
     (check-equal? (length representatives) 13)
     (check-equal? (length representatives)
                   (length (remove-duplicates (map first representatives))))

     (for ([representative (in-list representatives)])
       (match-define (list expected-label source) representative)
       (check-equal? source (row-source-ref corpus expected-label))
       (define oracle-proofs (oracle-raw source))
       (define generated-proofs ((stage-api-source-raw api) source))
       (check-equal? (canonical-proof-multiset generated-proofs)
                     (canonical-proof-multiset oracle-proofs))
       (check-equal? (map first generated-proofs) (list expected-label))

       (define decompositions ((stage-api-decompose api) source))
       (check-equal? (length decompositions) 1)
       (check-equal? ((stage-api-decompose-count api) source)
                     (length decompositions))
       (define decomposition (first decompositions))
       (check-equal? ((stage-api-plug-d api) decomposition) source)

       (define contractions ((stage-api-contract api) decomposition))
       (check-equal? (canonical-proof-multiset contractions)
                     (canonical-proof-multiset oracle-proofs))
       (check-equal? (length contractions) 1)
       (check-equal? ((stage-api-contract-count api) decomposition)
                     (length oracle-proofs))

       (define d-proofs ((stage-api-d-step api) decomposition))
       (check-equal? (canonical-proof-multiset
                      (proofs->frontier api d-proofs))
                     (canonical-proof-multiset oracle-proofs))
       (check-equal? (length d-proofs) 1)
       (check-equal? ((stage-api-d-step-count api) decomposition)
                     (length oracle-proofs))))

   (test-case "source and every derived carrier satisfy grammar and WF boundaries"
     (for ([representative (in-list representatives)])
       (match-define (list _label source) representative)
       (check-true ((stage-api-source-member? api) source))
       (check-true ((stage-api-source-wf? api) source))

       (define decomposition (source->d api source))
       (define refocused ((stage-api-d->z api) decomposition))
       (define machine ((stage-api-encode-zm api) refocused))
       (define compressed ((stage-api-encode-mb api) machine))
       (define big
         (only-result 'grammar/big ((stage-api-big-direct api) source)))

       (check-true ((stage-api-d-member? api) decomposition))
       (check-true ((stage-api-z-member? api) refocused))
       (check-true ((stage-api-m-member? api) machine))
       (check-true ((stage-api-b-member? api) compressed))
       (check-true ((stage-api-big-member? api) big))

       (check-true
        ((stage-api-source-wf? api)
         ((stage-api-plug-d api) decomposition)))
       (check-true
        ((stage-api-source-wf? api)
         ((stage-api-readback-z api) refocused)))
       (check-true
        ((stage-api-source-wf? api)
         ((stage-api-readback-m api) machine)))
       (check-true
        ((stage-api-source-wf? api)
         ((stage-api-readback-b api) compressed)))
       (check-true
        ((stage-api-source-wf? api)
         ((stage-api-readback-big api) big))))

     (for ([failure (in-list (row-corpus-failures corpus))])
       (check-true ((stage-api-source-member? api)
                    (failure-case-source failure)))
       (check-true ((stage-api-source-wf? api)
                    (failure-case-source failure))))

     (check-false ((stage-api-source-member? api) 'malformed-source))
     (check-false ((stage-api-d-member? api) 'malformed-D))
     (check-false ((stage-api-z-member? api) 'malformed-Z))
     (check-false ((stage-api-m-member? api) 'malformed-M))
     (check-false ((stage-api-b-member? api) 'malformed-B))
     (check-false ((stage-api-big-member? api) 'malformed-Big)))

   (test-case "duplicate binders inhabit no selected source or finite carrier"
     (define duplicate-source
       (row-corpus-duplicate-binder-source corpus))
     (match-define `(More ,duplicate-work) duplicate-source)
     (define root-work-focus '(More hole))
     (define duplicate-d
       `(DecAllocate ,duplicate-work ,root-work-focus))
     (define duplicate-z
       `(ZAllocate ,duplicate-work ,root-work-focus))
     (define duplicate-m
       `(MAllocate ,duplicate-work ,root-work-focus))
     (define duplicate-b
       `(BRun ,duplicate-work ,root-work-focus))

     (check-false ((stage-api-source-member? api) duplicate-source))
     (check-false ((stage-api-d-member? api) duplicate-d))
     (check-false ((stage-api-z-member? api) duplicate-z))
     (check-false ((stage-api-m-member? api) duplicate-m))
     (check-false ((stage-api-b-member? api) duplicate-b))
     (check-exn
      #rx"judgment input values do not match its contract"
      (lambda () ((stage-api-decompose api) duplicate-source)))
     (check-exn
      #rx"judgment input values do not match its contract"
      (lambda () ((stage-api-decompose-count api) duplicate-source))))

   (test-case "terminal inputs traverse every direct selected phase arrow"
     (define terminals
       (list
        (row-corpus-golden-terminal corpus)
        (failure-case-terminal
         (first (row-corpus-failures corpus)))))

     (for ([terminal (in-list terminals)])
       (define decomposition `(Final ,terminal))
       (define refocused `(ZFinal ,terminal))
       (define machine `(MFinal ,terminal))
       (define compressed `(BFinal ,terminal))
       (define big `(BigFinal ,terminal))

       (check-equal? ((stage-api-decompose api) terminal)
                     (list decomposition))
       (check-equal? ((stage-api-decompose-count api) terminal) 1)
       (check-equal? ((stage-api-refocus-phase api) decomposition)
                     refocused)
       (check-equal? ((stage-api-machineize api) refocused) machine)
       (check-equal? ((stage-api-compress api) machine) compressed)
       (check-equal? ((stage-api-promote api) compressed) (list big))
       (check-equal? ((stage-api-big-direct api) terminal) (list big))
       (check-equal? ((stage-api-big-direct-count api) terminal) 1)

       (check-equal? ((stage-api-d-step api) decomposition) '())
       (check-equal? ((stage-api-d-step-count api) decomposition) 0)
       (check-equal? ((stage-api-z-step-direct api) refocused) '())
       (check-equal? ((stage-api-z-step-direct-count api) refocused) 0)
       (check-equal? ((stage-api-m-step-direct api) machine) '())
       (check-equal? ((stage-api-m-step-direct-count api) machine) 0)
       (check-equal? ((stage-api-b-step-direct api) compressed) '())
       (check-equal? ((stage-api-b-step-direct-count api) compressed) 0)

       ;; These are secondary readback diagnostics over coordinates already
       ;; constructed by the primary phase arrows above.
       (check-equal? ((stage-api-plug-d api) decomposition) terminal)
       (check-equal? ((stage-api-readback-z api) refocused) terminal)
       (check-equal? ((stage-api-readback-m api) machine) terminal)
       (check-equal? ((stage-api-readback-b api) compressed) terminal)
       (check-equal? ((stage-api-readback-big api) big) terminal)))

   (test-case "standalone direct refocus preserves every raw contract proof"
     (for ([representative (in-list representatives)])
       (match-define (list _expected-label source) representative)
       (match-define (list (list _oracle-label expected-target))
         (oracle-raw source))
       (define decomposition (source->d api source))
       (define contracta ((stage-api-contracta api) decomposition))
       (check-equal? (length contracta) 1)
       (check-equal? ((stage-api-contract-count api) decomposition)
                     (length contracta))

       (define contractum (only-result 'standalone-refocus contracta))
       (define direct ((stage-api-refocus-direct api) contractum))
       (define spec ((stage-api-refocus-spec api) contractum))
       (define expected-refocused
         (source->z/direct api expected-target))

       ;; Both lists come directly from build-derivations.  Sorting preserves
       ;; duplicate equal outputs instead of normalizing them to a set.
       (check-equal? (canonical-proof-multiset direct)
                     (canonical-proof-multiset spec))
       (check-equal? (length direct) 1)
       (check-equal? (length spec) 1)
       (check-equal? direct (list expected-refocused))

       ;; Readback is a secondary diagnostic, not the construction route for
       ;; the expected selected coordinate.
       (check-equal? (map (stage-api-readback-z api) direct)
                     (list expected-target))))

   (test-case "Z direct/spec, Z-M isomorphism, and all squares cover 13 rules"
     (for ([representative (in-list representatives)])
       (match-define (list expected-label source) representative)
       (match-define (list (list _expected-label expected-target))
         (oracle-raw source))
       (define decomposition (source->d api source))
       (define refocused ((stage-api-d->z api) decomposition))
       (check-equal? ((stage-api-z->d api) refocused) decomposition)
       (check-equal? ((stage-api-readback-z api) refocused) source)

       (define z-direct ((stage-api-z-step-direct api) refocused))
       (define z-spec ((stage-api-z-step-spec api) refocused))
       (check-equal? z-direct z-spec)
       (check-equal? (length z-direct) 1)
       (check-equal? ((stage-api-z-step-direct-count api) refocused)
                     (length z-direct))
       (check-equal? ((stage-api-z-step-spec-count api) refocused)
                     (length z-spec))
       (check-equal? ((stage-api-z-step-direct-count api) refocused)
                     ((stage-api-z-step-spec-count api) refocused))
       (check-equal? (first (first z-direct)) expected-label)
       (check-equal? (steps->readback (stage-api-readback-z api) z-direct)
                     (list (list expected-label expected-target)))

       (define machine ((stage-api-encode-zm api) refocused))
       (check-equal? ((stage-api-decode-mz api) machine) refocused)
       (check-equal? ((stage-api-d->m api) decomposition) machine)
       (check-equal? ((stage-api-m->d api) machine) decomposition)
       (check-equal? ((stage-api-readback-m api) machine) source)

       (define m-direct ((stage-api-m-step-direct api) machine))
       (define m-spec ((stage-api-m-step-spec api) machine))
       (check-equal? m-direct m-spec)
       (check-equal? (length m-direct) 1)
       (check-equal? ((stage-api-m-step-direct-count api) machine)
                     (length m-direct))
       (check-equal? ((stage-api-m-step-spec-count api) machine)
                     (length m-spec))
       (check-equal? ((stage-api-m-step-direct-count api) machine)
                     ((stage-api-m-step-spec-count api) machine))
       (check-equal? (steps->readback (stage-api-readback-m api) m-direct)
                     (list (list expected-label expected-target)))

       (match-define (list label z-next) (first z-direct))
       (check-equal?
        ((stage-api-zm-square api) refocused)
        (list
         (list label
               z-next
               machine
               ((stage-api-encode-zm api) z-next))))))

   (test-case "B direct/spec spans replay exactly at every core control point"
     (for ([representative (in-list representatives)])
       (match-define (list expected-label source) representative)
       (define machine (source->m api source))
       (define compressed ((stage-api-encode-mb api) machine))
       (check-equal? ((stage-api-decode-bm api) compressed) machine)
       (check-equal? ((stage-api-readback-b api) compressed) source)

       (define direct ((stage-api-b-step-direct api) compressed))
       (define spec ((stage-api-b-step-spec api) compressed))
       (check-equal? direct spec)
       (check-equal? (length direct) 1)
       (check-equal? ((stage-api-b-step-direct-count api) compressed)
                     (length direct))
       (check-equal? ((stage-api-b-step-spec-count api) compressed)
                     (length spec))
       (check-equal? ((stage-api-b-step-direct-count api) compressed)
                     ((stage-api-b-step-spec-count api) compressed))
       (match-define (list span compressed-next) (first direct))
       (define labels ((stage-api-span-labels api) span))
       (check-equal? (first labels) expected-label)
       (check-equal? (length labels)
                     (if (member expected-label PRODUCER-RULE-NAMES) 2 1))
       (define machine-next ((stage-api-decode-bm api) compressed-next))
       (check-equal? ((stage-api-replay api) machine)
                     (list (list span machine-next)))
       (check-equal? ((stage-api-replay-count api) machine) 1)
       (check-equal?
        ((stage-api-mb-square api) compressed)
        (list (list span compressed-next machine machine-next)))))

   (test-case "all four direct Big entries preserve raw singleton proofs"
     (define entry-sources
       (list
        (list 'run (row-source-ref corpus 'succeed))
        (list 'settled (row-source-ref corpus 'finish-success))
        (list 'dead (row-source-ref corpus 'finish-failure))
        (list
         'final
         (failure-case-terminal
          (first (row-corpus-failures corpus))))))

     (for ([entry-source (in-list entry-sources)])
       (match-define (list entry-kind source) entry-source)
       (define compressed (source->b/direct api source))
       (define entry-results
         (match (list entry-kind compressed)
           [(list 'run `(BRun ,work ,focus))
            ((stage-api-big-run api) work focus)]
           [(list 'settled `(BSettled ,settled ,focus))
            ((stage-api-big-settled api) settled focus)]
           [(list 'dead `(BDead ,failure-summary ,focus))
            ((stage-api-big-dead api) failure-summary focus)]
           [(list 'final `(BFinal ,terminal))
            ((stage-api-big-final api) terminal)]
           [unexpected
            (error 'direct-Big-entry
                   "entry kind and direct B coordinate disagree: ~e"
                   unexpected)]))
       (define promoted ((stage-api-promote api) compressed))
       (define evaluated ((stage-api-big-direct api) source))

       ;; Entry and promotion results are raw build-derivations outputs.
       (check-equal? (length entry-results) 1)
       (check-equal? (length promoted) 1)
       (check-equal? ((stage-api-big-direct-count api) source) 1)
       (check-equal? entry-results promoted)
       (check-equal? entry-results evaluated)))

   (test-case "finite M/B/Big trace has exact labels, spans, and every suffix"
     (define source (row-corpus-finite-source corpus))
     (define expected-terminal (row-corpus-golden-terminal corpus))
     (define machine (source->m api source))
     (define compressed ((stage-api-encode-mb api) machine))
     (define expected-big `(BigFinal ,expected-terminal))

     (define-values (machine-labels terminal-machine)
       (machine-trace api machine))
     (define-values (spans terminal-compressed)
       (compressed-trace api compressed))
     (check-equal? machine-labels GOLDEN-M-LABELS)
     (check-equal? spans GOLDEN-B-SPANS)
     (check-equal? (append-map (stage-api-span-labels api) spans)
                   GOLDEN-M-LABELS)
     (check-equal? ((stage-api-readback-m api) terminal-machine)
                   expected-terminal)
     (check-equal? ((stage-api-readback-b api) terminal-compressed)
                   expected-terminal)

     (define direct-big ((stage-api-big-direct api) source))
     (define spec-big ((stage-api-big-spec api) source))
     (define root-square ((stage-api-root-square api) source))
     (check-equal? direct-big (list expected-big))
     (check-equal? spec-big (list (list GOLDEN-B-SPANS expected-big)))
     (check-equal? root-square spec-big)
     (check-equal? ((stage-api-flatten api) GOLDEN-B-SPANS)
                   GOLDEN-M-LABELS)
     (check-equal? ((stage-api-readback-big api) expected-big)
                   expected-terminal)

     (define path (compressed-path api compressed))
     (check-equal? (length path) (add1 (length GOLDEN-B-SPANS)))
     (for ([compressed-suffix (in-list path)]
           [index (in-naturals)])
       (define expected-spans (drop GOLDEN-B-SPANS index))
       (check-equal? ((stage-api-promote api) compressed-suffix)
                     (list expected-big))
       (check-equal? ((stage-api-close api) compressed-suffix)
                     (list (list expected-spans expected-terminal)))
       (check-equal? ((stage-api-closure api) compressed-suffix)
                     (list (list expected-spans expected-big)))

       (when (< index (length GOLDEN-B-SPANS))
         (define expected-span (list-ref GOLDEN-B-SPANS index))
         (define expected-next (list-ref path (add1 index)))
         (check-equal?
          ((stage-api-unfold api) compressed-suffix)
          (list (list expected-span expected-next expected-big))))))

   (test-case "all 13 finite roots have singleton direct/spec Big outcomes"
     (for ([representative (in-list representatives)])
       (match-define (list _label source) representative)
       (define direct ((stage-api-big-direct api) source))
       (define spec ((stage-api-big-spec api) source))
       (define square ((stage-api-root-square api) source))
       (check-equal? (length direct) 1)
       (check-equal? (length spec) 1)
       (check-equal? ((stage-api-big-direct-count api) source)
                     (length direct))
       (check-equal? ((stage-api-big-spec-count api) source)
                     (length spec))
       (check-equal? ((stage-api-big-direct-count api) source)
                     ((stage-api-big-spec-count api) source))
       (check-equal? square spec)
       (check-equal? direct (map second spec))))

   (test-case "failure traces preserve exact phase-sensitive supply summaries"
     (for ([failure (in-list (row-corpus-failures corpus))])
       (define source (failure-case-source failure))
       (define expected-labels (failure-case-labels failure))
       (define expected-terminal (failure-case-terminal failure))
       (define expected-big `(BigFinal ,expected-terminal))

       (define-values (source-labels source-terminal)
         (source-trace (stage-api-source-raw api) source))
       (define-values (oracle-labels oracle-terminal)
         (source-trace oracle-raw source))
       (define-values (machine-labels terminal-machine)
         (machine-trace api (source->m api source)))
       (define-values (spans terminal-compressed)
         (compressed-trace api (source->b api source)))
       (check-equal? source-labels expected-labels)
       (check-equal? source-terminal expected-terminal)
       (check-equal? oracle-labels expected-labels)
       (check-equal? oracle-terminal expected-terminal)
       (check-equal? machine-labels expected-labels)
       (check-equal? ((stage-api-readback-m api) terminal-machine)
                     expected-terminal)
       (check-equal? (append-map (stage-api-span-labels api) spans)
                     expected-labels)
       (check-equal? ((stage-api-readback-b api) terminal-compressed)
                     expected-terminal)
       (check-equal? ((stage-api-big-direct api) source)
                     (list expected-big))
       (define big-spec ((stage-api-big-spec api) source))
       (check-equal? (map first big-spec) (list spans))
       (check-equal? (map second big-spec) (list expected-big))))))

(define ROW-S-HORIZONTAL
  (make-row-suite STAGES/S oracle-s:raw-successors/s))

(define ROW-E-HORIZONTAL
  (make-row-suite STAGES/E oracle-e:raw-successors/e))

(define ROW-N-HORIZONTAL
  (make-row-suite STAGES/N oracle-n:raw-successors/n))

(define S-REFERENCE-CORRESPONDENCE
  (test-suite
   "selected generated S agrees with independent handwritten S stages"

   (test-case "bounded 13-rule core corpus agrees exactly through Big"
     (for ([representative
            (in-list (row-corpus-rule-sources CORE-CORPUS/S))])
       (match-define (list _label source) representative)
       (define selected-d (source->d STAGES/S source))
       (define reference-d
         (only-result
          'reference-decompose/s
          (judgment-holds (ref-d:decompose/s ,source D) D)))
       (check-equal? selected-d reference-d)
       (check-equal?
        (judgment-holds
         (stage-s:generated-stage-contract/s ,selected-d C)
         C)
        (judgment-holds (ref-d:contract/s ,reference-d C) C))
       (check-equal?
        ((stage-api-d-step STAGES/S) selected-d)
        (judgment-holds
         (ref-d:decomposed-step/direct/s
          ,reference-d
          RuleName
          D_next)
         (RuleName D_next)))

       (define selected-z ((stage-api-d->z STAGES/S) selected-d))
       (define reference-z (term (ref-z:D->Z/s ,reference-d)))
       (check-equal? selected-z reference-z)
       (check-equal?
        ((stage-api-z-step-direct STAGES/S) selected-z)
        (judgment-holds
         (ref-z:refocused-step/direct/s ,reference-z RuleName Z_next)
         (RuleName Z_next)))

       (define selected-m ((stage-api-encode-zm STAGES/S) selected-z))
       (define reference-m (term (ref-m:encode-ZM/s ,reference-z)))
       (check-equal? selected-m reference-m)
       (check-equal?
        ((stage-api-m-step-direct STAGES/S) selected-m)
        (judgment-holds
         (ref-m:machine-step/direct/s ,reference-m RuleName M_next)
         (RuleName M_next)))

       (define selected-b ((stage-api-encode-mb STAGES/S) selected-m))
       (define reference-b (term (ref-b:encode-MB/s ,reference-m)))
       (check-equal? selected-b reference-b)
       (check-equal?
        ((stage-api-b-step-direct STAGES/S) selected-b)
        (judgment-holds
         (ref-b:compressed-step/direct/s
          ,reference-b
          TransitionSpan
          B_next)
         (TransitionSpan B_next)))

       (check-equal?
        ((stage-api-big-direct STAGES/S) source)
        (judgment-holds (ref-big:big-evaluate/direct/s ,source Big) Big))))))

(define/provide-test-suite GENERATED-CORE-STAGES-HORIZONTAL
  ROW-S-HORIZONTAL
  ROW-E-HORIZONTAL
  ROW-N-HORIZONTAL
  S-REFERENCE-CORRESPONDENCE)

(module+ test
  (run-tests GENERATED-CORE-STAGES-HORIZONTAL))
