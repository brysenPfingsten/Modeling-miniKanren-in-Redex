#lang racket

(require racket/match
         redex/reduction-semantics
         "search-strategy.rkt"
         (prefix-in lang: "./search-lattice/languages/all.rkt")
         (prefix-in wf: "./search-lattice/wf/all.rkt")
         (rename-in "./search-lattice/reduction-relations/search-dfs-seq-calls-red.rkt"
                    [step-once step-once/search-dfs-seq-calls])
         (rename-in "./search-lattice/reduction-relations/search-dfs-fused-calls-red.rkt"
                    [step-once step-once/search-dfs-fused-calls])
         (rename-in "./search-lattice/reduction-relations/search-flip-seq-calls-red.rkt"
                    [step-once step-once/search-flip-seq-calls])
         (rename-in "./search-lattice/reduction-relations/search-flip-fused-calls-red.rkt"
                    [step-once step-once/search-flip-fused-calls])
         (rename-in "./search-lattice/reduction-relations/rail-seq-calls-red.rkt"
                    [step-once step-once/rail-seq-calls])
         (rename-in "./search-lattice/reduction-relations/rail-fused-calls-red.rkt"
                    [step-once step-once/rail-fused-calls]))

(provide canonical-flat->calls-config
         calls-config->canonical-flat
         lookup-search-step-once
         search-config-in-domain?
         search-config-well-formed?
         check-search-config)

(define (canonical-flat->calls-config cfg)
  (match cfg
    [`(,Γ ,s ,as) `(,Γ (,s ,as))]
    [_ (error 'canonical-flat->calls-config
              "expected flat canonical config '(Γ s as), got ~e"
              cfg)]))

(define (calls-config->canonical-flat cfg)
  (match cfg
    [`(,Γ (,s ,as)) `(,Γ ,s ,as)]
    [_ (error 'calls-config->canonical-flat
              "expected internal calls config '(Γ (s as)), got ~e"
              cfg)]))

(define (lookup-internal-step-once strategy)
  (match strategy
    [(search-strategy "early" "dfs") step-once/search-dfs-seq-calls]
    [(search-strategy "late" "dfs") step-once/search-dfs-fused-calls]
    [(search-strategy "early" "flip") step-once/search-flip-seq-calls]
    [(search-strategy "late" "flip") step-once/search-flip-fused-calls]
    [(search-strategy "early" "rail") step-once/rail-seq-calls]
    [(search-strategy "late" "rail") step-once/rail-fused-calls]
    [_ (error 'lookup-internal-step-once
              "unsupported search strategy ~e"
              strategy)]))

(define (lookup-search-step-once strategy)
  (define normalized (normalize-search-strategy strategy))
  (define step-internal (lookup-internal-step-once normalized))
  (lambda (cfg)
    (define next*
      (step-internal (canonical-flat->calls-config cfg)))
    (match next*
      ['() '()]
      [(list (list name cfg^))
       (list (list name (calls-config->canonical-flat cfg^)))]
      [_ (error 'lookup-search-step-once
                "unexpected successor set for ~e under ~e: ~e"
                cfg
                normalized
                next*)])))

(define (search-config-in-domain? strategy cfg)
  (define normalized (normalize-search-strategy strategy))
  (define calls-cfg (canonical-flat->calls-config cfg))
  (match normalized
    [(search-strategy "early" "rail")
     (redex-match? lang:rail-seq-calls-lang config calls-cfg)]
    [(search-strategy "late" "rail")
     (redex-match? lang:rail-fused-calls-lang config calls-cfg)]
    [(search-strategy "early" _)
     (redex-match? lang:search-base-seq-calls-lang config calls-cfg)]
    [(search-strategy "late" _)
     (redex-match? lang:search-base-fused-calls-lang config calls-cfg)]
    [_ #f]))

(define (search-config-well-formed? strategy cfg)
  (define normalized (normalize-search-strategy strategy))
  (define calls-cfg (canonical-flat->calls-config cfg))
  (match normalized
    [(search-strategy _ "rail")
     (judgment-holds (wf:wf-config/rail-calls? ,calls-cfg))]
    [(search-strategy _ _)
     (judgment-holds (wf:wf-config/search-base-calls? ,calls-cfg))]
    [_ #f]))

(define (check-search-config strategy cfg)
  (define normalized (normalize-search-strategy strategy))
  (unless (search-config-in-domain? normalized cfg)
    (error 'check-search-config
           "program is outside the internal search target for strategy ~e"
           (search-strategy->jsexpr normalized)))
  (unless (search-config-well-formed? normalized cfg)
    (error 'check-search-config
           "program failed internal search wf check for strategy ~e"
           (search-strategy->jsexpr normalized))))
