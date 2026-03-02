#lang racket

(require (prefix-in var: "reduction-relations/extensions/variant-relations.rkt")
         "transpiler.rkt")

(provide model-spec?
         model-spec-id
         model-spec-label
         model-spec-parser-profile
         model-spec-parser-target
         model-spec-step-once
         all-model-specs
         default-model-id
         default-parser-target-id
         lookup-model-spec
         lookup-model-step-once
         model-spec->jsexpr)

(struct model-spec (id label parser-profile parser-target step-once) #:transparent)

;; This is intentionally a backend-only source of truth for model dispatch.
;; Frontend option wiring can consume this later without changing stepping code.
(define all-model-specs
  (list (model-spec "microKanren-rail"
                    "microKanren (Interleave + Railroad, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rrail-l)
        (model-spec "microKanren-noi-flip"
                    "microKanren (No Interleave + Flip Syntax, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rbase-l)
        (model-spec "microKanren-dfs-nodelay"
                    "microKanren (DFS, No Delay/Proceed, Left Disjunction)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rdfs-nodelay)
        (model-spec "microKanren-flip"
                    "microKanren (Interleave + Flip-Flop, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rflip-l)
        (model-spec "microKanren-rail-eager"
                    "microKanren (Interleave + Railroad, Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rrail-e)
        (model-spec "microKanren-flip-eager"
                    "microKanren (Interleave + Flip-Flop, Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rflip-e)
        (model-spec "dmitry"
                    "Dmitry et al. (provisional alias: L4/Rrail-e)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rrail-e)
        (model-spec "dfs"
                    "DFS (L4/Rrail-l)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    var:step-once/Rrail-l)))

(define default-model-id "microKanren-rail")
(define default-parser-target-id canonical-parser-target-id)

(define spec-by-id
  (for/hash ([spec (in-list all-model-specs)])
    (values (model-spec-id spec) spec)))

(define (lookup-model-spec model-id)
  (define canonical-id
    (cond
      [(equal? model-id "microKanren") "microKanren-rail"]
      [else model-id]))
  (and (string? canonical-id)
       (hash-ref spec-by-id canonical-id #f)))

(define (lookup-model-step-once model-id)
  (define maybe-spec (lookup-model-spec model-id))
  (and maybe-spec (model-spec-step-once maybe-spec)))

(define (model-spec->jsexpr spec)
  (hasheq 'id (model-spec-id spec)
          'label (model-spec-label spec)
          'parserProfile (model-spec-parser-profile spec)
          'parserTarget (model-spec-parser-target spec)))
