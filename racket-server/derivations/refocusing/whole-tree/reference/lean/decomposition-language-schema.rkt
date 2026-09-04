#lang racket

(require redex/reduction-semantics)

(provide define-lean-decomposition-language)

(define-syntax-rule (define-lean-decomposition-language language-id source-language-id)
  (define-extended-language language-id
                            source-language-id
                            [BF (More hole) (Emit A BF) (Forced BF)]
                            [BR (Returned kst) Dead (PendingDelay W) (DisjL S W) (DisjR W S)]
                            [LR
                             (Work g kst)
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
                            [T Done (Last A)]
                            [D (DecWork BR BF) (DecWork LR WF) (DecFrontier T FF)]
                            [C (ContractWork ell W WF) (ContractFrontier ell F FF)]
                            [Labels (ell (... ...))]))
