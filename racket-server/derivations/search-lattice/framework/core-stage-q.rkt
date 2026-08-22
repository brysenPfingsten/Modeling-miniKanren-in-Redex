#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     racket/syntax
                     syntax/parse))

(provide define-core-stage-Q-maps)

;; Emit the direct structural representation maps for one directed edge of the
;; core representation matrix.  The source and target stage artifacts remain
;; ordinary statically named Redex objects; this macro only builds theorem-side
;; host functions over their public carrier syntax.
(define-syntax (define-core-stage-Q-maps stx)
  (syntax-parse stx
    [(_ #:Q-R Q-R:id
        #:Q-focus Q-focus:id
        #:Q-C Q-C:id
        #:Q-D Q-D:id
        #:Q-D/transport Q-D/transport:id
        #:Q-Z Q-Z:id
        #:Q-Z/transport Q-Z/transport:id
        #:Q-M Q-M:id
        #:Q-M/transport Q-M/transport:id
        #:Q-B Q-B:id
        #:Q-B/transport Q-B/transport:id
        #:Q-Big Q-Big:id
        #:source-plug-D source-plug-D:id
        #:target-decompose target-decompose:id
        #:source-Z->D source-Z->D:id
        #:target-D->Z target-D->Z:id
        #:source-decode-MZ source-decode-MZ:id
        #:target-encode-ZM target-encode-ZM:id
        #:source-decode-BM source-decode-BM:id
        #:target-encode-MB target-encode-MB:id)
     (with-syntax ([D-result
                    (datum->syntax #'target-decompose 'D_result)]
                   [(map-focused map-root-spine)
                    (generate-temporaries
                     '(map-focused map-root-spine))])
       #'(begin
           (define (map-focused who focused focus)
             (match (Q-focus focused focus)
               [(list target-focused target-focus)
                (values target-focused target-focus)]
               [other
                (error who
                       "focused representation map returned ~e, expected a two-element list"
                       other)]))

           (define (map-root-spine who frontier spine)
             ;; Every selected core row has the closed root spine `hole`.  A
             ;; feature schema with a nontrivial spine must supply its own
             ;; structural spine view rather than silently using this core map.
             ;; Preserve the grammatical input hole itself: Redex holes are
             ;; opaque values, and independently expanded languages need not
             ;; share object identity for separately constructed holes.
             (values (Q-R frontier) spine))

           (define (Q-C contractum)
             (match contractum
               [`(ContractWork ,label ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-C focused focus))
                `(ContractWork
                  ,label
                  ,target-focused
                  ,target-focus)]
               [`(ContractFrontier ,label ,frontier ,spine)
                (define-values (target-frontier target-spine)
                  (map-root-spine 'Q-C frontier spine))
                `(ContractFrontier
                  ,label
                  ,target-frontier
                  ,target-spine)]
               [other
                (error 'Q-C
                       "expected a core contractum, received ~e"
                       other)]))

           (define (Q-D decomposition)
             (match decomposition
               [`(Final ,terminal)
                `(Final ,(Q-R terminal))]
               [`(DecWork ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-D focused focus))
                `(DecWork ,target-focused ,target-focus)]
               [`(DecFrontier ,frontier ,spine)
                (define-values (target-frontier target-spine)
                  (map-root-spine 'Q-D frontier spine))
                `(DecFrontier ,target-frontier ,target-spine)]
               [`(DecAllocate ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-D focused focus))
                `(DecAllocate ,target-focused ,target-focus)]
               [other
                (error 'Q-D
                       "expected a core D carrier, received ~e"
                       other)]))

           (define (Q-D/transport decomposition)
             (define source-frontier
               (term (source-plug-D ,decomposition)))
             (define target-frontier (Q-R source-frontier))
             (define derivations
               (build-derivations
                (target-decompose ,target-frontier D-result)))
             (match derivations
               [(list derivation)
                (last (derivation-term derivation))]
               [_
                (error 'Q-D/transport
                       "target decomposition produced ~a raw results for ~e"
                       (length derivations)
                       target-frontier)]))

           (define (Q-Z refocused)
             (match refocused
               [`(ZFinal ,terminal)
                `(ZFinal ,(Q-R terminal))]
               [`(ZWork ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-Z focused focus))
                `(ZWork ,target-focused ,target-focus)]
               [`(ZFrontier ,frontier ,spine)
                (define-values (target-frontier target-spine)
                  (map-root-spine 'Q-Z frontier spine))
                `(ZFrontier ,target-frontier ,target-spine)]
               [`(ZAllocate ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-Z focused focus))
                `(ZAllocate ,target-focused ,target-focus)]
               [other
                (error 'Q-Z
                       "expected a core Z carrier, received ~e"
                       other)]))

           (define (Q-Z/transport refocused)
             (define source-D
               (term (source-Z->D ,refocused)))
             (define target-D (Q-D source-D))
             (term (target-D->Z ,target-D)))

           (define (Q-M machine)
             (match machine
               [`(MFinal ,terminal)
                `(MFinal ,(Q-R terminal))]
               [`(MWork ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-M focused focus))
                `(MWork ,target-focused ,target-focus)]
               [`(MFrontier ,frontier ,spine)
                (define-values (target-frontier target-spine)
                  (map-root-spine 'Q-M frontier spine))
                `(MFrontier ,target-frontier ,target-spine)]
               [`(MAllocate ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-M focused focus))
                `(MAllocate ,target-focused ,target-focus)]
               [other
                (error 'Q-M
                       "expected a core M carrier, received ~e"
                       other)]))

           (define (Q-M/transport machine)
             (define source-Z
               (term (source-decode-MZ ,machine)))
             (define target-Z (Q-Z source-Z))
             (term (target-encode-ZM ,target-Z)))

           (define (Q-B compressed)
             (match compressed
               [`(BFinal ,terminal)
                `(BFinal ,(Q-R terminal))]
               [`(BRun ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-B focused focus))
                `(BRun ,target-focused ,target-focus)]
               [`(BSettled ,focused ,focus)
                (define-values (target-focused target-focus)
                  (map-focused 'Q-B focused focus))
                `(BSettled ,target-focused ,target-focus)]
               [`(BDead ,summary ,focus)
                (define-values (target-dead target-focus)
                  (map-focused 'Q-B `(Dead ,summary) focus))
                (match target-dead
                  [`(Dead ,target-summary)
                   `(BDead ,target-summary ,target-focus)]
                  [other
                   (error 'Q-B
                          "focused map rebuilt a non-dead target ~e"
                          other)])]
               [other
                (error 'Q-B
                       "expected a core B carrier, received ~e"
                       other)]))

           (define (Q-B/transport compressed)
             (define source-M
               (term (source-decode-BM ,compressed)))
             (define target-M (Q-M source-M))
             (term (target-encode-MB ,target-M)))

           (define (Q-Big big)
             (match big
               [`(BigFinal ,terminal)
                `(BigFinal ,(Q-R terminal))]
               [other
                (error 'Q-Big
                       "expected a core Big carrier, received ~e"
                       other)]))))]))
