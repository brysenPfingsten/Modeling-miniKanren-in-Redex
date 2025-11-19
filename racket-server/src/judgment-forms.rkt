#lang racket
(require rackunit
         redex
         redex/reduction-semantics
         "definitions.rkt")

(check-redundancy #t)

(provide wf-goal?
		 wf-tree?
		 wf-term?
		 wf-state?
         wf-sub/wf+equiv-trail?
         wf-sub?
		 wf-program?)


(module+ test
  (require rackunit)
  )

(define-judgment-form
  Core
  #:contract (lvar-member? u c)
  #:mode (lvar-member? I I)

  [--------"lvar member"
   (lvar-member? u (u_1 ... u u_2 ...))]
)

(module+ test
  (check-true (judgment-holds (lvar-member? u:0 (u:0))))
  (check-true (judgment-holds (lvar-member? u:0 (u:1 u:0))))
  (check-false (judgment-holds (lvar-member? u:7 (u:0))))
  (check-true (judgment-holds (lvar-member? u:1 (u:2 u:1 u:0))))
)

(define-judgment-form
  Core
  #:contract (wf-term? t (x ...) c)
  #:mode (wf-term? I I I)

  [(lvar-member? u c)
   -------------- "lv in extant lvs"
   (wf-term? u (x ...) c)]

  [-------------- "primitive terms are wf and valid"
   (wf-term? pt (x ...) c)]

  [(wf-term? t_2 (x ...) c)
   (wf-term? t_1 (x ...) c)
   -------------- "pairs wf when constituents wf"
   (wf-term? (t_1 : t_2) (x ...) c)]

  [-------------- "lexical var is in bound vars"
   (wf-term? x_2 (x_1 ... x_2 x_3 ...) c)])

(module+ test
  (check-true (judgment-holds (wf-term? (sym "a") () ())))
  (check-true (judgment-holds (wf-term? u:0 () (u:0))))
  (check-true (judgment-holds (wf-term? u:1 () (u:0 u:1))))
  (check-false (judgment-holds (wf-term? u:3 () (u:0 u:1))))
)

(define-judgment-form
  Core
  #:contract (wf-sub? sub c)
  #:mode (wf-sub? I I)

  [(wf-term? t () c) ...
   (lvar-member? u c) ...
   ------------------"sub is wf"
   (wf-sub? ([u t] ...) c)])

(module+ test
  (check-true  (judgment-holds (wf-sub? ((u:0 (sym "x"))) (u:0))))
  (check-false (judgment-holds (wf-sub? ((u:1 (sym "x"))) (u:0))))
)


(define-judgment-form
  Core
  #:contract (wf-goal? g ((r (x ...)) ...) (x_1 ...) c)
  #:mode (wf-goal? I I I I)

  [------------------ "trivial success wf"
   (wf-goal? (succeed) ((r (x ...)) ...) (x_1 ...) c)]

  [(where (u_i ...) c)
   (where (u_j ...) (fresh-lvars (x_1 ...) c))
   (wf-goal? g ((r (x ...)) ...) (x_1 ... x_2 ...) (u_j ... u_i ...))
   ------------------- "fresh-wf"
   (wf-goal? (∃ (x_1 ...) g tag) ((r (x ...)) ...) (x_2 ...) c)]

  [(wf-goal? g_1 ((r (x ...)) ...) (x_1 ...) c)
   (wf-goal? g_2 ((r (x ...)) ...) (x_1 ...) c)
   ---------- "conj-wf"
   (wf-goal? (g_1 ∧ g_2 tag) ((r (x ...)) ...) (x_1 ...) c)]

  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ---------- "==-wf"
   (wf-goal? (t_1 =? t_2 tag) ((r (x ...)) ...) (x_1 ...) c)]

  )

(module+ test
  (check-true (judgment-holds (wf-goal? (succeed) () () ())))
)

;; Given a list of used symbols, produce a fresh one
(define-metafunction Core
  ;; Takes a list of symbols, returns a fresh symbol
  fresh-lv : (u ...) -> u
  [(fresh-lv (u ...)) ,(variable-not-in (cons 'u: (term (u  ...))) 'u:)])


;;
;;
;; redex's variables-not-in uses the vars list themselves as the
;; prefixes, which doesn't work with our use case.
(define-metafunction Core
  fresh-lvars : (x ...) c -> c
  [(fresh-lvars (x ...) c)
   ,(for/fold ([fv* '()])
              ([_ (in-list (term (x ...)))])
      (define fv (variable-not-in (cons 'u: (append fv* (term c))) 'u:))
      (cons fv fv*))])

(module+ test
  (check-equal?
    (term (fresh-lvars (x:0 x:1 x:2) (u:1 u:7 u:3)))
    '(u:5 u:4 u:2)))

(define-judgment-form
  Core
  #:contract (wf-trail-unify*s-to-σ? (eq ...) c sub sub)
  #:mode (wf-trail-unify*s-to-σ? I I I I)

  [-------------------"trail is empty, acc is our sub"
   (wf-trail-unify*s-to-σ? () c sub sub)]

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(where (name sub_acc2 ([u_s t_s] ...)) (unify (walk t_1 sub_acc) (walk t_2 sub_acc) sub_acc))
   (wf-term? t_1 () c)
   (wf-term? t_2 () c)
   (wf-trail-unify*s-to-σ? (eq ...) c sub_acc2 sub)
   -------------------"this pair is well formed and unify"
   (wf-trail-unify*s-to-σ? ((t_1 =? t_2 tag) eq ...) c sub_acc sub)]

)

(module+ test
  (check-false (judgment-holds (wf-trail-unify*s-to-σ? () (u:2 u:1 u:0) ((u:0 u:2) (u:1 u:0)) ((u:1 u:0)))))
  (check-false (judgment-holds (wf-trail-unify*s-to-σ? () (u:2 u:1 u:0) ((u:1 u:0)) ((u:0 u:2) (u:1 u:0)))))
)



(define-judgment-form
  Core
  #:contract (wf-sub/wf+equiv-trail? sub c trail)
  #:mode (wf-sub/wf+equiv-trail? I I I)

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(wf-sub? sub c)
   (wf-trail-unify*s-to-σ? (eq ...) c () sub)
   -------------------"goal w/ sub wf"
   (wf-sub/wf+equiv-trail? sub c (eq ...))]

)

(define-judgment-form
  Core
  #:contract (wf-state? σ)
  #:mode (wf-state? I)

  [(wf-sub/wf+equiv-trail? sub c trail)
   ----------------------- "state wf"
   (wf-state? (state sub c trail tag))])

(define-judgment-form
  Core
  #:contract (wf-tree? s Γ)
  #:mode (wf-tree? I I)

  [-------------------"empty tree is wf"
   (wf-tree? (empty-tree) ((r (x ...)) ...))]

  [(wf-goal? g ((r (x ...)) ...) () c)
   (wf-sub/wf+equiv-trail? sub c trail)
   -------------------"goal/state wf"
   (wf-tree? (g (state sub c trail tag)) ((r (x ...)) ...))]

  [(wf-tree? s ((r (x ...)) ...))
   (wf-goal? g ((r (x ...)) ...) () ())
   -------------------"conj wf"
   (wf-tree? (s × g) ((r (x ...)) ...))])

(define-judgment-form
  Core
  #:contract (wf-program? config)
  #:mode (wf-program? I)
  [(wf-state? σ) ...
   (wf-tree? s ((r (x ...)) ...))
   (wf-goal? g ((r (x ...)) ...) (x ...) ()) ...
   ----------------------- "program-wf"
   (wf-program? (((r (x ...) g) ...) (σ ...) s))]
  )

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"partial tree wf"
   (wf-tree? (∂ s _) ((r (x ...)) ...))] ;; TODO: wf-state-judgement?

  #;[(wf-tree? s_1 ((r (x ...)) ...))
   (wf-tree? s_2 ((r (x ...)) ...))
   -------------------"left disj wf"
   (wf-tree? (s_1 <-+ s_2) ((r (x ...)) ...))]

  #;[(wf-tree? s_1 ((r (x ...)) ...))
   (wf-tree? s_2 ((r (x ...)) ...))
   -------------------"right disj wf"
   (wf-tree? (s_1 +-> s_2) ((r (x ...)) ...))]



;; (define-judgment-form
;;   Core
;;   #:contract (wf-trail? trail c)
;;   #:mode (wf-trail? I I)

;;   [
;;    ------------------ "empty trail is wf"
;;    (wf-trail? () c)]

;;   [(wf-term? t_1 () c)
;;    (wf-term? t_2 () c)
;;    (wf-trail? ((t_3 =? t_4 o) ...) c)
;;    ------------------ "trail is wf"
;;   (wf-trail? ((t_1 =? t_2 _) (t_3 =? t_4 o) ...) c)])

  ;; [(wf-goal? g_1 ((r (x ...)) ...) (x_1 ...) c)
  ;;  (wf-goal? g_2 ((r (x ...)) ...) (x_1 ...) c)
  ;;  ---------- "disj-wf"
  ;;  (wf-goal? (g_1 ∨ g_2 _) ((r (x ...)) ...) (x_1 ...) c)]

  ;; [(same-length? (t ...) (x_i ...))
  ;;  (wf-term? t (x_k ...) c) ...
  ;;  ---------- "relcall-wf"
  ;;  (wf-goal? (r_i t ... _) ((r_1 (x_1 ...)) ... (r_i (x_i ...)) (r_j (x_j ...)) ...) (x_k ...) c)]

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"delay wf"
   (wf-tree? (delay s) ((r (x ...)) ...))]

  #;[(wf-tree? s ((r (x ...)) ...))
   -------------------"proceed wf"
   (wf-tree? (proceed s) ((r (x ...)) ...))]
