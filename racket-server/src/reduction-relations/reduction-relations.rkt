#lang racket
(require redex
         redex/reduction-semantics
         redex/pict)
(check-redundancy #t)

(provide red step-once red-tree)
(require "../definitions.rkt" "../judgment-forms.rkt")

(module+ test
  (require rackunit))

;; Term -> [Listof [List String Term]]
(define (step-once prog)
  (apply-reduction-relation/tag-with-names red (term ,prog)))

(define red
  (reduction-relation Core
                      #:domain (side-condition (name prog config) (judgment-holds (wf-program? prog)))
                      #:codomain (side-condition (name prog-out config) (judgment-holds (wf-program? prog-out)))

                      [--> (Γ (σ ...) (⊤ σ_new))
                           (Γ (σ ... σ_new) (empty-tree))]))


(define step-tree
  (reduction-relation Core
                      #:domain s
                      #:codomain s

                      [--> ((g_1 ∧ g_2 _) σ)
                           ((g_1 σ) × g_2)
                           "Distribute State Over Conjunction"]

                      [--> ((⊤ σ) × g)
                           (g σ)
                           "Bring Success State To Second Conjunct"]

                      [--> ((empty-tree) × g)
                           (empty-tree)
                           "Prune Failed Conjuncts"]

                      [--> ((∃ (x ...) g _) (state sub c trail o))
                           ((substitute g c^) (state sub (,@(term c^) ,@(term c))  trail o))
                           (where c^ (fresh-lvars (x ...) c))
                           "Substitute Fresh Variables"]

                      [--> ((t_1 =? t_2 tag) (state sub c ((t_3 =? t_4 tag_1) ...) tag_2))
                           (⊤ (state sub_1 c ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag)) tag_2))
                           (where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
                           "Unification Succeeds"]

                      [--> ((t_1 =? t_2 _) (state sub _ _ _))
                           (empty-tree)
                           (where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
                            "Unification Fails"]
                      ))

(define red-tree (compatible-closure step-tree Core s))

(module+ test

  (check-true (redex-match? Core σ (term (state () () () (label "cat")))))
  (check-true (redex-match? Core g (term ((succeed) ∧ (succeed) (label "horse")))))
  (check-true (redex-match? Core s (term (((succeed) ∧ (succeed) (label "horse")) (state () () () (label "cat"))))))

  (define trivial-conjunction-tree
    (term (((succeed) ∧ (succeed) (label "horse")) (state () () () (label "cat")))))

  (check-equal?
   (apply-reduction-relation red-tree trivial-conjunction-tree)
   (list (term (((succeed) (state () () () (label "cat"))) × (succeed)))))

  (define (red-tree-closed-under-s? st)
    (match-let ([(list st^) (apply-reduction-relation red-tree st)])
      (redex-match? Core s st^)))

  (check-reduction-relation red-tree red-tree-closed-under-s?)

  )
