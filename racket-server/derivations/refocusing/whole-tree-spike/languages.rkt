#lang racket

(require redex/reduction-semantics)

(provide whole-core-lang
         whole-delay-lang
         whole-disj-lang
         whole-search-lang
         goal-in-language?
         tree-in-language?
         value-in-language?
         context-in-language?)

(check-redundancy #t)

;; The control spike keeps logic-state effects opaque. `put` supplies distinct
;; payloads so answer order and commitment can be tested without committing the
;; source calculus to a particular unification representation. Source fresh
;; binds x variables; its reduction allocates the u variables stored below.
(define-language whole-core-lang
  [p (sym string)
     (nat number)
     boolean
     (str string)
     unit
     x
     u
     (p : p)]
  [st (state p)]
  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [lexical (x ...)]
  [intro (u ...)]
  [tag (label string)]

  [g (succeed tag)
     (fail tag)
     (put p tag)
     (fresh lexical g tag)
     (conj g g tag)]

  ;; Core owns ordinary terminal answers. Disjunction extends this payload
  ;; language with ownership evidence for answers emitted from local branches.
  [A (Answer st)]

  [W (Work g st)
     (Returned st)
     Dead
     (WorkFresh intro W tag)
     (Conj W g)]

  ;; Every F has one rightward terminal: More while work remains, Done when a
  ;; residual produces no answer, or Last when it terminates directly with one.
  [F (More W)
     Done
     (Last A)
     (FrontierFresh intro F tag)]

  [V Done
     (Last A)
     (FrontierFresh intro V tag)]

  ;; Contexts are part of the presentation. The list is innermost first.
  [frame (fresh-frame intro tag)
         (conj-frame g)
         more-frame
         (frontier-fresh-frame intro tag)]
  [C (frame ...)])

(define-extended-language whole-delay-lang whole-core-lang
  [g ....
     (suspend g tag)]
  [W ....
     (PendingDelay W)]
  [F ....
     (Forced F)]
  [V ....
     (Forced V)]
  [frame ....
         forced-frame])

(define-extended-language whole-disj-lang whole-core-lang
  [A ....
     (AnswerFresh intro A tag)]
  [g ....
     (disj g g tag)]
  [W ....
     (DisjL W W)]
  [F ....
     (Emit A F)]
  [V ....
     (Emit A V)]
  [frame ....
         (disj-left-frame W)
         (emit-frame A)])

(define-union-language whole-search-base-lang
  whole-delay-lang
  whole-disj-lang)

;; DisjR is owned by the delay/disjunction join. It records that rail
;; scheduling is currently advancing the right branch. Plain DFS shares this
;; carrier but never constructs the form.
(define-extended-language whole-search-lang whole-search-base-lang
  [W ....
     (DisjR W W)]
  [frame ....
         (disj-right-frame W)])

(define (goal-in-language? index term)
  (match index
    ['core (redex-match? whole-core-lang g term)]
    ['delay (redex-match? whole-delay-lang g term)]
    ['disj (redex-match? whole-disj-lang g term)]
    ['search (redex-match? whole-search-lang g term)]
    [_ #f]))

(define (tree-in-language? index term)
  (match index
    ['core (redex-match? whole-core-lang F term)]
    ['delay (redex-match? whole-delay-lang F term)]
    ['disj (redex-match? whole-disj-lang F term)]
    ['search (redex-match? whole-search-lang F term)]
    [_ #f]))

(define (value-in-language? index term)
  (match index
    ['core (redex-match? whole-core-lang V term)]
    ['delay (redex-match? whole-delay-lang V term)]
    ['disj (redex-match? whole-disj-lang V term)]
    ['search (redex-match? whole-search-lang V term)]
    [_ #f]))

(define (context-in-language? index term)
  (match index
    ['core (redex-match? whole-core-lang C term)]
    ['delay (redex-match? whole-delay-lang C term)]
    ['disj (redex-match? whole-disj-lang C term)]
    ['search (redex-match? whole-search-lang C term)]
    [_ #f]))
