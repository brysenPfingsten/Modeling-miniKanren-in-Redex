#lang racket

(require (prefix-in rr:l0: "reduction-relations/l0.rkt")
         (prefix-in rr:l1e: "reduction-relations/l1-call-eager.rkt")
         (prefix-in rr:l1l: "reduction-relations/l1-call-lazy.rkt")
         (prefix-in rr:l2: "reduction-relations/l2-disj-left.rkt")
         (prefix-in rr:l3be: "reduction-relations/l3-base-eager.rkt")
         (prefix-in rr:l3bl: "reduction-relations/l3-base-lazy.rkt")
         (prefix-in rr:l3de: "reduction-relations/l3-dfs-eager.rkt")
         (prefix-in rr:l3dl: "reduction-relations/l3-dfs-lazy.rkt")
         (prefix-in rr:l3fe: "reduction-relations/l3-flip-eager.rkt")
         (prefix-in rr:l3fl: "reduction-relations/l3-flip-lazy.rkt")
         (prefix-in rr:l4re: "reduction-relations/l4-rail-eager.rkt")
         (prefix-in rr:l4rl: "reduction-relations/l4-rail-lazy.rkt")
         "transpiler.rkt")

(provide model-spec?
         model-spec-id
         model-spec-label
         model-spec-parser-profile
         model-spec-parser-target
         model-spec-capabilities
         model-spec-step-once
         all-model-specs
         default-model-id
         lookup-model-spec
         lookup-model-step-once
         model-spec->jsexpr)

(struct model-spec (id label parser-profile parser-target capabilities step-once) #:transparent)

(define all-model-specs
  (list (model-spec "l0-core"
                    "L0 Core (No RelCall/No Disjunction)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/fresh")
                    rr:l0:step-once)
        (model-spec "l1-call-lazy"
                    "L1 Calls (Lazy, No Disjunction)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/fresh" "cap/delay")
                    rr:l1l:step-once)
        (model-spec "l1-call-eager"
                    "L1 Calls (Eager, No Disjunction)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/fresh" "cap/delay")
                    rr:l1e:step-once)
        (model-spec "l2-disj-left"
                    "L2 Disjunction (No RelCall)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/disjunction" "cap/fresh")
                    rr:l2:step-once)
        (model-spec "l4-rail-lazy"
                    "(Interleave + Railroad, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l4rl:step-once)
        (model-spec "l3-dfs-lazy"
                    "(No Interleave, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3dl:step-once)
        (model-spec "l3-flip-lazy"
                    "(Interleave + Flip-Flop, Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3fl:step-once)
        (model-spec "l4-rail-eager"
                    "(Interleave + Railroad, Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l4re:step-once)
        (model-spec "l3-dfs-eager"
                    "(No Interleave, Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3de:step-once)
        (model-spec "l3-flip-eager"
                    "(Interleave + Flip-Flop, Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3fe:step-once)
        (model-spec "l3-base-lazy"
                    "L3 Base (Lazy)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3bl:step-once)
        (model-spec "l3-base-eager"
                    "L3 Base (Eager)"
                    canonical-parser-profile
                    canonical-parser-target-id
                    '("cap/core" "cap/relcall" "cap/disjunction" "cap/fresh" "cap/delay")
                    rr:l3be:step-once)))

(define default-model-id "l4-rail-lazy")

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
          'parserProfile (model-spec-parser-profile spec)
          'parserTarget (model-spec-parser-target spec)
          'capabilities (model-spec-capabilities spec)))
