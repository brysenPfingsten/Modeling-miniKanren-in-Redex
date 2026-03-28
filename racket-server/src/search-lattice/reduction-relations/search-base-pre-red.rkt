#lang racket

(require redex/reduction-semantics
         (only-in "./core-red.rkt"
                  extend-core-redex)
         (only-in "./delay-red.rkt"
                  delay-local/base
                  delay-frontier/base))

(provide search-base-seq-pre-red
         search-base-fused-pre-red)

(check-redundancy #t)

(define-syntax-rule (define-search-base-pre pre-name lang)
  (define pre-name
    (let ()
      (define core-base
        (extend-core-redex lang))
      (define core-local
        (context-closure core-base lang KWork))
      (define core-search
        (context-closure core-local lang KBranch))
      (define search-base-core
        (context-closure core-search lang QSpine))

      (define lifted-delay-local/base
        (extend-reduction-relation delay-local/base lang))
      (define delay-local
        (context-closure lifted-delay-local/base lang KBranch))
      (define delay-local/under-QSpine
        (context-closure delay-local lang QSpine))
      (define delay-frontier
        (extend-reduction-relation delay-frontier/base lang))

      (define goal-local/base
        (reduction-relation
         lang
         #:domain cfg
         [--> (in-hole KBranch (in-hole KWork ((g_1 ∨ g_2 tag) σ)))
              (in-hole KBranch (in-hole KWork ((g_1 σ) <-+ (g_2 σ))))
              "search-base/goal-to-tree"]))
      (define goal-local/under-QSpine
        (context-closure goal-local/base lang QSpine))

      (define branch-frontier
        (reduction-relation
         lang
         #:domain cfg
         [--> (in-hole QFront cfg_i)
              (in-hole QFront cfg_o)
              (where (name cfg_o cfg)
                     ,(or (bubble-left-answer-host (term cfg_i))
                          'no-frontier-rewrite))
              "search-base/bubble-left-answer"]
         [--> (in-hole QFront cfg_i)
              (in-hole QFront cfg_o)
              (where (name cfg_o cfg)
                     ,(or (promote-left-answer-host (term cfg_i))
                          'no-frontier-rewrite))
              "search-base/promote-left-answer"]
         [--> (in-hole QFront cfg_i)
              (in-hole QFront cfg_o)
              (where (name cfg_o cfg)
                     ,(or (bubble-left-fail-host (term cfg_i))
                          'no-frontier-rewrite))
              "search-base/bubble-left-fail"]
         [--> (in-hole QFront cfg_i)
              (in-hole QFront cfg_o)
              (where (name cfg_o cfg)
                     ,(or (skip-left-fail-host (term cfg_i))
                          'no-frontier-rewrite))
              "search-base/skip-left-fail"]))

      (union-reduction-relations
       search-base-core
       delay-local/under-QSpine
       delay-frontier
       goal-local/under-QSpine
       branch-frontier))))

(require "./private/common.rkt"
         "../languages/search-base-seq-lang.rkt"
         "../languages/search-base-fused-lang.rkt")

(define-search-base-pre search-base-seq-pre-red search-base-seq-lang)
(define-search-base-pre search-base-fused-pre-red search-base-fused-lang)
