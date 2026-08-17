#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     syntax/parse))

(provide define-pk-machine-stage)

;; The direct M presentation intentionally repeats the retained-context
;; refocusing equations in M syntax.  It does not call the Z refocuser or a
;; codec; the transported presentation belongs to machine-spec-schema.rkt.
(define-syntax (define-pk-machine-stage stx)
  (syntax-parse stx
    [(_ #:refocused-language refocused-lang:id
        #:machine-language machine-lang:id
        #:contract contract:id
        #:contract-label contract-label:id
        #:label->redex-name label->redex-name:id
        #:encode encode:id
        #:decode decode:id
        #:d->m d->m:id
        #:m->d m->d:id
        #:readback readback:id
        #:refocus-query refocus-query:id
        #:refocus refocus:id
        #:step step:id
        #:steps steps:id
        #:relation relation:id)
     #'(begin
         (define-extended-language machine-lang
           refocused-lang
           [M (MWork BR BF)
              (MWork LFR LF)
              (MWork LR WF)
              (MFrontier T FF)]
           [MQ (MQContract C)
               (MQFrontier F FF)
               (MQWork W WF)]
           [MLabels (ell (... ...))])

         (define-metafunction machine-lang
           encode : Z -> M
           [(encode (ZWork W WF)) (MWork W WF)]
           [(encode (ZFrontier T FF)) (MFrontier T FF)])

         (define-metafunction machine-lang
           decode : M -> Z
           [(decode (MWork W WF)) (ZWork W WF)]
           [(decode (MFrontier T FF)) (ZFrontier T FF)])

         (define-metafunction machine-lang
           d->m : D -> M
           [(d->m (DecWork W WF)) (MWork W WF)]
           [(d->m (DecFrontier T FF)) (MFrontier T FF)])

         (define-metafunction machine-lang
           m->d : M -> D
           [(m->d (MWork W WF)) (DecWork W WF)]
           [(m->d (MFrontier T FF)) (DecFrontier T FF)])

         (define-metafunction machine-lang
           readback : M -> F
           [(readback (MWork W WF)) (in-hole WF W)]
           [(readback (MFrontier T FF)) (in-hole FF T)])

         (define-judgment-form
           machine-lang
           #:contract (refocus-query MQ M)
           #:mode (refocus-query I O)

           [(refocus-query (MQWork W WF) M)
            ------------------------------------------------ "retained work contract"
            (refocus-query
             (MQContract (ContractWork ell W WF))
             M)]

           [(refocus-query (MQFrontier F FF) M)
            ------------------------------------------------ "retained frontier contract"
            (refocus-query
             (MQContract (ContractFrontier ell F FF))
             M)]

           [(refocus-query
             (MQFrontier F (in-hole FF (Emit A hole)))
             M)
            ------------------------------------------------ "through emit"
            (refocus-query (MQFrontier (Emit A F) FF) M)]

           [(refocus-query
             (MQFrontier
              F
              (in-hole FF (FrontierFresh intro hole tag)))
             M)
            ------------------------------------------------ "through frontier fresh"
            (refocus-query
             (MQFrontier (FrontierFresh intro F tag) FF)
             M)]

           [(refocus-query
             (MQFrontier F (in-hole FF (Forced hole)))
             M)
            ------------------------------------------------ "through forced"
            (refocus-query (MQFrontier (Forced F) FF) M)]

           [(refocus-query
             (MQWork W (in-hole FF (More hole)))
             M)
            ------------------------------------------------ "frontier More"
            (refocus-query (MQFrontier (More W) FF) M)]

           [------------------------------------------------ "frontier terminal"
            (refocus-query
             (MQFrontier T FF)
             (MFrontier T FF))]

           [------------------------------------------------ "More boundary"
            (refocus-query
             (MQWork BR BF)
             (MWork BR BF))]

           [------------------------------------------------ "local WorkFresh redex"
            (refocus-query
             (MQWork LFR LF)
             (MWork LFR LF))]

           [------------------------------------------------ "other local redex"
            (refocus-query
             (MQWork LR WF)
             (MWork LR WF))]

           [(refocus-query
             (MQWork NW
                     (in-hole LF
                              (WorkFresh intro hole tag)))
             M)
            ------------------------------------------------ "down through local work fresh"
            (refocus-query
             (MQWork (WorkFresh intro NW tag) LF)
             M)]

           [(refocus-query
             (MQWork NW (in-hole WF (Conj hole g)))
             M)
            ------------------------------------------------ "down through conjunction"
            (refocus-query (MQWork (Conj NW g) WF) M)]

           [(refocus-query
             (MQWork NW (in-hole WF (DisjL hole W)))
             M)
            ------------------------------------------------ "down left choice"
            (refocus-query (MQWork (DisjL NW W) WF) M)]

           [(refocus-query
             (MQWork NW (in-hole WF (DisjR W hole)))
             M)
            ------------------------------------------------ "down right choice"
            (refocus-query (MQWork (DisjR W NW) WF) M)]

           [(refocus-query
             (MQWork (in-hole WFrame R) WF)
             M)
            ------------------------------------------------ "completed work up one frame"
            (refocus-query
             (MQWork R (in-hole WF WFrame))
             M)])

         (define-judgment-form
           machine-lang
           #:contract (refocus C M)
           #:mode (refocus I O)
           [(refocus-query (MQContract C) M)
            ------------------------------------------------ "direct retained-context refocus"
            (refocus C M)])

         (define-judgment-form
           machine-lang
           #:contract (step M ell M)
           #:mode (step I O O)
           [(where D (m->d M_0))
            (contract D C)
            (where ell (contract-label C))
            (refocus C M_1)
            ------------------------------------------------ "direct marked machine step"
            (step M_0 ell M_1)])

         (define-judgment-form
           machine-lang
           #:contract (steps M MLabels M)
           #:mode (steps I O O)
           [------------------------------------------------ "zero marked machine steps"
            (steps M () M)]
           [(step M_0 ell M_1)
            (steps M_1 (ell_rest (... ...)) M_2)
            ------------------------------------------------ "one or more marked machine steps"
            (steps M_0 (ell ell_rest (... ...)) M_2)])

         (define relation
           (reduction-relation
            machine-lang
            #:domain M
            [--> M_0 M_1
                 (judgment-holds (step M_0 ell M_1))
                 (computed-name
                  (term (label->redex-name ell)))])))]))
