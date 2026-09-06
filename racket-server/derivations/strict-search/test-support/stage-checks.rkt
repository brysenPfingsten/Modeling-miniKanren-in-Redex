#lang racket

(require rackunit redex/reduction-semantics
         "../shared/stages/schema.rkt")

(provide check-row successor-list map-edge)

;; The source relation and stage instance are inputs, so this checker is shared
;; by the pending-prefix checkpoint and retained-scope derivation.
(define (successor-list edge)
  (match edge [#f '()] [_ (list edge)]))

(define (map-edge edge map-state)
  (match edge [#f #f] [(list label next) (list label (map-state next))]))

(define (check-row stage source computation)
  (define initial-d (decompose stage computation))
  (define initial-z (initial-Z stage computation))
  (define initial-m (initial-M stage computation))
  (define initial-b (initial-B stage computation))
  (check-equal? (readback-D initial-d) computation)
  (check-equal? (readback-Z initial-z) computation)
  (check-equal? (readback-M initial-m) computation)
  (check-equal? (readback-B initial-b) computation)

  (define d-edges (d-trace stage initial-d #:fuel 3000))
  (for ([configuration (in-list (cons initial-d (map second d-edges)))])
    (check-equal?
     (apply-reduction-relation/tag-with-names source (readback-D configuration))
     (successor-list (map-edge (d-step stage configuration) readback-D))))

  (define z-edges (z-trace stage initial-z #:fuel 10000))
  (for ([configuration (in-list (cons initial-z (map second z-edges)))])
    (define machine (encode-ZM configuration))
    (check-equal? (decode-MZ machine) configuration)
    (check-equal? (encode-ZM (decode-MZ machine)) machine)
    (check-equal? (readback-M machine) (readback-Z configuration))
    (check-equal? (map-edge (z-step stage configuration) encode-ZM) (m-step stage machine))
    (match (z-step stage configuration)
      [(list "admin" next) (check-equal? (readback-Z configuration) (readback-Z next))]
      [other
       (check-equal?
        (apply-reduction-relation/tag-with-names source (readback-Z configuration))
        (successor-list (map-edge other readback-Z)))]))

  (define m-edges (m-trace stage initial-m #:fuel 10000))
  (define b-edges (b-trace stage initial-b #:fuel 3000))
  (for ([configuration (in-list (cons initial-b (map second b-edges)))])
    (check-false (m-admin? stage (decode-BM configuration)))
    (check-true (compression-square? stage configuration))
    (match (b-step stage configuration)
      [#f (check-true (BFinal? configuration))]
      [(list span next)
       (check-equal? (length (semantic-labels span)) 1)
       (check-equal?
        (apply-reduction-relation/tag-with-names source (readback-B configuration))
        (list (list (first (semantic-labels span)) (readback-B next))))]))
  (check-equal? (map first z-edges) (map first m-edges))
  (check-equal? (append-map (lambda (edge) (Span-labels (first edge))) b-edges)
                (map first m-edges))
  (check-equal? (append-map (lambda (edge) (semantic-labels (first edge))) b-edges)
                (map first d-edges))
  (define expected
    (readback-D (if (null? d-edges) initial-d (second (last d-edges)))))
  (check-equal? (run-Z stage computation) expected)
  (check-equal? (run-M stage computation) expected)
  (check-equal? (run-B stage computation) expected))

