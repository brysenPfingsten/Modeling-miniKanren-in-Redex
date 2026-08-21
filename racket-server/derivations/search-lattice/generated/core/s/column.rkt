#lang racket

(require redex/reduction-semantics
         "../../../framework/stage-generators.rkt"
         (only-in "../../../../../src/search-lattice/languages/core-lang.rkt"
                  core-lang
                  invalid?
                  owners-append
                  unify
                  walk)
         (only-in "../../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "../../../core/s/private/support-kernel.rkt")

(provide core/S
         core/D/S
         core/Z/S
         core/M/S
         core/compression/S
         core/B/S
         core/Big/S
         generated-core-s-decomposition-lang
         generated-plug-D/s
         generated-plug-C/s
         generated-contract-label/s
         generated-decompose/s
         generated-contract/s
         generated-decomposed-step/s
         generated-core-s-refocused-lang
         generated-D->Z/s
         generated-Z->D/s
         generated-readback-Z/s
         generated-refocus/spec/s
         generated-refocus-work/direct/s
         generated-refocus/direct/s
         generated-refocused-step/spec/s
         generated-refocused-step/direct/s
         generated-core-s-machine-lang
         generated-encode-ZM/s
         generated-decode-MZ/s
         generated-D->M/s
         generated-M->D/s
         generated-readback-M/s
         generated-machine-refocus-work/direct/s
         generated-machine-refocus/direct/s
         generated-machine-step/direct/s
         generated-ZM-corresponds/s
         generated-machine-step/spec/s
         generated-ZM-step-square/s
         generated-core-s-compressed-lang
         generated-encode-MB/s
         generated-decode-BM/s
         generated-readback-B/s
         generated-transition-span-labels/s
         generated-produce-settled/direct/s
         generated-produce-dead/direct/s
         generated-advance-settled/direct/s
         generated-advance-dead/direct/s
         generated-compressed-step/direct/s
         generated-MB-corresponds/s
         generated-replay-transition-span/M/s
         generated-compressed-step/spec/s
         generated-MB-step-square/s
         generated-core-s-big-lang
         generated-readback-Big/s
         generated-big-dispatch/direct/s
         generated-big-run/direct/s
         generated-big-settled/direct/s
         generated-big-dead/direct/s
         generated-big-final/direct/s
         generated-big-evaluate/direct/s
         generated-core-s-big-spec-lang
         generated-initialize-B/spec/s
         generated-close-B/spec/s
         generated-flatten-BTrace/s
         generated-promote-B/direct/s
         generated-big-evaluate/spec/s
         generated-B-Big-unfold-square/s
         generated-B-Big-closure-square/s
         generated-B-Big-root-square/s)

(check-redundancy #t)

;; This is the generated column's sole declaration of the core/S semantic
;; equations.  Production R[S] and the handwritten core/s column remain
;; independent artifacts and are imported only by the comparison tests.  The
;; column reproduces the current allocation-support policy; it does not select
;; that policy as the eventual world-local S semantics.
(define-derivation-instance core/S
  #:source-language core-lang
  #:work W
  #:frontier F
  #:settled S
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:environment owners
  #:run-productions
  ((Work owners g σ))
  #:nonallocation-run-productions
  ((Work owners eq σ)
   (Work owners (t != t tag) σ)
   (Work owners (succeed tag) σ)
   (Work owners (fail tag) σ)
   (Work owners (g ∧ g tag) σ))
  #:dead-view [owners (Dead owners)]
  #:root-focus (More hole)
  #:root-spine hole
  #:frames
  ((Conj owners hole g))
  #:work-redexes
  ((Work owners (g_1 ∧ g_2 tag) σ)
   (Work owners (succeed tag) σ)
   (Work owners (fail tag) σ)
   (Work owners (t_1 =? t_2 tag) σ)
   (Work owners (t_1 != t_2 tag) σ)
   (Conj owners_outer (Returned owners_inner σ) g)
   (Conj owners_outer (Dead owners_inner) g))
  #:frontier-redexes
  ((More (Returned owners σ))
   (More (Dead owners)))
  #:allocation-redexes
  ((Work owners (∃ d g tag) σ))
  #:terminals
  ((Last owners A)
   (Done owners))
  #:open-work-productions
  ((Conj owners OpenW g))
  #:rules
  ([expand-conjunction
    #:site work
    #:from
    (run
     (Work owners
           (g_1 ∧ g_2 tag)
           (state sub dis trail tag_1))
     WorkFocus)
    #:to
    (push
     (Conj owners hole g_2)
     (Work (Owners) g_1 (state sub dis trail tag_1))
     WorkFocus)
    #:premises ()]

   [succeed
    #:site work
    #:from (run (Work owners (succeed tag) σ) WorkFocus)
    #:to (settled (Returned owners σ) WorkFocus)
    #:premises ()]

   [fail
    #:site work
    #:from (run (Work owners (fail tag) σ) WorkFocus)
    #:to (dead owners (Dead owners) WorkFocus)
    #:premises ()]

   [conj-return
    #:site work
    #:from
    (pop-settled
     (Conj owners_outer hole g)
     (Returned owners_inner σ)
     WorkFocus)
    #:to
    (run
     (Work (owners-append owners_outer owners_inner) g σ)
     WorkFocus)
    #:premises ()]

   [conj-fail
    #:site work
    #:from
    (pop-dead
     (Conj owners_outer hole g)
     owners_inner
     (Dead owners_inner)
     WorkFocus)
    #:to
    (dead
     (owners-append owners_outer owners_inner)
     (Dead (owners-append owners_outer owners_inner))
     WorkFocus)
    #:premises ()]

   [allocate-fresh
    #:site allocation
    #:from
    (run
     (Work owners (∃ (x_bound ...) g tag) σ)
     WorkFocus)
    #:to
    (run
     (Work
      (owners-append owners (Owners (Owner (u_new ...) tag)))
      g_new
      σ)
     WorkFocus)
    #:premises
    ((where (u_new ...)
            ,(fresh-intro/separated/host
              (term WorkFocus)
              (term (Work owners (∃ (x_bound ...) g tag) σ))
              (term (x_bound ...))))
     (where g_new
            ,(subst-goal-host
              (term g)
              (term ((x_bound u_new) ...)))))]

   [unify-success
    #:site work
    #:from
    (run
     (Work owners
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    #:to
    (settled
     (Returned
      owners
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
     (Work owners
           (t_1 =? t_2 tag)
           (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
     WorkFocus)
    #:to (dead owners (Dead owners) WorkFocus)
    #:premises
    ((where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
     (where #t (invalid? sub_1 dis)))]

   [unify-fail
    #:site work
    #:from
    (run
     (Work owners
           (t_1 =? t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    #:to (dead owners (Dead owners) WorkFocus)
    #:premises
    ((where #f (unify (walk t_1 sub) (walk t_2 sub) sub)))]

   [disequality-success
    #:site work
    #:from
    (run
     (Work owners
           (t_1 != t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    #:to
    (settled
     (Returned owners (state sub dis_1 trail tag_2))
     WorkFocus)
    #:premises
    ((where dis_1 ((t_1 t_2) ,@(term dis)))
     (where #f (invalid? sub dis_1)))]

   [disequality-fail
    #:site work
    #:from
    (run
     (Work owners
           (t_1 != t_2 tag)
           (state sub dis trail tag_2))
     WorkFocus)
    #:to (dead owners (Dead owners) WorkFocus)
    #:premises
    ((where dis_1 ((t_1 t_2) ,@(term dis)))
     (where #t (invalid? sub dis_1)))]

   [finish-success
    #:site frontier
    #:from
    (root-settled (Returned owners σ) SpineContext)
    #:to
    (final (Last owners (Answer (Owners) σ)) SpineContext)
    #:premises ()]

   [finish-failure
    #:site frontier
    #:from (root-dead owners (Dead owners) SpineContext)
    #:to (final (Done owners) SpineContext)
    #:premises ()]))

(define-decomposition-stage core/D/S
  #:from core/S
  #:language generated-core-s-decomposition-lang
  #:plug-D generated-plug-D/s
  #:plug-C generated-plug-C/s
  #:contract-label generated-contract-label/s
  #:decompose generated-decompose/s
  #:contract generated-contract/s
  #:step generated-decomposed-step/s)

(define-refocused-stage core/Z/S
  #:from core/D/S
  #:language generated-core-s-refocused-lang
  #:D->Z generated-D->Z/s
  #:Z->D generated-Z->D/s
  #:readback generated-readback-Z/s
  #:refocus-spec generated-refocus/spec/s
  #:refocus-work-direct generated-refocus-work/direct/s
  #:refocus-direct generated-refocus/direct/s
  #:step-spec generated-refocused-step/spec/s
  #:step-direct generated-refocused-step/direct/s)

(define-machine-isomorphism-stage core/M/S
  #:from core/Z/S
  #:language generated-core-s-machine-lang
  #:encode-ZM generated-encode-ZM/s
  #:decode-MZ generated-decode-MZ/s
  #:D->M generated-D->M/s
  #:M->D generated-M->D/s
  #:readback generated-readback-M/s
  #:refocus-work-direct generated-machine-refocus-work/direct/s
  #:refocus-direct generated-machine-refocus/direct/s
  #:step-direct generated-machine-step/direct/s
  #:corresponds generated-ZM-corresponds/s
  #:step-spec generated-machine-step/spec/s
  #:square generated-ZM-step-square/s)

(define-compression-policy core/compression/S
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

(define-compressed-stage core/B/S
  #:from core/M/S
  #:policy core/compression/S
  #:language generated-core-s-compressed-lang
  #:encode-MB generated-encode-MB/s
  #:decode-BM generated-decode-BM/s
  #:readback generated-readback-B/s
  #:span-labels generated-transition-span-labels/s
  #:produce-settled generated-produce-settled/direct/s
  #:produce-dead generated-produce-dead/direct/s
  #:advance-settled generated-advance-settled/direct/s
  #:advance-dead generated-advance-dead/direct/s
  #:step-direct generated-compressed-step/direct/s
  #:corresponds generated-MB-corresponds/s
  #:replay generated-replay-transition-span/M/s
  #:step-spec generated-compressed-step/spec/s
  #:square generated-MB-step-square/s)

(define-fixed-point-stage core/Big/S
  #:from core/B/S
  #:language generated-core-s-big-lang
  #:readback generated-readback-Big/s
  #:dispatch generated-big-dispatch/direct/s
  #:run generated-big-run/direct/s
  #:settled generated-big-settled/direct/s
  #:dead generated-big-dead/direct/s
  #:final generated-big-final/direct/s
  #:evaluate generated-big-evaluate/direct/s
  #:spec-language generated-core-s-big-spec-lang
  #:initialize generated-initialize-B/spec/s
  #:close generated-close-B/spec/s
  #:flatten generated-flatten-BTrace/s
  #:promote generated-promote-B/direct/s
  #:evaluate-spec generated-big-evaluate/spec/s
  #:unfold-square generated-B-Big-unfold-square/s
  #:closure-square generated-B-Big-closure-square/s
  #:root-square generated-B-Big-root-square/s)
