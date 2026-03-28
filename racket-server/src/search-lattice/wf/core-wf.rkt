#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./kernel.rkt")

(provide (all-from-out "./kernel.rkt")
         wf-goal/core?
         wf-answer/core?
         wf-frontier/core?
         wf-cfg/core?)

(check-redundancy #t)

(define-judgment-form
  core-lang
  #:contract (wf-goal/core? g (x_1 ...) c)
  #:mode (wf-goal/core? I I I)
  [------------------ "trivial success wf/core"
   (wf-goal/core? (succeed tag) (x_1 ...) c)]
  [------------------ "trivial fail wf/core"
   (wf-goal/core? (fail tag) (x_1 ...) c)]
  [(where (u_old ...) c)
   (where (u_new ...) (fresh-lvars (x_1 ...) c))
   (wf-goal/core? g (x_1 ... x_2 ...) (u_new ... u_old ...))
   ------------------- "fresh-wf/core"
   (wf-goal/core? (∃ (x_1 ...) g tag) (x_2 ...) c)]
  [(wf-goal/core? g_1 (x_1 ...) c)
   (wf-goal/core? g_2 (x_1 ...) c)
   ---------- "conj-wf/core"
   (wf-goal/core? (g_1 ∧ g_2 tag) (x_1 ...) c)]
  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ---------- "==-wf/core"
   (wf-goal/core? (t_1 =? t_2 tag) (x_1 ...) c)]
  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ---------- "=/=-wf/core"
   (wf-goal/core? (t_1 != t_2 tag) (x_1 ...) c)])

(define-judgment-form
  core-lang
  #:contract (wf-answer/core? search c)
  #:mode (wf-answer/core? I I)
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   ------------------- "raw answer/state wf/core"
   (wf-answer/core? (⊤ (state sub dis c_i trail tag)) c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-answer/core? search_tail c_2)
   ------------------- "answer-wrapper freshened wf/core"
   (wf-answer/core? (Freshened c_1 search_tail tag_1) c)])

(define-judgment-form
  core-lang
  #:contract (wf-frontier/core? search c)
  #:mode (wf-frontier/core? I I)
  [------------------- "empty frontier residual is wf/core"
   (wf-frontier/core? (empty-tree) c)]
  [(wf-answer/core? search_i c)
   ------------------- "bare answer wf/core"
   (wf-frontier/core? search_i c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-frontier/core? search_i c_2)
   ------------------- "search freshened scope wf/core"
   (wf-frontier/core? (Freshened c_1 search_i tag_1) c)]
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   (wf-goal/core? g () c_i)
   ------------------- "goal/state frontier wf/core"
   (wf-frontier/core? (g (state sub dis c_i trail tag)) c)]
  [(lvars-same-members? c c_i)
   (wf-frontier/core? search_i c_i)
   (wf-goal/core? g () c_i)
   ------------------- "conj frontier wf/core"
   (wf-frontier/core? (search_i × g c_i) c)])

(define-judgment-form
  core-lang
  #:contract (wf-cfg/core? search)
  #:mode (wf-cfg/core? I)
  [(wf-frontier/core? search ())
   ----------------------- "cfg-wf/core"
   (wf-cfg/core? search)])
