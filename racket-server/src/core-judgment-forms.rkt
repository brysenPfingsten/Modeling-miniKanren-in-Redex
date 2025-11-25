#lang racket
(require rackunit
         redex
         redex/reduction-semantics
         "core-definitions.rkt")

(check-redundancy #t)

(provide wf-goal?
		 wf-tree?
		 wf-term?
		 wf-state?
         wf-sub/wf+equiv-trail?
         wf-sub?
		 wf-config?)

(module+ test
  (require rackunit)
  (default-language Core))

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
  #:contract (lvars-subset? (u ...) (u ...))
  #:mode (lvars-subset? I I)

  [------------------- "empty ⊆ anything"
   (lvars-subset? () c)]

  [(lvar-member? u c_2)
   (lvars-subset? (u_rest ...) c_2)
   ------------------- "cons ⊆"
   (lvars-subset? (u u_rest ...) c_2)])


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

  [-------------- "lexical var is in lv bindings"
   (wf-term? x_2 (x_1 ... x_2 x_3 ...) c)])

(module+ test
  (check-true (judgment-holds (wf-term? (sym "a") () ())))
  (check-true (judgment-holds (wf-term? u:0 () (u:0))))
  (check-true (judgment-holds (wf-term? u:1 () (u:0 u:1))))
  (check-false (judgment-holds (wf-term? u:3 () (u:0 u:1))))
  ;; lexical variable must be in the binder list
  (check-true  (judgment-holds (wf-term? x:0 (x:0) (u:5))))
  (check-false (judgment-holds (wf-term? x:0 () (u:5))))
)

(define-judgment-form
  Core
  #:contract (wf-sub? sub c)
  #:mode (wf-sub? I I)

  [(wf-term? t () c) ...
   (lvar-member? u c) ...
   #;(triangular? ([u t] ...))
   ------------------"sub closed under c w/no lexical vars"
   (wf-sub? ([u t] ...) c)])

(module+ test
  (check-true  (judgment-holds (wf-sub? ((u:0 (sym "x"))) (u:0))))
  (check-false (judgment-holds (wf-sub? ((u:1 (sym "x"))) (u:0))))
  ;; two bindings ok
  (check-true  (judgment-holds (wf-sub? ((u:0 (sym "x")) (u:2 (sym "y")))
                                        (u:0 u:2))))
)

(define-judgment-form
  Core
  #:contract (wf-goal? g ((r (x ...)) ...) (x_1 ...) c)
  #:mode (wf-goal? I I I I)

  [------------------ "trivial success wf"
   (wf-goal? (succeed tag) ((r (x ...)) ...) (x_1 ...) c)]

  [(where (u_old ...) c)
   (where (u_new ...) (fresh-lvars (x_1 ...) c))
   (wf-goal? g ((r (x ...)) ...) (x_1 ... x_2 ...) (u_new ... u_old ...))
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
  ;; succeed
  (check-true (judgment-holds (wf-goal? (succeed (label "fish")) () () ())))

  ;; equality with only lvs present in c
  (check-true (judgment-holds
               (wf-goal? (u:0 =? (sym "a") (label "t"))
                         ()
                         ()
                         (u:0))))

  ;; conjunction
  (check-true (judgment-holds
               (wf-goal? ((u:0 =? (sym "a") (label "t1"))
                          ∧ (u:1 =? (sym "b") (label "t2")) (label "∧"))
                         ()
                         ()
                         (u:0 u:1))))

  ;; ∃ adds fresh u's to c via add-vars-not-in
  (check-true
    (judgment-holds
      (wf-goal? (u:0 =? (sym "a") (label "t"))
                ()
                (x:0 x:1)
                (u:2 u:1 u:0))))

  ;; ∃ adds fresh u's to c via add-vars-not-in
  (check-true
    (judgment-holds
      (wf-goal? (∃ (x:0 x:1)
                  (u:0 =? (sym "a") (label "t")) (label "fresh"))
                ()
                ()
                (u:0))))
)

;; Given a list of used symbols, produce a fresh one
(define-metafunction Core
  ;; Takes a list of symbols, returns a fresh symbol
  fresh-lv : (u ...) -> u
  [(fresh-lv (u ...)) ,(variable-not-in (cons 'u: (term (u  ...))) 'u:)])


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
  #:contract (wf-trail-unify*s-to-sub (eq ...) c sub sub)
  #:mode (wf-trail-unify*s-to-sub I I I I)

  [-------------------"trail is empty, acc is our sub"
   (wf-trail-unify*s-to-sub () c sub sub)]

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(where sub_acc2 (unify (walk t_1 sub_acc) (walk t_2 sub_acc) sub_acc))
   (wf-term? t_1 () c)
   (wf-term? t_2 () c)
   (wf-trail-unify*s-to-sub (eq ...) c sub_acc2 sub)
   -------------------"this pair is well formed and unify"
   (wf-trail-unify*s-to-sub ((t_1 =? t_2 tag) eq ...) c sub_acc sub)]

)

(module+ test
  (check-false (judgment-holds (wf-trail-unify*s-to-sub () (u:2 u:1 u:0) ((u:0 u:2) (u:1 u:0)) ((u:1 u:0)))))
  (check-false (judgment-holds (wf-trail-unify*s-to-sub () (u:2 u:1 u:0) ((u:1 u:0)) ((u:0 u:2) (u:1 u:0)))))
)



(define-judgment-form
  Core
  #:contract (wf-sub/wf+equiv-trail? sub c trail)
  #:mode (wf-sub/wf+equiv-trail? I I I)

  ;; grammar makes subst's u's distinct; if each is in c, |subst| < c
  [(wf-sub? sub c)
   (wf-trail-unify*s-to-sub (eq ...) c () sub)
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
  #:contract (wf-tree? s ((r d) ...) c)
  #:mode (wf-tree? I I I)

  [-------------------"empty tree is wf"
   (wf-tree? (empty-tree) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   -------------------"single answer/state wf"
   (wf-tree? (⊤ (state sub c_i trail tag)) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-goal? g ((r d) ...) () c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   -------------------"goal/state wf"
   (wf-tree? (g (state sub c_i trail tag)) ((r d) ...) c)]

  [(lvars-subset? c c_i)
   (wf-tree? s ((r d) ...) c_i)
   (wf-goal? g ((r d) ...) () c_i)
   -------------------"conj wf"
   (wf-tree? (s × g c_i) ((r d) ...) c)])

(define-judgment-form
  Core
  #:contract (wf-config? config)
  #:mode (wf-config? I)
  [(wf-state? σ) ...
   (wf-tree? s ((r d) ...) ())
   (wf-goal? g ((r d) ...) d ()) ...
   ----------------------- "program-wf"
   (wf-config? (((r d g) ...) (σ ...) s))]
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



(module+ test
  ;; two-step trail; final σ must be exactly as unify builds it (new bindings consed in front)
  (check-true
   (judgment-holds
    (wf-trail-unify*s-to-sub
     ((u:0 =? (sym "a") (label "t1"))
      ((u:1 : u:0) =? ((sym "b") : (sym "a")) (label "t2")))
     (u:0 u:1)
     ()
     ((u:1 (sym "b")) (u:0 (sym "a"))))))

  (check-true
   (judgment-holds
    (wf-sub/wf+equiv-trail?
     ((u:1 (sym "b")) (u:0 (sym "a")))
     (u:0 u:1)
     ((u:0 =? (sym "a") (label "t1"))
      ((u:1 : u:0) =? ((sym "b") : (sym "a")) (label "t2"))))))
)


(module+ test
  (check-false
   (judgment-holds
    (wf-state? (state ((u:1 (sym "b")) (u:0 (sym "a")))
                      (u:0 u:1)
                      ((u:0 =? (sym "a") (label "t1")))
                      (label "σ")))))

  (check-false
   (judgment-holds
    (wf-state? (state ((u:1 (sym "b")) (u:0 (sym "a")))
                      (u:0 u:1)
                      ((u:1 =? (sym "b") (label "t2"))
                       (u:0 =? (sym "a") (label "t1")))
                      (label "σ")))))

  ;; empty tree
  (check-true (judgment-holds (wf-tree? (empty-tree) () ())))
  ;; goal/state node
  (check-true
   (judgment-holds
    (wf-tree?
      ((u:0 =? (sym "a") (label "t"))
       (state ((u:0 (sym "a")))
              (u:0)
              ((u:0 =? (sym "a") (label "t1")))
              (label "σ")))
      ()
	  (u:0))))
  ;; conjunction
  (check-true
   (judgment-holds
    (wf-tree?
      (((u:0 =? (sym "a") (label "t"))
       (state ((u:0 (sym "a")))
              (u:0)
              ((u:0 =? (sym "a") (label "t1")))
              (label "σ")))
       ×
       (succeed (label "fish"))
	   ())
      ()
	  ())))

  ;; whole program: no states and empty relations
  (check-true
   (judgment-holds
    (wf-config? (() () (empty-tree)))))

  ;; whole program: one state and empty relations
  (check-true
   (judgment-holds
    (wf-config?
     (()  ; Γ
      ((state ((u:0 (sym "a"))) (u:0) (((sym "a") =? u:0 (label "g1"))) (label "σ"))) ; ans*
      (empty-tree)))))                                ; s
)

(module+ test
  (require redex rackunit)

  ;; walk is idempotent
  (redex-check Core
    (t sub)
    (equal? (term (walk (walk t sub) sub)) (term (walk t sub))))

  ;; if unify succeeds, the results walk to the same thing
  (redex-check Core
    (t_1 t_2 sub c trail tag_1 tag_2)
    (implies
     (judgment-holds (wf-tree? ((t_1 =? t_2 tag_1) (state sub c trail tag_2)) () ()))
     (let ([sub^ (term (unify (walk t_1 sub) (walk t_2 sub) sub))])
       (or (equal? sub^ (term #f))
           (equal? (term (walk t_1 ,sub^))
                   (term (walk t_2 ,sub^)))))))

  ;; WF-guarded property: valid triangular subst property
  ;; TODO

)
