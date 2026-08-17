#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     syntax/parse))

(provide define-pk-refocused-stage)

;; Redex languages and judgment forms are compile-time bindings, so P[K]
;; stage parameterization is expressed as a definition-producing macro.  The
;; macro mentions only the shared control grammar and the decomposition
;; contract interface; it has no kernel operation or state destructuring
;; parameter.
(define-syntax (define-pk-refocused-stage stx)
  (syntax-parse stx
    [(_ #:decomposition-language decomposition-lang:id
        #:refocused-language refocused-lang:id
        #:contract contract:id
        #:contract-label contract-label:id
        #:label->redex-name label->redex-name:id
        #:d->z d->z:id
        #:z->d z->d:id
        #:readback readback:id
        #:refocus-query refocus-query:id
        #:refocus refocus:id
        #:step step:id
        #:steps steps:id
        #:image image:id
        #:relation relation:id)
     #'(begin
         (define-extended-language refocused-lang
           decomposition-lang
           ;; Z is the exact grammar-indexed image of D.
           [Z (ZWork BR BF)
              (ZWork LFR LF)
              (ZWork LR WF)
              (ZFrontier T FF)]
           ;; Private derivation program points.  Every work query retains one
           ;; complete W-to-F context; there is no reified resume mode.
           [Q (QContract C)
              (QFrontier F FF)
              (QWork W WF)]
           [ZLabels (ell (... ...))])

         (define-metafunction refocused-lang
           d->z : D -> Z
           [(d->z (DecWork W WF)) (ZWork W WF)]
           [(d->z (DecFrontier T FF)) (ZFrontier T FF)])

         (define-metafunction refocused-lang
           z->d : Z -> D
           [(z->d (ZWork W WF)) (DecWork W WF)]
           [(z->d (ZFrontier T FF)) (DecFrontier T FF)])

         (define-metafunction refocused-lang
           readback : Z -> F
           [(readback (ZWork W WF)) (in-hole WF W)]
           [(readback (ZFrontier T FF)) (in-hole FF T)])

         ;; Direct fusion of plugging with root decomposition.  NW is the
         ;; grammar-level complement of completed work; it replaces a dynamic
         ;; non-outcome test.
         (define-judgment-form
           refocused-lang
           #:contract (refocus-query Q Z)
           #:mode (refocus-query I O)

           [(refocus-query (QWork W WF) Z)
            ------------------------------------------------ "retained work contract"
            (refocus-query
             (QContract (ContractWork ell W WF))
             Z)]

           [(refocus-query (QFrontier F FF) Z)
            ------------------------------------------------ "retained frontier contract"
            (refocus-query
             (QContract (ContractFrontier ell F FF))
             Z)]

           [(refocus-query
             (QFrontier F (in-hole FF (Emit A hole)))
             Z)
            ------------------------------------------------ "through emit"
            (refocus-query (QFrontier (Emit A F) FF) Z)]

           [(refocus-query
             (QFrontier
              F
              (in-hole FF (FrontierFresh intro hole tag)))
             Z)
            ------------------------------------------------ "through frontier fresh"
            (refocus-query
             (QFrontier (FrontierFresh intro F tag) FF)
             Z)]

           [(refocus-query
             (QFrontier F (in-hole FF (Forced hole)))
             Z)
            ------------------------------------------------ "through forced"
            (refocus-query (QFrontier (Forced F) FF) Z)]

           [(refocus-query
             (QWork W (in-hole FF (More hole)))
             Z)
            ------------------------------------------------ "frontier More"
            (refocus-query (QFrontier (More W) FF) Z)]

           [------------------------------------------------ "frontier terminal"
            (refocus-query
             (QFrontier T FF)
             (ZFrontier T FF))]

           [------------------------------------------------ "More boundary"
            (refocus-query
             (QWork BR BF)
             (ZWork BR BF))]

           [------------------------------------------------ "local WorkFresh redex"
            (refocus-query
             (QWork LFR LF)
             (ZWork LFR LF))]

           [------------------------------------------------ "other local redex"
            (refocus-query
             (QWork LR WF)
             (ZWork LR WF))]

           [(refocus-query
             (QWork NW
                    (in-hole LF
                             (WorkFresh intro hole tag)))
             Z)
            ------------------------------------------------ "down through local work fresh"
            (refocus-query
             (QWork (WorkFresh intro NW tag) LF)
             Z)]

           [(refocus-query
             (QWork NW (in-hole WF (Conj hole g)))
             Z)
            ------------------------------------------------ "down through conjunction"
            (refocus-query (QWork (Conj NW g) WF) Z)]

           [(refocus-query
             (QWork NW (in-hole WF (DisjL hole W)))
             Z)
            ------------------------------------------------ "down left choice"
            (refocus-query (QWork (DisjL NW W) WF) Z)]

           [(refocus-query
             (QWork NW (in-hole WF (DisjR W hole)))
             Z)
            ------------------------------------------------ "down right choice"
            (refocus-query (QWork (DisjR W NW) WF) Z)]

           [(refocus-query
             (QWork (in-hole WFrame R) WF)
             Z)
            ------------------------------------------------ "completed work up one frame"
            (refocus-query
             (QWork R (in-hole WF WFrame))
             Z)])

         (define-judgment-form
           refocused-lang
           #:contract (refocus C Z)
           #:mode (refocus I O)
           [(refocus-query (QContract C) Z)
            ------------------------------------------------ "direct retained-context refocus"
            (refocus C Z)])

         (define-judgment-form
           refocused-lang
           #:contract (step Z ell Z)
           #:mode (step I O O)
           [(where D (z->d Z_0))
            (contract D C)
            (where ell (contract-label C))
            (refocus C Z_1)
            ------------------------------------------------ "direct refocused step"
            (step Z_0 ell Z_1)])

         (define-judgment-form
           refocused-lang
           #:contract (steps Z ZLabels Z)
           #:mode (steps I O O)
           [------------------------------------------------ "zero refocused steps"
            (steps Z () Z)]
           [(step Z_0 ell Z_1)
            (steps Z_1 (ell_rest (... ...)) Z_2)
            ------------------------------------------------ "one or more refocused steps"
            (steps Z_0 (ell ell_rest (... ...)) Z_2)])

         (define-judgment-form
           refocused-lang
           #:contract (image D Z)
           #:mode (image I O)
           [(where Z (d->z D))
            ------------------------------------------------ "refocused structural image"
            (image D Z)])

         (define relation
           (reduction-relation
            refocused-lang
            #:domain Z
            [--> Z_0 Z_1
                 (judgment-holds (step Z_0 ell Z_1))
                 (computed-name
                  (term (label->redex-name ell)))])))]))
