#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/languages/core-lang.rkt"
                  invalid?
                  unify
                  walk)
         (only-in "../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "../../framework/decomposition-instance.rkt"
         "./language.rkt")

(provide core-e-decomposition-lang
         plug-D/e
         plug-C/e
         contract-label/e
         decompose/e
         contract/e
         decomposed-step/e)

(check-redundancy #t)

(define-decomposition-instance
  #:source-language core-e-lang
  #:decomposition-language core-e-decomposition-lang
  #:work W
  #:frontier F
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:rule-names
  (expand-conjunction
   succeed
   fail
   conj-return
   conj-fail
   allocate-fresh
   unify-success
   unify-violates-disequality
   unify-fail
   disequality-success
   disequality-fail
   finish-success
   finish-failure)
  #:work-redexes
  ((Work support (g ∧ g tag) σ)
   (Work support (succeed tag) σ)
   (Work support (fail tag) σ)
   (Conj support (Returned support σ) g)
   (Conj support (Dead support) g)
   (Work support (t =? t tag) σ)
   (Work support (t != t tag) σ))
  #:frontier-redexes
  ((More (Returned support σ))
   (More (Dead support)))
  #:allocation-redexes
  ((Work support (∃ d g tag) σ))
  #:terminals
  ((Last support A)
   (Done support))
  #:plug-D plug-D/e
  #:plug-C plug-C/e
  #:contract-label contract-label/e
  #:decompose decompose/e)

;; The 13 contractions are independent statements of the E semantics.  They
;; share only the pure miniKanren kernel algebra with R[E]; no source relation
;; or common contractum table is imported here.
(define-judgment-form
  core-e-decomposition-lang
  #:contract (contract/e D C)
  #:mode (contract/e I O)

  [---------------------------------------------------- "contract expand conjunction/e"
   (contract/e
    (DecWork
     (Work support (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
     WorkFocus)
    (ContractWork
     expand-conjunction
     (Conj support
           (Work support g_1 (state sub dis trail tag_1))
           g_2)
     WorkFocus))]

  [---------------------------------------------------- "contract succeed/e"
   (contract/e
    (DecWork (Work support (succeed tag) σ) WorkFocus)
    (ContractWork succeed (Returned support σ) WorkFocus))]

  [---------------------------------------------------- "contract fail/e"
   (contract/e
    (DecWork (Work support (fail tag) σ) WorkFocus)
    (ContractWork fail (Dead support) WorkFocus))]

  [---------------------------------------------------- "contract conjunction return/e"
   (contract/e
    (DecWork
     (Conj support_outer (Returned support_inner σ) g)
     WorkFocus)
    (ContractWork
     conj-return
     (Work support_inner g σ)
     WorkFocus))]

  [---------------------------------------------------- "contract conjunction failure/e"
   (contract/e
    (DecWork
     (Conj support_outer (Dead support_inner) g)
     WorkFocus)
    (ContractWork
     conj-fail
     (Dead support_inner)
     WorkFocus))]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #f (invalid? sub_1 dis))
   ---------------------------------------------------- "contract unification success/e"
   (contract/e
    (DecWork
     (Work support
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    (ContractWork
     unify-success
     (Returned
      support
      (state sub_1
             dis
             ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
             tag_2))
     WorkFocus))]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #t (invalid? sub_1 dis))
   ---------------------------------------------------- "contract unification violates disequality/e"
   (contract/e
    (DecWork
     (Work support
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    (ContractWork
     unify-violates-disequality
     (Dead support)
     WorkFocus))]

  [(where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
   ---------------------------------------------------- "contract unification failure/e"
   (contract/e
    (DecWork
     (Work support
           (t_1 =? t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork unify-fail (Dead support) WorkFocus))]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #f (invalid? sub dis_1))
   ---------------------------------------------------- "contract disequality success/e"
   (contract/e
    (DecWork
     (Work support
           (t_1 != t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork
     disequality-success
     (Returned support (state sub dis_1 trail tag_2))
     WorkFocus))]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #t (invalid? sub dis_1))
   ---------------------------------------------------- "contract disequality failure/e"
   (contract/e
    (DecWork
     (Work support
           (t_1 != t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork disequality-fail (Dead support) WorkFocus))]

  [(where (u_new ...)
          ,(variables-not-in
            (term support)
            (make-list (length (term (x_bound ...))) 'u:0)))
   (where g_new
          ,(subst-goal-host
            (term g)
            (term ((x_bound u_new) ...))))
   ---------------------------------------------------- "contract allocate fresh/e"
   (contract/e
    (DecAllocate
     (Work support (∃ (x_bound ...) g tag) σ)
     WorkFocus)
    (ContractWork
     allocate-fresh
     (Work
      (support-append support (Support u_new ...))
      g_new
      σ)
     WorkFocus))]

  [---------------------------------------------------- "contract finish success/e"
   (contract/e
    (DecFrontier
     (More (Returned support σ))
     SpineContext)
    (ContractFrontier
     finish-success
     (Last support (Answer support σ))
     SpineContext))]

  [---------------------------------------------------- "contract finish failure/e"
   (contract/e
    (DecFrontier (More (Dead support)) SpineContext)
    (ContractFrontier
     finish-failure
     (Done support)
     SpineContext))])

(define-judgment-form
  core-e-decomposition-lang
  #:contract (decomposed-step/e D RuleName D)
  #:mode (decomposed-step/e I O O)
  [(contract/e D_0 C)
   (where RuleName (contract-label/e C))
   (where F (plug-C/e C))
   (decompose/e F D_1)
   ---------------------------------------------------- "decomposed step/e"
   (decomposed-step/e D_0 RuleName D_1)])
