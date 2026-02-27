#lang racket

(require (prefix-in mmk:    "reduction-relations/reduction-relations.rkt")
         (prefix-in dmitry: "reduction-relations/dmitry-and-dmitry.rkt")
         (prefix-in dfs:    "reduction-relations/dfs.rkt"))

(provide model-spec?
         model-spec-id
         model-spec-label
         model-spec-parser-profile
         model-spec-step-once
         all-model-specs
         default-model-id
         lookup-model-spec
         lookup-model-step-once
         model-spec->jsexpr)

(struct model-spec (id label parser-profile step-once) #:transparent)

;; This is intentionally a backend-only source of truth for model dispatch.
;; Frontend option wiring can consume this later without changing stepping code.
(define all-model-specs
  (list (model-spec "microKanren" "microKanren (legacy)" "legacy" mmk:step-once)
        (model-spec "dmitry" "Dmitry et al." "legacy" dmitry:step-once)
        (model-spec "dfs" "DFS (legacy)" "legacy" dfs:step-once)))

(define default-model-id "microKanren")

(define spec-by-id
  (for/hash ([spec (in-list all-model-specs)])
    (values (model-spec-id spec) spec)))

(define (lookup-model-spec model-id)
  (and (string? model-id)
       (hash-ref spec-by-id model-id #f)))

(define (lookup-model-step-once model-id)
  (define maybe-spec (lookup-model-spec model-id))
  (and maybe-spec (model-spec-step-once maybe-spec)))

(define (model-spec->jsexpr spec)
  (hasheq 'id (model-spec-id spec)
          'label (model-spec-label spec)
          'parserProfile (model-spec-parser-profile spec)))
