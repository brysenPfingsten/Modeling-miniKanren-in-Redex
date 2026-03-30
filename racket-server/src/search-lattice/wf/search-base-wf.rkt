#lang racket

(require redex/reduction-semantics
         "../languages/search-base-lang.rkt"
         (only-in "../languages/core-lang.rkt" c-append)
         "./core-wf.rkt")

(provide wf-goal/search-base?
         wf-work/search-base?
         wf-resolved/search-base?
         wf-search/search-base?
         wf-frontier/search-base?
         wf-cfg/search-base?)

(check-redundancy #t)

(define-judgment-form
  search-base-lang
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
  search-base-lang
  #:contract (wf-resolved/search-base? search c)
  #:mode (wf-resolved/search-base? I I)
  [------------------- "empty frontier residual is wf/search-base"
   (wf-resolved/search-base? (empty-tree) c)]
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   ------------------- "raw answer/state wf/search-base"
   (wf-resolved/search-base? (⊤ (state sub dis c_i trail tag)) c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-resolved/search-base? search_tail c_2)
   ------------------- "resolved freshened scope wf/search-base"
   (wf-resolved/search-base? (Freshened c_1 search_tail tag_1) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-work/search-base? runnable-search c)
  #:mode (wf-work/search-base? I I)
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-work/search-base? runnable-search_tail c_2)
   ------------------- "work freshened scope wf/search-base"
   (wf-work/search-base? (Freshened c_1 runnable-search_tail tag_1) c)]
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   (wf-goal/search-base? g () c_i)
   ------------------- "goal/state wf/search-base"
   (wf-work/search-base? (g (state sub dis c_i trail tag)) c)]
  [(lvars-same-members? c c_i)
   (wf-frontier/search-base? search_i c_i)
   (wf-goal/search-base? g () c_i)
   ------------------- "conj wf/search-base"
   (wf-work/search-base? (search_i × g c_i) c)]
  [(wf-frontier/search-base? search_1 c)
   (wf-frontier/search-base? search_2 c)
   ------------------- "disj wf/search-base"
   (wf-work/search-base? (search_1 <-+ search_2) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-search/search-base? search c)
  #:mode (wf-search/search-base? I I)
  [(wf-resolved/search-base? search_i c)
   ------------------- "resolved search wf/search-base"
   (wf-search/search-base? search_i c)]
  [(wf-work/search-base? runnable-search_i c)
   ------------------- "work search wf/search-base"
   (wf-search/search-base? runnable-search_i c)]
  [(wf-work/search-base? runnable-search_i c)
   ------------------- "delay search wf/search-base"
   (wf-search/search-base? (delay runnable-search_i) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-promoted/search-base? promoted c)
  #:mode (wf-promoted/search-base? I I)
  [(wf-state/at-scope? (state sub dis c_i trail tag) c)
   ------------------- "raw promoted/state wf/search-base"
   (wf-promoted/search-base? (⊤ (state sub dis c_i trail tag)) c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-promoted/search-base? promoted_tail c_2)
   ------------------- "promoted freshened scope wf/search-base"
   (wf-promoted/search-base? (Freshened c_1 promoted_tail tag_1) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-cfg-root/search-base? cfg-root c)
  #:mode (wf-cfg-root/search-base? I I)
  [(wf-search/search-base? search_i c)
   ------------------- "search cfg root wf/search-base"
   (wf-cfg-root/search-base? search_i c)]
  [(wf-promoted/search-base? promoted_i c)
   (wf-frontier/search-base? cfg_tail c)
   ------------------- "promoted stream node wf/search-base"
   (wf-cfg-root/search-base? (promoted_i + cfg_tail) c)]
  [(wf-frontier/search-base? cfg_tail c)
   ------------------- "bounced cfg root wf/search-base"
   (wf-cfg-root/search-base? (Bounced cfg_tail) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-frontier/search-base? cfg c)
  #:mode (wf-frontier/search-base? I I)
  [(wf-cfg-root/search-base? cfg-root_i c)
   ------------------- "cfg root wf/search-base"
   (wf-frontier/search-base? cfg-root_i c)]
  [(lvars-fresh-extension? c_1 c)
   (where c_2 (c-append c_1 c))
   (wf-frontier/search-base? cfg_tail c_2)
   ------------------- "cfg freshened scope wf/search-base"
   (wf-frontier/search-base? (Freshened c_1 cfg_tail tag_1) c)])

(define-judgment-form
  search-base-lang
  #:contract (wf-cfg/search-base? cfg)
  #:mode (wf-cfg/search-base? I)
  [(wf-frontier/search-base? cfg ())
   ----------------------- "cfg-wf/search-base"
   (wf-cfg/search-base? cfg)])
