#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "./kernel-toy.rkt")

(provide source-red
         initial-tree
         redex-name->label
         label->redex-name)

;; The label maps are explicit derivation data.  A Redex rule name carries both
;; the frozen source name and its provenance owner.
(define-metafunction redex-column-source-lang
  redex-name->label : string -> ell
  [(redex-name->label "expose-frontier-fresh/core") (expose-frontier-fresh core)]
  [(redex-name->label "finish-success/core") (finish-success core)]
  [(redex-name->label "finish-failure/core") (finish-failure core)]
  [(redex-name->label "force-delay/delay") (force-delay delay)]
  [(redex-name->label "commit-choice-answer/disj") (commit-choice-answer disj)]
  [(redex-name->label "commit-right-choice-answer/search-join") (commit-right-choice-answer search-join)]
  [(redex-name->label "work-succeed/core") (work-succeed core)]
  [(redex-name->label "work-fail/core") (work-fail core)]
  [(redex-name->label "work-put/core") (work-put core)]
  [(redex-name->label "allocate-fresh/core") (allocate-fresh core)]
  [(redex-name->label "expand-conjunction/core") (expand-conjunction core)]
  [(redex-name->label "expand-disjunction/disj") (expand-disjunction disj)]
  [(redex-name->label "suspend-goal/delay") (suspend-goal delay)]
  [(redex-name->label "expose-choice-through-work-fresh/disj") (expose-choice-through-work-fresh disj)]
  [(redex-name->label "expose-choice-through-work-fresh/search-join") (expose-choice-through-work-fresh search-join)]
  [(redex-name->label "erase-dead-fresh/core") (erase-dead-fresh core)]
  [(redex-name->label "bubble-delay-through-fresh/delay") (bubble-delay-through-fresh delay)]
  [(redex-name->label "conj-return/core") (conj-return core)]
  [(redex-name->label "conj-fail/core") (conj-fail core)]
  [(redex-name->label "bubble-delay-through-conj/delay") (bubble-delay-through-conj delay)]
  [(redex-name->label "late-distribute-settled/disj") (late-distribute-settled disj)]
  [(redex-name->label "late-distribute-right-settled/search-join") (late-distribute-right-settled search-join)]
  [(redex-name->label "skip-left-failure/disj") (skip-left-failure disj)]
  [(redex-name->label "rail-enter-right/search-join") (rail-enter-right search-join)]
  [(redex-name->label "reassociate-left-result/disj") (reassociate-left-result disj)]
  [(redex-name->label "skip-right-failure/search-join") (skip-right-failure search-join)]
  [(redex-name->label "rail-return-left/search-join") (rail-return-left search-join)]
  [(redex-name->label "reassociate-right-result/search-join") (reassociate-right-result search-join)])

(define-metafunction redex-column-source-lang
  label->redex-name : ell -> string
  [(label->redex-name (expose-frontier-fresh core)) "expose-frontier-fresh/core"]
  [(label->redex-name (finish-success core)) "finish-success/core"]
  [(label->redex-name (finish-failure core)) "finish-failure/core"]
  [(label->redex-name (force-delay delay)) "force-delay/delay"]
  [(label->redex-name (commit-choice-answer disj)) "commit-choice-answer/disj"]
  [(label->redex-name (commit-right-choice-answer search-join)) "commit-right-choice-answer/search-join"]
  [(label->redex-name (work-succeed core)) "work-succeed/core"]
  [(label->redex-name (work-fail core)) "work-fail/core"]
  [(label->redex-name (work-put core)) "work-put/core"]
  [(label->redex-name (allocate-fresh core)) "allocate-fresh/core"]
  [(label->redex-name (expand-conjunction core)) "expand-conjunction/core"]
  [(label->redex-name (expand-disjunction disj)) "expand-disjunction/disj"]
  [(label->redex-name (suspend-goal delay)) "suspend-goal/delay"]
  [(label->redex-name (expose-choice-through-work-fresh disj)) "expose-choice-through-work-fresh/disj"]
  [(label->redex-name (expose-choice-through-work-fresh search-join)) "expose-choice-through-work-fresh/search-join"]
  [(label->redex-name (erase-dead-fresh core)) "erase-dead-fresh/core"]
  [(label->redex-name (bubble-delay-through-fresh delay)) "bubble-delay-through-fresh/delay"]
  [(label->redex-name (conj-return core)) "conj-return/core"]
  [(label->redex-name (conj-fail core)) "conj-fail/core"]
  [(label->redex-name (bubble-delay-through-conj delay)) "bubble-delay-through-conj/delay"]
  [(label->redex-name (late-distribute-settled disj)) "late-distribute-settled/disj"]
  [(label->redex-name (late-distribute-right-settled search-join)) "late-distribute-right-settled/search-join"]
  [(label->redex-name (skip-left-failure disj)) "skip-left-failure/disj"]
  [(label->redex-name (rail-enter-right search-join)) "rail-enter-right/search-join"]
  [(label->redex-name (reassociate-left-result disj)) "reassociate-left-result/disj"]
  [(label->redex-name (skip-right-failure search-join)) "skip-right-failure/search-join"]
  [(label->redex-name (rail-return-left search-join)) "rail-return-left/search-join"]
  [(label->redex-name (reassociate-right-result search-join)) "reassociate-right-result/search-join"])

(define-metafunction redex-column-source-lang
  initial-tree : g -> F
  [(initial-tree g) (More (Work g (state unit)))])

(define-metafunction redex-column-source-lang
  settled-choice-success : SC -> S
  [(settled-choice-success (DisjL S W)) S]
  [(settled-choice-success (DisjR W S)) S])

(define-metafunction redex-column-source-lang
  settled-choice-alternate : SC -> W
  [(settled-choice-alternate (DisjL S W)) W]
  [(settled-choice-alternate (DisjR W S)) W])

;; Every clause is a source control rule.  The actual-hole context families
;; choose the active path; host Racket is used only through kernel metafunctions.
(define source-red
  (reduction-relation
   redex-column-source-lang
   #:domain F

   [--> (in-hole FF (More (WorkFresh intro W tag)))
        (in-hole FF (FrontierFresh intro (More W) tag))
        "expose-frontier-fresh/core"]
   [--> (in-hole FF (More (Returned st)))
        (in-hole FF (Last (Answer st)))
        "finish-success/core"]
   [--> (in-hole FF (More Dead))
        (in-hole FF Done)
        "finish-failure/core"]
   [--> (in-hole FF (More (PendingDelay W)))
        (in-hole FF (Forced (More W)))
        "force-delay/delay"]
   [--> (in-hole FF (More (DisjL S W)))
        (in-hole FF (Emit (kernel-freeze S) (More W)))
        "commit-choice-answer/disj"]
   [--> (in-hole FF (More (DisjR W S)))
        (in-hole FF (Emit (kernel-freeze S) (More W)))
        "commit-right-choice-answer/search-join"]

   [--> (in-hole WF (Work (succeed tag) st))
        (in-hole WF (Returned st))
        "work-succeed/core"]
   [--> (in-hole WF (Work (fail tag) st))
        (in-hole WF Dead)
        "work-fail/core"]
   [--> (in-hole WF (Work (put p tag) st))
        (in-hole WF (Returned (kernel-put p st)))
        "work-put/core"]
   [--> (name F_whole
              (in-hole WF
                       (Work (fresh (x ...) g tag_fresh) st)))
        (in-hole WF
                 (WorkFresh (u_new ...)
                            (Work g_new st)
                            tag_fresh))
        (where (u_new ...) (kernel-fresh (x ...) F_whole))
        (where g_new
               (kernel-substitute
                g
                ((x u_new) ...)))
        "allocate-fresh/core"]
   [--> (in-hole WF (Work (conj g_1 g_2 tag) st))
        (in-hole WF (Conj (Work g_1 st) g_2))
        "expand-conjunction/core"]
   [--> (in-hole WF (Work (disj g_1 g_2 tag) st))
        (in-hole WF (DisjL (Work g_1 st) (Work g_2 st)))
        "expand-disjunction/disj"]
   [--> (in-hole WF (Work (suspend g tag) st))
        (in-hole WF (PendingDelay (Work g st)))
        "suspend-goal/delay"]

   ;; WF+ excludes a WorkFresh immediately below More.  These are therefore
   ;; precisely the branch-local rules; global WorkFresh uses the first rule.
   [--> (in-hole WF+
                 (WorkFresh intro (DisjL S W) tag))
        (in-hole WF+
                 (DisjL (WorkFresh intro S tag)
                        (WorkFresh intro W tag)))
        "expose-choice-through-work-fresh/disj"]
   [--> (in-hole WF+
                 (WorkFresh intro (DisjR W S) tag))
        (in-hole WF+
                 (DisjR (WorkFresh intro W tag)
                        (WorkFresh intro S tag)))
        "expose-choice-through-work-fresh/search-join"]
   [--> (in-hole WF+ (WorkFresh intro Dead tag))
        (in-hole WF+ Dead)
        "erase-dead-fresh/core"]
   [--> (in-hole WF+
                 (WorkFresh intro (PendingDelay W) tag))
        (in-hole WF+
                 (PendingDelay (WorkFresh intro W tag)))
        "bubble-delay-through-fresh/delay"]

   [--> (in-hole WF (Conj S g))
        (in-hole WF (kernel-resume S g))
        "conj-return/core"]
   [--> (in-hole WF (Conj Dead g))
        (in-hole WF Dead)
        "conj-fail/core"]
   [--> (in-hole WF (Conj (PendingDelay W) g))
        (in-hole WF (PendingDelay (Conj W g)))
        "bubble-delay-through-conj/delay"]
   [--> (in-hole WF (Conj (DisjL S W) g))
        (in-hole WF
                 (DisjL (kernel-resume S g)
                        (Conj W g)))
        "late-distribute-settled/disj"]
   [--> (in-hole WF (Conj (DisjR W S) g))
        (in-hole WF
                 (DisjR (Conj W g)
                        (kernel-resume S g)))
        "late-distribute-right-settled/search-join"]

   [--> (in-hole WF (DisjL Dead W))
        (in-hole WF W)
        "skip-left-failure/disj"]
   [--> (in-hole WF (DisjL (PendingDelay W_1) W_2))
        (in-hole WF (PendingDelay (DisjR W_1 W_2)))
        "rail-enter-right/search-join"]
   [--> (in-hole WF (DisjL SC W_2))
        (in-hole WF
                 (DisjL (settled-choice-success SC)
                        (DisjL (settled-choice-alternate SC) W_2)))
        "reassociate-left-result/disj"]

   [--> (in-hole WF (DisjR W Dead))
        (in-hole WF W)
        "skip-right-failure/search-join"]
   [--> (in-hole WF (DisjR W_1 (PendingDelay W_2)))
        (in-hole WF (PendingDelay (DisjL W_1 W_2)))
        "rail-return-left/search-join"]
   [--> (in-hole WF (DisjR W_1 SC))
        (in-hole WF
                 (DisjR
                  (DisjR W_1 (settled-choice-alternate SC))
                  (settled-choice-success SC)))
        "reassociate-right-result/search-join"]))
