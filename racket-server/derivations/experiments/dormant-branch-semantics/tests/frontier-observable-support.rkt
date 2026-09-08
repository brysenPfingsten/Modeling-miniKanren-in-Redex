#lang racket

(require redex/reduction-semantics
         "../source/structural-observations.rkt"
         (prefix-in lang: "../source/languages/all.rkt")
         (prefix-in wf: "../source/wf/all.rkt"))

(provide (all-from-out
          "../source/structural-observations.rkt")
         structurally-well-formed?
         visible-json-wf?
         visible-json-trace-wf?
         trace-deterministic)

;; Test support accepts either ordinary search or rail syntax, with or without
;; relcall. This is intentionally broader than any one production strategy
;; domain, because crosscutting trace laws inspect all surfaced fibers. Every
;; branch first proves membership in its exact grammar root; no untyped
;; fallback acceptance is involved.
(define (structurally-well-formed? datum)
  (match datum
    [(list (? list?) _frontier)
     (or (and (redex-match? lang:search-relcall-lang config datum)
              (judgment-holds
               (wf:wf-config/search-relcall? ,datum)))
         (and (redex-match? lang:rail-relcall-lang config datum)
              (judgment-holds
               (wf:wf-config/rail-relcall? ,datum))))]
    [_
     (or (and (redex-match? lang:search-lang F datum)
              (judgment-holds
               (wf:wf-cfg/search? ,datum)))
         (and (redex-match? lang:rail-lang F datum)
              (judgment-holds
               (wf:wf-cfg/rail? ,datum))))]))

(define (trace-deterministic rel cfg [step-cap 64])
  (define next*
    (remove-duplicates
     (apply-reduction-relation/tag-with-names rel cfg)))
  (match next*
    ['()
     (values '() cfg 'done)]
    [_ #:when (zero? step-cap)
       (values '() cfg 'cap)]
    [(list (list name cfg1))
     (define-values (steps cfg^ status)
       (trace-deterministic rel cfg1 (sub1 step-cap)))
     (values (cons (~a name) steps)
             cfg^
             status)]
    [_ (values '() cfg 'nondeterministic)]))

(define (valid-child-indexes? node)
  (match node
    [(hash* ['children children] #:open)
     (and
      (match (hash-ref node 'activeChildIndex #f)
        [#f #t]
        [(? exact-nonnegative-integer? idx)
         (< idx (length children))]
        [_ #f])
      (match (hash-ref node 'resolvedChildIndices #f)
        [#f #t]
        [(list idxs ...)
         (for/and ([idx (in-list idxs)])
           (and (exact-nonnegative-integer? idx)
                (< idx (length children))))]
        [_ #f]))]
    [_ #t]))

(define (visible-answer-node? node)
  (match node
    [(hash* ['name "Answer"]
            ['renderRole "answer-node"]
            ['nodeColor "green"]
            #:open)
     #t]
    [(hash* ['name "Freshened"]
            ['renderRole "freshened"]
            ['children (list child)]
            #:open)
     (visible-answer-node? child)]
    [_ #f]))

(define (visible-search-tree? node)
  (match node
    [(hash* ['name "Empty"]
            ['renderRole "terminal"]
            #:open)
     #t]
    [(hash* ['name "Succeed"]
            ['renderRole "terminal"]
            #:open)
     #t]
    [(hash* ['name "Fail"]
            ['renderRole "terminal"]
            #:open)
     #t]
    [(hash* ['name "Unify"]
            ['renderRole "goal-leaf"]
            #:open)
     #t]
    [(hash* ['name "Disequality"]
            ['renderRole "goal-leaf"]
            #:open)
     #t]
    [(hash* ['name "Rel-Call"]
            ['renderRole "goal-leaf"]
            #:open)
     #t]
    [(hash* ['name "Fresh"]
            ['renderRole "goal-fresh"]
            ['activeChildIndex 0]
            ['children (list child)]
            #:open)
     (visible-search-tree? child)]
    [(hash* ['name "Goal-Delay"]
            ['renderRole "delay"]
            ['activeChildIndex 0]
            ['children (list child)]
            #:open)
     (visible-search-tree? child)]
    [(hash* ['name "Goal-Conj"]
            ['renderRole "goal-branch"]
            ['focusColor "blue"]
            ['activeChildIndex 0]
            ['children (list left right)]
            #:open)
     (and (visible-search-tree? left)
          (visible-search-tree? right))]
    [(hash* ['name "Goal-Disj"]
            ['renderRole "goal-branch"]
            ['focusColor "#ff8000"]
            ['activeChildIndex 0]
            ['children (list left right)]
            #:open)
     (and (visible-search-tree? left)
          (visible-search-tree? right))]
    [(hash* ['name "Conjunction"]
            ['renderRole "search-conjunction"]
            ['focusColor "blue"]
            ['activeChildIndex 0]
            ['children (list left right)]
            #:open)
     (and (visible-root? left)
          (visible-search-tree? right))]
    [(hash* ['name "Freshened"]
            ['renderRole "freshened"]
            ['activeChildIndex 0]
            ['children (list child)]
            #:open)
     (visible-root? child)]
    [(hash* ['name "Deferred"]
            ['renderRole "forced"]
            ['activeChildIndex 0]
            ['children (list child)]
            #:open)
     (visible-root? child)]
    [(hash* ['name "Emit"]
            ['renderRole "stream-emit"]
            ['children (list left right)]
            #:open)
     (and (visible-root? left)
          (visible-root? right))]
    [(hash* ['name "Delay"]
            ['renderRole "delay"]
            ['activeChildIndex 0]
            ['children (list child)]
            #:open)
     (visible-root? child)]
    [(hash* ['name "<-+"]
            ['renderRole "search-branch"]
            ['focusColor "#ff8000"]
            ['activeChildIndex 0]
            ['children (list left right)]
            #:open)
     (and (visible-root? left)
          (visible-root? right))]
    [(hash* ['name "+->"]
            ['renderRole "search-branch"]
            ['focusColor "#ff8000"]
            ['activeChildIndex 1]
            ['children (list left right)]
            #:open)
     (and (visible-root? left)
          (visible-root? right))]
    [_ #f]))

(define (visible-stream? node)
  (match node
    [(hash* ['name "Empty"]
            ['renderRole "terminal"]
            #:open)
     #t]
    [(hash* ['name "Emit"]
            ['renderRole "stream-emit"]
            ['children (list left right)]
            #:open)
     (and (visible-root? left)
          (visible-root? right))]
    [(hash* ['name "Deferred"]
            ['renderRole "forced"]
            ['children (list child)]
            #:open)
     (visible-root? child)]
    [(hash* ['name "Freshened"]
            ['renderRole "freshened"]
            ['children (list child)]
            #:open)
     (visible-root? child)]
    [_ #f]))

(define (visible-root? node)
  (and (hash? node)
       (valid-child-indexes? node)
       (or (visible-stream? node)
           (visible-answer-node? node)
           (visible-search-tree? node))))

(define (visible-json-wf? node)
  (visible-root? node))

(define (visible-json-trace-wf? nodes)
  (for/and ([node (in-list nodes)])
    (visible-json-wf? node)))
