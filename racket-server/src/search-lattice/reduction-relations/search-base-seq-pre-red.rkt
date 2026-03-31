#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         "./search-base-pre-red.rkt")

(provide search-base-seq-pre-red)

(check-redundancy #t)

(define lifted-search-base-core-local/base
  (extend-reduction-relation search-base-core-local/base search-base-seq-lang))

(define lifted-search-base-goal-local/base
  (extend-reduction-relation search-base-goal-local/base search-base-seq-lang))

(define lifted-search-base-frontier/local-base
  (extend-reduction-relation search-base-frontier/local-base search-base-seq-lang))

(define lifted-search-base-delay-local/base
  (extend-reduction-relation search-base-delay-local/base search-base-seq-lang))

(define lifted-search-base-delay-frontier/base
  (extend-reduction-relation search-base-delay-frontier/base search-base-seq-lang))

(define search-base-core-local/under-branch
  (context-closure lifted-search-base-core-local/base search-base-seq-lang KBranch))

(define search-base-goal-local/under-branch
  (context-closure lifted-search-base-goal-local/base search-base-seq-lang KBranch))

(define search-base-delay-local/under-branch
  (context-closure lifted-search-base-delay-local/base search-base-seq-lang KBranch))

(define search-base-seq-base-core
  (context-closure search-base-core-local/under-branch search-base-seq-lang QShell))

(define search-base-goal-local/under-QShell
  (context-closure search-base-goal-local/under-branch search-base-seq-lang QShell))

(define search-base-delay-local/under-QShell
  (context-closure search-base-delay-local/under-branch search-base-seq-lang QShell))

(define search-base-frontier/under-QShell
  (context-closure lifted-search-base-frontier/local-base search-base-seq-lang QShell))

(define search-base-seq-pre-red
  (union-reduction-relations
   search-base-seq-base-core
   search-base-delay-local/under-QShell
   lifted-search-base-delay-frontier/base
   search-base-goal-local/under-QShell
   search-base-frontier/under-QShell))
