#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in stage-s: "./s.rkt")
         (prefix-in stage-s: (submod "./s.rkt" diagnostics))
         (prefix-in stage-e: "./e.rkt")
         (prefix-in stage-e: (submod "./e.rkt" diagnostics))
         (prefix-in stage-n: "./n.rkt")
         (prefix-in stage-n: (submod "./n.rkt" diagnostics))
         (prefix-in stage-q: "./vertical.rkt")
         "./corpus.rkt")

(provide GENERATED-CORE-STAGES-VERTICAL-TRANSPORT-DIAGNOSTICS)

;; These plug, inverse-codec, and readback paths are deliberately confined to
;; a test module.  They compare against already generated direct Q maps; they
;; do not construct a selected matrix coordinate or implement a public map.

(struct row-api
  (name
   corpus
   decompose
   plug-D
   refocus
   Z->D
   machineize
   decode-MZ
   compress
   decode-BM
   big
   readback-Z
   readback-M
   readback-B
   readback-Big)
  #:transparent)

(define-syntax-rule
  (define-row-api
    api-id row-name corpus-id
    decompose-id plug-D-id
    refocus-id Z->D-id
    machineize-id decode-MZ-id
    compress-id decode-BM-id
    promote-id
    readback-Z-id readback-M-id readback-B-id readback-Big-id)
  (define api-id
    (row-api
     row-name
     corpus-id
     (lambda (frontier)
       (for/list ([proof
                   (in-list
                    (build-derivations
                     (decompose-id ,frontier D)))])
         (last (derivation-term proof))))
     (lambda (decomposition) (term (plug-D-id ,decomposition)))
     (lambda (decomposition) (term (refocus-id ,decomposition)))
     (lambda (refocused) (term (Z->D-id ,refocused)))
     (lambda (refocused) (term (machineize-id ,refocused)))
     (lambda (machine) (term (decode-MZ-id ,machine)))
     (lambda (machine) (term (compress-id ,machine)))
     (lambda (compressed) (term (decode-BM-id ,compressed)))
     (lambda (compressed)
       (for/list ([proof
                   (in-list
                    (build-derivations
                     (promote-id ,compressed Big)))])
         (last (derivation-term proof))))
     (lambda (refocused) (term (readback-Z-id ,refocused)))
     (lambda (machine) (term (readback-M-id ,machine)))
     (lambda (compressed) (term (readback-B-id ,compressed)))
     (lambda (big) (term (readback-Big-id ,big))))))

(define-row-api
  ROW/S 'S CORE-CORPUS/S
  stage-s:generated-stage-decompose/s
  stage-s:generated-stage-plug-D/s
  stage-s:generated-stage-refocus-phase/s
  stage-s:generated-stage-Z->D/s
  stage-s:generated-stage-machineize/s
  stage-s:generated-stage-decode-MZ/s
  stage-s:generated-stage-compress/s
  stage-s:generated-stage-decode-BM/s
  stage-s:generated-stage-promote-B/direct/s
  stage-s:generated-stage-readback-Z/s
  stage-s:generated-stage-readback-M/s
  stage-s:generated-stage-readback-B/s
  stage-s:generated-stage-readback-Big/s)

(define-row-api
  ROW/E 'E CORE-CORPUS/E
  stage-e:generated-stage-decompose/e
  stage-e:generated-stage-plug-D/e
  stage-e:generated-stage-refocus-phase/e
  stage-e:generated-stage-Z->D/e
  stage-e:generated-stage-machineize/e
  stage-e:generated-stage-decode-MZ/e
  stage-e:generated-stage-compress/e
  stage-e:generated-stage-decode-BM/e
  stage-e:generated-stage-promote-B/direct/e
  stage-e:generated-stage-readback-Z/e
  stage-e:generated-stage-readback-M/e
  stage-e:generated-stage-readback-B/e
  stage-e:generated-stage-readback-Big/e)

(define-row-api
  ROW/N 'N CORE-CORPUS/N
  stage-n:generated-stage-decompose/n
  stage-n:generated-stage-plug-D/n
  stage-n:generated-stage-refocus-phase/n
  stage-n:generated-stage-Z->D/n
  stage-n:generated-stage-machineize/n
  stage-n:generated-stage-decode-MZ/n
  stage-n:generated-stage-compress/n
  stage-n:generated-stage-decode-BM/n
  stage-n:generated-stage-promote-B/direct/n
  stage-n:generated-stage-readback-Z/n
  stage-n:generated-stage-readback-M/n
  stage-n:generated-stage-readback-B/n
  stage-n:generated-stage-readback-Big/n)

(struct edge-api
  (name source target Q-R Q-D Q-Z Q-M Q-B Q-Big)
  #:transparent)

(define EDGE/SE
  (edge-api
   'S->E ROW/S ROW/E
   stage-q:Q-SE/R/stages
   stage-q:Q-SE/D/stages
   stage-q:Q-SE/Z/stages
   stage-q:Q-SE/M/stages
   stage-q:Q-SE/B/stages
   stage-q:Q-SE/Big/stages))

(define EDGE/EN
  (edge-api
   'E->N ROW/E ROW/N
   stage-q:Q-EN/R/stages
   stage-q:Q-EN/D/stages
   stage-q:Q-EN/Z/stages
   stage-q:Q-EN/M/stages
   stage-q:Q-EN/B/stages
   stage-q:Q-EN/Big/stages))

(define EDGE/SN
  (edge-api
   'S->N ROW/S ROW/N
   stage-q:Q-SN/R/stages
   stage-q:Q-SN/D/stages
   stage-q:Q-SN/Z/stages
   stage-q:Q-SN/M/stages
   stage-q:Q-SN/B/stages
   stage-q:Q-SN/Big/stages))

(define EDGES (list EDGE/SE EDGE/EN EDGE/SN))

(define (only-result who results)
  (match results
    [(list result) result]
    [_
     (error who
            "secondary diagnostic expected one bounded result, received ~e"
            results)]))

(define (check-diagnostics edge source)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (define source-D
    (only-result
     `(,(edge-api-name edge) source-D)
     ((row-api-decompose source-row) source)))
  (define target-D ((edge-api-Q-D edge) source-D))

  ;; Plug/Q_R/decompose transport is only a comparator for the direct Q_D.
  (define transported-D
    (only-result
     `(,(edge-api-name edge) transported-D)
     ((row-api-decompose target-row)
      ((edge-api-Q-R edge)
       ((row-api-plug-D source-row) source-D)))))
  (check-equal? target-D transported-D)
  (check-equal?
   ((row-api-plug-D target-row) target-D)
   ((edge-api-Q-R edge) ((row-api-plug-D source-row) source-D)))

  (define source-Z ((row-api-refocus source-row) source-D))
  (define target-Z ((edge-api-Q-Z edge) source-Z))
  (define transported-Z
    ((row-api-refocus target-row)
     ((edge-api-Q-D edge)
      ((row-api-Z->D source-row) source-Z))))
  (check-equal? target-Z transported-Z)
  (check-equal?
   ((row-api-Z->D source-row) source-Z)
   source-D)
  (check-equal?
   ((row-api-readback-Z target-row) target-Z)
   ((edge-api-Q-R edge) ((row-api-readback-Z source-row) source-Z)))

  (define source-M ((row-api-machineize source-row) source-Z))
  (define target-M ((edge-api-Q-M edge) source-M))
  (define transported-M
    ((row-api-machineize target-row)
     ((edge-api-Q-Z edge)
      ((row-api-decode-MZ source-row) source-M))))
  (check-equal? target-M transported-M)
  (check-equal?
   ((row-api-decode-MZ source-row) source-M)
   source-Z)
  (check-equal?
   ((row-api-readback-M target-row) target-M)
   ((edge-api-Q-R edge) ((row-api-readback-M source-row) source-M)))

  (define source-B ((row-api-compress source-row) source-M))
  (define target-B ((edge-api-Q-B edge) source-B))
  (define transported-B
    ((row-api-compress target-row)
     ((edge-api-Q-M edge)
      ((row-api-decode-BM source-row) source-B))))
  (check-equal? target-B transported-B)
  (check-equal?
   ((row-api-decode-BM source-row) source-B)
   source-M)
  (check-equal?
   ((row-api-readback-B target-row) target-B)
   ((edge-api-Q-R edge) ((row-api-readback-B source-row) source-B)))

  (define source-Big
    (only-result
     `(,(edge-api-name edge) source-Big)
     ((row-api-big source-row) source-B)))
  (define target-Big ((edge-api-Q-Big edge) source-Big))
  (check-equal?
   ((row-api-readback-Big target-row) target-Big)
   ((edge-api-Q-R edge)
    ((row-api-readback-Big source-row) source-Big))))

(define GENERATED-CORE-STAGES-VERTICAL-TRANSPORT-DIAGNOSTICS
  (test-suite
   "secondary codec and readback diagnostics for direct stage maps"

   (test-case "all 13 representatives agree with test-only transports"
     (for* ([edge (in-list EDGES)]
            [rule-name (in-list CORE-RULE-NAMES)])
       (check-diagnostics
        edge
        (row-source-ref
         (row-api-corpus (edge-api-source edge))
         rule-name))))

   (test-case "sparse and complete executions agree with diagnostics"
     (for ([edge (in-list EDGES)]
           [sparse (in-list (list SPARSE-VERTICAL-WITNESS/S
                                  SPARSE-VERTICAL-WITNESS/E
                                  SPARSE-VERTICAL-WITNESS/S))])
       (check-diagnostics edge sparse)
       (define source-corpus
         (row-api-corpus (edge-api-source edge)))
       (check-diagnostics edge (row-corpus-finite-source source-corpus))
       (for ([failure (in-list (row-corpus-failures source-corpus))])
         (check-diagnostics edge (failure-case-source failure)))))))

(module+ test
  (run-tests GENERATED-CORE-STAGES-VERTICAL-TRANSPORT-DIAGNOSTICS))
