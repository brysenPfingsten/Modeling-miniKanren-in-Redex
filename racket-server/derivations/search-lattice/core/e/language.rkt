#lang racket

(require redex/reduction-semantics
         "../../../../src/search-lattice/languages/core-lang.rkt")

(provide core-e-lang
         support-append)

(check-redundancy #t)

;; This prototype E forgets binder boundaries and provenance tags.  It replaces
;; S-side Owner positions with a cumulative Support at each corresponding
;; configuration-carrier position.  This support-decorated-node grammar is not
;; the selected state-local E representation.
(define-extended-language core-e-lang
  core-lang
  [support (Support u_!_ ...)]

  [A (Answer support σ)]

  [S (Returned support σ)]

  [W (Work support g σ)
     (Returned support σ)
     (Dead support)
     (Conj support W g)]

  [F (Last support A)
     (Done support)
     (More W)]

  [WorkOwnerSlot (Work hole g σ)
                 (Returned hole σ)
                 (Dead hole)
                 (Conj hole W g)]

  [WorkPath hole
            (Conj support WorkPath g)]

  [SpineContext hole]

  [WorkFocus (in-hole SpineContext (More WorkPath))])

(define-metafunction core-e-lang
  support-append : support support -> support
  [(support-append (Support u_outer ...)
                   (Support u_inner ...))
   (Support u_outer ... u_inner ...)])

(module+ test
  (require rackunit)

  (define sigma
    (term (state () () () (label "state"))))

  (define support-carrier
    (term
     (More
      (Conj (Support u:outer)
            (Returned (Support u:outer u:inner) ,sigma)
            (succeed (label "continue"))))))

  (define owners-carrier
    (term
     (More
      (Conj (Owners (Owner (u:outer) (label "owner")))
            (Returned (Owners) ,sigma)
            (succeed (label "continue"))))))

  (check-true (redex-match? core-e-lang F support-carrier))
  (check-false (redex-match? core-e-lang F owners-carrier))

  ;; Check every owner-bearing core carrier constructor, not merely a sample
  ;; frontier: extending core-lang must not leave an inherited Owners branch.
  (for ([support-work
         (in-list
          (list
           (term
            (Work (Support u:work)
                  (succeed (label "work"))
                  ,sigma))
           (term (Returned (Support u:return) ,sigma))
           (term (Dead (Support u:dead)))
           (term
            (Conj (Support u:conj)
                  (Dead (Support u:conj))
                  (succeed (label "right"))))))]
        [owners-work
         (in-list
          (list
           (term
            (Work (Owners)
                  (succeed (label "work"))
                  ,sigma))
           (term (Returned (Owners) ,sigma))
           (term (Dead (Owners)))
           (term
            (Conj (Owners)
                  (Dead (Support))
                  (succeed (label "right"))))))])
    (check-true (redex-match? core-e-lang W support-work))
    (check-false (redex-match? core-e-lang W owners-work)))

  (check-true
   (redex-match?
    core-e-lang
    A
    (term (Answer (Support u:answer) ,sigma))))
  (check-false
   (redex-match?
    core-e-lang
    A
    (term (Answer (Owners) ,sigma))))
  (check-true
   (redex-match?
    core-e-lang
    F
    (term (Last (Support u:answer)
                (Answer (Support u:answer) ,sigma)))))
  (check-false
   (redex-match?
    core-e-lang
    F
    (term (Last (Owners)
                (Answer (Owners) ,sigma)))))
  (check-true
   (redex-match? core-e-lang F (term (Done (Support u:dead)))))
  (check-false
   (redex-match? core-e-lang F (term (Done (Owners))))))
