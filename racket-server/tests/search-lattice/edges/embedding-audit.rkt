#lang racket

(require rackunit
         redex/reduction-semantics)

(provide GENERATED-SAMPLE-COUNT
         GENERATED-TERM-DEPTH
         generated-corpus
         audit-identity-edge)

(define GENERATED-SAMPLE-COUNT 120)
(define GENERATED-TERM-DEPTH 8)

(define (generated-corpus generator seed)
  (define rng
    (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator rng])
    (random-seed seed)
    (for/list ([_ (in-range GENERATED-SAMPLE-COUNT)])
      (generator))))

(define (sort-tagged-successors successors)
  (sort successors string<? #:key (lambda (successor) (format "~s" successor))))

(define (check-raw-uniqueness label side source raw-successors)
  (define named-successors
    (remove-duplicates raw-successors))
  (check-equal? (length raw-successors)
                (length named-successors)
                (format "~a: ~a relation has duplicate raw proofs for ~s: ~s"
                        label
                        side
                        source
                        raw-successors))
  (check-true (<= (length named-successors) 1)
              (format "~a: ~a relation has multiple named successors for ~s: ~s"
                      label
                      side
                      source
                      named-successors)))

(define (audit-identity-edge #:label label
                             #:source-relation source-relation
                             #:target-relation target-relation
                             #:source? source?
                             #:target? target?
                             #:source-wf? source-wf?
                             #:target-wf? target-wf?
                             #:representatives representatives
                             #:generated generated)
  (check-equal? (length generated)
                GENERATED-SAMPLE-COUNT
                (format "~a: generated corpus was filtered or truncated" label))
  (define sources
    (append representatives generated))
  (check-equal? (length sources)
                (+ (length representatives) GENERATED-SAMPLE-COUNT)
                (format "~a: full attempt count drifted" label))
  (define reducible-count
    (for/sum ([source (in-list sources)])
      (check-true (source? source)
                  (format "~a: source corpus escaped its grammar: ~s"
                          label
                          source))
      (check-true (target? source)
                  (format "~a: identity embedding escaped target grammar: ~s"
                          label
                          source))
      (define source-successors
        (apply-reduction-relation/tag-with-names source-relation source))
      (define target-successors
        (apply-reduction-relation/tag-with-names target-relation source))
      (check-raw-uniqueness label "source" source source-successors)
      (check-raw-uniqueness label "target" source target-successors)
      (check-equal? (sort-tagged-successors target-successors)
                    (sort-tagged-successors source-successors)
                    (format "~a: complete named successors changed for ~s"
                            label
                            source))
      (if (null? source-successors) 0 1)))
  (define wf-hit-count
    (for/sum ([source (in-list sources)])
      (define source-wf-result
        (source-wf? source))
      (define target-wf-result
        (target-wf? source))
      (check-equal? target-wf-result
                    source-wf-result
                    (format "~a: target WF changed under identity embedding for ~s"
                            label
                            source))
      (if source-wf-result 1 0)))
  (check-true (positive? reducible-count)
              (format "~a: corpus exercised no live source rule" label))
  (check-true (positive? wf-hit-count)
              (format "~a: corpus exercised no well-formed source term" label)))
