#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "./kernel-toy.rkt"
         "./labels.rkt")

(provide source-red
         initial-tree
         (all-from-out "./labels.rkt"))

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
