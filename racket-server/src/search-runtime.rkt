#lang racket

(require redex/reduction-semantics
         (prefix-in strict: "../derivations/strict-search/matrix/full-source.rkt")
         (only-in "../derivations/strict-search/matrix/stages/full.rkt"
                  s-rel-status)
         (only-in "../derivations/strict-search/shared/wf.rkt" wf-s-rel?)
         (prefix-in lang:
                    "./search-lattice/languages/search-relcall-lang.rkt")
         (prefix-in rail-lang:
                    "./search-lattice/languages/rail-relcall-lang.rkt")
         (rename-in "./search-lattice/reduction-relations/search-dfs-relcall-red.rkt"
                    [step-once step-once/search-dfs-relcall])
         (rename-in "./search-lattice/reduction-relations/search-flip-relcall-red.rkt"
                    [step-once step-once/search-flip-relcall])
         (rename-in "./search-lattice/reduction-relations/rail-relcall-red.rkt"
                    [step-once step-once/rail-relcall])
         (prefix-in wf:
                    "./search-lattice/wf/search-relcall-wf.rkt")
         (prefix-in rail-wf:
                    "./search-lattice/wf/rail-relcall-wf.rkt")
         "search-strategy.rkt")

(provide (struct-out strategy-spec)
         all-strategy-specs
         lookup-strategy-spec
         lookup-search-step-once
         search-config-in-domain?
         search-config-well-formed?
         check-search-config
         configuration-status
         advance-configuration)

(struct strategy-spec (strategy step-once in-domain? well-formed?) #:transparent)

(define/match (strategy-key strategy)
  [((strict-search)) 'strict]
  [((search-strategy scheduler))
   scheduler])

;; This is the matrix relation itself: no copied control rules or lowering to
;; the old work tree. A step remains bounded even for an unguarded self-call.
(define (strict-step-once configuration)
  (match (apply-reduction-relation/tag-with-names strict:strict-s-rel-red configuration)
    ['() '()]
    [(list successor) (list successor)]
    [successors (error 'strict-step-once "nonunique matrix successors: ~e" successors)]))

(define all-strategy-specs
  (list
   (strategy-spec
    (strict-search)
    strict-step-once
    (lambda (cfg)
      (redex-match? strict:StrictSRel p cfg))
    wf-s-rel?)
   (strategy-spec
    (search-strategy "dfs")
    step-once/search-dfs-relcall
    (lambda (cfg)
      (redex-match? lang:search-relcall-lang config cfg))
    (lambda (cfg)
      (judgment-holds (wf:wf-config/search-relcall? ,cfg))))
   (strategy-spec
    (search-strategy "flip")
    step-once/search-flip-relcall
    (lambda (cfg)
      (redex-match? lang:search-relcall-lang config cfg))
    (lambda (cfg)
      (judgment-holds (wf:wf-config/search-relcall? ,cfg))))
   (strategy-spec
    (search-strategy "rail")
    step-once/rail-relcall
    (lambda (cfg)
      (redex-match? rail-lang:rail-relcall-lang config cfg))
    (lambda (cfg)
      (judgment-holds (rail-wf:wf-config/rail-relcall? ,cfg))))))

;; Read the exposed phase without reducing a goal or replaying the kernel.
;; Nested delays still need their scheduler/bubbling reductions; a delay at
;; the outer Frontier tip is the lattice's public forcing boundary.
(define (lattice-work-status work definitions)
  (match work
    [(or `(Conj ,_ ,active ,_)
         `(DisjL ,_ ,active ,_)
         `(DisjR ,_ ,_ ,active))
     (lattice-work-status active definitions)]
    [`(Work ,_ (,name ,arguments ... ,_) ,_)
     #:when (redex-match? rail-lang:rail-relcall-lang r name)
     (match (assoc name definitions)
       [(list _ formals _) (if (= (length formals) (length arguments)) 'running 'stuck)]
       [#f 'stuck])]
    [_ 'running]))

(define (lattice-frontier-status frontier definitions)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) 'complete]
    [(or `(Emit ,_ ,_ ,tail) `(Forced ,_ ,tail))
     (lattice-frontier-status tail definitions)]
    [`(More (PendingDelay ,_ ,_)) 'paused]
    [`(More ,work) (lattice-work-status work definitions)]))

(define (configuration-status configuration)
  (match configuration
    [`(program ,_ ,_) (s-rel-status configuration)]
    [`(,definitions ,frontier)
     #:when (redex-match? rail-lang:rail-relcall-lang config configuration)
     (lattice-frontier-status frontier definitions)]
    [_ 'stuck]))

;; Public invocation is distinct from an R contraction. Session history keeps
;; this explicit advance term before stepping its named source rules.
(define (advance-configuration configuration)
  (match configuration
    [`(program ,definitions ,frontier)
     #:when (eq? (configuration-status configuration) 'paused)
     `(program ,definitions (advance ,frontier))]
    [_ (raise-argument-error 'advance-configuration "paused strict matrix Frontier" configuration)]))

(define spec-by-key
  (for/hash ([spec (in-list all-strategy-specs)])
    (match-define (strategy-spec strategy _ _ _) spec)
    (values (strategy-key strategy)
            spec)))

(define (lookup-strategy-spec strategy)
  (define normalized (normalize-search-strategy strategy))
  (hash-ref spec-by-key
            (strategy-key normalized)
            (lambda ()
              (error 'lookup-strategy-spec
                     "unsupported search strategy ~e"
                     normalized))))

(define (lookup-search-step-once strategy)
  (match-define (strategy-spec _ step-once _ _) (lookup-strategy-spec strategy))
  step-once)

(define (search-config-in-domain? strategy cfg)
  ((strategy-spec-in-domain? (lookup-strategy-spec strategy))
   cfg))

(define (search-config-well-formed? strategy cfg)
  ((strategy-spec-well-formed? (lookup-strategy-spec strategy))
   cfg))

(define (check-search-config strategy cfg)
  (match-define (strategy-spec normalized _ in-domain? well-formed?)
    (lookup-strategy-spec strategy))
  (unless (in-domain? cfg)
    (error 'check-search-config
           "program is outside the internal search target for strategy ~e"
           (search-strategy->jsexpr normalized)))
  (unless (well-formed? cfg)
    (error 'check-search-config
           "program failed internal search wf check for strategy ~e"
           (search-strategy->jsexpr normalized))))
