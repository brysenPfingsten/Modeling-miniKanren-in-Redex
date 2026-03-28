#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         (only-in "../languages/core-lang.rkt" c-append)
         "./core-wf.rkt")

(provide wf-goal/search-base?
         wf-frontier/search-base?
         wf-cfg/search-base?)

(check-redundancy #t)

(define-judgment-form
  search-base-seq-lang
  #:contract (wf-goal/search-base? g (x_1 ...) c)
  #:mode (wf-goal/search-base? I I I)
  [------------------ "trivial success wf/search-base"
   (wf-goal/search-base? (succeed tag) (x_1 ...) c)]
  [------------------ "trivial fail wf/search-base"
   (wf-goal/search-base? (fail tag) (x_1 ...) c)]
  [(where (u_old ...) c)
   (where (u_new ...) (fresh-lvars (x_1 ...) c))
   (wf-goal/search-base? g (x_1 ... x_2 ...) (u_new ... u_old ...))
   ------------------- "fresh-wf/search-base"
   (wf-goal/search-base? (∃ (x_1 ...) g tag) (x_2 ...) c)]
  [(wf-goal/search-base? g_1 (x_1 ...) c)
   (wf-goal/search-base? g_2 (x_1 ...) c)
   ------------------- "conj-wf/search-base"
   (wf-goal/search-base? (g_1 ∧ g_2 tag) (x_1 ...) c)]
  [(wf-goal/search-base? g_1 (x_1 ...) c)
   (wf-goal/search-base? g_2 (x_1 ...) c)
   ------------------- "disj-wf/search-base"
   (wf-goal/search-base? (g_1 ∨ g_2 tag) (x_1 ...) c)]
  [(wf-goal/search-base? g (x_1 ...) c)
   ------------------- "delay-goal-wf/search-base"
   (wf-goal/search-base? (suspend g tag) (x_1 ...) c)]
  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ------------------- "==-wf/search-base"
   (wf-goal/search-base? (t_1 =? t_2 tag) (x_1 ...) c)]
  [(wf-term? t_1 (x_1 ...) c)
   (wf-term? t_2 (x_1 ...) c)
   ------------------- "=/=-wf/search-base"
   (wf-goal/search-base? (t_1 != t_2 tag) (x_1 ...) c)])

(define-judgment-form
  search-base-seq-lang
  #:contract (wf-frontier/search-base? cfg c)
  #:mode (wf-frontier/search-base? I I)
  [------------------- "empty frontier residual is wf/search-base"
   (wf-frontier/search-base? (empty-tree) c)]
  [(wf-answer/core? search_i c)
   ------------------- "bare answer wf/search-base"
   (wf-frontier/search-base? search_i c)]
  [(wf-answer/core? promoted c)
   (wf-frontier/search-base? cfg_tail c)
   ------------------- "promoted stream node wf/search-base"
   (wf-frontier/search-base? (promoted + cfg_tail) c)]
  [(wf-frontier/search-base? cfg_tail c)
   ------------------- "bounced segment wf/search-base"
   (wf-frontier/search-base? (Bounced cfg_tail) c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-frontier/search-base? cfg_tail c_2)
   ------------------- "cfg freshened scope wf/search-base"
   (wf-frontier/search-base? (Freshened c_1 cfg_tail tag_1) c)]
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   (wf-goal/search-base? g () c_i)
   ------------------- "goal/state wf/search-base"
   (wf-frontier/search-base? (g (state sub dis c_i trail tag)) c)]
  [(lvars-same-members? c c_i)
   (wf-frontier/search-base? search_i c_i)
   (wf-goal/search-base? g () c_i)
   ------------------- "conj wf/search-base"
   (wf-frontier/search-base? (search_i × g c_i) c)]
  [(wf-frontier/search-base? search_1 c)
   (wf-frontier/search-base? search_2 c)
   ------------------- "disj wf/search-base"
   (wf-frontier/search-base? (search_1 <-+ search_2) c)]
  [(wf-frontier/search-base? delayed_i c)
   ------------------- "delay wf/search-base"
   (wf-frontier/search-base? (delay delayed_i) c)])

(define-judgment-form
  search-base-seq-lang
  #:contract (wf-cfg/search-base? cfg)
  #:mode (wf-cfg/search-base? I)
  [(wf-frontier/search-base? cfg ())
   ----------------------- "cfg-wf/search-base"
   (wf-cfg/search-base? cfg)])
