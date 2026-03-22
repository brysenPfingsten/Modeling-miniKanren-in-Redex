#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./kernel.rkt")

(provide (all-from-out "./kernel.rkt")
         wf-goal/core?
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
  #:contract (wf-frontier/core? f c)
  #:mode (wf-frontier/core? I I)
  [------------------- "empty frontier residual is wf/core"
   (wf-frontier/core? (empty-tree) c)]
  [(lvars-same-members? c c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   (wf-dis? dis c_i)
   ------------------- "raw answer/state wf/core"
   (wf-frontier/core? (⊤ (state sub dis c_i trail tag)) c)]
  [(lvars-same-members? c c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   (wf-dis? dis c_i)
   (wf-frontier/core? f_tail c)
   ------------------- "observable answer prefix wf/core"
   (wf-frontier/core? ((⊤ (state sub dis c_i trail tag)) + f_tail) c)]
  [(wf-frontier/core? f_tail c)
   ------------------- "bounced prefix wf/core"
   (wf-frontier/core? (Bounced + f_tail) c)]
  [(lvars-fresh-extension? c_1 c_2)
   (where c_3 (c-append c_1 c_2))
   (wf-frontier/core? f_obs c_3)
   (wf-frontier/core? f_tail c_2)
   ------------------- "freshened observable prefix wf/core"
   (wf-frontier/core? ((Freshened c_1 f_obs) + f_tail) c_2)]
  [(lvars-fresh-extension? c_1 c_2)
   (where c_3 (c-append c_1 c_2))
   (wf-frontier/core? f_inner c_3)
   ------------------- "freshened frontier wf/core"
   (wf-frontier/core? (Freshened c_1 f_inner) c_2)]
  [(lvars-same-members? c c_i)
   (wf-goal/core? g () c_i)
   (wf-sub/wf+equiv-trail? sub c_i trail)
   (wf-dis? dis c_i)
   ------------------- "goal/state frontier wf/core"
   (wf-frontier/core? (g (state sub dis c_i trail tag)) c)]
  [(lvars-same-members? c c_i)
   (wf-frontier/core? f c_i)
   (wf-goal/core? g () c_i)
   ------------------- "conj frontier wf/core"
   (wf-frontier/core? (f × g c_i) c)])

(define-judgment-form
  core-lang
  #:contract (wf-cfg/core? cfg)
  #:mode (wf-cfg/core? I)
  [(wf-frontier/core? f ())
   ----------------------- "cfg-wf/core"
   (wf-cfg/core? f)])
