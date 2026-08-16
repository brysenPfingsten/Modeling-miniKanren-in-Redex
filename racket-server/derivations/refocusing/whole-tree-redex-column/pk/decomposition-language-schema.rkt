#lang racket

(require redex/reduction-semantics)

(provide define-pk-decomposition-language)

(define-syntax-rule
  (define-pk-decomposition-language language-id source-language-id)
  (define-extended-language language-id
    source-language-id
    [BR (WorkFresh intro W tag)
        (Returned kst)
        Dead
        (PendingDelay W)
        (DisjL S W)
        (DisjR W S)]
    [LFR (WorkFresh intro SC tag)
         (WorkFresh intro Dead tag)
         (WorkFresh intro (PendingDelay W) tag)]
    [LR (Work g kst)
        (Conj S g)
        (Conj Dead g)
        (Conj (PendingDelay W) g)
        (Conj SC g)
        (DisjL Dead W)
        (DisjL (PendingDelay W) W)
        (DisjL SC W)
        (DisjR W Dead)
        (DisjR W (PendingDelay W))
        (DisjR W SC)]
    [D (DecWork BR BF)
       (DecWork LFR LF)
       (DecWork LR WF)
       (DecFrontier T FF)]
    [C (ContractWork ell W WF)
       (ContractFrontier ell F FF)]
    [Labels (ell (... ...))]))
