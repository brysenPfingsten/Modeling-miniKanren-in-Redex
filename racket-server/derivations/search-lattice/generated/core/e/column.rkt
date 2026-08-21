#lang racket

(require redex/reduction-semantics
         (only-in "../../../../../src/search-lattice/languages/core-lang.rkt"
                  invalid?
                  unify
                  walk)
         (only-in "../../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "../../../core/e/language.rkt"
         "../../../framework/stage-generators.rkt")

(provide generated-core/e
         generated-core/D/e
         generated-core/Z/e
         generated-core/M/e
         generated-core/compression/e
         generated-core/B/e
         generated-core/Big/e
         generated-core-e-decomposition-lang
         plug-D/generated-e
         plug-C/generated-e
         contract-label/generated-e
         decompose/generated-e
         contract/generated-e
         decomposed-step/generated-e
         generated-core-e-refocused-lang
         D->Z/generated-e
         Z->D/generated-e
         readback-Z/generated-e
         refocus/spec/generated-e
         refocus-work/direct/generated-e
         refocus/direct/generated-e
         refocused-step/spec/generated-e
         refocused-step/direct/generated-e
         generated-core-e-machine-lang
         encode-ZM/generated-e
         decode-MZ/generated-e
         D->M/generated-e
         M->D/generated-e
         readback-M/generated-e
         machine-refocus-work/direct/generated-e
         machine-refocus/direct/generated-e
         machine-step/direct/generated-e
         ZM-corresponds/generated-e
         machine-step/spec/generated-e
         ZM-step-square/generated-e
         generated-core-e-compressed-lang
         encode-MB/generated-e
         decode-BM/generated-e
         readback-B/generated-e
         transition-span-labels/generated-e
         produce-settled/direct/generated-e
         produce-dead/direct/generated-e
         advance-settled/direct/generated-e
         advance-dead/direct/generated-e
         compressed-step/direct/generated-e
         MB-corresponds/generated-e
         replay-transition-span/M/generated-e
         compressed-step/spec/generated-e
         MB-step-square/generated-e
         generated-core-e-big-lang
         readback-Big/generated-e
         big-dispatch/direct/generated-e
         big-run/direct/generated-e
         big-settled/direct/generated-e
         big-dead/direct/generated-e
         big-final/direct/generated-e
         big-evaluate/direct/generated-e
         generated-core-e-big-spec-lang
         initialize-B/spec/generated-e
         close-B/spec/generated-e
         flatten-BTrace/generated-e
         promote-B/direct/generated-e
         big-evaluate/spec/generated-e
         B-Big-unfold-square/generated-e
         B-Big-closure-square/generated-e
         B-Big-root-square/generated-e)

(check-redundancy #t)

;; This is the generated support-decorated-node prototype's sole declaration
;; of its core/E semantic equations.  Its direct R[E] relation and handwritten
;; D[E] remain independent oracles.  Later stage macros consume this retained
;; declaration rather than restating these clauses.  This is not yet the
;; selected state-local E representation.
(define-derivation-instance generated-core/e
  #:source-language core-e-lang
  #:work W
  #:frontier F
  #:settled S
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:environment support
  #:run-productions
  ((Work support g σ))
  #:nonallocation-run-productions
  ((Work support eq σ)
   (Work support (t != t tag) σ)
   (Work support (succeed tag) σ)
   (Work support (fail tag) σ)
   (Work support (g ∧ g tag) σ))
  #:dead-view
  [support (Dead support)]
  #:root-focus
  (More hole)
  #:root-spine
  hole
  #:frames
  ((Conj support hole g))
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
  #:open-work-productions
  ((Conj support OpenW g))
  #:rules
  ([expand-conjunction
    #:site work
    #:from
    (run
     (Work support (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
     WorkFocus)
    #:to
    (push
     (Conj support hole g_2)
     (Work support g_1 (state sub dis trail tag_1))
     WorkFocus)
    #:premises ()]

   [succeed
    #:site work
    #:from (run (Work support (succeed tag) σ) WorkFocus)
    #:to (settled (Returned support σ) WorkFocus)
    #:premises ()]

   [fail
    #:site work
    #:from (run (Work support (fail tag) σ) WorkFocus)
    #:to (dead support (Dead support) WorkFocus)
    #:premises ()]

   [conj-return
    #:site work
    #:from
    (pop-settled
     (Conj support_outer hole g)
     (Returned support_inner σ)
     WorkFocus)
    #:to (run (Work support_inner g σ) WorkFocus)
    #:premises ()]

   [conj-fail
    #:site work
    #:from
    (pop-dead
     (Conj support_outer hole g)
     support_inner
     (Dead support_inner)
     WorkFocus)
    #:to (dead support_inner (Dead support_inner) WorkFocus)
    #:premises ()]

   [unify-success
    #:site work
    #:from
    (run
     (Work
      support
      (t_1 =? t_2 tag)
      (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    #:to
    (settled
     (Returned
      support
      (state sub_1
             dis
             ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
             tag_2))
     WorkFocus)
    #:premises
    ((where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
     (where #f (invalid? sub_1 dis)))]

   [unify-violates-disequality
    #:site work
    #:from
    (run
     (Work
      support
      (t_1 =? t_2 tag)
      (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    #:to (dead support (Dead support) WorkFocus)
    #:premises
    ((where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
     (where #t (invalid? sub_1 dis)))]

   [unify-fail
    #:site work
    #:from
    (run
     (Work
      support
      (t_1 =? t_2 tag)
      (state sub dis trail tag_2))
     WorkFocus)
    #:to (dead support (Dead support) WorkFocus)
    #:premises
    ((where #f (unify (walk t_1 sub) (walk t_2 sub) sub)))]

   [disequality-success
    #:site work
    #:from
    (run
     (Work
      support
      (t_1 != t_2 tag)
      (state sub dis trail tag_2))
     WorkFocus)
    #:to
    (settled
     (Returned support (state sub dis_1 trail tag_2))
     WorkFocus)
    #:premises
    ((where dis_1 ((t_1 t_2) ,@(term dis)))
     (where #f (invalid? sub dis_1)))]

   [disequality-fail
    #:site work
    #:from
    (run
     (Work
      support
      (t_1 != t_2 tag)
      (state sub dis trail tag_2))
     WorkFocus)
    #:to (dead support (Dead support) WorkFocus)
    #:premises
    ((where dis_1 ((t_1 t_2) ,@(term dis)))
     (where #t (invalid? sub dis_1)))]

   [allocate-fresh
    #:site allocation
    #:from
    (run
     (Work support (∃ (x_bound ...) g tag) σ)
     WorkFocus)
    #:to
    (run
     (Work support_new g_new σ)
     WorkFocus)
    #:premises
    ((where (u_new ...)
            ,(variables-not-in
              (term support)
              (make-list (length (term (x_bound ...))) 'u:0)))
     (where g_new
            ,(subst-goal-host
              (term g)
              (term ((x_bound u_new) ...))))
     (where support_new
            (support-append support (Support u_new ...))))]

   [finish-success
    #:site frontier
    #:from
    (root-settled (Returned support σ) SpineContext)
    #:to
    (final (Last support (Answer support σ)) SpineContext)
    #:premises ()]

   [finish-failure
    #:site frontier
    #:from
    (root-dead support (Dead support) SpineContext)
    #:to (final (Done support) SpineContext)
    #:premises ()]))

(define-decomposition-stage generated-core/D/e
  #:from generated-core/e
  #:language generated-core-e-decomposition-lang
  #:plug-D plug-D/generated-e
  #:plug-C plug-C/generated-e
  #:contract-label contract-label/generated-e
  #:decompose decompose/generated-e
  #:contract contract/generated-e
  #:step decomposed-step/generated-e)

(define-refocused-stage generated-core/Z/e
  #:from generated-core/D/e
  #:language generated-core-e-refocused-lang
  #:D->Z D->Z/generated-e
  #:Z->D Z->D/generated-e
  #:readback readback-Z/generated-e
  #:refocus-spec refocus/spec/generated-e
  #:refocus-work-direct refocus-work/direct/generated-e
  #:refocus-direct refocus/direct/generated-e
  #:step-spec refocused-step/spec/generated-e
  #:step-direct refocused-step/direct/generated-e)

;; Z and M intentionally differ only by this generated structural
;; isomorphism and the mechanically specialized retained-context equations.
(define-machine-isomorphism-stage generated-core/M/e
  #:from generated-core/Z/e
  #:language generated-core-e-machine-lang
  #:encode-ZM encode-ZM/generated-e
  #:decode-MZ decode-MZ/generated-e
  #:D->M D->M/generated-e
  #:M->D M->D/generated-e
  #:readback readback-M/generated-e
  #:refocus-work-direct machine-refocus-work/direct/generated-e
  #:refocus-direct machine-refocus/direct/generated-e
  #:step-direct machine-step/direct/generated-e
  #:corresponds ZM-corresponds/generated-e
  #:step-spec machine-step/spec/generated-e
  #:square ZM-step-square/generated-e)

(define-compression-policy generated-core/compression/e
  #:settled-producers
  (succeed
   unify-success
   disequality-success)
  #:dead-producers
  (fail
   unify-violates-disequality
   unify-fail
   disequality-fail)
  #:settled-followers
  (conj-return
   finish-success)
  #:dead-followers
  (conj-fail
   finish-failure)
  #:singletons
  (expand-conjunction
   allocate-fresh
   conj-return
   conj-fail
   finish-success
   finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-compressed-stage generated-core/B/e
  #:from generated-core/M/e
  #:policy generated-core/compression/e
  #:language generated-core-e-compressed-lang
  #:encode-MB encode-MB/generated-e
  #:decode-BM decode-BM/generated-e
  #:readback readback-B/generated-e
  #:span-labels transition-span-labels/generated-e
  #:produce-settled produce-settled/direct/generated-e
  #:produce-dead produce-dead/direct/generated-e
  #:advance-settled advance-settled/direct/generated-e
  #:advance-dead advance-dead/direct/generated-e
  #:step-direct compressed-step/direct/generated-e
  #:corresponds MB-corresponds/generated-e
  #:replay replay-transition-span/M/generated-e
  #:step-spec compressed-step/spec/generated-e
  #:square MB-step-square/generated-e)

(define-fixed-point-stage generated-core/Big/e
  #:from generated-core/B/e
  #:language generated-core-e-big-lang
  #:readback readback-Big/generated-e
  #:dispatch big-dispatch/direct/generated-e
  #:run big-run/direct/generated-e
  #:settled big-settled/direct/generated-e
  #:dead big-dead/direct/generated-e
  #:final big-final/direct/generated-e
  #:evaluate big-evaluate/direct/generated-e
  #:spec-language generated-core-e-big-spec-lang
  #:initialize initialize-B/spec/generated-e
  #:close close-B/spec/generated-e
  #:flatten flatten-BTrace/generated-e
  #:promote promote-B/direct/generated-e
  #:evaluate-spec big-evaluate/spec/generated-e
  #:unfold-square B-Big-unfold-square/generated-e
  #:closure-square B-Big-closure-square/generated-e
  #:root-square B-Big-root-square/generated-e)
