#lang racket

(require "model-registry.rkt")

(provide surfaced-model-ids
         internal-smoke-model-ids
         surfaced-model-specs
         internal-smoke-model-specs)

(define surfaced-model-ids
  '("l3-dfs-lazy"
    "l3-flip-lazy"
    "l4-rail-lazy"
    "l3-dfs-eager"
    "l3-flip-eager"
    "l4-rail-eager"))

(define internal-smoke-model-ids
  '("l0-core"
    "l1-call-lazy"
    "l1-call-eager"
    "l2-disj-left"))

(define (ids->specs ids)
  (for/list ([mid (in-list ids)])
	(cond
	  ((lookup-model-spec mid))
	  (else (error 'ids->specs (format "unknown model id in surface policy: ~a" mid))))))

(define surfaced-model-specs (ids->specs surfaced-model-ids))
(define internal-smoke-model-specs (ids->specs internal-smoke-model-ids))
