#lang racket

(require redex/reduction-semantics)

(provide redex-column-kernel-interface-lang
         kernel-success?
         kernel-result-state
         kernel-label-name
         kernel-label-owner)

;; A kernel instantiation supplies precise productions for `katom`, `kst`,
;; and `kname`, and a Redex judgment with the following shape:
;;
;;   kernel-step/K : katom x kst -> kresult x kell
;;
;; The result has only the control-relevant distinction: success carries an
;; opaque next state and failure carries no state.  The label retains the
;; kernel-owned rule name while recording that atomic goal evaluation belongs
;; to the core feature.  Control stages may branch on KernelSuccess versus
;; KernelFailure, but must not inspect `kst` or `kname`.
;;
;; Each instantiation also supplies initial-state, fresh/open, substitution,
;; atomic-goal well-formedness, and state-at-ambient-scope well-formedness.
;; AnswerFresh/WorkFresh traversal is deliberately not a kernel operation: it
;; is shared control syntax over an opaque state.
(define-language redex-column-kernel-interface-lang
  [katom any]
  [kst any]
  [kresult (KernelSuccess kst)
           KernelFailure]
  [kname variable-not-otherwise-mentioned]
  [kowner core]
  [kell (kernel kname kowner)])

(define-metafunction redex-column-kernel-interface-lang
  kernel-success? : kresult -> boolean
  [(kernel-success? (KernelSuccess kst)) #t]
  [(kernel-success? KernelFailure) #f])

(define-metafunction redex-column-kernel-interface-lang
  kernel-result-state : (KernelSuccess kst) -> kst
  [(kernel-result-state (KernelSuccess kst)) kst])

(define-metafunction redex-column-kernel-interface-lang
  kernel-label-name : kell -> kname
  [(kernel-label-name (kernel kname kowner)) kname])

(define-metafunction redex-column-kernel-interface-lang
  kernel-label-owner : kell -> kowner
  [(kernel-label-owner (kernel kname kowner)) kowner])
