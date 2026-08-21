#lang racket

(require racket/list
         redex/reduction-semantics
         "../../framework/decomposition-instance.rkt"
         (only-in "../../../../src/search-lattice/languages/core-lang.rkt"
                  core-lang
                  invalid?
                  owners-append
                  unify
                  walk)
         (only-in "../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "./private/support-kernel.rkt")

(provide core-s-decomposition-lang
         plug-D/s
         plug-C/s
         contract-label/s
         decompose/s
         contract/s
         decomposed-step/direct/s
         whole-frontier-support/s
         separated-work-support/s
         support-split-agrees?/s
         fresh-intro/whole/s
         fresh-intro/separated/s)

(check-redundancy #t)

;; The shell owns only the grammatical partition and administrative plugs.
;; In particular, allocation is kept out of WR because its name choice depends
;; on support supplied structurally by the separated focus/context.
(define-decomposition-instance
  #:source-language core-lang
  #:decomposition-language core-s-decomposition-lang
  #:work W
  #:frontier F
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:rule-names (expand-conjunction
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
  #:work-redexes ((Work owners (g_1 ∧ g_2 tag) σ)
                   (Work owners (succeed tag) σ)
                   (Work owners (fail tag) σ)
                   (Work owners (t_1 =? t_2 tag) σ)
                   (Work owners (t_1 != t_2 tag) σ)
                   (Conj owners_outer (Returned owners_inner σ) g)
                   (Conj owners_outer (Dead owners_inner) g))
  #:frontier-redexes ((More (Returned owners σ))
                       (More (Dead owners)))
  #:allocation-redexes ((Work owners (∃ d g tag) σ))
  #:terminals ((Last owners A)
                (Done owners))
  #:plug-D plug-D/s
  #:plug-C plug-C/s
  #:contract-label contract-label/s
  #:decompose decompose/s)

(define-metafunction core-s-decomposition-lang
  whole-frontier-support/s : F -> intro
  [(whole-frontier-support/s F)
   ,(canonical-u-support/host (term F))])

(define-metafunction core-s-decomposition-lang
  separated-work-support/s : WorkFocus W -> intro
  [(separated-work-support/s WorkFocus W)
   ,(canonical-u-support/host
     (list (term WorkFocus) (term W)))])

(define-metafunction core-s-decomposition-lang
  support-split-agrees?/s : WorkFocus W -> boolean
  [(support-split-agrees?/s WorkFocus W)
   ,(equal? (term (whole-frontier-support/s (in-hole WorkFocus W)))
            (term (separated-work-support/s WorkFocus W)))])

(define-metafunction core-s-decomposition-lang
  fresh-intro/whole/s : F d -> intro
  [(fresh-intro/whole/s F (x_bound ...))
   ,(fresh-intro/from-datum/host
     (term F)
     (term (x_bound ...)))])

(define-metafunction core-s-decomposition-lang
  fresh-intro/separated/s : WorkFocus W d -> intro
  [(fresh-intro/separated/s WorkFocus W (x_bound ...))
   ,(fresh-intro/separated/host
     (term WorkFocus)
     (term W)
     (term (x_bound ...)))])

;; These clauses are an independent Redex statement of all thirteen core
;; contractions.  They do not call core-red or share a rule table with it.
(define-judgment-form
  core-s-decomposition-lang
  #:contract (contract/s D C)
  #:mode (contract/s I O)

  [---------------------------------------------------- "contract expand conjunction/S"
   (contract/s
    (DecWork
     (Work owners (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
     WorkFocus)
    (ContractWork
     expand-conjunction
     (Conj owners (Work (Owners) g_1 (state sub dis trail tag_1)) g_2)
     WorkFocus))]

  [---------------------------------------------------- "contract succeed/S"
   (contract/s
    (DecWork (Work owners (succeed tag) σ) WorkFocus)
    (ContractWork succeed (Returned owners σ) WorkFocus))]

  [---------------------------------------------------- "contract fail/S"
   (contract/s
    (DecWork (Work owners (fail tag) σ) WorkFocus)
    (ContractWork fail (Dead owners) WorkFocus))]

  [---------------------------------------------------- "contract conjunction return/S"
   (contract/s
    (DecWork
     (Conj owners_outer (Returned owners_inner σ) g)
     WorkFocus)
    (ContractWork
     conj-return
     (Work (owners-append owners_outer owners_inner) g σ)
     WorkFocus))]

  [---------------------------------------------------- "contract conjunction failure/S"
   (contract/s
    (DecWork (Conj owners_outer (Dead owners_inner) g) WorkFocus)
    (ContractWork
     conj-fail
     (Dead (owners-append owners_outer owners_inner))
     WorkFocus))]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #f (invalid? sub_1 dis))
   ---------------------------------------------------- "contract unification success/S"
   (contract/s
    (DecWork
     (Work owners
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    (ContractWork
     unify-success
     (Returned
      owners
      (state sub_1
             dis
             ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
             tag_2))
     WorkFocus))]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #t (invalid? sub_1 dis))
   ---------------------------------------------------- "contract unification violates disequality/S"
   (contract/s
    (DecWork
     (Work owners
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    (ContractWork unify-violates-disequality (Dead owners) WorkFocus))]

  [(where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
   ---------------------------------------------------- "contract unification failure/S"
   (contract/s
    (DecWork
     (Work owners (t_1 =? t_2 tag) (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork unify-fail (Dead owners) WorkFocus))]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #f (invalid? sub dis_1))
   ---------------------------------------------------- "contract disequality success/S"
   (contract/s
    (DecWork
     (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork
     disequality-success
     (Returned owners (state sub dis_1 trail tag_2))
     WorkFocus))]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #t (invalid? sub dis_1))
   ---------------------------------------------------- "contract disequality failure/S"
   (contract/s
    (DecWork
     (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
     WorkFocus)
    (ContractWork disequality-fail (Dead owners) WorkFocus))]

  [---------------------------------------------------- "contract finish success/S"
   (contract/s
    (DecFrontier (More (Returned owners σ)) SpineContext)
    (ContractFrontier
     finish-success
     (Last owners (Answer (Owners) σ))
     SpineContext))]

  [---------------------------------------------------- "contract finish failure/S"
   (contract/s
    (DecFrontier (More (Dead owners)) SpineContext)
    (ContractFrontier finish-failure (Done owners) SpineContext))]

  [;; The whole-frontier equality is checked independently by the support
   ;; theorem and matrix tests.  This direct clause reads only the separated
   ;; WorkFocus/redex representation.
   (where (u_new ...)
          (fresh-intro/separated/s
           WorkFocus
           (Work owners (∃ (x_bound ...) g tag) σ)
           (x_bound ...)))
   (where g_new
          ,(subst-goal-host
            (term g)
            (term ((x_bound u_new) ...))))
   ---------------------------------------------------- "contract allocate fresh/S"
   (contract/s
    (DecAllocate
     (Work owners (∃ (x_bound ...) g tag) σ)
     WorkFocus)
    (ContractWork
     allocate-fresh
     (Work
      (owners-append owners (Owners (Owner (u_new ...) tag)))
      g_new
      σ)
     WorkFocus))])

(define-judgment-form
  core-s-decomposition-lang
  #:contract (decomposed-step/direct/s D RuleName D)
  #:mode (decomposed-step/direct/s I O O)

  [(contract/s D C)
   (where RuleName (contract-label/s C))
   (where F_next (plug-C/s C))
   (decompose/s F_next D_next)
   ---------------------------------------------------- "direct decomposed step/S"
   (decomposed-step/direct/s D RuleName D_next)])
