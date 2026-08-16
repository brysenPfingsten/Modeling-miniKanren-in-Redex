#lang racket

(require "./decomposition.rkt"
         "./language.rkt")

(provide (struct-out machine-transition)
         initial-machine
         readback
         refocus-work
         refocus-frontier
         refocus-contract
         machine-step
         machine-trace)

;; A machine state is exactly one of the two indexed decomposition results:
;; DecWork or DecFrontier.  This structure carries a transition between states;
;; it is not another state constructor.
(struct machine-transition (name owner next) #:transparent)

(define (settled-success? work)
  (match work
    [`(Returned ,_state) #t]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (settled-success? inner)]
    [_ #f]))

(define (settled-choice? work)
  (match work
    [`(DisjL ,active ,_alternate)
     (settled-success? active)]
    [`(DisjR ,_alternate ,active)
     (settled-success? active)]
    [_ #f]))

;; R is the derived class of completed work observations that must be offered
;; to the nearest retained frame:
;;
;;   R ::= S | Dead | (PendingDelay W) | (DisjL S W) | (DisjR W S)
;;
;; It is a grammatical subset of W, not a reified W/F sort or a state tag.
(define (settled-work-outcome? work)
  (or (settled-success? work)
      (match work
        ['Dead #t]
        [`(PendingDelay ,_inner) #t]
        [(? settled-choice?) #t]
        [_ #f])))

;; These predicates are the focus equations derived at checkpoint 2.  They are
;; repeated here so refocusing is visibly a transformation of decomposition,
;; rather than a call back to the root decomposer.
(define (work-fresh-redex? inner)
  (match inner
    ['Dead #t]
    [`(PendingDelay ,_work) #t]
    [(? settled-choice?) #t]
    [_ #f]))

(define (conjunction-redex? left)
  (or (settled-success? left)
      (match left
        ['Dead #t]
        [`(PendingDelay ,_work) #t]
        [(? settled-choice?) #t]
        [_ #f])))

(define (active-choice-redex? active)
  (match active
    ['Dead #t]
    [`(PendingDelay ,_work) #t]
    [(? settled-choice?) #t]
    [_ #f]))

(define (work-redex? work)
  (match work
    [`(Work ,_goal ,_state) #t]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (work-fresh-redex? inner)]
    [`(Conj ,left ,_goal)
     (conjunction-redex? left)]
    [`(DisjL ,left ,_right)
     (active-choice-redex? left)]
    [`(DisjR ,_left ,right)
     (active-choice-redex? right)]
    [_ #f]))

;; More has priority over the local W rules.  In particular, every WorkFresh
;; immediately below More is exposed as FrontierFresh before its child is
;; inspected.
(define (more-redex? work)
  (match work
    [`(WorkFresh ,_intro ,_inner ,_tag) #t]
    [`(Returned ,_state) #t]
    ['Dead #t]
    [`(PendingDelay ,_inner) #t]
    [`(DisjL ,active ,_alternate)
     (settled-success? active)]
    [`(DisjR ,_alternate ,active)
     (settled-success? active)]
    [_ #f]))

;; Contexts are nearest-frame-first.  Once a replacement has become a settled
;; work outcome, resume-work rebuilds one parent and searches again.  It never
;; reconstructs the root frontier.
(define (resume-work work work-context frontier-context)
  (match work-context
    ['ww-hole
     (DecWork work `(wf-more ww-hole ,frontier-context))]
    [`(ww-fresh ,intro ,tag ,outer)
     (search-work `(WorkFresh ,intro ,work ,tag)
                  outer
                  frontier-context)]
    [`(ww-conj ,goal ,outer)
     (search-work `(Conj ,work ,goal)
                  outer
                  frontier-context)]
    [`(ww-disj-left ,right ,outer)
     (search-work `(DisjL ,work ,right)
                  outer
                  frontier-context)]
    [`(ww-disj-right ,left ,outer)
     (search-work `(DisjR ,left ,work)
                  outer
                  frontier-context)]))

;; search-work is the fused down/up decomposition.  The More test must precede
;; local W focus when no WW frame remains: both can recognize a WorkFresh, but
;; the source gives the boundary rule priority.
(define (search-work work work-context frontier-context)
  (cond
    [(and (equal? work-context 'ww-hole)
          (more-redex? work))
     (DecWork work `(wf-more ww-hole ,frontier-context))]
    [(work-redex? work)
     (DecWork work `(wf-more ,work-context ,frontier-context))]
    [(settled-work-outcome? work)
     (resume-work work work-context frontier-context)]
    [else
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (search-work inner
                     `(ww-fresh ,intro ,tag ,work-context)
                     frontier-context)]
       [`(Conj ,left ,goal)
        (search-work left
                     `(ww-conj ,goal ,work-context)
                     frontier-context)]
       [`(DisjL ,left ,right)
        (search-work left
                     `(ww-disj-left ,right ,work-context)
                     frontier-context)]
       [`(DisjR ,left ,right)
        (search-work right
                     `(ww-disj-right ,left ,work-context)
                     frontier-context)]
       [_
        ;; As in decomposition, retain an unsupported terminal W as a stuck
        ;; focus rather than inventing a transition.
        (DecWork work
                 `(wf-more ,work-context ,frontier-context))])]))

(define (refocus-work replacement context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (search-work replacement work-context frontier-context)]
    [_
     (raise-argument-error 'refocus-work
                           "wf-context-in-language?"
                           context)]))

;; Refocusing a frontier contractum descends through only the new F fragment
;; and extends the retained F-to-F context.  At More it enters the same
;; priority-aware W search used by ContractWork.
(define (refocus-frontier replacement context)
  (match replacement
    [`(Emit ,answer ,rest)
     (refocus-frontier rest `(ff-emit ,answer ,context))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (refocus-frontier
      rest
      `(ff-frontier-fresh ,intro ,tag ,context))]
    [`(Forced ,rest)
     (refocus-frontier rest `(ff-forced ,context))]
    [`(More ,work)
     (search-work work 'ww-hole context)]
    ['Done
     (DecFrontier 'Done context)]
    [`(Last ,answer)
     (DecFrontier `(Last ,answer) context)]
    [_
     (raise-argument-error 'refocus-frontier
                           "frontier-in-language?"
                           replacement)]))

(define (refocus-contract contraction-result)
  (match contraction-result
    [(ContractWork _name _owner replacement context)
     (refocus-work replacement context)]
    [(ContractFrontier _name _owner replacement context)
     (refocus-frontier replacement context)]
    [_
     (raise-argument-error
      'refocus-contract
      "(or/c ContractWork? ContractFrontier?)"
      contraction-result)]))

;; Root decomposition is used once, to enter the machine.  Neither machine-step
;; nor any refocus function calls it.
(define (initial-machine frontier)
  (decompose frontier))

;; Readback is observational and is not part of the transition path.
(define (readback machine)
  (match machine
    [(DecWork focus context)
     (plug-wf focus context)]
    [(DecFrontier focus context)
     (plug-ff focus context)]
    [_
     (raise-argument-error 'readback
                           "(or/c DecWork? DecFrontier?)"
                           machine)]))

(define (machine-step machine)
  (match (contract machine)
    [#f #f]
    [(and contraction-result
          (ContractWork name owner _replacement _context))
     (machine-transition name
                         owner
                         (refocus-contract contraction-result))]
    [(and contraction-result
          (ContractFrontier name owner _replacement _context))
     (machine-transition name
                         owner
                         (refocus-contract contraction-result))]))

(define (machine-trace machine
                       [limit 256]
                       [steps '()]
                       [machines (list machine)])
  (match (machine-step machine)
    [#f
     (values (reverse steps)
             machine
             (if (value-in-language? (readback machine))
                 'value
                 'stuck)
             (reverse machines))]
    [_ #:when (zero? limit)
     (values (reverse steps) machine 'cap (reverse machines))]
    [(machine-transition name owner next)
     (machine-trace next
                    (sub1 limit)
                    (cons (list name owner) steps)
                    (cons next machines))]))
