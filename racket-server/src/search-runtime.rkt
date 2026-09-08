#lang racket

(require redex/reduction-semantics
         (prefix-in strict: "../derivations/matrix/full-source.rkt")
         (prefix-in scheduler: "../derivations/matrix/scheduler-source.rkt")
         (only-in "../derivations/shared/wf.rkt" wf-s-rel?)
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
(define (source-step-once relation configuration)
  (match (apply-reduction-relation/tag-with-names relation configuration)
    ['() '()]
    [(list successor) (list successor)]
    [successors (error 'source-step-once "nonunique matrix successors: ~e" successors)]))

(define all-strategy-specs
  (cons
   (strategy-spec
    (strict-search)
    (lambda (cfg) (source-step-once strict:strict-s-rel-red cfg))
    (lambda (cfg)
      (redex-match? strict:StrictSRel p cfg))
    wf-s-rel?)
   (for/list ([policy '("dfs" "flip" "rail")]
              [relation (list scheduler:strict-dfs-red scheduler:strict-flip-red scheduler:strict-rail-red)])
     (strategy-spec
      (search-strategy policy)
      (lambda (cfg) (source-step-once relation cfg))
      (lambda (cfg) (scheduler:scheduler-in-domain? policy cfg))
      scheduler:scheduler-well-formed?))))

(define (configuration-status configuration)
  (match configuration
    [`(program ,_ ,_) (scheduler:scheduler-status configuration)]
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
